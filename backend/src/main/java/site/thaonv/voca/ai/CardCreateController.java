package site.thaonv.voca.ai;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import site.thaonv.voca.apikey.ApiKeyPrincipal;
import site.thaonv.voca.card.CardDto;
import site.thaonv.voca.user.UserPrincipal;

/** Card creation via LLM (no PNG). App path uses JWT; public path uses an API key with scope cards:create. */
@RestController
public class CardCreateController {

    private final CardGenerationService generation;

    public CardCreateController(CardGenerationService generation) {
        this.generation = generation;
    }

    public record CreateRequest(String word) {
    }

    @PostMapping("/api/cards/create")
    public CardDto createForApp(@RequestBody CreateRequest req, @AuthenticationPrincipal UserPrincipal principal) {
        return generation.createFromWord(principal.id(), req.word());
    }

    @PostMapping("/v1/cards/create")
    @PreAuthorize("hasAuthority('SCOPE_cards:create')")
    public CardDto createForThirdParty(@RequestBody CreateRequest req, @AuthenticationPrincipal ApiKeyPrincipal principal) {
        return generation.createFromWord(ApiKeyPrincipal.requireOwner(principal), req.word());
    }
}
