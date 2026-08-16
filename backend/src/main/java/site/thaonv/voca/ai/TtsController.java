package site.thaonv.voca.ai;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import site.thaonv.voca.common.ApiException;
import site.thaonv.voca.user.UserPrincipal;

/**
 * Server-side TTS for arbitrary text (words, sentences, dialogue lines). Uses the user's
 * server-held TTS key — the browser never sees the secret.
 */
@RestController
@RequestMapping("/api")
public class TtsController {

    private final TtsService tts;

    public TtsController(TtsService tts) {
        this.tts = tts;
    }

    public record TtsRequest(String text, String voiceModel) {
    }

    @PostMapping(value = "/tts", produces = "audio/mpeg")
    public ResponseEntity<byte[]> synthesize(@RequestBody TtsRequest req, @AuthenticationPrincipal UserPrincipal principal) {
        if (req.text() == null || req.text().isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MISSING_TEXT", "text is required.");
        }
        byte[] audio = tts.synthesize(principal.id(), req.text().trim(), req.voiceModel());
        return ResponseEntity.ok().contentType(MediaType.parseMediaType("audio/mpeg")).body(audio);
    }
}
