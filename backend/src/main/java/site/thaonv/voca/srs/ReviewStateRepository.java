package site.thaonv.voca.srs;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface ReviewStateRepository extends JpaRepository<ReviewState, Long> {

    Optional<ReviewState> findByUserIdAndCardId(Long userId, Long cardId);

    List<ReviewState> findByUserId(Long userId);

    long countByUserIdAndDueLessThanEqual(Long userId, Instant due);
}
