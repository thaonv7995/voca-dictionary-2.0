package site.thaonv.voca.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import site.thaonv.voca.card.Card;
import site.thaonv.voca.card.CardRepository;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class PracticeSupportTest {

    private final PracticePrompts prompts = new PracticePrompts(new ObjectMapper());

    @Test
    void buildsChinesePromptsWhenLanguageIsZhCn() {
        List<String> index = List.of("朋友", "咖啡");

        String assistant = prompts.assistantSystemPrompt("zh-CN");
        assertTrue(assistant.contains("Hán ngữ"));
        assertTrue(assistant.contains("Pinyin"));

        String drill = prompts.drillPrompt(index, "朋友", 3, "HSK 1", "none", "zh-CN");
        assertTrue(drill.contains("Chinese (Hán ngữ"));
        assertTrue(drill.contains("Simplified Chinese"));
        assertFalse(drill.contains("IELTS vocabulary drills"));

        String reading = prompts.readingPrompt(index, "朋友", "part6", "HSK 1", "none", "zh-CN");
        assertTrue(reading.contains("chinese_passage"));
        assertFalse(reading.contains("IELTS Academic Reading"));

        String article = prompts.articlePrompt(index, "朋友", "HSK 1", "none", "zh-CN");
        assertTrue(article.contains("chinese_article"));
        assertFalse(article.contains("IELTS-style article"));

        String speaking = prompts.speakingPrompt(index, "朋友", "HSK 1", "none", "zh-CN");
        assertTrue(speaking.contains("Chinese (Hán ngữ)"));
        assertFalse(speaking.contains("English speaking/shadowing"));
    }

    @Test
    void preservesEnglishPromptsByDefault() {
        assertTrue(prompts.assistantSystemPrompt(null).contains("IELTS vocabulary tutor"));
        assertTrue(prompts.drillPrompt(List.of("mitigate"), null, 5, "All", "none", "en")
                .contains("IELTS vocabulary drills"));
    }

    @Test
    void vocabularyIndexScopesByOwnerAndLanguageSortedByPriority() {
        CardRepository repo = Mockito.mock(CardRepository.class);
        LlmClient llm = Mockito.mock(LlmClient.class);
        AiConfigResolver resolver = Mockito.mock(AiConfigResolver.class);

        Card mastered = card("谢谢", "mastered", 10);
        Card learning = card("朋友", "learning", 20);
        Card fresh = card("你好", "new", 30);
        when(repo.findByOwnerIdAndLanguage(42L, "zh-CN")).thenReturn(List.of(mastered, learning, fresh));

        PracticeService service = new PracticeService(repo, llm, resolver);
        List<String> result = service.vocabularyIndex(42L, "zh", 10);

        verify(repo).findByOwnerIdAndLanguage(42L, "zh-CN");
        assertEquals(List.of("你好", "朋友", "谢谢"), result);
    }

    private static Card card(String word, String level, long epochSeconds) {
        Card c = new Card();
        c.setWord(word);
        c.setLevel(level);
        c.setLanguage("zh-CN");
        c.setCreatedAt(Instant.ofEpochSecond(epochSeconds));
        return c;
    }
}
