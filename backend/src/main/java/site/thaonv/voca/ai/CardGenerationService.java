package site.thaonv.voca.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import site.thaonv.voca.ai.AiConfigResolver.LlmConfig;
import site.thaonv.voca.card.Card;
import site.thaonv.voca.card.CardDto;
import site.thaonv.voca.card.CardService;
import site.thaonv.voca.common.ApiException;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Generates a vocabulary card's content via the LLM (JSON only — no PNG image in v2) and persists it. */
@Service
public class CardGenerationService {

    private final LlmClient llm;
    private final AiConfigResolver resolver;
    private final PracticePrompts prompts;
    private final CardService cardService;
    private final ObjectMapper mapper;

    public CardGenerationService(LlmClient llm,
                                 AiConfigResolver resolver,
                                 PracticePrompts prompts,
                                 CardService cardService,
                                 ObjectMapper mapper) {
        this.llm = llm;
        this.resolver = resolver;
        this.prompts = prompts;
        this.cardService = cardService;
        this.mapper = mapper;
    }

    public CardDto createFromWord(Long userId, String word) {
        if (word == null || word.isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MISSING_WORD", "word is required.");
        }
        String w = word.trim();
        String slug = CardService.slugify(w);

        // Already in this user's list.
        if (cardService.userHasSlug(userId, slug)) {
            throw new ApiException(HttpStatus.CONFLICT, "CARD_EXISTS", "Từ '" + w + "' đã có trong danh sách của bạn.");
        }
        // Someone already generated this word — reuse its content instead of spending LLM tokens again.
        Card existing = cardService.findAnyBySlug(slug);
        if (existing != null) {
            return cardService.copyToUser(existing, userId);
        }

        LlmConfig cfg = resolver.resolveLlm(userId);
        String prompt = prompts.cardCreationPrompt(List.of(w));

        List<Map<String, Object>> messages = new ArrayList<>();
        messages.add(message("system", "Return only valid JSON matching the requested schema."));
        messages.add(message("user", prompt));

        String text = llm.complete(cfg, messages);
        JsonNode entry = firstEntry(extractJson(text));
        return cardService.create(toInput(w, entry), userId);
    }

    private CardService.CardInput toInput(String word, JsonNode e) {
        String pos = text(e, "partOfSpeech");
        String topic = text(e, "topic");
        List<String> tags = new ArrayList<>();
        if (topic != null) tags.add(topic.toLowerCase());
        if (pos != null) tags.add(pos.toLowerCase());
        tags.add("custom");

        return new CardService.CardInput(
                e.hasNonNull("word") ? e.get("word").asText() : word,
                null,
                text(e, "pronunciation"),
                text(e, "pronunciation"),
                text(e, "frequency"),
                text(e, "meaningEn"),
                text(e, "meaningVi"),
                stringList(e, "useCases"),
                stringList(e, "examples"),
                text(e, "memoryTip"),
                text(e, "toeicTrap"),
                pos,
                topic,
                tags,
                word,
                text(e, "practicePrompt"),
                text(e, "answer"),
                "new",
                null);
    }

    private JsonNode extractJson(String text) {
        if (text == null || text.isBlank()) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "LLM_PARSE_ERROR", "Empty LLM response.");
        }
        String t = text.trim();
        if (t.startsWith("```")) {
            t = t.replaceAll("(?s)^```[a-zA-Z]*", "").replaceAll("```\\s*$", "").trim();
        }
        int arr = t.indexOf('[');
        int obj = t.indexOf('{');
        int start;
        char open;
        if (arr >= 0 && (obj < 0 || arr < obj)) {
            start = arr;
            open = '[';
        } else {
            start = obj;
            open = '{';
        }
        if (start < 0) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "LLM_PARSE_ERROR", "No JSON found in LLM response.");
        }
        int end = open == '[' ? t.lastIndexOf(']') : t.lastIndexOf('}');
        if (end < start) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "LLM_PARSE_ERROR", "Malformed JSON in LLM response.");
        }
        try {
            return mapper.readTree(t.substring(start, end + 1));
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "LLM_PARSE_ERROR", "Could not parse LLM JSON output.");
        }
    }

    private JsonNode firstEntry(JsonNode parsed) {
        if (parsed.isArray()) {
            if (parsed.isEmpty()) {
                throw new ApiException(HttpStatus.BAD_GATEWAY, "LLM_PARSE_ERROR", "LLM returned an empty array.");
            }
            return parsed.get(0);
        }
        for (String key : List.of("entries", "cards", "words")) {
            JsonNode arr = parsed.get(key);
            if (arr != null && arr.isArray() && !arr.isEmpty()) {
                return arr.get(0);
            }
        }
        if (parsed.hasNonNull("word")) {
            return parsed;
        }
        throw new ApiException(HttpStatus.BAD_GATEWAY, "LLM_PARSE_ERROR", "LLM JSON had no card entry.");
    }

    private static String text(JsonNode node, String field) {
        return node.hasNonNull(field) ? node.get(field).asText() : null;
    }

    private static List<String> stringList(JsonNode node, String field) {
        List<String> out = new ArrayList<>();
        JsonNode arr = node.get(field);
        if (arr != null && arr.isArray()) {
            arr.forEach(item -> out.add(item.asText()));
        }
        return out;
    }

    private static Map<String, Object> message(String role, String content) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("role", role);
        m.put("content", content);
        return m;
    }
}
