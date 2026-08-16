package site.thaonv.voca.apikey;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import site.thaonv.voca.common.ApiException;
import site.thaonv.voca.user.User;
import site.thaonv.voca.user.UserPrincipal;
import site.thaonv.voca.user.UserRepository;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Self-service API keys: any signed-in user can mint keys for their own integrations (other systems
 * calling the Voca /v1 API). Keys hang off a per-user "personal" {@link ApiClient} created on demand.
 * The plaintext key is returned once at creation and never again — only its SHA-256 hash is stored.
 */
@RestController
@RequestMapping("/api/user/api-keys")
public class UserApiKeyController {

    /** Scopes offered in the UI, in display order, each documenting the endpoints it unlocks. */
    private static final List<Map<String, String>> OFFERED_SCOPES = List.of(
            scope(ApiScope.CARDS_READ, "Đọc từ vựng", "GET /v1/cards · /v1/cards/{slug} · /v1/cards/lookup"),
            scope(ApiScope.CARDS_CREATE, "Tạo thẻ từ", "POST /v1/cards/create"),
            scope(ApiScope.AUDIO_READ, "Phát âm (audio)", "GET /v1/audio/{id}"),
            scope(ApiScope.PRACTICE_GENERATE, "Sinh bài luyện tập", "POST /v1/practice/drills · /v1/practice/reading"));

    private final ApiClientRepository clientRepo;
    private final ApiKeyRepository keyRepo;
    private final ApiKeyService apiKeyService;
    private final UserRepository userRepo;

    public UserApiKeyController(ApiClientRepository clientRepo,
                               ApiKeyRepository keyRepo,
                               ApiKeyService apiKeyService,
                               UserRepository userRepo) {
        this.clientRepo = clientRepo;
        this.keyRepo = keyRepo;
        this.apiKeyService = apiKeyService;
        this.userRepo = userRepo;
    }

    public record CreateKeyRequest(String name, List<String> scopes) {
    }

    @GetMapping
    public Map<String, Object> list(@AuthenticationPrincipal UserPrincipal principal) {
        List<Map<String, Object>> keys = keyRepo.findByClient_OwnerUserIdOrderByCreatedAtDesc(principal.id())
                .stream().map(UserApiKeyController::toDto).toList();
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("keys", keys);
        res.put("scopes", OFFERED_SCOPES);
        return res;
    }

    @PostMapping
    public Map<String, Object> create(@AuthenticationPrincipal UserPrincipal principal,
                                      @RequestBody CreateKeyRequest req) {
        // A user key represents that user's own access — grant full access by default.
        // (An explicit scope subset is still honoured if a caller sends one.)
        List<String> scopes = req.scopes() == null || req.scopes().isEmpty()
                ? List.copyOf(ApiScope.KNOWN)
                : req.scopes();
        for (String scope : scopes) {
            if (!ApiScope.KNOWN.contains(scope)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_SCOPE", "Unknown scope: " + scope);
            }
        }
        ApiClient client = personalClient(principal.id());
        String name = req.name() == null || req.name().isBlank() ? "API key" : req.name().trim();

        ApiKeyService.IssuedKey issued = apiKeyService.issue(client, name, scopes, null);

        Map<String, Object> dto = toDto(issued.key());
        dto.put("key", issued.plaintext()); // shown ONCE — never retrievable again
        return dto;
    }

    /** Deactivate a key but keep the record (it stops authenticating immediately). */
    @PostMapping("/{id}/revoke")
    public Map<String, Object> revoke(@AuthenticationPrincipal UserPrincipal principal, @PathVariable Long id) {
        ApiKey key = requireOwnedKey(principal.id(), id);
        apiKeyService.revoke(key);
        return Map.of("id", id, "status", "revoked");
    }

    /** Permanently remove a key record (e.g. to clear out revoked keys). */
    @DeleteMapping("/{id}")
    public Map<String, Object> delete(@AuthenticationPrincipal UserPrincipal principal, @PathVariable Long id) {
        ApiKey key = requireOwnedKey(principal.id(), id);
        keyRepo.delete(key);
        return Map.of("id", id, "deleted", true);
    }

    /** Loads a key only if it belongs to the caller — otherwise a uniform 404 (don't leak others' keys). */
    private ApiKey requireOwnedKey(Long userId, Long id) {
        ApiKey key = keyRepo.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Key not found."));
        if (key.getClient() == null || !userId.equals(key.getClient().getOwnerUserId())) {
            throw new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Key not found.");
        }
        return key;
    }

    /** Finds (or lazily creates) the calling user's personal API client that owns their keys. */
    private ApiClient personalClient(Long userId) {
        return clientRepo.findFirstByOwnerUserId(userId).orElseGet(() -> {
            User user = userRepo.findById(userId).orElse(null);
            String label = user == null ? "user-" + userId
                    : (user.getDisplayName() != null && !user.getDisplayName().isBlank()
                        ? user.getDisplayName() : user.getEmail());
            ApiClient client = new ApiClient();
            client.setName(label + " (personal)");
            client.setDescription("Self-service keys for " + (user != null ? user.getEmail() : userId));
            client.setOwnerUserId(userId);
            client.setContactEmail(user != null ? user.getEmail() : null);
            return clientRepo.save(client);
        });
    }

    private static Map<String, Object> toDto(ApiKey k) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", k.getId());
        m.put("name", k.getName());
        m.put("prefix", k.getKeyPrefix());
        m.put("scopes", k.scopeSet());
        m.put("status", k.getStatus());
        m.put("lastUsedAt", k.getLastUsedAt());
        m.put("createdAt", k.getCreatedAt());
        return m;
    }

    private static Map<String, String> scope(String value, String label, String endpoints) {
        Map<String, String> m = new LinkedHashMap<>();
        m.put("value", value);
        m.put("label", label);
        m.put("endpoints", endpoints);
        return m;
    }
}
