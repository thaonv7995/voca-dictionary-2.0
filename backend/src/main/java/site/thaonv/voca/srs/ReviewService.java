package site.thaonv.voca.srs;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import site.thaonv.voca.card.Card;
import site.thaonv.voca.card.CardRepository;
import site.thaonv.voca.card.CardService;
import site.thaonv.voca.common.ApiException;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class ReviewService {

    private final ReviewStateRepository states;
    private final ReviewLogRepository logs;
    private final FsrsScheduler scheduler;
    private final CardRepository cards;
    private final CardService cardService;

    public ReviewService(ReviewStateRepository states,
                         ReviewLogRepository logs,
                         FsrsScheduler scheduler,
                         CardRepository cards,
                         CardService cardService) {
        this.states = states;
        this.logs = logs;
        this.scheduler = scheduler;
        this.cards = cards;
        this.cardService = cardService;
    }

    @Transactional
    public Map<String, Object> review(Long userId, String slug, int grade) {
        Card card = cards.findFirstByOwnerIdAndSlugIgnoreCase(userId, slug)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Card not found: " + slug));
        Instant now = Instant.now();

        ReviewState state = states.findByUserIdAndCardId(userId, card.getId()).orElse(null);
        int elapsedDays = (state != null && state.getLastReview() != null)
                ? (int) Duration.between(state.getLastReview(), now).toDays() : 0;

        boolean wasNew = state == null || state.getState() == FsrsScheduler.STATE_NEW;
        FsrsScheduler.Computation c = scheduler.review(state, grade, now);

        if (state == null) {
            state = new ReviewState();
            state.setUserId(userId);
            state.setCardId(card.getId());
        }
        state.setStability(c.stability());
        state.setDifficulty(c.difficulty());
        state.setState((short) c.state());
        state.setDue(c.due());
        state.setLastReview(now);
        state.setReps(state.getReps() + 1);
        if (grade == 1 && !wasNew) {
            state.setLapses(state.getLapses() + 1);
        }
        states.save(state);

        String derivedLevel = LevelMapper.levelFor(state);
        if (!derivedLevel.equals(card.getLevel())) {
            card.setLevel(derivedLevel);
            cards.save(card);
        }

        ReviewLog logEntry = new ReviewLog();
        logEntry.setUserId(userId);
        logEntry.setCardId(card.getId());
        logEntry.setRating((short) grade);
        logEntry.setState((short) c.state());
        logEntry.setElapsedDays(elapsedDays);
        logEntry.setScheduledDays(c.intervalDays());
        logEntry.setReviewedAt(now);
        logs.save(logEntry);

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("slug", card.getSlug());
        res.put("grade", grade);
        res.put("level", derivedLevel);
        res.put("due", state.getDue());
        res.put("intervalDays", c.intervalDays());
        res.put("stability", round(state.getStability()));
        res.put("difficulty", round(state.getDifficulty()));
        res.put("reps", state.getReps());
        res.put("lapses", state.getLapses());
        res.put("state", state.getState());
        return res;
    }

    public Map<String, Object> due(Long userId) {
        return due(userId, null);
    }

    public Map<String, Object> due(Long userId, String language) {
        Instant now = Instant.now();
        Map<Long, ReviewState> byCard = states.findByUserId(userId).stream()
                .collect(Collectors.toMap(ReviewState::getCardId, Function.identity(), (a, b) -> a));

        String filterLang = (language == null || language.isBlank()) ? null : CardService.normalizeLanguage(language);
        List<Map<String, Object>> out = new ArrayList<>();
        for (Card card : cards.findByOwnerIdOrderByCreatedAtDesc(userId)) {
            if (filterLang != null && !filterLang.equals(CardService.normalizeLanguage(card.getLanguage()))) {
                continue;
            }
            ReviewState st = byCard.get(card.getId());
            boolean isDue = st == null || st.getDue() == null || !st.getDue().isAfter(now);
            if (isDue) {
                out.add(dueEntry(card, st));
            }
        }
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("count", out.size());
        res.put("cards", out);
        return res;
    }

    public Map<String, Object> stats(Long userId) {
        return stats(userId, null);
    }

    public Map<String, Object> stats(Long userId, String language) {
        Instant now = Instant.now();
        Map<Long, ReviewState> byCard = states.findByUserId(userId).stream()
                .collect(Collectors.toMap(ReviewState::getCardId, Function.identity(), (a, b) -> a));

        String filterLang = (language == null || language.isBlank()) ? null : CardService.normalizeLanguage(language);
        Map<String, Integer> byLevel = new LinkedHashMap<>();
        for (String level : List.of("new", "learning", "known", "mastered")) {
            byLevel.put(level, 0);
        }
        int dueNow = 0;
        int totalCards = 0;
        for (Card card : cards.findByOwnerIdOrderByCreatedAtDesc(userId)) {
            if (filterLang != null && !filterLang.equals(CardService.normalizeLanguage(card.getLanguage()))) {
                continue;
            }
            totalCards++;
            ReviewState st = byCard.get(card.getId());
            String level = effectiveLevel(card, st);
            byLevel.merge(level, 1, Integer::sum);
            if (st == null || st.getDue() == null || !st.getDue().isAfter(now)) {
                dueNow++;
            }
        }

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("totalCards", totalCards);
        res.put("totalReviews", logs.countByUserId(userId));
        res.put("dueNow", dueNow);
        res.put("byLevel", byLevel);
        return res;
    }

    private Map<String, Object> dueEntry(Card card, ReviewState st) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("card", cardService.toDto(card));
        Map<String, Object> review = new LinkedHashMap<>();
        review.put("level", effectiveLevel(card, st));
        review.put("due", st == null ? null : st.getDue());
        review.put("reps", st == null ? 0 : st.getReps());
        review.put("lapses", st == null ? 0 : st.getLapses());
        review.put("isNew", st == null);
        m.put("review", review);
        return m;
    }

    private static String effectiveLevel(Card card, ReviewState st) {
        if (st != null) {
            return LevelMapper.levelFor(st);
        }
        String cardLevel = card.getLevel();
        if (cardLevel != null && List.of("new", "learning", "known", "mastered").contains(cardLevel)) {
            return cardLevel;
        }
        return "new";
    }

    private static Double round(Double v) {
        return v == null ? null : Math.round(v * 1000.0) / 1000.0;
    }
}
