package site.thaonv.voca.ai;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import reactor.core.Disposable;

import site.thaonv.voca.ai.AiConfigResolver.LlmConfig;
import site.thaonv.voca.user.UserPrincipal;

import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * v1-compatible raw LLM proxy. The web app builds messages client-side (with @voca/core prompts) and
 * streams the provider's SSE back through here — the same contract v1 used against the Node bridge,
 * but JWT-authenticated and with the API key resolved server-side (or from client settings).
 */
@RestController
@RequestMapping("/api")
public class ChatController {

    private static final Logger log = LoggerFactory.getLogger(ChatController.class);

    private final LlmClient llm;
    private final AiConfigResolver resolver;

    public ChatController(LlmClient llm, AiConfigResolver resolver) {
        this.llm = llm;
        this.resolver = resolver;
    }

    public record ChatRequest(String model, List<Map<String, Object>> messages, Map<String, Object> settings) {
    }

    @PostMapping(value = "/chat/completions", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter chat(@RequestBody ChatRequest req, @AuthenticationPrincipal UserPrincipal principal) {
        LlmConfig cfg = resolveConfig(principal.id(), req);
        SseEmitter emitter = new SseEmitter(180_000L);
        // The upstream WebClient stream runs on a reactive (reactor-http-nio) thread while the SSE
        // response lives on the servlet container. A terminal signal can race with a trailing send
        // (or the provider closes the socket right after [DONE]), which previously escalated to
        // completeWithError() and reset an already-committed response — the client saw "network error"
        // even though it had received every chunk. Guard the terminal action so it runs exactly once,
        // and once any bytes are on the wire always close cleanly (an error status is impossible then).
        AtomicBoolean done = new AtomicBoolean(false);
        AtomicBoolean sentAny = new AtomicBoolean(false);
        Disposable[] sub = new Disposable[1];
        sub[0] = llm.streamRawChunks(cfg, req.messages()).subscribe(
                chunk -> {
                    if (done.get()) {
                        return;
                    }
                    try {
                        emitter.send(SseEmitter.event().data(chunk));
                        sentAny.set(true);
                    } catch (Exception e) {
                        // Client went away or the response is already closed — stop quietly.
                        finish(emitter, done, sentAny, e);
                    }
                },
                error -> finish(emitter, done, sentAny, error),
                () -> finish(emitter, done, sentAny, null));
        emitter.onCompletion(() -> sub[0].dispose());
        emitter.onTimeout(() -> {
            sub[0].dispose();
            finish(emitter, done, sentAny, null);
        });
        emitter.onError(e -> sub[0].dispose());
        return emitter;
    }

    /** Terminates the SSE response exactly once; never resets a stream that already delivered data. */
    private void finish(SseEmitter emitter, AtomicBoolean done, AtomicBoolean sentAny, Throwable error) {
        if (!done.compareAndSet(false, true)) {
            return;
        }
        try {
            if (error != null && !sentAny.get()) {
                log.warn("chat proxy error (no data sent): {}", error.toString());
                emitter.completeWithError(error);
            } else {
                if (error != null) {
                    log.warn("chat proxy stream ended after streaming data: {}", error.toString());
                }
                emitter.complete();
            }
        } catch (Exception ignored) {
            /* emitter already finalised by the container */
        }
    }

    private LlmConfig resolveConfig(Long userId, ChatRequest req) {
        // v1 sends AI settings in the body; honour them when they carry a usable base URL + key.
        if (req.settings() != null) {
            String base = str(req.settings().get("baseURL"));
            String key = str(req.settings().get("apiKey"));
            String model = str(req.settings().get("model"));
            if (base != null && !base.isBlank() && key != null && !key.isBlank()) {
                return new LlmConfig(base.replaceAll("/+$", ""), key, model != null && !model.isBlank() ? model : "gpt-4o-mini");
            }
        }
        LlmConfig resolved = resolver.resolveLlm(userId);
        if (req.model() != null && !req.model().isBlank()) {
            return new LlmConfig(resolved.baseUrl(), resolved.apiKey(), req.model());
        }
        return resolved;
    }

    private static String str(Object o) {
        return o == null ? null : String.valueOf(o);
    }
}
