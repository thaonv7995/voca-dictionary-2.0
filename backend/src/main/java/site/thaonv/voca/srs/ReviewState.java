package site.thaonv.voca.srs;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "card_review_states", uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "card_id"}))
@Getter
@Setter
@NoArgsConstructor
public class ReviewState {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "card_id", nullable = false)
    private Long cardId;

    private Double stability;

    private Double difficulty;

    private Instant due;

    @Column(nullable = false)
    private short state = 0;

    @Column(nullable = false)
    private int reps = 0;

    @Column(nullable = false)
    private int lapses = 0;

    @Column(name = "last_review")
    private Instant lastReview;
}
