package site.thaonv.voca.card;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import site.thaonv.voca.deck.Deck;
import site.thaonv.voca.deck.DeckRepository;
import site.thaonv.voca.user.User;
import site.thaonv.voca.user.UserRepository;

import java.io.File;
import java.io.InputStream;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

/** One-time import of the legacy cards.json into Postgres (runs only when the cards table is empty). */
@Component
@Order(20)
public class CardImportRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(CardImportRunner.class);

    private final CardRepository cards;
    private final DeckRepository decks;
    private final UserRepository users;
    private final ObjectMapper mapper;
    private final String cardsFile;

    public CardImportRunner(CardRepository cards,
                            DeckRepository decks,
                            UserRepository users,
                            ObjectMapper mapper,
                            @Value("${app.import.cards-file:../../cards.json}") String cardsFile) {
        this.cards = cards;
        this.decks = decks;
        this.users = users;
        this.mapper = mapper;
        this.cardsFile = cardsFile;
    }

    @Override
    public void run(ApplicationArguments args) throws Exception {
        if (cards.count() > 0) {
            return;
        }
        JsonNode root = readCards();
        if (root == null) {
            log.warn("Card seed not found (tried '{}', common paths, and bundled resource). Skipping import.", cardsFile);
            return;
        }
        JsonNode array = root.isArray() ? root : root.get("cards");
        if (array == null || !array.isArray()) {
            log.warn("Card import file is not a JSON array. Skipping import.");
            return;
        }

        Long ownerId = users.findAll().stream().filter(User::isAdmin).map(User::getId).findFirst().orElse(null);
        Deck deck = decks.findFirstByNameIgnoreCase("TOEIC Vocabulary").orElseGet(() -> {
            Deck d = new Deck();
            d.setName("TOEIC Vocabulary");
            d.setOwnerId(ownerId);
            d.setPublic(true);
            return decks.save(d);
        });

        int imported = 0;
        for (JsonNode n : array) {
            String word = text(n, "word");
            if (word == null || word.isBlank()) {
                continue;
            }
            String slug = CardService.slugify(word);
            if (cards.existsBySlugIgnoreCase(slug)) {
                continue;
            }
            Card c = new Card();
            c.setWord(word.trim());
            c.setSlug(slug);
            c.setDeckId(deck.getId());
            c.setPronunciation(text(n, "pronunciation"));
            c.setIpa(text(n, "pronunciation")); // v1 kept the IPA string in the pronunciation field
            c.setFrequency(text(n, "frequency"));
            c.setMeaningEn(text(n, "meaningEn"));
            c.setMeaningVi(text(n, "meaningVi"));
            c.setUseCases(stringList(n, "useCases"));
            c.setExamples(stringList(n, "examples"));
            c.setMemoryTip(text(n, "memoryTip"));
            c.setToeicTrap(text(n, "toeicTrap"));
            if (text(n, "partOfSpeech") != null) c.setPartOfSpeech(text(n, "partOfSpeech"));
            if (text(n, "topic") != null) c.setTopic(text(n, "topic"));
            c.setTags(stringList(n, "tags"));
            c.setKeyword(text(n, "keyword"));
            c.setPracticePrompt(text(n, "practicePrompt"));
            c.setAnswer(text(n, "answer"));
            String level = text(n, "level");
            if (level != null && !level.isBlank()) c.setLevel(level);
            Instant createdAt = parseInstant(text(n, "createdAt"));
            if (createdAt != null) c.setCreatedAt(createdAt);
            cards.save(c);
            imported++;
        }
        log.info("Imported {} cards.", imported);
    }

    /**
     * Reads the seed cards from: the configured path, then common relative paths (dev), then the
     * jar's bundled resource (classpath:seed/cards.json) so a downloaded release self-seeds anywhere.
     */
    private JsonNode readCards() throws Exception {
        for (String candidate : new String[]{cardsFile, "cards.json", "../cards.json", "../../cards.json", "../../../cards.json"}) {
            if (candidate == null || candidate.isBlank()) {
                continue;
            }
            File f = new File(candidate);
            if (f.exists()) {
                log.info("Importing seed cards from file {}", f.getPath());
                return mapper.readTree(f);
            }
        }
        ClassPathResource bundled = new ClassPathResource("seed/cards.json");
        if (bundled.exists()) {
            try (InputStream in = bundled.getInputStream()) {
                log.info("Importing seed cards from bundled resource (classpath:seed/cards.json)");
                return mapper.readTree(in);
            }
        }
        return null;
    }

    private static String text(JsonNode node, String field) {
        return node.hasNonNull(field) ? node.get(field).asText() : null;
    }

    private static List<String> stringList(JsonNode node, String field) {
        List<String> out = new ArrayList<>();
        JsonNode arr = node.get(field);
        if (arr != null && arr.isArray()) {
            arr.forEach(item -> out.add(item.asText()));
        }
        return out;
    }

    private static Instant parseInstant(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            return OffsetDateTime.parse(value).toInstant();
        } catch (Exception ignored) {
            try {
                return Instant.parse(value);
            } catch (Exception ignored2) {
                return null;
            }
        }
    }
}
