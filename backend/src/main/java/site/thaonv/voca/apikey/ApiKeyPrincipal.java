package site.thaonv.voca.apikey;

import java.util.Set;

/** Authenticated third-party caller (set as the Authentication principal for /v1/* requests). */
public record ApiKeyPrincipal(Long keyId, Long clientId, String clientName, Set<String> scopes) {
}
