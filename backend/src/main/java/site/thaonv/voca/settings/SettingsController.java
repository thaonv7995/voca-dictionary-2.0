package site.thaonv.voca.settings;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import site.thaonv.voca.user.UserPrincipal;

import java.util.Map;

@RestController
@RequestMapping("/api/user/settings")
public class SettingsController {

    private final SettingsService settingsService;

    public SettingsController(SettingsService settingsService) {
        this.settingsService = settingsService;
    }

    @GetMapping
    public Map<String, Object> get(@AuthenticationPrincipal UserPrincipal principal) {
        return settingsService.toSafeDto(settingsService.getOrCreate(principal.id()));
    }

    @PutMapping
    public Map<String, Object> update(@AuthenticationPrincipal UserPrincipal principal,
                                      @RequestBody SettingsService.UpdateSettingsRequest req) {
        return settingsService.update(principal.id(), req);
    }
}
