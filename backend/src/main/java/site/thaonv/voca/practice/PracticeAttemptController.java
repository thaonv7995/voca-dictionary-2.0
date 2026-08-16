package site.thaonv.voca.practice;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import site.thaonv.voca.card.CardRepository;
import site.thaonv.voca.user.UserPrincipal;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/practice/attempts")
public class PracticeAttemptController {

    private final PracticeAttemptRepository attempts;
    private final CardRepository cards;

    public PracticeAttemptController(PracticeAttemptRepository attempts, CardRepository cards) {
        this.attempts = attempts;
        this.cards = cards;
    }

    public record AttemptRequest(String mode, String cardSlug, Boolean correct, Map<String, Object> payload) {
    }

    @PostMapping
    public PracticeAttempt record(@RequestBody AttemptRequest req, @AuthenticationPrincipal UserPrincipal principal) {
        PracticeAttempt attempt = new PracticeAttempt();
        attempt.setUserId(principal.id());
        attempt.setMode(req.mode() == null ? "unknown" : req.mode());
        attempt.setCorrect(req.correct());
        attempt.setPayload(req.payload());
        if (req.cardSlug() != null && !req.cardSlug().isBlank()) {
            cards.findFirstBySlugIgnoreCase(req.cardSlug()).ifPresent(c -> attempt.setCardId(c.getId()));
        }
        return attempts.save(attempt);
    }

    @GetMapping
    public List<PracticeAttempt> recent(@AuthenticationPrincipal UserPrincipal principal) {
        return attempts.findTop50ByUserIdOrderByCreatedAtDesc(principal.id());
    }
}
