package site.thaonv.voca.card;

import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import site.thaonv.voca.common.ApiException;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

@Service
public class CardService {

    private static final Set<String> LEVELS = Set.of("new", "learning", "known", "mastered");

    private final CardRepository cards;

    public CardService(CardRepository cards) {
        this.cards = cards;
    }

    public static String slugify(String value) {
        String slug = value.toLowerCase()
                .replaceAll("[^a-z0-9]+", "-")
                .replaceAll("-+", "-")
                .replaceAll("^-|-$", "");
        return slug.isBlank() ? "word" : slug;
    }

    /** Signature the clients poll with ifChangedSince to avoid re-downloading unchanged data. */
    public String manifestVersion() {
        long count = cards.count();
        Instant max = cards.maxCreatedAt();
        return "cards:" + count + ":" + (max == null ? 0 : max.toEpochMilli());
    }

    public List<CardDto> listAll() {
        return cards.findAllByOrderByCreatedAtDesc().stream().map(this::toDto).toList();
    }

    public CardDto getBySlug(String slug) {
        return toDto(requireBySlug(slug));
    }

    @Transactional
    public CardDto setLevel(String slug, String level) {
        if (level == null || !LEVELS.contains(level)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_LEVEL", "Level must be one of " + LEVELS);
        }
        Card card = requireBySlug(slug);
        card.setLevel(level);
        return toDto(card);
    }

    @Transactional
    public void deleteBySlug(String slug) {
        Card card = requireBySlug(slug);
        cards.delete(card);
    }

    /** Fills in missing meanings for cards matched by word. Returns how many were updated. */
    @Transactional
    public int fillMeanings(List<Map<String, String>> updates) {
        int count = 0;
        for (Map<String, String> u : updates) {
            String word = u.get("word");
            if (word == null || word.isBlank()) {
                continue;
            }
            Optional<Card> opt = cards.findFirstByWordIgnoreCase(word.trim());
            if (opt.isEmpty()) {
                continue;
            }
            Card c = opt.get();
            if (u.get("meaningEn") != null) c.setMeaningEn(u.get("meaningEn"));
            if (u.get("meaningVi") != null) c.setMeaningVi(u.get("meaningVi"));
            count++;
        }
        return count;
    }

    /** Deletes every card (bulk clear). Review states/logs cascade via the DB. */
    @Transactional
    public long deleteAll() {
        long n = cards.count();
        cards.deleteAll();
        return n;
    }

    @Transactional
    public CardDto create(CardInput input) {
        if (input.word() == null || input.word().isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MISSING_WORD", "word is required.");
        }
        String slug = input.slug() == null || input.slug().isBlank() ? slugify(input.word()) : input.slug();
        if (cards.existsBySlugIgnoreCase(slug)) {
            throw new ApiException(HttpStatus.CONFLICT, "CARD_EXISTS", "A card with slug '" + slug + "' already exists.");
        }
        Card card = new Card();
        card.setWord(input.word().trim());
        card.setSlug(slug);
        card.setIpa(input.ipa());
        card.setPronunciation(input.pronunciation() != null ? input.pronunciation() : input.ipa());
        card.setFrequency(input.frequency());
        card.setMeaningEn(input.meaningEn());
        card.setMeaningVi(input.meaningVi());
        card.setUseCases(nullSafe(input.useCases()));
        card.setExamples(nullSafe(input.examples()));
        card.setMemoryTip(input.memoryTip());
        card.setToeicTrap(input.toeicTrap());
        if (input.partOfSpeech() != null) card.setPartOfSpeech(input.partOfSpeech());
        if (input.topic() != null) card.setTopic(input.topic());
        card.setTags(nullSafe(input.tags()));
        card.setKeyword(input.keyword());
        card.setPracticePrompt(input.practicePrompt());
        card.setAnswer(input.answer());
        if (input.level() != null && LEVELS.contains(input.level())) card.setLevel(input.level());
        card.setDeckId(input.deckId());
        cards.save(card);
        return toDto(card);
    }

    /** Fast word lookup used by the public /v1 API (exact then partial). */
    public Map<String, Object> lookup(String word) {
        String q = word.trim();
        Optional<Card> exact = cards.findFirstBySlugIgnoreCase(q);
        if (exact.isEmpty()) {
            exact = cards.findFirstByWordIgnoreCase(q);
        }

        List<Card> matches = new ArrayList<>();
        String matchType;
        if (exact.isPresent()) {
            matchType = "exact";
            matches.add(exact.get());
            for (Card c : cards.search(q, PageRequest.of(0, 8))) {
                if (!c.getId().equals(exact.get().getId())) {
                    matches.add(c);
                }
            }
        } else {
            matchType = "partial";
            matches.addAll(cards.search(q, PageRequest.of(0, 8)));
        }

        if (matches.isEmpty()) {
            return Map.of("found", false, "word", q);
        }
        List<CardDto> dtos = matches.stream().limit(8).map(this::toDto).toList();
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("found", true);
        res.put("word", q);
        res.put("matchType", matchType);
        res.put("card", dtos.get(0));
        res.put("cards", dtos);
        return res;
    }

    public CardDto toDto(Card c) {
        return new CardDto(
                c.getId(), c.getSlug(), c.getWord(), c.getIpa(), c.getPronunciation(), c.getFrequency(),
                c.getMeaningEn(), c.getMeaningVi(), c.getUseCases(), c.getExamples(), c.getMemoryTip(),
                c.getToeicTrap(), c.getPartOfSpeech(), c.getTopic(), c.getTags(), c.getKeyword(),
                c.getPracticePrompt(), c.getAnswer(), c.getLevel(),
                c.getAudioKey() != null ? "/v1/audio/" + c.getSlug() : "/v1/audio/" + c.getSlug(),
                c.getCreatedAt());
    }

    private Card requireBySlug(String slug) {
        return cards.findFirstBySlugIgnoreCase(slug)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Card not found: " + slug));
    }

    private static List<String> nullSafe(List<String> in) {
        return in == null ? new ArrayList<>() : in;
    }

    public record CardInput(
            String word, String slug, String ipa, String pronunciation, String frequency,
            String meaningEn, String meaningVi, List<String> useCases, List<String> examples,
            String memoryTip, String toeicTrap, String partOfSpeech, String topic, List<String> tags,
            String keyword, String practicePrompt, String answer, String level, Long deckId) {
    }
}
