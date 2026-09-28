package site.thaonv.voca.card;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import site.thaonv.voca.ai.HtmlSheetService;
import site.thaonv.voca.user.UserPrincipal;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** App-facing card API for the Voca web/iOS clients (JWT-authenticated). Every card is per-user. */
@RestController
@RequestMapping("/api/cards")
public class CardController {

    private final CardService cardService;
    private final HtmlSheetService htmlSheetService;

    public CardController(CardService cardService, HtmlSheetService htmlSheetService) {
        this.cardService = cardService;
        this.htmlSheetService = htmlSheetService;
    }

    public record LevelRequest(String level) {
    }

    @GetMapping
    public Map<String, Object> list(@AuthenticationPrincipal UserPrincipal principal) {
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("version", cardService.manifestVersion(principal.id()));
        res.put("cards", cardService.listAll(principal.id()));
        return res;
    }

    @GetMapping("/{slug}")
    public CardDto get(@PathVariable String slug, @AuthenticationPrincipal UserPrincipal principal) {
        return cardService.getBySlug(slug, principal.id());
    }

    @PostMapping
    public CardDto create(@RequestBody CardService.CardInput input, @AuthenticationPrincipal UserPrincipal principal) {
        return cardService.create(input, principal.id());
    }

    @PatchMapping("/{slug}/level")
    public CardDto setLevel(@PathVariable String slug, @RequestBody LevelRequest req,
                            @AuthenticationPrincipal UserPrincipal principal) {
        return cardService.setLevel(slug, req.level(), principal.id());
    }

    @DeleteMapping("/{slug}")
    public Map<String, Object> delete(@PathVariable String slug, @AuthenticationPrincipal UserPrincipal principal) {
        cardService.deleteBySlug(slug, principal.id());
        return Map.of("ok", true, "slug", slug);
    }

    public record FillMeaningsRequest(List<Map<String, String>> updates) {
    }

    @PostMapping("/fill-meanings")
    public Map<String, Object> fillMeanings(@RequestBody FillMeaningsRequest req,
                                            @AuthenticationPrincipal UserPrincipal principal) {
        int updated = cardService.fillMeanings(req.updates() == null ? List.of() : req.updates(), principal.id());
        return Map.of("updatedCount", updated);
    }

    /** Clears the caller's own vocabulary list. */
    @DeleteMapping
    public Map<String, Object> deleteAll(@AuthenticationPrincipal UserPrincipal principal) {
        return Map.of("deleted", cardService.deleteAll(principal.id()));
    }

    @GetMapping("/{idOrSlug}/html")
    public ResponseEntity<byte[]> getHtmlSheet(@PathVariable String idOrSlug,
                                               @RequestParam(name = "embed", required = false, defaultValue = "false") boolean embed,
                                               @AuthenticationPrincipal UserPrincipal principal) {
        Card card = cardService.requireCard(idOrSlug, principal.id());
        if (!htmlSheetService.hasSheet(card.getSlug())) {
            htmlSheetService.generateSheet(card.getId());
        }
        byte[] bytes = htmlSheetService.readSheet(card.getSlug(), embed);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("text/html; charset=UTF-8"))
                .body(bytes);
    }

    @PostMapping("/{idOrSlug}/html")
    public Map<String, Object> generateHtmlSheet(@PathVariable String idOrSlug,
                                                 @AuthenticationPrincipal UserPrincipal principal) {
        Card card = cardService.requireCard(idOrSlug, principal.id());
        htmlSheetService.generateSheet(card.getId());
        return Map.of(
                "ok", true,
                "hasHtml", true,
                "htmlUrl", "/api/cards/" + card.getId() + "/html",
                "slug", card.getSlug()
        );
    }
}
