package site.thaonv.voca.srs;

/** Maps an FSRS review state onto the four legacy display levels used across the Voca UI. */
public final class LevelMapper {

    private LevelMapper() {
    }

    public static String levelFor(ReviewState state) {
        if (state == null) {
            return "new";
        }
        short s = state.getState();
        if (s == FsrsScheduler.STATE_NEW) {
            return "new";
        }
        if (s == FsrsScheduler.STATE_LEARNING || s == FsrsScheduler.STATE_RELEARNING) {
            return "learning";
        }
        double stability = state.getStability() == null ? 0 : state.getStability();
        if (stability >= 100) {
            return "mastered";
        }
        if (stability >= 21) {
            return "known";
        }
        return "learning";
    }
}
