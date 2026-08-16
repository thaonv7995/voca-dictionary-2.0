package site.thaonv.voca.user;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import site.thaonv.voca.common.ApiException;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HexFormat;

@Service
public class UserService {

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordEncoder encoder;
    private final JwtService jwtService;
    private final long refreshTtlDays;
    private final SecureRandom random = new SecureRandom();

    public UserService(UserRepository users,
                       RefreshTokenRepository refreshTokens,
                       PasswordEncoder encoder,
                       JwtService jwtService,
                       @Value("${app.auth.refresh-ttl-days:30}") long refreshTtlDays) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.encoder = encoder;
        this.jwtService = jwtService;
        this.refreshTtlDays = refreshTtlDays;
    }

    public record AuthResult(String accessToken, String refreshToken, User user) {
    }

    @Transactional
    public AuthResult register(String email, String password, String displayName) {
        if (users.existsByEmailIgnoreCase(email)) {
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_TAKEN", "Email already registered.");
        }
        User user = new User();
        user.setEmail(email.trim());
        user.setPasswordHash(encoder.encode(password));
        user.setDisplayName(displayName);
        user.setAdmin(false);
        users.save(user);
        return issue(user);
    }

    @Transactional
    public AuthResult login(String email, String password) {
        User user = users.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "Invalid email or password."));
        if (user.getPasswordHash() == null || !encoder.matches(password, user.getPasswordHash())) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "Invalid email or password.");
        }
        return issue(user);
    }

    @Transactional
    public AuthResult refresh(String refreshToken) {
        RefreshToken stored = refreshTokens.findByToken(refreshToken)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH", "Invalid refresh token."));
        if (stored.getExpiresAt().isBefore(Instant.now())) {
            refreshTokens.delete(stored);
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH", "Refresh token expired.");
        }
        User user = users.findById(stored.getUserId())
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH", "User not found."));
        refreshTokens.delete(stored); // rotate
        return issue(user);
    }

    @Transactional
    public void logout(String refreshToken) {
        refreshTokens.deleteByToken(refreshToken);
    }

    public User requireUser(Long id) {
        return users.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "User not found."));
    }

    private AuthResult issue(User user) {
        String accessToken = jwtService.generateAccessToken(user);

        byte[] buf = new byte[32];
        random.nextBytes(buf);
        String refresh = "vrt_" + HexFormat.of().formatHex(buf);

        RefreshToken token = new RefreshToken();
        token.setUserId(user.getId());
        token.setToken(refresh);
        token.setExpiresAt(Instant.now().plus(refreshTtlDays, ChronoUnit.DAYS));
        refreshTokens.save(token);

        return new AuthResult(accessToken, refresh, user);
    }
}
