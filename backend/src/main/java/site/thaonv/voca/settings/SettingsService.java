package site.thaonv.voca.settings;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@Service
public class SettingsService {

    private final UserSettingsRepository repo;

    public SettingsService(UserSettingsRepository repo) {
        this.repo = repo;
    }

    public UserSettings getOrCreate(Long userId) {
        return repo.findById(userId).orElseGet(() -> {
            UserSettings s = new UserSettings();
            s.setUserId(userId);
            return s;
        });
    }

    /** Non-secret view returned to clients: secrets are replaced by boolean "has*" flags. */
    public Map<String, Object> toSafeDto(UserSettings s) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("llmBaseUrl", s.getLlmBaseUrl());
        m.put("llmModel", s.getLlmModel());
        m.put("hasLlmKey", s.getLlmApiKey() != null && !s.getLlmApiKey().isBlank());
        m.put("ttsBaseUrl", s.getTtsBaseUrl());
        m.put("ttsModel", s.getTtsModel());
        m.put("hasTtsKey", s.getTtsApiKey() != null && !s.getTtsApiKey().isBlank());
        m.put("voices", s.getVoices());
        m.put("featureFlags", s.getFeatureFlags());
        return m;
    }

    @Transactional
    public Map<String, Object> update(Long userId, UpdateSettingsRequest req) {
        UserSettings s = getOrCreate(userId);
        if (req.llmBaseUrl() != null) s.setLlmBaseUrl(blankToNull(req.llmBaseUrl()));
        if (req.llmModel() != null) s.setLlmModel(blankToNull(req.llmModel()));
        if (req.llmApiKey() != null) s.setLlmApiKey(blankToNull(req.llmApiKey())); // only overwrite when provided
        if (req.ttsBaseUrl() != null) s.setTtsBaseUrl(blankToNull(req.ttsBaseUrl()));
        if (req.ttsModel() != null) s.setTtsModel(blankToNull(req.ttsModel()));
        if (req.ttsApiKey() != null) s.setTtsApiKey(blankToNull(req.ttsApiKey()));
        if (req.voices() != null) s.setVoices(req.voices());
        if (req.featureFlags() != null) s.setFeatureFlags(req.featureFlags());
        s.setUpdatedAt(Instant.now());
        repo.save(s);
        return toSafeDto(s);
    }

    public record UpdateSettingsRequest(
            String llmBaseUrl, String llmApiKey, String llmModel,
            String ttsBaseUrl, String ttsApiKey, String ttsModel,
            Map<String, Object> voices, Map<String, Object> featureFlags) {
    }

    private static String blankToNull(String v) {
        return v == null || v.isBlank() ? null : v.trim();
    }
}
