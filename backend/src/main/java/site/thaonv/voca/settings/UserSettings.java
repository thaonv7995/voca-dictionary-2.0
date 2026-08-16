package site.thaonv.voca.settings;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.Map;

/** Per-user settings, including server-held LLM/TTS secrets that are never returned to clients. */
@Entity
@Table(name = "user_settings")
@Getter
@Setter
@NoArgsConstructor
public class UserSettings {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @Column(name = "llm_base_url")
    private String llmBaseUrl;

    @Column(name = "llm_api_key_enc")
    private String llmApiKey;

    @Column(name = "llm_model")
    private String llmModel;

    @Column(name = "tts_base_url")
    private String ttsBaseUrl;

    @Column(name = "tts_api_key_enc")
    private String ttsApiKey;

    @Column(name = "tts_model")
    private String ttsModel;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private Map<String, Object> voices;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "feature_flags", columnDefinition = "jsonb")
    private Map<String, Object> featureFlags;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();
}
