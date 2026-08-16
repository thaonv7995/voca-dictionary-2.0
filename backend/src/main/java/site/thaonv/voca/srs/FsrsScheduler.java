package site.thaonv.voca.srs;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

/**
 * FSRS (Free Spaced Repetition Scheduler) — Java implementation with FSRS-5 default weights.
 * Computes the next stability/difficulty/interval from a review grade. Same-day short-term steps
 * (w[17], w[18]) are omitted; this is the daily scheduler used server-side as the single source of truth.
 * Grades: 1=Again, 2=Hard, 3=Good, 4=Easy. States: 0=New, 1=Learning, 2=Review, 3=Relearning.
 */
@Component
public class FsrsScheduler {

    public static final int STATE_NEW = 0;
    public static final int STATE_LEARNING = 1;
    public static final int STATE_REVIEW = 2;
    public static final int STATE_RELEARNING = 3;

    private static final double DECAY = -0.5;
    private static final double FACTOR = Math.pow(0.9, 1.0 / DECAY) - 1.0; // ≈ 19/81

    // FSRS-5 default parameters (w0..w18).
    private static final double[] W = {
            0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575,
            0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621
    };

    private final double requestRetention;
    private final int maximumInterval;

    public FsrsScheduler(@Value("${app.srs.request-retention:0.9}") double requestRetention,
                         @Value("${app.srs.maximum-interval:36500}") int maximumInterval) {
        this.requestRetention = requestRetention;
        this.maximumInterval = maximumInterval;
    }

    public record Computation(double stability, double difficulty, int state, int intervalDays, Instant due) {
    }

    /** Compute the next scheduling state. Pass prev=null for a card's first review. */
    public Computation review(ReviewState prev, int grade, Instant now) {
        int g = Math.max(1, Math.min(4, grade));

        double stability;
        double difficulty;
        int state;

        boolean firstReview = prev == null || prev.getLastReview() == null || prev.getStability() == null;
        if (firstReview) {
            stability = initStability(g);
            difficulty = initDifficulty(g);
            state = (g == 1) ? STATE_LEARNING : STATE_REVIEW;
        } else {
            double elapsedDays = Math.max(0.0,
                    (now.toEpochMilli() - prev.getLastReview().toEpochMilli()) / 86_400_000.0);
            double r = retrievability(elapsedDays, prev.getStability());
            difficulty = nextDifficulty(prev.getDifficulty(), g);
            if (g == 1) {
                stability = nextStabilityForget(difficulty, prev.getStability(), r);
                state = STATE_RELEARNING;
            } else {
                stability = nextStabilityRecall(difficulty, prev.getStability(), r, g);
                state = STATE_REVIEW;
            }
        }

        stability = Math.max(0.1, stability);
        int interval = nextInterval(stability);
        Instant due = now.plus(interval, ChronoUnit.DAYS);
        return new Computation(stability, difficulty, state, interval, due);
    }

    private double initStability(int g) {
        return Math.max(0.1, W[g - 1]);
    }

    private double initDifficulty(int g) {
        return clampDifficulty(W[4] - Math.exp(W[5] * (g - 1)) + 1.0);
    }

    private double retrievability(double elapsedDays, double stability) {
        return Math.pow(1.0 + FACTOR * elapsedDays / stability, DECAY);
    }

    private int nextInterval(double stability) {
        double ivl = stability / FACTOR * (Math.pow(requestRetention, 1.0 / DECAY) - 1.0);
        long rounded = Math.round(ivl);
        return (int) Math.max(1, Math.min(rounded, maximumInterval));
    }

    private double nextDifficulty(double d, int g) {
        double deltaD = -W[6] * (g - 3);
        double damped = d + deltaD * (10.0 - d) / 9.0; // FSRS-5 linear damping
        double reverted = W[7] * initDifficulty(4) + (1.0 - W[7]) * damped; // mean reversion
        return clampDifficulty(reverted);
    }

    private double nextStabilityRecall(double d, double s, double r, int g) {
        double hardPenalty = (g == 2) ? W[15] : 1.0;
        double easyBonus = (g == 4) ? W[16] : 1.0;
        double inc = Math.exp(W[8]) * (11.0 - d) * Math.pow(s, -W[9])
                * (Math.exp(W[10] * (1.0 - r)) - 1.0) * hardPenalty * easyBonus;
        return s * (1.0 + inc);
    }

    private double nextStabilityForget(double d, double s, double r) {
        double postLapse = W[11] * Math.pow(d, -W[12]) * (Math.pow(s + 1.0, W[13]) - 1.0) * Math.exp(W[14] * (1.0 - r));
        return Math.min(postLapse, s); // a lapse never increases stability
    }

    private double clampDifficulty(double d) {
        return Math.max(1.0, Math.min(10.0, d));
    }
}
