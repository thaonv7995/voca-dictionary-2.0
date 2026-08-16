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

/** Vocabulary is per-user: every read/write is scoped to the owning user's id. */
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
    public String manifestVersion(Long ownerId) {
        long count = cards.countByOwnerId(ownerId);
        Instant max = cards.maxCreatedAtByOwner(ownerId);
        return "cards:" + ownerId + ":" + count + ":" + (max == null ? 0 : max.toEpochMilli());
    }

    public List<CardDto> listAll(Long ownerId) {
        return cards.findByOwnerIdOrderByCreatedAtDesc(ownerId).stream().map(this::toDto).toList();
    }

    public CardDto getBySlug(String slug, Long ownerId) {
        return toDto(requireBySlug(slug, ownerId));
    }

    @Transactional
    public CardDto setLevel(String slug, String level, Long ownerId) {
        if (level == null || !LEVELS.contains(level)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_LEVEL", "Level must be one of " + LEVELS);
        }
        Card card = requireBySlug(slug, ownerId);
        card.setLevel(level);
        return toDto(card);
    }

    @Transactional
    public void deleteBySlug(String slug, Long ownerId) {
        cards.delete(requireBySlug(slug, ownerId));
    }

    /** Fills in missing meanings for the owner's cards matched by word. Returns how many were updated. */
    @Transactional
    public int fillMeanings(List<Map<String, String>> updates, Long ownerId) {
        int count = 0;
        for (Map<String, String> u : updates) {
            String word = u.get("word");
            if (word == null || word.isBlank()) {
                continue;
            }
            Optional<Card> opt = cards.findFirstByOwnerIdAndWordIgnoreCase(ownerId, word.trim());
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

    /** Clears the owner's whole list. Their review states/logs cascade via the DB. */
    @Transactional
    public long deleteAll(Long ownerId) {
        long n = cards.countByOwnerId(ownerId);
        cards.deleteByOwnerId(ownerId);
        return n;
    }

    /** True if this user already owns a card with the given slug. */
    public boolean userHasSlug(Long ownerId, String slug) {
        return cards.existsByOwnerIdAndSlugIgnoreCase(ownerId, slug);
    }

    /** Any user's card with this slug (for copy-on-add de-dup), or null. */
    public Card findAnyBySlug(String slug) {
        return cards.findFirstBySlugIgnoreCase(slug).orElse(null);
    }

    /** Copies an existing card's content into a fresh card owned by ownerId (no LLM cost). Level starts at "new". */
    @Transactional
    public CardDto copyToUser(Card source, Long ownerId) {
        CardInput input = new CardInput(
                source.getWord(), source.getSlug(), source.getIpa(), source.getPronunciation(), source.getFrequency(),
                source.getMeaningEn(), source.getMeaningVi(), source.getUseCases(), source.getExamples(), source.getMemoryTip(),
                source.getToeicTrap(), source.getPartOfSpeech(), source.getTopic(), source.getTags(), source.getKeyword(),
                source.getPracticePrompt(), source.getAnswer(), "new", source.getDeckId());
        return create(input, ownerId);
    }

    @Transactional
    public CardDto create(CardInput input, Long ownerId) {
        if (ownerId == null) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "No owner for card.");
        }
        if (input.word() == null || input.word().isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MISSING_WORD", "word is required.");
        }
        String slug = input.slug() == null || input.slug().isBlank() ? slugify(input.word()) : input.slug();
        if (cards.existsByOwnerIdAndSlugIgnoreCase(ownerId, slug)) {
            throw new ApiException(HttpStatus.CONFLICT, "CARD_EXISTS", "Từ '" + slug + "' đã có trong danh sách của bạn.");
        }
        Card card = new Card();
        card.setOwnerId(ownerId);
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

    /** Word lookup within the owner's cards (exact then partial). Used by the /v1 API (owner = key holder). */
    public Map<String, Object> lookup(String word, Long ownerId) {
        String q = word.trim();
        Optional<Card> exact = cards.findFirstByOwnerIdAndSlugIgnoreCase(ownerId, q);
        if (exact.isEmpty()) {
            exact = cards.findFirstByOwnerIdAndWordIgnoreCase(ownerId, q);
        }

        List<Card> matches = new ArrayList<>();
        String matchType;
        if (exact.isPresent()) {
            matchType = "exact";
            matches.add(exact.get());
            for (Card c : cards.searchByOwner(ownerId, q, PageRequest.of(0, 8))) {
                if (!c.getId().equals(exact.get().getId())) {
                    matches.add(c);
                }
            }
        } else {
            matchType = "partial";
            matches.addAll(cards.searchByOwner(ownerId, q, PageRequest.of(0, 8)));
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
                "/v1/audio/" + c.getSlug(),
                c.getCreatedAt());
    }

    private Card requireBySlug(String slug, Long ownerId) {
        return cards.findFirstByOwnerIdAndSlugIgnoreCase(ownerId, slug)
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
