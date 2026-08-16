package site.thaonv.voca.user;

import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/**
 * Authenticates /api/** requests from the Voca web/iOS apps by JWT ("Authorization: Bearer &lt;jwt&gt;").
 * Ignores "voca_" API keys (those authenticate on the /v1 chain). Constructed in SecurityConfig,
 * so it is not registered as a global servlet filter.
 */
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtService jwtService;

    public JwtAuthFilter(JwtService jwtService) {
        this.jwtService = jwtService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {

        String authorization = request.getHeader("Authorization");
        if (authorization != null && authorization.startsWith("Bearer ")) {
            String token = authorization.substring(7).trim();
            if (!token.startsWith("voca_")) {
                try {
                    Claims claims = jwtService.parse(token);
                    long uid = ((Number) claims.get("uid")).longValue();
                    boolean admin = Boolean.TRUE.equals(claims.get("admin", Boolean.class));

                    List<SimpleGrantedAuthority> authorities = new ArrayList<>();
                    authorities.add(new SimpleGrantedAuthority("ROLE_USER"));
                    if (admin) {
                        authorities.add(new SimpleGrantedAuthority("ROLE_ADMIN"));
                    }
                    UserPrincipal principal = new UserPrincipal(uid, claims.getSubject(), admin);
                    UsernamePasswordAuthenticationToken authentication =
                            new UsernamePasswordAuthenticationToken(principal, null, authorities);
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                } catch (Exception ignored) {
                    // Invalid/expired token — leave unauthenticated; authorization rules return 401.
                }
            }
        }
        chain.doFilter(request, response);
    }
}
