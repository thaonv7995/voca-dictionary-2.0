package site.thaonv.voca.apikey;

import org.springframework.http.HttpStatus;

import site.thaonv.voca.common.ApiException;

import java.util.Set;

/** Authenticated third-party caller (set as the Authentication principal for /v1/* requests). */
public record ApiKeyPrincipal(Long keyId, Long clientId, String clientName, Long ownerUserId, Set<String> scopes) {

    /**
     * The Voca user this key acts on behalf of. Every /v1 route needs it: LLM/TTS credentials and
     * card ownership are per-user, and a null userId silently falls back to the (usually unset)
     * env-level config instead — which is how /v1/audio and /v1/practice ended up always 503-ing.
     */
    public static Long requireOwner(ApiKeyPrincipal principal) {
        if (principal == null || principal.ownerUserId() == null) {
            throw new ApiException(HttpStatus.FORBIDDEN, "KEY_NO_OWNER",
                    "API key is not linked to a user account.");
        }
        return principal.ownerUserId();
    }
}
