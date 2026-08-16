package site.thaonv.voca.user;

import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import site.thaonv.voca.apikey.ApiClient;
import site.thaonv.voca.apikey.ApiClientRepository;
import site.thaonv.voca.apikey.ApiKeyRepository;
import site.thaonv.voca.common.ApiException;
import site.thaonv.voca.settings.UserSettingsRepository;

import java.security.SecureRandom;

/** Admin-only user administration: create/role-change/removal with dependent-data cleanup. */
@Service
public class AdminUserService {

    // No look-alike characters (0/O, 1/l/I) so a shared credential is easy to read/type.
    private static final String PW_ALPHABET = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private static final SecureRandom RANDOM = new SecureRandom();

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final UserSettingsRepository settings;
    private final ApiClientRepository clients;
    private final ApiKeyRepository keys;
    private final PasswordEncoder encoder;

    public AdminUserService(UserRepository users,
                            RefreshTokenRepository refreshTokens,
                            UserSettingsRepository settings,
                            ApiClientRepository clients,
                            ApiKeyRepository keys,
                            PasswordEncoder encoder) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.settings = settings;
        this.clients = clients;
        this.keys = keys;
        this.encoder = encoder;
    }

    /** A newly-provisioned account plus its plaintext password (returned once for the admin to share). */
    public record CreatedUser(User user, String password) {
    }

    /** Admin provisions an account; password is auto-generated when not supplied. */
    @Transactional
    public CreatedUser create(String email, String displayName, boolean admin, String password) {
        if (email == null || email.isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MISSING_EMAIL", "Email là bắt buộc.");
        }
        String normalizedEmail = email.trim();
        if (users.existsByEmailIgnoreCase(normalizedEmail)) {
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_TAKEN", "Email đã tồn tại.");
        }
        String plain = password == null || password.isBlank() ? generatePassword(14) : password;
        if (plain.length() < 6) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "WEAK_PASSWORD", "Mật khẩu tối thiểu 6 ký tự.");
        }
        User user = new User();
        user.setEmail(normalizedEmail);
        user.setPasswordHash(encoder.encode(plain));
        user.setDisplayName(displayName == null || displayName.isBlank() ? null : displayName.trim());
        user.setAdmin(admin);
        users.save(user);
        return new CreatedUser(user, plain);
    }

    private static String generatePassword(int len) {
        StringBuilder sb = new StringBuilder(len);
        for (int i = 0; i < len; i++) {
            sb.append(PW_ALPHABET.charAt(RANDOM.nextInt(PW_ALPHABET.length())));
        }
        return sb.toString();
    }

    @Transactional
    public User update(Long id, Boolean admin, String displayName) {
        User user = require(id);
        if (displayName != null) {
            user.setDisplayName(displayName.isBlank() ? null : displayName.trim());
        }
        if (admin != null && admin != user.isAdmin()) {
            if (!admin && user.isAdmin() && users.countByAdminTrue() <= 1) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "LAST_ADMIN",
                        "Không thể bỏ quyền của admin cuối cùng.");
            }
            user.setAdmin(admin);
        }
        return users.save(user);
    }

    @Transactional
    public void delete(Long id, Long actingUserId) {
        User user = require(id);
        if (id.equals(actingUserId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "SELF_DELETE",
                    "Bạn không thể xóa chính tài khoản của mình.");
        }
        if (user.isAdmin() && users.countByAdminTrue() <= 1) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "LAST_ADMIN",
                    "Không thể xóa admin cuối cùng.");
        }
        // Remove dependent rows (no DB-level FK cascade — these reference the user id loosely).
        refreshTokens.deleteByUserId(id);
        if (settings.existsById(id)) {
            settings.deleteById(id);
        }
        for (ApiClient client : clients.findByOwnerUserId(id)) {
            keys.deleteByClient_Id(client.getId());
            clients.delete(client);
        }
        users.delete(user);
    }

    private User require(Long id) {
        return users.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "User not found."));
    }
}
