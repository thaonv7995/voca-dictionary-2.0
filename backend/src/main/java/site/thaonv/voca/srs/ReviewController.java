package site.thaonv.voca.srs;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import site.thaonv.voca.common.ApiException;
import site.thaonv.voca.user.UserPrincipal;

import java.util.Map;

/** SRS endpoints for the Voca app: grade a card, list what's due, and see progress stats. */
@RestController
@RequestMapping("/api")
public class ReviewController {

    private final ReviewService reviewService;

    public ReviewController(ReviewService reviewService) {
        this.reviewService = reviewService;
    }

    public record ReviewRequest(String slug, Integer grade) {
    }

    @PostMapping("/review")
    public Map<String, Object> review(@RequestBody ReviewRequest req, @AuthenticationPrincipal UserPrincipal principal) {
        if (req.slug() == null || req.slug().isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MISSING_SLUG", "slug is required.");
        }
        if (req.grade() == null || req.grade() < 1 || req.grade() > 4) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_GRADE", "grade must be 1..4 (Again/Hard/Good/Easy).");
        }
        return reviewService.review(principal.id(), req.slug(), req.grade());
    }

    @GetMapping("/study/due")
    public Map<String, Object> due(@AuthenticationPrincipal UserPrincipal principal) {
        return reviewService.due(principal.id());
    }

    @GetMapping("/study/stats")
    public Map<String, Object> stats(@AuthenticationPrincipal UserPrincipal principal) {
        return reviewService.stats(principal.id());
    }
}
