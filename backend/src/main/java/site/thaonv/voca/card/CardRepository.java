package site.thaonv.voca.card;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface CardRepository extends JpaRepository<Card, Long> {

    Optional<Card> findFirstBySlugIgnoreCase(String slug);

    Optional<Card> findFirstByWordIgnoreCase(String word);

    boolean existsBySlugIgnoreCase(String slug);

    List<Card> findAllByOrderByCreatedAtDesc();

    @Query("select max(c.createdAt) from Card c")
    Instant maxCreatedAt();

    @Query("select c from Card c "
            + "where lower(c.word) like lower(concat('%', :q, '%')) "
            + "or lower(c.slug) like lower(concat('%', :q, '%')) "
            + "order by c.word")
    List<Card> search(@Param("q") String q, Pageable pageable);
}
