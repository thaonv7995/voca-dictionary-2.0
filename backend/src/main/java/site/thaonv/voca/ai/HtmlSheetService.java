package site.thaonv.voca.ai;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import site.thaonv.voca.card.Card;
import site.thaonv.voca.card.CardRepository;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Generates and serves single-page A4 printable HTML study sheets for Chinese vocabulary cards.
 * Adheres strictly to the LearnHSK A4 print standard (.agents/rules/chinese_vocab_html.md).
 */
@Service
public class HtmlSheetService {

    private static final Logger log = LoggerFactory.getLogger(HtmlSheetService.class);

    private final CardRepository cardRepository;
    private final Path htmlDir;

    public HtmlSheetService(CardRepository cardRepository,
                            @Value("${app.html.dir:./data/html}") String htmlDir) {
        this.cardRepository = cardRepository;
        this.htmlDir = Path.of(htmlDir);
        try {
            Files.createDirectories(this.htmlDir);
        } catch (IOException e) {
            throw new UncheckedIOException("Cannot create html sheet directory: " + htmlDir, e);
        }
    }

    public Path pathFor(String slug) {
        String clean = slug.replaceAll("[^a-zA-Z0-9_\\-\\u4e00-\\u9fa5]", "_");
        return htmlDir.resolve(clean + ".html");
    }

    public boolean hasSheet(String slug) {
        return Files.exists(pathFor(slug));
    }

    public byte[] readSheet(String slug) {
        return readSheet(slug, false);
    }

    public byte[] readSheet(String slug, boolean embed) {
        try {
            Path target = pathFor(slug);
            if (!Files.exists(target)) {
                return null;
            }
            return Files.readAllBytes(target);
        } catch (IOException e) {
            throw new UncheckedIOException("Cannot read HTML sheet for " + slug, e);
        }
    }

    /**
     * Asynchronously generates an HTML sheet for the card after card creation.
     */
    @Async
    @Transactional
    public void generateSheetAsync(Long cardId) {
        try {
            generateSheet(cardId);
        } catch (Exception e) {
            log.error("Failed to generate HTML sheet asynchronously for card id={}: {}", cardId, e.getMessage(), e);
        }
    }

    /**
     * Synchronously generates (or re-generates) an HTML sheet for the given card ID.
     */
    @Transactional
    public String generateSheet(Long cardId) {
        Optional<Card> opt = cardRepository.findById(cardId);
        if (opt.isEmpty()) {
            throw new IllegalArgumentException("Card not found: " + cardId);
        }
        Card card = opt.get();
        if (!"zh-CN".equalsIgnoreCase(card.getLanguage())) {
            return null;
        }

        String html = renderA4Html(card);
        Path target = pathFor(card.getSlug());
        try {
            if (target.getParent() != null) {
                Files.createDirectories(target.getParent());
            }
            Files.writeString(target, html, StandardCharsets.UTF_8);
            card.setHasHtml(true);
            cardRepository.save(card);
            log.info("Generated A4 HTML sheet for card id={}, slug={} at {}", cardId, card.getSlug(), target);
            return html;
        } catch (IOException e) {
            throw new UncheckedIOException("Failed to write HTML sheet for " + card.getSlug(), e);
        }
    }

    /**
     * Renders the complete, self-contained, print-ready A4 HTML document.
     */
    public String renderA4Html(Card card) {
        String word = card.getWord() != null ? card.getWord().trim() : "";
        List<String> chars = extractHanziCharacters(word);
        int charCount = chars.size();

        String pinyin = card.getPronunciation() != null ? card.getPronunciation() : (card.getIpa() != null ? card.getIpa() : "");
        String meaningVi = card.getMeaningVi() != null ? card.getMeaningVi() : "";
        String pos = card.getPartOfSpeech() != null ? card.getPartOfSpeech() : "Từ vựng";

        StringBuilder sb = new StringBuilder();
        sb.append("<!DOCTYPE html>\n");
        sb.append("<html lang=\"vi\">\n");
        sb.append("<head>\n");
        sb.append("  <meta charset=\"UTF-8\">\n");
        sb.append("  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n");
        sb.append("  <title>Chi tiết từ: ").append(escapeHtml(word)).append(" (").append(escapeHtml(pinyin)).append(")</title>\n");
        sb.append("  <style>\n");
        appendStyles(sb);
        sb.append("  </style>\n");
        sb.append("</head>\n");
        sb.append("<body>\n");

        // A4 Page Container
        sb.append("  <div class=\"a4-page\">\n");

        // Hero Card with Mizige Boxes
        appendHeroCard(sb, word, chars, charCount, pinyin, meaningVi, pos);

        // Section 1: Character Analysis / Stroke breakdown
        appendSection1Analysis(sb, word, chars, charCount, card.getMemoryTip());

        // Section 2: Collocations / Common Compounds
        appendSection2Collocations(sb, card.getUseCases());

        // Section 3: Practical Examples
        appendSection3Examples(sb, card.getExamples());

        // Section 4: Handwriting Practice
        appendSection4Practice(sb, word, chars, charCount);

        // Page footer
        appendPageFooter(sb, word, pinyin);

        sb.append("  </div>\n"); // Close .a4-page
        sb.append("</body>\n");
        sb.append("</html>\n");

        return sb.toString();
    }

    private void appendHeroCard(StringBuilder sb, String word, List<String> chars, int charCount,
                                String pinyin, String meaningVi, String pos) {
        sb.append("      <div class=\"hero-card\">\n");
        sb.append("        <div class=\"hero-mizige-wrap\">\n");

        String boxClass = charCount == 1 ? "mizige-box m-single" :
                          charCount == 2 ? "mizige-box m-pair" :
                          charCount == 3 ? "mizige-box m-trio" :
                          charCount == 4 ? "mizige-box m-quad" : "mizige-box m-multi";

        for (String ch : (chars.isEmpty() ? List.of(word) : chars)) {
            sb.append("          <div class=\"").append(boxClass).append("\">\n");
            sb.append("            <span class=\"mizige-char zh\">").append(escapeHtml(ch)).append("</span>\n");
            sb.append("          </div>\n");
        }

        sb.append("        </div>\n");
        sb.append("        <div class=\"hero-info\">\n");
        sb.append("          <div class=\"hero-pinyin\">").append(escapeHtml(pinyin)).append("</div>\n");
        if (!meaningVi.isBlank()) {
            sb.append("          <div class=\"hero-meaning\">Nghĩa: <b>").append(escapeHtml(meaningVi)).append("</b></div>\n");
        }
        sb.append("          <div class=\"hero-tags\">\n");
        sb.append("            <span class=\"hero-tag-item\">Từ loại: <b>").append(escapeHtml(pos)).append("</b></span>\n");
        sb.append("            <span class=\"hero-tag-item\">Số chữ: <b>").append(charCount > 0 ? charCount : 1).append(" chữ Hán</b></span>\n");
        sb.append("            <span class=\"hero-tag-item\">Dạng chữ: <b>Giản thể</b></span>\n");
        sb.append("          </div>\n");
        sb.append("        </div>\n");
        sb.append("      </div>\n\n");
    }

    private void appendSection1Analysis(StringBuilder sb, String word, List<String> chars, int charCount, String memoryTip) {
        sb.append("      <div class=\"section\">\n");

        if (charCount <= 1) {
            // 1 Character: Stroke decomposition / character structure
            sb.append("        <div class=\"section-title\">1. Cấu Tạo & Ý Nghĩa Chữ Hán</div>\n");
            if (memoryTip != null && !memoryTip.isBlank()) {
                sb.append("        <div class=\"memory-box\">\n");
                sb.append("          💡 <b>Mẹo nhớ tượng hình & Cấu tạo:</b> ").append(escapeHtml(memoryTip)).append("\n");
                sb.append("        </div>\n");
            } else {
                sb.append("        <div class=\"memory-box\">\n");
                sb.append("          💡 <b>Mẹo nhớ:</b> Quan sát chữ <span class=\"zh\" style=\"font-size:16px;font-weight:700;\">")
                  .append(escapeHtml(word)).append("</span>, chú ý quy tắc viết từ trên xuống dưới, từ trái sang phải, nét ngang trước nét sổ sau.\n");
                sb.append("        </div>\n");
            }
        } else if (charCount == 2) {
            // 2 Characters: 2-column side-by-side comparison
            sb.append("        <div class=\"section-title\">1. Chiết Tự & Cấu Tạo Từng Chữ Song Song</div>\n");
            sb.append("        <div class=\"char-split-grid\">\n");
            for (int i = 0; i < chars.size() && i < 2; i++) {
                String ch = chars.get(i);
                sb.append("          <div class=\"char-card\">\n");
                sb.append("            <div class=\"char-header\">\n");
                sb.append("              <span class=\"char-badge zh\">").append(escapeHtml(ch)).append("</span>\n");
                sb.append("              <span class=\"char-sub\">Chữ thứ ").append(i + 1).append("</span>\n");
                sb.append("            </div>\n");
                sb.append("            <div class=\"char-content\">\n");
                sb.append("              • <b>Phân tích:</b> Nét chữ <span class=\"zh\" style=\"font-size:15px;font-weight:700;\">")
                  .append(escapeHtml(ch)).append("</span> đóng vai trò từ tố trong tổng thể từ ghép <span class=\"zh\">").append(escapeHtml(word)).append("</span>.<br>\n");
                sb.append("              • <b>Thứ tự viết:</b> Tuân thủ quy tắc viết từ ngoài vào trong, viết nét bao bọc trước rồi đóng đáy sau.\n");
                sb.append("            </div>\n");
                sb.append("          </div>\n");
            }
            sb.append("        </div>\n");
            if (memoryTip != null && !memoryTip.isBlank()) {
                sb.append("        <div class=\"memory-box\" style=\"margin-top:8px;\">\n");
                sb.append("          💡 <b>Mẹo nhớ kết hợp:</b> ").append(escapeHtml(memoryTip)).append("\n");
                sb.append("        </div>\n");
            }
        } else if (charCount == 3) {
            // 3 Characters: 3-column grid
            sb.append("        <div class=\"section-title\">1. Chiết Tự & Cấu Tạo 3 Chữ</div>\n");
            sb.append("        <div class=\"char-split-grid-3\">\n");
            for (int i = 0; i < chars.size() && i < 3; i++) {
                String ch = chars.get(i);
                sb.append("          <div class=\"char-card\">\n");
                sb.append("            <div class=\"char-header\">\n");
                sb.append("              <span class=\"char-badge zh\">").append(escapeHtml(ch)).append("</span>\n");
                sb.append("              <span class=\"char-sub\">Vị trí ").append(i + 1).append("</span>\n");
                sb.append("            </div>\n");
                sb.append("            <div class=\"char-content\" style=\"font-size:11.5px;\">\n");
                sb.append("              Từ tố: <span class=\"zh\" style=\"font-size:14px;font-weight:700;\">").append(escapeHtml(ch)).append("</span>\n");
                sb.append("            </div>\n");
                sb.append("          </div>\n");
            }
            sb.append("        </div>\n");
            if (memoryTip != null && !memoryTip.isBlank()) {
                sb.append("        <div class=\"memory-box\" style=\"margin-top:8px;\">\n");
                sb.append("          💡 <b>Mẹo nhớ:</b> ").append(escapeHtml(memoryTip)).append("\n");
                sb.append("        </div>\n");
            }
        } else {
            // 4+ Characters: Idiom / Compound phrase analysis
            sb.append("        <div class=\"section-title\">1. Phân Tích Cấu Trúc Ngữ Nghĩa & Từ Tố (").append(charCount).append(" Chữ)</div>\n");
            sb.append("        <div class=\"char-chips-row\">\n");
            for (int i = 0; i < chars.size(); i++) {
                String ch = chars.get(i);
                sb.append("          <div class=\"char-chip-box\">\n");
                sb.append("            <span class=\"chip-idx\">").append(i + 1).append("</span>\n");
                sb.append("            <span class=\"chip-zh zh\">").append(escapeHtml(ch)).append("</span>\n");
                sb.append("          </div>\n");
            }
            sb.append("        </div>\n");
            sb.append("        <div class=\"memory-box\" style=\"margin-top:8px;\">\n");
            sb.append("          📖 <b>Ý nghĩa tổng thể & Cấu trúc ngữ pháp:</b> ");
            if (memoryTip != null && !memoryTip.isBlank()) {
                sb.append(escapeHtml(memoryTip));
            } else {
                sb.append("Cụm từ cố định / thành ngữ <b><span class=\"zh\">").append(escapeHtml(word))
                  .append("</span></b> biểu thị sự phối hợp hài hòa giữa các từ tố, cần học theo ngữ cảnh nguyên vẹn.");
            }
            sb.append("\n        </div>\n");
        }

        sb.append("      </div>\n\n");
    }

    private void appendSection2Collocations(StringBuilder sb, List<String> useCases) {
        sb.append("      <div class=\"section\">\n");
        sb.append("        <div class=\"section-title\">2. Cụm Từ & Cách Kết Hợp Thường Gặp (Collocations)</div>\n");
        sb.append("        <div class=\"collocation-box\">\n");

        if (useCases != null && !useCases.isEmpty()) {
            for (String uc : useCases) {
                if (uc.isBlank()) continue;
                sb.append("          <div class=\"colloc-item\">• ").append(formatChineseSnippet(uc)).append("</div>\n");
            }
        } else {
            sb.append("          <div class=\"colloc-item\" style=\"color:#64748b;\">• Đang cập nhật thêm các cụm từ kết hợp cho từ này.</div>\n");
        }

        sb.append("        </div>\n");
        sb.append("      </div>\n\n");
    }

    private void appendSection3Examples(StringBuilder sb, List<String> examples) {
        sb.append("      <div class=\"section\">\n");
        sb.append("        <div class=\"section-title\">3. Các Câu Ví Dụ Ứng Dụng Thực Tế</div>\n");

        if (examples != null && !examples.isEmpty()) {
            int idx = 1;
            for (String ex : examples) {
                if (ex.isBlank()) continue;
                String[] parts = ex.split("\\|");
                sb.append("        <div class=\"dialogue-card\">\n");
                if (parts.length >= 3) {
                    sb.append("          <div class=\"dialogue-zh zh\">").append(idx).append(". ").append(escapeHtml(parts[0].trim())).append("</div>\n");
                    sb.append("          <div class=\"dialogue-pinyin\">").append(escapeHtml(parts[1].trim())).append("</div>\n");
                    sb.append("          <div class=\"dialogue-vi\">").append(escapeHtml(parts[2].trim())).append("</div>\n");
                } else if (parts.length == 2) {
                    sb.append("          <div class=\"dialogue-zh zh\">").append(idx).append(". ").append(escapeHtml(parts[0].trim())).append("</div>\n");
                    sb.append("          <div class=\"dialogue-vi\">").append(escapeHtml(parts[1].trim())).append("</div>\n");
                } else {
                    sb.append("          <div class=\"dialogue-zh zh\">").append(idx).append(". ").append(escapeHtml(ex.trim())).append("</div>\n");
                }
                sb.append("        </div>\n");
                idx++;
                if (idx > 3) break; // Keep strictly within 1 A4 page
            }
        } else {
            sb.append("        <div class=\"dialogue-card\" style=\"color:#64748b;\">\n");
            sb.append("          Chưa có câu ví dụ mẫu. Hãy thực hành đặt câu trong phần chat trợ lý.\n");
            sb.append("        </div>\n");
        }

        sb.append("      </div>\n\n");
    }

    private void appendSection4Practice(StringBuilder sb, String word, List<String> chars, int charCount) {
        sb.append("    <div class=\"practice-section\">\n");
        sb.append("      <div style=\"font-size:11.5px;font-weight:600;color:#475569;display:flex;justify-content:space-between;margin-bottom:6px;\">\n");
        sb.append("        <span>✍️ Ô luyện viết tay khi in ra giấy: <b class=\"zh\" style=\"font-size:13px;color:#0f172a;\">")
          .append(escapeHtml(word)).append("</b></span>\n");
        sb.append("        <span style=\"font-style:italic;color:#94a3b8;\">Ghi chú cá nhân: ....................................................................</span>\n");
        sb.append("      </div>\n");

        if (charCount <= 1) {
            // 2 rows of 8 single boxes
            for (int r = 0; r < 2; r++) {
                String rowStyle = r == 0 ? " style=\"margin-bottom:6px;\"" : "";
                sb.append("      <div class=\"practice-row-single\"").append(rowStyle).append(">\n");
                for (int i = 0; i < 8; i++) {
                    sb.append("        <div class=\"practice-box\"></div>\n");
                }
                sb.append("      </div>\n");
            }
        } else if (charCount == 2) {
            // 2 rows of 5 pairs
            for (int r = 0; r < 2; r++) {
                String rowStyle = r == 0 ? " style=\"margin-bottom:6px;\"" : "";
                sb.append("      <div class=\"practice-pairs-row\"").append(rowStyle).append(">\n");
                for (int i = 0; i < 5; i++) {
                    sb.append("        <div class=\"practice-pair\">\n");
                    sb.append("          <div class=\"practice-box\"></div>\n");
                    sb.append("          <div class=\"practice-box\"></div>\n");
                    sb.append("        </div>\n");
                }
                sb.append("      </div>\n");
            }
        } else if (charCount == 3) {
            // 2 rows of 3 trios
            for (int r = 0; r < 2; r++) {
                String rowStyle = r == 0 ? " style=\"margin-bottom:6px;\"" : "";
                sb.append("      <div class=\"practice-pairs-row\"").append(rowStyle).append(">\n");
                for (int i = 0; i < 3; i++) {
                    sb.append("        <div class=\"practice-pair\">\n");
                    sb.append("          <div class=\"practice-box\"></div>\n");
                    sb.append("          <div class=\"practice-box\"></div>\n");
                    sb.append("          <div class=\"practice-box\"></div>\n");
                    sb.append("        </div>\n");
                }
                sb.append("      </div>\n");
            }
        } else {
            // 2 rows of 2 quads or multi-group
            for (int r = 0; r < 2; r++) {
                String rowStyle = r == 0 ? " style=\"margin-bottom:6px;\"" : "";
                sb.append("      <div class=\"practice-pairs-row\"").append(rowStyle).append(">\n");
                for (int i = 0; i < 2; i++) {
                    sb.append("        <div class=\"practice-pair\">\n");
                    for (int j = 0; j < Math.min(charCount, 5); j++) {
                        sb.append("          <div class=\"practice-box\"></div>\n");
                    }
                    sb.append("        </div>\n");
                }
                sb.append("      </div>\n");
            }
        }

        sb.append("    </div>\n\n");
    }

    private void appendPageFooter(StringBuilder sb, String word, String pinyin) {
        sb.append("    <div class=\"page-footer\">\n");
        sb.append("      <span>Voca Dictionary • Chinese Study Sheet</span>\n");
        sb.append("      <span>Từ vựng: <b class=\"zh\">").append(escapeHtml(word)).append("</b> (").append(escapeHtml(pinyin)).append(")</span>\n");
        sb.append("      <span>Trang 1 / 1</span>\n");
        sb.append("    </div>\n");
    }

    private void appendStyles(StringBuilder sb) {
        sb.append("""
            @page {
              size: 210mm 297mm;
              margin: 0;
            }
            * {
              box-sizing: border-box;
              margin: 0;
              padding: 0;
            }
            body {
              background-color: transparent;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
              color: #1f2937;
              display: flex;
              flex-direction: column;
              align-items: center;
              margin: 0;
              padding: 0;
              -webkit-font-smoothing: antialiased;
            }
            .zh {
              font-family: 'Kaiti SC', 'STKaiti', 'KaiTi', '楷体', serif;
            }
            .a4-page {
              width: 210mm;
              height: 297mm;
              max-height: 297mm;
              padding: 14mm 16mm;
              background: #ffffff;
              box-shadow: 0 10px 30px rgba(0, 0, 0, 0.35);
              position: relative;
              display: flex;
              flex-direction: column;
              box-sizing: border-box;
              overflow: hidden;
            }
            .hero-card {
              display: flex;
              gap: 16px;
              align-items: center;
              background: #f8fafc;
              border: 1px solid #e2e8f0;
              border-radius: 10px;
              padding: 12px 16px;
              margin-bottom: 11px;
            }
            .hero-mizige-wrap {
              display: flex;
              gap: 6px;
              flex-shrink: 0;
            }
            .mizige-box {
              border: 2px solid #ef4444;
              position: relative;
              background: #fff;
              display: flex;
              align-items: center;
              justify-content: center;
              flex-shrink: 0;
            }
            .mizige-box::before {
              content: "";
              position: absolute;
              width: 100%;
              height: 100%;
              background: 
                linear-gradient(to right, transparent 49.5%, #fca5a5 49.5%, #fca5a5 50.5%, transparent 50.5%),
                linear-gradient(to bottom, transparent 49.5%, #fca5a5 49.5%, #fca5a5 50.5%, transparent 50.5%),
                linear-gradient(45deg, transparent 49.5%, #fed7d7 49.5%, #fed7d7 50.5%, transparent 50.5%),
                linear-gradient(-45deg, transparent 49.5%, #fed7d7 49.5%, #fed7d7 50.5%, transparent 50.5%);
            }
            .mizige-char {
              position: relative;
              color: #111827;
              line-height: 1;
              z-index: 1;
            }
            /* Kích thước co giãn theo số lượng chữ */
            .m-single { width: 96px; height: 96px; }
            .m-single .mizige-char { font-size: 74px; }
            .m-pair { width: 78px; height: 78px; }
            .m-pair .mizige-char { font-size: 58px; }
            .m-trio { width: 64px; height: 64px; }
            .m-trio .mizige-char { font-size: 46px; }
            .m-quad { width: 54px; height: 54px; }
            .m-quad .mizige-char { font-size: 38px; }
            .m-multi { width: 46px; height: 46px; }
            .m-multi .mizige-char { font-size: 32px; }

            .hero-info {
              flex: 1;
            }
            .hero-pinyin {
              font-size: 27px;
              font-weight: 700;
              color: #b91c1c;
              line-height: 1.1;
            }
            .hero-meaning {
              font-size: 14px;
              color: #334155;
              margin-top: 3px;
            }
            .hero-tags {
              display: flex;
              flex-wrap: wrap;
              gap: 8px;
              margin-top: 6px;
              font-size: 11.5px;
              color: #475569;
            }
            .hero-tag-item {
              background: #e2e8f0;
              padding: 2px 7px;
              border-radius: 4px;
            }
            .section {
              margin-bottom: 10px;
            }
            .section-title {
              font-size: 13px;
              font-weight: 700;
              color: #0f172a;
              border-left: 3px solid #dc2626;
              padding-left: 7px;
              margin-bottom: 6px;
              text-transform: uppercase;
              letter-spacing: 0.5px;
            }
            .memory-box {
              background: #fef2f2;
              border: 1px dashed #f87171;
              border-radius: 6px;
              padding: 8px 12px;
              font-size: 12.5px;
              line-height: 1.45;
              color: #7f1d1d;
            }
            .char-split-grid {
              display: grid;
              grid-template-columns: 1fr 1fr;
              gap: 8px;
            }
            .char-split-grid-3 {
              display: grid;
              grid-template-columns: 1fr 1fr 1fr;
              gap: 6px;
            }
            .char-card {
              border: 1px solid #e2e8f0;
              border-radius: 6px;
              background: #fafafa;
              padding: 7px 10px;
            }
            .char-header {
              display: flex;
              align-items: center;
              gap: 8px;
              margin-bottom: 4px;
            }
            .char-badge {
              font-size: 20px;
              font-weight: 700;
              color: #b91c1c;
              background: #fee2e2;
              width: 30px;
              height: 30px;
              border-radius: 6px;
              display: flex;
              align-items: center;
              justify-content: center;
            }
            .char-sub {
              font-size: 12px;
              color: #475569;
            }
            .char-content {
              font-size: 12px;
              color: #334155;
              line-height: 1.4;
            }
            .char-chips-row {
              display: flex;
              gap: 8px;
              margin-bottom: 6px;
            }
            .char-chip-box {
              display: flex;
              align-items: center;
              gap: 6px;
              background: #f1f5f9;
              border: 1px solid #cbd5e1;
              padding: 4px 10px;
              border-radius: 6px;
            }
            .chip-idx {
              font-size: 11px;
              font-weight: 700;
              color: #94a3b8;
            }
            .chip-zh {
              font-size: 20px;
              color: #b91c1c;
              font-weight: 700;
            }
            .collocation-box {
              background: #f8fafc;
              border: 1px solid #e2e8f0;
              border-radius: 6px;
              padding: 7px 12px;
              display: grid;
              grid-template-columns: 1fr 1fr;
              gap: 4px 12px;
            }
            .colloc-item {
              font-size: 12.5px;
              color: #334155;
              line-height: 1.35;
            }
            .dialogue-card {
              background: #fafafa;
              border-left: 3px solid #ef4444;
              padding: 5px 10px;
              margin-bottom: 5px;
              border-radius: 0 5px 5px 0;
            }
            .dialogue-zh {
              font-size: 17px;
              color: #111827;
              font-weight: 600;
              line-height: 1.25;
            }
            .dialogue-pinyin {
              font-size: 12px;
              color: #b91c1c;
              font-style: italic;
              margin-top: 1px;
            }
            .dialogue-vi {
              font-size: 12.5px;
              color: #475569;
              margin-top: 1px;
            }
            .practice-section {
              background: #f8fafc;
              border: 1px solid #e2e8f0;
              border-radius: 8px;
              padding: 8px 12px;
            }
            .practice-row-single {
              display: flex;
              gap: 8px;
              justify-content: space-between;
            }
            .practice-pairs-row {
              display: flex;
              gap: 12px;
              justify-content: space-between;
            }
            .practice-pair {
              display: flex;
              gap: 4px;
            }
            .practice-box {
              width: 38px;
              height: 38px;
              border: 1px solid #f87171;
              background: #fff;
              position: relative;
            }
            .practice-box::before {
              content: "";
              position: absolute;
              width: 100%;
              height: 100%;
              background: 
                linear-gradient(to right, transparent 49%, #fecaca 49%, #fecaca 51%, transparent 51%),
                linear-gradient(to bottom, transparent 49%, #fecaca 49%, #fecaca 51%, transparent 51%),
                linear-gradient(45deg, transparent 49%, #fee2e2 49%, #fee2e2 51%, transparent 51%),
                linear-gradient(-45deg, transparent 49%, #fee2e2 49%, #fee2e2 51%, transparent 51%);
            }
            .page-footer {
              margin-top: auto;
              width: 100%;
              border-top: 1px solid #e5e7eb;
              padding-top: 5px;
              display: flex;
              justify-content: space-between;
              font-size: 10.5px;
              color: #94a3b8;
            }
            @media print {
              html, body {
                width: 210mm !important;
                height: 297mm !important;
                margin: 0 !important;
                padding: 0 !important;
                background: transparent !important;
              }
              .a4-page {
                box-shadow: none !important;
                margin: 0 !important;
                width: 210mm !important;
                height: 297mm !important;
                max-height: 297mm !important;
                page-break-after: avoid !important;
                page-break-inside: avoid !important;
              }
            }
        """);
    }

    private List<String> extractHanziCharacters(String text) {
        List<String> result = new ArrayList<>();
        if (text == null) return result;
        int len = text.length();
        for (int i = 0; i < len; ) {
            int cp = text.codePointAt(i);
            if (isHanzi(cp)) {
                result.add(new String(Character.toChars(cp)));
            }
            i += Character.charCount(cp);
        }
        return result;
    }

    private boolean isHanzi(int codePoint) {
        Character.UnicodeScript script = Character.UnicodeScript.of(codePoint);
        return script == Character.UnicodeScript.HAN;
    }

    private String escapeHtml(String text) {
        if (text == null) return "";
        return text.replace("&", "&amp;")
                   .replace("<", "&lt;")
                   .replace(">", "&gt;")
                   .replace("\"", "&quot;")
                   .replace("'", "&#39;");
    }

    private String formatChineseSnippet(String text) {
        // Formats snippets like "回家 (huí jiā): Về nhà" into bold Chinese + italic pinyin + regular text
        String escaped = escapeHtml(text);
        return "<span class=\"zh\" style=\"font-size:14px;font-weight:700;\">" + escaped + "</span>";
    }
}
