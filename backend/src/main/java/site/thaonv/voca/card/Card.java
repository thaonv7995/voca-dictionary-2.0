package site.thaonv.voca.card;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "cards")
@Getter
@Setter
@NoArgsConstructor
public class Card {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "deck_id")
    private Long deckId;

    @Column(name = "owner_id", nullable = false)
    private Long ownerId;

    @Column(nullable = false)
    private String word;

    @Column(nullable = false)
    private String language = "en";

    @Column(nullable = false)
    private String slug;

    private String ipa;

    private String pronunciation;

    private String frequency;

    @Column(name = "meaning_en")
    private String meaningEn;

    @Column(name = "meaning_vi")
    private String meaningVi;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private List<String> examples = new ArrayList<>();

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "use_cases", columnDefinition = "jsonb")
    private List<String> useCases = new ArrayList<>();

    @Column(name = "memory_tip")
    private String memoryTip;

    @Column(name = "toeic_trap")
    private String toeicTrap;

    @Column(name = "part_of_speech", nullable = false)
    private String partOfSpeech = "unknown";

    @Column(nullable = false)
    private String topic = "uncategorized";

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private List<String> tags = new ArrayList<>();

    private String keyword;

    @Column(name = "practice_prompt")
    private String practicePrompt;

    private String answer;

    @Column(nullable = false)
    private String level = "new";

    @Column(name = "audio_key")
    private String audioKey;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();
}
