package site.thaonv.voca.apikey;

import com.fasterxml.jackson.databind.ObjectMapper;
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
import java.util.Map;
import java.util.Optional;

/**
 * Authenticates /v1/* requests by API key ("X-API-Key" or "Authorization: Bearer voca_...").
 * Not a Spring bean on purpose — it is constructed in SecurityConfig and added only to the
 * /v1/** chain, so it does not auto-register as a global servlet filter.
 */
public class ApiKeyAuthFilter extends OncePerRequestFilter {

    private final ApiKeyService apiKeyService;
    private final RateLimiter rateLimiter;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public ApiKeyAuthFilter(ApiKeyService apiKeyService, RateLimiter rateLimiter) {
        this.apiKeyService = apiKeyService;
        this.rateLimiter = rateLimiter;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {

        String token = resolveToken(request);
        if (token == null) {
            // No key presented — let authorization rules (401) handle protected endpoints.
            chain.doFilter(request, response);
            return;
        }

        Optional<ApiKey> keyOpt = apiKeyService.verify(token);
        if (keyOpt.isEmpty()) {
            writeError(response, HttpServletResponse.SC_UNAUTHORIZED, "UNAUTHORIZED", "Invalid or inactive API key.");
            return;
        }

        ApiKey key = keyOpt.get();
        if (!rateLimiter.allow(key.getId())) {
            writeError(response, 429, "RATE_LIMITED", "Rate limit exceeded for this API key.");
            return;
        }

        List<SimpleGrantedAuthority> authorities = new ArrayList<>();
        authorities.add(new SimpleGrantedAuthority("ROLE_API_CLIENT"));
        for (String scope : key.scopeSet()) {
            authorities.add(new SimpleGrantedAuthority("SCOPE_" + scope));
        }

        ApiKeyPrincipal principal = new ApiKeyPrincipal(
                key.getId(), key.getClient().getId(), key.getClient().getName(),
                key.getClient().getOwnerUserId(), key.scopeSet());
        UsernamePasswordAuthenticationToken authentication =
                new UsernamePasswordAuthenticationToken(principal, null, authorities);
        SecurityContextHolder.getContext().setAuthentication(authentication);

        chain.doFilter(request, response);
    }

    private String resolveToken(HttpServletRequest request) {
        String apiKeyHeader = request.getHeader("X-API-Key");
        if (apiKeyHeader != null && !apiKeyHeader.isBlank()) {
            return apiKeyHeader.trim();
        }
        String authorization = request.getHeader("Authorization");
        if (authorization != null && authorization.startsWith("Bearer ")) {
            String value = authorization.substring(7).trim();
            if (value.startsWith("voca_")) {
                return value;
            }
        }
        return null;
    }

    private void writeError(HttpServletResponse response, int status, String code, String message) throws IOException {
        response.setStatus(status);
        response.setContentType("application/json");
        objectMapper.writeValue(response.getWriter(),
                Map.of("error", Map.of("code", code, "message", message)));
    }
}
