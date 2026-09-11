package site.thaonv.voca.card;

import java.time.Instant;
import java.util.List;

public record CardDto(
        Long id,
        String slug,
        String word,
        String language,
        String ipa,
        String pronunciation,
        String frequency,
        String meaningEn,
        String meaningVi,
        List<String> useCases,
        List<String> examples,
        String memoryTip,
        String toeicTrap,
        String partOfSpeech,
        String topic,
        List<String> tags,
        String keyword,
        String practicePrompt,
        String answer,
        String level,
        String audioUrl,
        Instant createdAt) {
}
