package site.thaonv.voca.user;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import site.thaonv.voca.apikey.ApiKey;
import site.thaonv.voca.apikey.ApiKeyRepository;

import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Admin-only user management. Guarded by the /api/admin/** chain (ROLE_ADMIN). */
@RestController
@RequestMapping("/api/admin/users")
public class AdminUserController {

    private final UserRepository users;
    private final ApiKeyRepository keys;
    private final AdminUserService adminUserService;

    public AdminUserController(UserRepository users, ApiKeyRepository keys, AdminUserService adminUserService) {
        this.users = users;
        this.keys = keys;
        this.adminUserService = adminUserService;
    }

    public record UpdateUserRequest(Boolean admin, String displayName) {
    }

    @GetMapping
    public List<Map<String, Object>> list() {
        return users.findAll().stream()
                .sorted(Comparator.comparing(User::getId))
                .map(this::toDto)
                .toList();
    }

    @PatchMapping("/{id}")
    public Map<String, Object> update(@PathVariable Long id, @RequestBody UpdateUserRequest req) {
        return toDto(adminUserService.update(id, req.admin(), req.displayName()));
    }

    @DeleteMapping("/{id}")
    public Map<String, Object> delete(@PathVariable Long id, @AuthenticationPrincipal UserPrincipal principal) {
        adminUserService.delete(id, principal.id());
        return Map.of("id", id, "deleted", true);
    }

    private Map<String, Object> toDto(User u) {
        long activeKeys = keys.findByClient_OwnerUserIdOrderByCreatedAtDesc(u.getId()).stream()
                .filter(ApiKey::isActive)
                .count();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", u.getId());
        m.put("email", u.getEmail());
        m.put("displayName", u.getDisplayName());
        m.put("admin", u.isAdmin());
        m.put("apiKeyCount", activeKeys);
        m.put("createdAt", u.getCreatedAt());
        return m;
    }
}
