package site.thaonv.voca.ai;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import site.thaonv.voca.ai.AiConfigResolver.TtsConfig;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
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

        return webClient.post()
                .uri(cfg.baseUrl() + "/audio/speech")
                .header("Authorization", "Bearer " + cfg.apiKey())
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(body)
                .retrieve()
                .bodyToMono(byte[].class)
                .block();
    }

    /** Generates audio for the given text and caches it under the id (card slug). */
    public void generate(Long userId, String id, String text, String voiceModelOverride) {
        byte[] audio = synthesize(userId, text, voiceModelOverride);
        try {
            Files.write(pathFor(id), audio);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private Path pathFor(String id) {
        String safe = id.replaceAll("[^a-zA-Z0-9._-]", "_");
        return audioDir.resolve(safe + ".mp3");
    }
}
