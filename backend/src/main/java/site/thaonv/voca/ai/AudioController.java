package site.thaonv.voca.ai;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import site.thaonv.voca.card.CardRepository;
import site.thaonv.voca.common.ApiException;
import site.thaonv.voca.user.UserPrincipal;

import java.util.Map;

/** Cache-first audio. Third-party path (/v1) uses API-key scope audio:read; app path (/api) uses JWT. */
@RestController
public class AudioController {

    private final TtsService tts;
    private final CardRepository cards;

    public AudioController(TtsService tts, CardRepository cards) {
        this.tts = tts;
        this.cards = cards;
    }

    public record AudioRequest(String text, String voiceModel) {
    }

    // ---- Third-party (API key) ----

    @GetMapping("/v1/audio/{id}")
    @PreAuthorize("hasAuthority('SCOPE_audio:read')")
    public ResponseEntity<byte[]> getPublic(@PathVariable String id) {
        return serve(id);
    }

    @PostMapping("/v1/audio/{id}")
    @PreAuthorize("hasAuthority('SCOPE_audio:read')")
    public Map<String, Object> generatePublic(@PathVariable String id, @RequestBody(required = false) AudioRequest req) {
        return generate(null, id, req);
    }

    // ---- App (JWT) ----

    @GetMapping("/api/audio/{id}")
    public ResponseEntity<byte[]> getApp(@PathVariable String id) {
        return serve(id);
    }

    @PostMapping("/api/audio/{id}")
    public Map<String, Object> generateApp(@PathVariable String id,
                                           @RequestBody(required = false) AudioRequest req,
                                           @AuthenticationPrincipal UserPrincipal principal) {
        return generate(principal != null ? principal.id() : null, id, req);
    }

    private ResponseEntity<byte[]> serve(String id) {
        if (!tts.isCached(id)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "AUDIO_NOT_FOUND", "No cached audio for '" + id + "'. POST to generate it.");
        }
        return ResponseEntity.ok().contentType(MediaType.parseMediaType("audio/mpeg")).body(tts.readCached(id));
    }

    private Map<String, Object> generate(Long userId, String id, AudioRequest req) {
        String text = req != null && req.text() != null && !req.text().isBlank() ? req.text() : cardWord(id);
        if (text == null || text.isBlank()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "No card '" + id + "' and no text provided.");
        }
        tts.generate(userId, id, text, req != null ? req.voiceModel() : null);
        return Map.of("audioUrl", "/v1/audio/" + id, "id", id);
    }

    private String cardWord(String slug) {
        return cards.findFirstBySlugIgnoreCase(slug).map(c -> c.getWord()).orElse(null);
    }
}
