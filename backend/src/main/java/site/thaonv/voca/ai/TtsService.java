package site.thaonv.voca.ai;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import site.thaonv.voca.ai.AiConfigResolver.TtsConfig;
import site.thaonv.voca.common.ApiException;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Map;

/** Generates and caches TTS audio (mp3) via an OpenAI-compatible /audio/speech endpoint. */
@Service
public class TtsService {

    private final AiConfigResolver resolver;
    private final WebClient webClient;
    private final Path audioDir;

    public TtsService(AiConfigResolver resolver, @Value("${app.audio.dir:./data/audio}") String audioDir) {
        this.resolver = resolver;
        this.webClient = WebClient.builder()
                .codecs(c -> c.defaultCodecs().maxInMemorySize(32 * 1024 * 1024))
                .build();
        this.audioDir = Path.of(audioDir);
        try {
            Files.createDirectories(this.audioDir);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    public boolean isCached(String id) {
        return Files.exists(pathFor(id));
    }

    public byte[] readCached(String id) {
        try {
            return Files.readAllBytes(pathFor(id));
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    /** Synthesizes audio for arbitrary text using the user's server-held TTS key. Returns mp3 bytes. */
    public byte[] synthesize(Long userId, String text, String voiceModelOverride) {
        TtsConfig cfg = resolver.resolveTts(userId);
        String model = voiceModelOverride != null && !voiceModelOverride.isBlank() ? voiceModelOverride : cfg.model();

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", model);
        body.put("input", text);
        body.put("response_format", "mp3");

        try {
            return webClient.post()
                    .uri(cfg.baseUrl() + "/audio/speech")
                    .header("Authorization", "Bearer " + cfg.apiKey())
                    .contentType(MediaType.APPLICATION_JSON)
                    .bodyValue(body)
                    .retrieve()
                    .bodyToMono(byte[].class)
                    .block(Duration.ofSeconds(45));
        } catch (WebClientResponseException ex) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "TTS_UPSTREAM_ERROR",
                    "TTS provider returned HTTP " + ex.getStatusCode().value() + ".");
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.BAD_GATEWAY, "TTS_UPSTREAM_ERROR",
                    "Failed to synthesize TTS audio: " + ex.getClass().getSimpleName());
        }
    }

    /** Generates audio for the given text and caches it under the id (card slug). */
    public void generate(Long userId, String id, String text, String voiceModelOverride) {
        byte[] audio = synthesize(userId, id, text, voiceModelOverride);
        try {
            Files.write(pathFor(id), audio);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private byte[] synthesize(Long userId, String id, String text, String voiceModelOverride) {
        return synthesize(userId, text, voiceModelOverride);
    }

    Path pathFor(String id) {
        String safe = id.replaceAll("[^\\p{L}\\p{N}._-]", "_");
        if (!safe.equals(id)) {
            safe = safe + "_" + Integer.toUnsignedString(id.hashCode(), 16);
        }
        return audioDir.resolve(safe + ".mp3");
    }
}
