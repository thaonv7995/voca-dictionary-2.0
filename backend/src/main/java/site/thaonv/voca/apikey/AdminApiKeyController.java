package site.thaonv.voca.apikey;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import site.thaonv.voca.common.ApiException;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Admin endpoints to register third-party clients and issue/revoke their API keys. */
@RestController
@RequestMapping("/api/admin")
public class AdminApiKeyController {

    private final ApiClientRepository clientRepo;
    private final ApiKeyRepository keyRepo;
    private final ApiKeyService apiKeyService;

    public AdminApiKeyController(ApiClientRepository clientRepo,
                                ApiKeyRepository keyRepo,
                                ApiKeyService apiKeyService) {
        this.clientRepo = clientRepo;
        this.keyRepo = keyRepo;
        this.apiKeyService = apiKeyService;
    }

    public record CreateClientRequest(@NotBlank String name, String description, String contactEmail) {
    }

    public record IssueKeyRequest(String name, List<String> scopes, Instant expiresAt) {
    }

    @PostMapping("/api-clients")
    public ApiClient createClient(@RequestBody @Valid CreateClientRequest req) {
        ApiClient client = new ApiClient();
        client.setName(req.name());
        client.setDescription(req.description());
        client.setContactEmail(req.contactEmail());
        return clientRepo.save(client);
    }

    @GetMapping("/api-clients")
    public List<ApiClient> listClients() {
        return clientRepo.findAll();
    }

    @PostMapping("/api-clients/{clientId}/keys")
    public Map<String, Object> issueKey(@PathVariable Long clientId, @RequestBody IssueKeyRequest req) {
        ApiClient client = clientRepo.findById(clientId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Client not found."));

        List<String> scopes = req.scopes() == null ? List.of() : req.scopes();
        for (String scope : scopes) {
            if (!ApiScope.KNOWN.contains(scope)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_SCOPE", "Unknown scope: " + scope);
            }
        }

        ApiKeyService.IssuedKey issued = apiKeyService.issue(client, req.name(), scopes, req.expiresAt());

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("id", issued.key().getId());
        body.put("clientId", clientId);
        body.put("prefix", issued.key().getKeyPrefix());
        body.put("scopes", scopes);
        body.put("expiresAt", issued.key().getExpiresAt());
        body.put("key", issued.plaintext()); // shown ONCE — not retrievable again
        return body;
    }

    @GetMapping("/api-keys")
    public List<Map<String, Object>> listKeys() {
        return keyRepo.findAll().stream().map(key -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", key.getId());
            m.put("clientId", key.getClient().getId());
            m.put("name", key.getName());
            m.put("prefix", key.getKeyPrefix());
            m.put("scopes", key.scopeSet());
            m.put("status", key.getStatus());
            m.put("expiresAt", key.getExpiresAt());
            m.put("lastUsedAt", key.getLastUsedAt());
            m.put("createdAt", key.getCreatedAt());
            return m;
        }).toList();
    }

    @DeleteMapping("/api-keys/{keyId}")
    public Map<String, Object> revokeKey(@PathVariable Long keyId) {
        ApiKey key = keyRepo.findById(keyId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Key not found."));
        apiKeyService.revoke(key);
        return Map.of("id", keyId, "status", "revoked");
    }
}
