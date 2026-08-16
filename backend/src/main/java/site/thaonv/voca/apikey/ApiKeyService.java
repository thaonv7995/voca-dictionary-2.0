package site.thaonv.voca.apikey;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Collection;
import java.util.HexFormat;
import java.util.Optional;

/** Issues, verifies and revokes third-party API keys. Stores only the SHA-256 hash of each key. */
@Service
public class ApiKeyService {

    private static final String PREFIX = "voca_";

    private final ApiKeyRepository keyRepo;
    private final SecureRandom random = new SecureRandom();

    public ApiKeyService(ApiKeyRepository keyRepo) {
        this.keyRepo = keyRepo;
    }

    /** Result of issuing a key: the persisted entity + the plaintext (returned to the caller once). */
    public record IssuedKey(ApiKey key, String plaintext) {
    }

    @Transactional
    public IssuedKey issue(ApiClient client, String name, Collection<String> scopes, Instant expiresAt) {
        byte[] buf = new byte[24];
        random.nextBytes(buf);
        String plaintext = PREFIX + HexFormat.of().formatHex(buf);

        ApiKey key = new ApiKey();
        key.setClient(client);
        key.setName(name);
        key.setKeyPrefix(plaintext.substring(0, Math.min(13, plaintext.length())));
        key.setKeyHash(sha256(plaintext));
        key.setScopes(scopes == null ? "" : String.join(" ", scopes));
        key.setExpiresAt(expiresAt);
        keyRepo.save(key);
        return new IssuedKey(key, plaintext);
    }

    /** Verifies a presented key; on success touches last_used_at. Returns empty if unknown/inactive. */
    @Transactional
    public Optional<ApiKey> verify(String plaintext) {
        if (plaintext == null || !plaintext.startsWith(PREFIX)) {
            return Optional.empty();
        }
        Optional<ApiKey> found = keyRepo.findByKeyHash(sha256(plaintext));
        if (found.isEmpty()) {
            return Optional.empty();
        }
        ApiKey key = found.get();
        if (!key.isActive()) {
            return Optional.empty();
        }
        key.setLastUsedAt(Instant.now()); // flushed by dirty checking on tx commit
        return Optional.of(key);
    }

    @Transactional
    public void revoke(ApiKey key) {
        key.setStatus("revoked");
        key.setRevokedAt(Instant.now());
        keyRepo.save(key);
    }

    private static String sha256(String value) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(value.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }
}
