package site.thaonv.voca.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

import site.thaonv.voca.apikey.ApiKeyAuthFilter;
import site.thaonv.voca.apikey.ApiKeyService;
import site.thaonv.voca.apikey.RateLimiter;
import site.thaonv.voca.user.JwtAuthFilter;
import site.thaonv.voca.user.JwtService;

import jakarta.servlet.DispatcherType;

import java.io.IOException;
import java.util.Map;

/**
 * Three security realms on a single port:
 *  - /v1/**    third-party machine access via API key (scopes).
 *  - /api/**   Voca web/iOS end-user access via JWT (/api/admin/** requires ROLE_ADMIN).
 *  - /**       everything else open: the embedded SPA, swagger, actuator.
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    @Order(1)
    public SecurityFilterChain apiKeyChain(HttpSecurity http,
                                           ApiKeyService apiKeyService,
                                           RateLimiter rateLimiter,
                                           ObjectMapper objectMapper) throws Exception {
        ApiKeyAuthFilter apiKeyAuthFilter = new ApiKeyAuthFilter(apiKeyService, rateLimiter);
        http
                .securityMatcher("/v1/**")
                .csrf(csrf -> csrf.disable())
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // Internal ASYNC/ERROR dispatches of an already-authorized request (e.g. SSE
                        // streaming completion) must not be re-authorized — the stateless auth context
                        // is gone by then, so re-checking would reset an already-committed response.
                        .dispatcherTypeMatchers(DispatcherType.ASYNC, DispatcherType.ERROR).permitAll()
                        .requestMatchers("/v1/health").permitAll()
                        .anyRequest().authenticated())
                .addFilterBefore(apiKeyAuthFilter, UsernamePasswordAuthenticationFilter.class)
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint((req, res, e) ->
                                writeError(res, objectMapper, 401, "UNAUTHORIZED", "API key required."))
                        .accessDeniedHandler((req, res, e) ->
                                writeError(res, objectMapper, 403, "FORBIDDEN", "Missing required scope.")));
        return http.build();
    }

    @Bean
    @Order(2)
    public SecurityFilterChain appChain(HttpSecurity http,
                                        JwtService jwtService,
                                        ObjectMapper objectMapper) throws Exception {
        JwtAuthFilter jwtAuthFilter = new JwtAuthFilter(jwtService);
        http
                .securityMatcher("/api/**")
                .csrf(csrf -> csrf.disable())
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // Internal ASYNC/ERROR dispatches of an already-authorized request (e.g. the
                        // /api/chat/completions SSE stream finishing) must bypass re-authorization: the
                        // JWT filter does not re-run on async dispatch, so re-checking would deny and
                        // reset the already-committed stream (client saw "network error").
                        .dispatcherTypeMatchers(DispatcherType.ASYNC, DispatcherType.ERROR).permitAll()
                        .requestMatchers("/api/auth/register", "/api/auth/login", "/api/auth/refresh").permitAll()
                        .requestMatchers("/api/admin/**").hasRole("ADMIN")
                        .anyRequest().authenticated())
                .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint((req, res, e) ->
                                writeError(res, objectMapper, 401, "UNAUTHORIZED", "Authentication required."))
                        .accessDeniedHandler((req, res, e) ->
                                writeError(res, objectMapper, 403, "FORBIDDEN", "Admin privileges required.")));
        return http.build();
    }

    @Bean
    @Order(3)
    public SecurityFilterChain publicChain(HttpSecurity http) throws Exception {
        http
                .securityMatcher("/**")
                .csrf(csrf -> csrf.disable())
                .authorizeHttpRequests(auth -> auth.anyRequest().permitAll());
        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    private static void writeError(jakarta.servlet.http.HttpServletResponse res, ObjectMapper mapper,
                                   int status, String code, String message) throws IOException {
        res.setStatus(status);
        res.setContentType("application/json");
        mapper.writeValue(res.getWriter(), Map.of("error", Map.of("code", code, "message", message)));
    }
}
