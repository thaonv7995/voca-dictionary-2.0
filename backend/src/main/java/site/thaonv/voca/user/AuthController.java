package site.thaonv.voca.user;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final UserService userService;

    public AuthController(UserService userService) {
        this.userService = userService;
    }

    public record RegisterRequest(@Email @NotBlank String email, @NotBlank String password, String displayName) {
    }

    public record LoginRequest(@NotBlank String email, @NotBlank String password) {
    }

    public record RefreshRequest(@NotBlank String refreshToken) {
    }

    @PostMapping("/register")
    public Map<String, Object> register(@RequestBody @Valid RegisterRequest req) {
        return toAuthResponse(userService.register(req.email(), req.password(), req.displayName()));
    }

    @PostMapping("/login")
    public Map<String, Object> login(@RequestBody @Valid LoginRequest req) {
        return toAuthResponse(userService.login(req.email(), req.password()));
    }

    @PostMapping("/refresh")
    public Map<String, Object> refresh(@RequestBody @Valid RefreshRequest req) {
        return toAuthResponse(userService.refresh(req.refreshToken()));
    }

    @PostMapping("/logout")
    public Map<String, Object> logout(@RequestBody RefreshRequest req) {
        userService.logout(req.refreshToken());
        return Map.of("ok", true);
    }

    @GetMapping("/me")
    public Map<String, Object> me(@AuthenticationPrincipal UserPrincipal principal) {
        return userDto(userService.requireUser(principal.id()));
    }

    private Map<String, Object> toAuthResponse(UserService.AuthResult result) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("accessToken", result.accessToken());
        body.put("refreshToken", result.refreshToken());
        body.put("user", userDto(result.user()));
        return body;
    }

    private Map<String, Object> userDto(User user) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", user.getId());
        m.put("email", user.getEmail());
        m.put("displayName", user.getDisplayName());
        m.put("admin", user.isAdmin());
        return m;
    }
}
