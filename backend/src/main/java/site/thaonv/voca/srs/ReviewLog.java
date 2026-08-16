package site.thaonv.voca.srs;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "review_logs")
@Getter
@Setter
@NoArgsConstructor
public class ReviewLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "card_id", nullable = false)
    private Long cardId;

    @Column(nullable = false)
    private short rating;

    private Short state;

    @Column(name = "elapsed_days")
    private Integer elapsedDays;

    @Column(name = "scheduled_days")
    private Integer scheduledDays;

    @Column(name = "reviewed_at", nullable = false)
    private Instant reviewedAt = Instant.now();
}
