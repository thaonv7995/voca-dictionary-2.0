package site.thaonv.voca.user;

/** Authenticated end-user principal placed in the SecurityContext for /api/** requests. */
public record UserPrincipal(Long id, String email, boolean admin) {
}
