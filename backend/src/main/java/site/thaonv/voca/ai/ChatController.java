package site.thaonv.voca.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.reactive.function.client.WebClientResponseException;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import reactor.core.Disposable;

import site.thaonv.voca.ai.AiConfigResolver.LlmConfig;
import site.thaonv.voca.user.UserPrincipal;

import java.util.LinkedHashMap;
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
    private final ObjectMapper mapper;

    public ChatController(LlmClient llm, AiConfigResolver resolver, ObjectMapper mapper) {
        this.llm = llm;
        this.resolver = resolver;
        this.mapper = mapper;
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
                // Upstream failed before any content. Surface a readable message AS the assistant's
                // reply (a normal SSE content chunk) instead of resetting the stream into an opaque 500.
                log.warn("chat proxy error (no data sent): {}", error.toString());
                try {
                    emitter.send(SseEmitter.event().data(errorChunk(llmErrorMessage(error))));
                } catch (Exception ignored) {
                    /* client already gone */
                }
                emitter.complete();
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

    /** A human-readable reason for an upstream LLM failure. */
    private static String llmErrorMessage(Throwable error) {
        if (error instanceof WebClientResponseException w) {
            int s = w.getStatusCode().value();
            if (s == 401 || s == 403) {
                return "⚠️ Không gọi được LLM: nhà cung cấp từ chối xác thực (" + s
                        + "). Kiểm tra lại API key trong Settings → Kết nối AI.";
            }
            if (s == 429) {
                return "⚠️ Không gọi được LLM: bị giới hạn tần suất (429). Thử lại sau ít phút.";
            }
            return "⚠️ Không gọi được LLM: nhà cung cấp trả lỗi " + s + ".";
        }
        return "⚠️ Không gọi được LLM (" + error.getClass().getSimpleName()
                + "). Thử lại hoặc kiểm tra cấu hình AI.";
    }

    /** Builds an OpenAI-style SSE chunk whose delta content is the given message. */
    private String errorChunk(String message) {
        Map<String, Object> delta = new LinkedHashMap<>();
        delta.put("content", message);
        Map<String, Object> choice = new LinkedHashMap<>();
        choice.put("index", 0);
        choice.put("delta", delta);
        choice.put("finish_reason", "stop");
        Map<String, Object> chunk = new LinkedHashMap<>();
        chunk.put("choices", List.of(choice));
        try {
            return mapper.writeValueAsString(chunk);
        } catch (Exception e) {
            return "{\"choices\":[{\"delta\":{\"content\":\"LLM error\"}}]}";
        }
    }

    private LlmConfig resolveConfig(Long userId, ChatRequest req) {
        // Keys are server-side per user — the authoritative source. We intentionally ignore any
        // apiKey the browser may still carry in its settings (a stale/wrong client key must never
        // override the good server-held one). Only the model name from the request is honoured.
        LlmConfig resolved = resolver.resolveLlm(userId);
        if (req.model() != null && !req.model().isBlank()) {
            return new LlmConfig(resolved.baseUrl(), resolved.apiKey(), req.model());
        }
        return resolved;
    }
}
