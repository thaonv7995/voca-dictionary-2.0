package site.thaonv.voca.ai;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import site.thaonv.voca.common.ApiException;
import site.thaonv.voca.settings.SettingsService;
import site.thaonv.voca.settings.UserSettings;

/** Resolves effective LLM/TTS config: per-user server-held settings override env defaults. */
@Component
public class AiConfigResolver {

    private final SettingsService settings;
    private final String llmBaseEnv;
    private final String llmKeyEnv;
    private final String llmModelEnv;
    private final String ttsBaseEnv;
    private final String ttsKeyEnv;
    private final String ttsModelEnv;

    public AiConfigResolver(SettingsService settings,
                            @Value("${app.llm.base-url:}") String llmBaseEnv,
                            @Value("${app.llm.api-key:}") String llmKeyEnv,
                            @Value("${app.llm.model:gpt-4o-mini}") String llmModelEnv,
                            @Value("${app.tts.base-url:}") String ttsBaseEnv,
                            @Value("${app.tts.api-key:}") String ttsKeyEnv,
                            @Value("${app.tts.model:edge-tts/en-US-AndrewNeural}") String ttsModelEnv) {
        this.settings = settings;
        this.llmBaseEnv = llmBaseEnv;
        this.llmKeyEnv = llmKeyEnv;
        this.llmModelEnv = llmModelEnv;
        this.ttsBaseEnv = ttsBaseEnv;
        this.ttsKeyEnv = ttsKeyEnv;
        this.ttsModelEnv = ttsModelEnv;
    }

    public record LlmConfig(String baseUrl, String apiKey, String model) {
    }

    public record TtsConfig(String baseUrl, String apiKey, String model) {
    }

    public LlmConfig resolveLlm(Long userId) {
        String base = llmBaseEnv;
        String key = llmKeyEnv;
        String model = llmModelEnv;
        if (userId != null) {
            UserSettings s = settings.getOrCreate(userId);
            if (notBlank(s.getLlmBaseUrl())) base = s.getLlmBaseUrl();
            if (notBlank(s.getLlmApiKey())) key = s.getLlmApiKey();
            if (notBlank(s.getLlmModel())) model = s.getLlmModel();
        }
        if (!notBlank(base) || !notBlank(key)) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "LLM_NOT_CONFIGURED",
                    "No LLM base URL/API key configured (env app.llm.* or user settings).");
        }
        return new LlmConfig(stripSlash(base), key, notBlank(model) ? model : "gpt-4o-mini");
    }

    public TtsConfig resolveTts(Long userId) {
        String base = ttsBaseEnv;
        String key = ttsKeyEnv;
        String model = ttsModelEnv;
        if (userId != null) {
            UserSettings s = settings.getOrCreate(userId);
            if (notBlank(s.getTtsBaseUrl())) base = s.getTtsBaseUrl();
            if (notBlank(s.getTtsApiKey())) key = s.getTtsApiKey();
            if (notBlank(s.getTtsModel())) model = s.getTtsModel();
        }
        if (!notBlank(base) || !notBlank(key)) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "TTS_NOT_CONFIGURED",
                    "No TTS base URL/API key configured (env app.tts.* or user settings).");
        }
        return new TtsConfig(stripSlash(base), key, notBlank(model) ? model : "edge-tts/en-US-AndrewNeural");
    }

    private static boolean notBlank(String v) {
        return v != null && !v.isBlank();
    }

    private static String stripSlash(String v) {
        return v.replaceAll("/+$", "");
    }
}
