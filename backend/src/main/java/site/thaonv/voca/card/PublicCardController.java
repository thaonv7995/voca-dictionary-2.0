package site.thaonv.voca.card;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import site.thaonv.voca.apikey.ApiKeyPrincipal;
import site.thaonv.voca.common.ApiException;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Public API surface for third-party clients (bilingual-app, etc.). Cards are per-user, so results
 * are scoped to the user who owns the API key. Protected by API-key scopes; /v1/health is open.
 */
@RestController
@RequestMapping("/v1")
public class PublicCardController {

    private final CardService cardService;

    public PublicCardController(CardService cardService) {
        this.cardService = cardService;
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        return Map.of("status", "ok", "service", "voca-api", "storage", "postgres", "version", "2.0");
    }

    @GetMapping("/cards")
    @PreAuthorize("hasAuthority('SCOPE_cards:read')")
    public Object listCards(@RequestParam(name = "ifChangedSince", required = false) String ifChangedSince,
                            @AuthenticationPrincipal ApiKeyPrincipal principal) {
        Long owner = requireOwner(principal);
        String version = cardService.manifestVersion(owner);
        if (ifChangedSince != null && ifChangedSince.equals(version)) {
            return Map.of("version", version, "changed", false);
        }
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("version", version);
        res.put("changed", true);
        res.put("cards", cardService.listAll(owner));
        return res;
    }

    @GetMapping("/cards/lookup")
    @PreAuthorize("hasAuthority('SCOPE_cards:read')")
    public Map<String, Object> lookup(@RequestParam(name = "word", required = false) String word,
                                      @AuthenticationPrincipal ApiKeyPrincipal principal) {
        if (word == null || word.isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MISSING_WORD", "Missing word query parameter.");
        }
        return cardService.lookup(word, requireOwner(principal));
    }

    @GetMapping("/cards/{slug}")
    @PreAuthorize("hasAuthority('SCOPE_cards:read')")
    public CardDto getCard(@PathVariable String slug, @AuthenticationPrincipal ApiKeyPrincipal principal) {
        return cardService.getBySlug(slug, requireOwner(principal));
    }

    private static Long requireOwner(ApiKeyPrincipal principal) {
        return ApiKeyPrincipal.requireOwner(principal);
    }
}
