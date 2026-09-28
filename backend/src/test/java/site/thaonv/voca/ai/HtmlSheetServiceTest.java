package site.thaonv.voca.ai;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.Mockito;

import site.thaonv.voca.card.Card;
import site.thaonv.voca.card.CardRepository;

import java.nio.file.Path;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertTrue;

class HtmlSheetServiceTest {

    @Test
    void rendersSingleCharacterCard(@TempDir Path tempDir) {
        CardRepository repo = Mockito.mock(CardRepository.class);
        HtmlSheetService service = new HtmlSheetService(repo, tempDir.toString());

        Card card = new Card();
        card.setWord("家");
        card.setSlug("zh-jia-家");
        card.setLanguage("zh-CN");
        card.setPronunciation("jiā");
        card.setMeaningVi("Nhà, gia đình");
        card.setPartOfSpeech("Danh từ");
        card.setTopic("HSK 1");
        card.setMemoryTip("Dưới mái nhà có con heo biểu thị gia đình ấm no.");
        card.setExamples(List.of("我想回家。 | Wǒ xiǎng huí jiā. | Tôi muốn về nhà."));
        card.setUseCases(List.of("回家: Về nhà", "大家: Mọi người"));

        String html = service.renderA4Html(card);

        assertTrue(html.contains("m-single"));
        assertTrue(html.contains("jiā"));
        assertTrue(html.contains("Nhà, gia đình"));
        assertTrue(html.contains("Mẹo nhớ tượng hình"));
        assertTrue(html.contains("Wǒ xiǎng huí jiā."));
        assertTrue(html.contains("practice-row-single"));
        assertTrue(html.contains("a4-page"));
        assertTrue(html.contains("Kaiti SC"));
    }

    @Test
    void rendersTwoCharacterCard(@TempDir Path tempDir) {
        CardRepository repo = Mockito.mock(CardRepository.class);
        HtmlSheetService service = new HtmlSheetService(repo, tempDir.toString());

        Card card = new Card();
        card.setWord("朋友");
        card.setSlug("zh-pengyou-朋友");
        card.setLanguage("zh-CN");
        card.setPronunciation("péngyou");
        card.setMeaningVi("Bạn bè");
        card.setPartOfSpeech("Danh từ");
        card.setTopic("HSK 1");
        card.setExamples(List.of("他是我的好朋友。 | Tā shì wǒ de hǎo péngyou. | Anh ấy là bạn thân của tôi."));
        card.setUseCases(List.of("好朋友: Bạn tốt"));

        String html = service.renderA4Html(card);

        assertTrue(html.contains("m-pair"));
        assertTrue(html.contains("péngyou"));
        assertTrue(html.contains("Chiết Tự & Cấu Tạo Từng Chữ Song Song"));
        assertTrue(html.contains("char-split-grid"));
        assertTrue(html.contains("practice-pairs-row"));
    }

    @Test
    void rendersThreeAndFourCharacterCards(@TempDir Path tempDir) {
        CardRepository repo = Mockito.mock(CardRepository.class);
        HtmlSheetService service = new HtmlSheetService(repo, tempDir.toString());

        // 3 characters
        Card card3 = new Card();
        card3.setWord("没关系");
        card3.setSlug("zh-meiguanxi");
        card3.setLanguage("zh-CN");
        card3.setPronunciation("méi guānxi");
        card3.setMeaningVi("Không có gì");
        String html3 = service.renderA4Html(card3);
        assertTrue(html3.contains("m-trio"));
        assertTrue(html3.contains("char-split-grid-3"));

        // 4 characters (Idiom)
        Card card4 = new Card();
        card4.setWord("一心一意");
        card4.setSlug("zh-yixinyiyi");
        card4.setLanguage("zh-CN");
        card4.setPronunciation("yì xīn yí yì");
        card4.setMeaningVi("Toàn tâm toàn ý");
        String html4 = service.renderA4Html(card4);
        assertTrue(html4.contains("m-quad"));
        assertTrue(html4.contains("char-chips-row"));
        assertTrue(html4.contains("Ý nghĩa tổng thể & Cấu trúc ngữ pháp"));
    }
}
