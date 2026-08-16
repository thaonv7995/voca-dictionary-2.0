package site.thaonv.voca.practice;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PracticeAttemptRepository extends JpaRepository<PracticeAttempt, Long> {
    List<PracticeAttempt> findTop50ByUserIdOrderByCreatedAtDesc(Long userId);
}
