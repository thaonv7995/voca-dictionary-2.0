package site.thaonv.voca.ai;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import site.thaonv.voca.ai.AiConfigResolver.LlmConfig;
import site.thaonv.voca.card.Card;
import site.thaonv.voca.card.CardRepository;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

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
        llm.streamDeltas(cfg, messages).subscribe(
                delta -> {
                    try {
                        emitter.send(SseEmitter.event().data(delta));
                    } catch (IOException e) {
                        // client disconnected — nothing more to do
                    }
                },
                error -> {
                    log.warn("LLM stream error: {}", error.toString());
                    emitter.completeWithError(error);
                },
                emitter::complete);
        return emitter;
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
