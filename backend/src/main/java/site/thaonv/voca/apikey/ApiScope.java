package site.thaonv.voca.apikey;

import java.util.Set;

/** Scopes a third-party API key may hold. Each maps to a Spring authority "SCOPE_&lt;value&gt;". */
public final class ApiScope {

    private ApiScope() {
    }

    public static final String CARDS_READ = "cards:read";
    public static final String CARDS_LOOKUP = "cards:lookup";
    public static final String CARDS_CREATE = "cards:create";
    public static final String AUDIO_READ = "audio:read";
    public static final String PRACTICE_GENERATE = "practice:generate";

    public static final Set<String> KNOWN = Set.of(
            CARDS_READ, CARDS_LOOKUP, CARDS_CREATE, AUDIO_READ, PRACTICE_GENERATE);
}
