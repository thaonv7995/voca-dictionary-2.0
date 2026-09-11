package site.thaonv.voca.card;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class CardServiceTest {

    @Test
    void createsStableUnicodeSlugForChineseCards() {
        assertEquals("学习", CardService.slugify("学习"));
        assertEquals("zh-学习", CardService.slugFor("zh-CN", "学习"));
    }

    @Test
    void preservesExistingEnglishSlugFormat() {
        assertEquals("follow-up", CardService.slugFor("en", "Follow up"));
        assertEquals("en", CardService.normalizeLanguage(null));
    }
}
