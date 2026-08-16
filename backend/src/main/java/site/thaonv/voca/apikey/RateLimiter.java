package site.thaonv.voca.apikey;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Per-key fixed-window rate limiter (in-memory).
 * Spike-grade only — replace with Bucket4j + Redis for a multi-instance production deployment.
 */
@Component
public class RateLimiter {

    private final int limitPerMinute;
    private final ConcurrentHashMap<String, AtomicInteger> windows = new ConcurrentHashMap<>();

    public RateLimiter(@Value("${app.apikey.rate-limit-per-minute:120}") int limitPerMinute) {
        this.limitPerMinute = limitPerMinute;
    }

    public boolean allow(long keyId) {
        long minute = System.currentTimeMillis() / 60_000L;
        String bucket = keyId + ":" + minute;

        // Opportunistic cleanup of stale windows from previous minutes.
        if (windows.size() > 10_000) {
            String suffix = ":" + minute;
            windows.keySet().removeIf(k -> !k.endsWith(suffix));
        }

        AtomicInteger counter = windows.computeIfAbsent(bucket, k -> new AtomicInteger(0));
        return counter.incrementAndGet() <= limitPerMinute;
    }
}
