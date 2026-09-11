package site.thaonv.voca.card;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface CardRepository extends JpaRepository<Card, Long> {

    // ---- Global (any owner) — used only for the copy-on-add de-dup check ----
    Optional<Card> findFirstBySlugIgnoreCase(String slug);

    Optional<Card> findFirstByLanguageAndWordIgnoreCase(String language, String word);

    // ---- Per-owner (the normal app scope) ----
    List<Card> findByOwnerIdOrderByCreatedAtDesc(Long ownerId);

    Optional<Card> findFirstByOwnerIdAndSlugIgnoreCase(Long ownerId, String slug);

    Optional<Card> findFirstByOwnerIdAndWordIgnoreCase(Long ownerId, String word);

    boolean existsByOwnerIdAndSlugIgnoreCase(Long ownerId, String slug);

    boolean existsByOwnerIdAndLanguageAndWordIgnoreCase(Long ownerId, String language, String word);

    long countByOwnerId(Long ownerId);

    void deleteByOwnerId(Long ownerId);

    @Query("select max(c.createdAt) from Card c where c.ownerId = :ownerId")
    Instant maxCreatedAtByOwner(@Param("ownerId") Long ownerId);

    @Query("select c from Card c "
            + "where c.ownerId = :ownerId "
            + "and (lower(c.word) like lower(concat('%', :q, '%')) "
            + "or lower(c.slug) like lower(concat('%', :q, '%'))) "
            + "order by c.word")
    List<Card> searchByOwner(@Param("ownerId") Long ownerId, @Param("q") String q, Pageable pageable);
}
