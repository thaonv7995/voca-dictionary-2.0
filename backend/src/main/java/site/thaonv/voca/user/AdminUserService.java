package site.thaonv.voca.user;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import site.thaonv.voca.apikey.ApiClient;
import site.thaonv.voca.apikey.ApiClientRepository;
import site.thaonv.voca.apikey.ApiKeyRepository;
import site.thaonv.voca.common.ApiException;
import site.thaonv.voca.settings.UserSettingsRepository;

/** Admin-only user administration: role changes and account removal with dependent-data cleanup. */
@Service
public class AdminUserService {

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final UserSettingsRepository settings;
    private final ApiClientRepository clients;
    private final ApiKeyRepository keys;

    public AdminUserService(UserRepository users,
                            RefreshTokenRepository refreshTokens,
                            UserSettingsRepository settings,
                            ApiClientRepository clients,
                            ApiKeyRepository keys) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.settings = settings;
        this.clients = clients;
        this.keys = keys;
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
