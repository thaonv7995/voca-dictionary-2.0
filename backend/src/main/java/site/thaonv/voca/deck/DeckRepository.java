package site.thaonv.voca.deck;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface DeckRepository extends JpaRepository<Deck, Long> {
    Optional<Deck> findFirstByNameIgnoreCase(String name);
}
