package site.thaonv.voca.card;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** App-facing card API for the Voca web/iOS clients (JWT-authenticated). */
@RestController
@RequestMapping("/api/cards")
public class CardController {

    private final CardService cardService;

    public CardController(CardService cardService) {
        this.cardService = cardService;
    }

    public record LevelRequest(String level) {
    }

    @GetMapping
    public Map<String, Object> list() {
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("version", cardService.manifestVersion());
        res.put("cards", cardService.listAll());
        return res;
    }

    @GetMapping("/{slug}")
    public CardDto get(@PathVariable String slug) {
        return cardService.getBySlug(slug);
    }

    @PostMapping
    public CardDto create(@RequestBody CardService.CardInput input) {
        return cardService.create(input);
    }

    @PatchMapping("/{slug}/level")
    public CardDto setLevel(@PathVariable String slug, @RequestBody LevelRequest req) {
        return cardService.setLevel(slug, req.level());
    }

    @DeleteMapping("/{slug}")
    public Map<String, Object> delete(@PathVariable String slug) {
        cardService.deleteBySlug(slug);
        return Map.of("ok", true, "slug", slug);
    }

    public record FillMeaningsRequest(List<Map<String, String>> updates) {
    }

    @PostMapping("/fill-meanings")
    public Map<String, Object> fillMeanings(@RequestBody FillMeaningsRequest req) {
        int updated = cardService.fillMeanings(req.updates() == null ? List.of() : req.updates());
        return Map.of("updatedCount", updated);
    }

    @DeleteMapping
    @PreAuthorize("hasRole('ADMIN')")
    public Map<String, Object> deleteAll() {
        return Map.of("deleted", cardService.deleteAll());
    }
}
