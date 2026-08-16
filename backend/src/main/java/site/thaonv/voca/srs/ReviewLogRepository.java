package site.thaonv.voca.srs;

import org.springframework.data.jpa.repository.JpaRepository;

public interface ReviewLogRepository extends JpaRepository<ReviewLog, Long> {
    long countByUserId(Long userId);
}
