package site.thaonv.voca.deck;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import site.thaonv.voca.common.ApiException;
import site.thaonv.voca.user.UserPrincipal;

import java.util.List;

@RestController
@RequestMapping("/api/decks")
public class DeckController {

    private final DeckRepository decks;

    public DeckController(DeckRepository decks) {
        this.decks = decks;
    }

    public record CreateDeckRequest(String name, boolean isPublic) {
    }

    @GetMapping
    public List<Deck> list(@AuthenticationPrincipal UserPrincipal principal) {
        Long userId = principal != null ? principal.id() : null;
        return decks.findAll().stream()
                .filter(d -> d.isPublic() || (userId != null && userId.equals(d.getOwnerId())))
                .toList();
    }

    @PostMapping
    public Deck create(@RequestBody CreateDeckRequest req, @AuthenticationPrincipal UserPrincipal principal) {
        if (req == null || req.name() == null || req.name().isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MISSING_NAME", "Deck name is required.");
        }
        Deck deck = new Deck();
        deck.setName(req.name().trim());
        deck.setPublic(req.isPublic());
        deck.setOwnerId(principal != null ? principal.id() : null);
        return decks.save(deck);
    }
}
