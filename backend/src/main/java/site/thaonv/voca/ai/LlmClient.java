package site.thaonv.voca.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Flux;

import site.thaonv.voca.ai.AiConfigResolver.LlmConfig;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Calls any OpenAI-compatible chat-completions endpoint. Provider-agnostic response parsing (ported from @voca/core). */
@Component
public class LlmClient {

    private final WebClient webClient;
    private final ObjectMapper mapper;

    public LlmClient(ObjectMapper mapper) {
        this.mapper = mapper;
        this.webClient = WebClient.builder()
                .codecs(c -> c.defaultCodecs().maxInMemorySize(16 * 1024 * 1024))
                .build();
    }

    /** Streams delta text pieces from the provider (SSE). */
    public Flux<String> streamDeltas(LlmConfig cfg, List<Map<String, Object>> messages) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", cfg.model());
        body.put("messages", messages);
        body.put("stream", true);
        return webClient.post()
                .uri(cfg.baseUrl() + "/chat/completions")
                .header("Authorization", "Bearer " + cfg.apiKey())
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.TEXT_EVENT_STREAM)
                .bodyValue(body)
                .retrieve()
                .bodyToFlux(String.class)
                .filter(s -> s != null && !s.isBlank() && !s.trim().equals("[DONE]"))
                .map(this::extractDeltaChunk)
                .filter(s -> !s.isEmpty());
    }

    /** Non-streaming completion returning the full text (used for card generation). */
    public String complete(LlmConfig cfg, List<Map<String, Object>> messages) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", cfg.model());
        body.put("messages", messages);
        body.put("stream", false);
        JsonNode response = webClient.post()
                .uri(cfg.baseUrl() + "/chat/completions")
                .header("Authorization", "Bearer " + cfg.apiKey())
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(body)
                .retrieve()
                .bodyToMono(JsonNode.class)
                .block();
        return extractResponseText(response);
    }

    /** Streams the provider's raw SSE JSON chunks unchanged (for the v1-compatible /api/chat/completions proxy). */
    public Flux<String> streamRawChunks(LlmConfig cfg, List<Map<String, Object>> messages) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", cfg.model());
        body.put("messages", messages);
        body.put("stream", true);
        return webClient.post()
                .uri(cfg.baseUrl() + "/chat/completions")
                .header("Authorization", "Bearer " + cfg.apiKey())
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.TEXT_EVENT_STREAM)
                .bodyValue(body)
                .retrieve()
                .bodyToFlux(String.class)
                .filter(s -> s != null && !s.isBlank());
    }

    private String extractDeltaChunk(String chunk) {
        try {
            return extractDelta(mapper.readTree(chunk));
        } catch (Exception e) {
            return "";
        }
    }

    static String extractDelta(JsonNode chunk) {
        if (chunk == null) {
            return "";
        }
        JsonNode choices = chunk.get("choices");
        if (choices != null && choices.isArray() && !choices.isEmpty()) {
            JsonNode delta = choices.get(0).get("delta");
            if (delta != null && delta.hasNonNull("content")) {
                return delta.get("content").asText();
            }
            JsonNode message = choices.get(0).get("message");
            if (message != null && message.hasNonNull("content")) {
                return message.get("content").asText();
            }
        }
        if (chunk.hasNonNull("output_text")) return chunk.get("output_text").asText();
        if (chunk.hasNonNull("text")) return chunk.get("text").asText();
        if (chunk.hasNonNull("response")) return chunk.get("response").asText();
        return "";
    }

    static String extractResponseText(JsonNode data) {
        if (data == null) {
            return "";
        }
        if (data.hasNonNull("output_text")) return data.get("output_text").asText();
        JsonNode choices = data.get("choices");
        if (choices != null && choices.isArray() && !choices.isEmpty()) {
            JsonNode content = choices.get(0).path("message").path("content");
            if (content.isTextual()) return content.asText();
        }
        if (data.hasNonNull("text")) return data.get("text").asText();
        if (data.hasNonNull("response")) return data.get("response").asText();
        JsonNode messageContent = data.path("message").path("content");
        if (messageContent.isTextual()) return messageContent.asText();
        return "";
    }
}
