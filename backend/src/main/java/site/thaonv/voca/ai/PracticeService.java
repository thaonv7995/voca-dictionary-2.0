package site.thaonv.voca.ai;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClientResponseException;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import reactor.core.Disposable;

import site.thaonv.voca.ai.AiConfigResolver.LlmConfig;
import site.thaonv.voca.card.Card;
import site.thaonv.voca.card.CardRepository;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

/** Builds the learner's target-vocabulary index and streams LLM output to the client over SSE. */
@Service
public class PracticeService {

    private static final Logger log = LoggerFactory.getLogger(PracticeService.class);

    private final CardRepository cards;
    private final LlmClient llm;
    private final AiConfigResolver resolver;

    public PracticeService(CardRepository cards, LlmClient llm, AiConfigResolver resolver) {
        this.cards = cards;
        this.llm = llm;
        this.resolver = resolver;
    }

    /** Words ordered by learning priority (new/learning first), used as the practice target index. */
    public List<String> vocabularyIndex(int limit) {
        List<Card> all = new ArrayList<>(cards.findAll());
        all.sort(Comparator.comparingInt((Card c) -> levelRank(c.getLevel()))
                .thenComparing(Card::getCreatedAt));
        return all.stream().map(Card::getWord).limit(limit).toList();
    }

    /** Resolves the LLM config (throws if unconfigured) then streams deltas to a new SseEmitter. */
    public SseEmitter stream(Long userId, String systemPrompt, String userPrompt) {
        LlmConfig cfg = resolver.resolveLlm(userId); // throws LLM_NOT_CONFIGURED before we open the stream

        List<Map<String, Object>> messages = new ArrayList<>();
        if (systemPrompt != null) {
            messages.add(msg("system", systemPrompt));
        }
        messages.add(msg("user", userPrompt));

        SseEmitter emitter = new SseEmitter(120_000L);
        // Same care as ChatController: never completeWithError after bytes are on the wire (it would
        // reset an already-committed SSE response into an opaque 500). If the provider fails before any
        // content, surface a readable message AS the reply (a plain-text delta) instead of a 500.
        AtomicBoolean done = new AtomicBoolean(false);
        AtomicBoolean sentAny = new AtomicBoolean(false);
        Disposable[] sub = new Disposable[1];
        sub[0] = llm.streamDeltas(cfg, messages).subscribe(
                delta -> {
                    if (done.get()) {
                        return;
                    }
                    try {
                        emitter.send(SseEmitter.event().data(delta));
                        sentAny.set(true);
                    } catch (Exception e) {
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
                log.warn("practice stream error (no data sent): {}", error.toString());
                try {
                    emitter.send(SseEmitter.event().data(llmErrorMessage(error)));
                } catch (Exception ignored) {
                    /* client already gone */
                }
                emitter.complete();
            } else {
                if (error != null) {
                    log.warn("practice stream ended after streaming data: {}", error.toString());
                }
                emitter.complete();
            }
        } catch (Exception ignored) {
            /* emitter already finalised by the container */
        }
    }

    /** A human-readable reason for an upstream LLM failure (sent as a plain-text delta). */
    private static String llmErrorMessage(Throwable error) {
        if (error instanceof WebClientResponseException w) {
            int s = w.getStatusCode().value();
            if (s == 401 || s == 403) {
                return "⚠️ Không gọi được LLM: nhà cung cấp từ chối xác thực (" + s
                        + "). Kiểm tra API key trong Cài đặt → Kết nối AI.";
            }
            if (s == 429) {
                return "⚠️ Không gọi được LLM: bị giới hạn tần suất (429). Thử lại sau ít phút.";
            }
            return "⚠️ Không gọi được LLM: nhà cung cấp trả lỗi " + s + ".";
        }
        return "⚠️ Không gọi được LLM (" + error.getClass().getSimpleName()
                + "). Thử lại hoặc kiểm tra cấu hình AI.";
    }

    private static Map<String, Object> msg(String role, String content) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("role", role);
        m.put("content", content);
        return m;
    }

    private static int levelRank(String level) {
        return switch (level == null ? "new" : level) {
            case "learning" -> 1;
            case "known" -> 2;
            case "mastered" -> 3;
            default -> 0;
        };
    }
}
