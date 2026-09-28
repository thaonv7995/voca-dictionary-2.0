# 🇨🇳 Quy Chuẩn Sinh File HTML Từ Vựng Khổ A4 (Chinese Vocab A4 Sheet Rule)

Tài liệu này định nghĩa quy tắc thiết kế và cấu trúc kỹ thuật cho file HTML chi tiết từ vựng tiếng Trung chuẩn in ấn A4 (1 trang duy nhất), kế thừa và nâng cấp từ chuẩn của `LearnHSK`.

---

## 1. Nguyên Tắc Cốt Lõi (Core Principles)

1. **Chuẩn in ấn A4 (210mm × 297mm) — Đúng 1 trang duy nhất (Single Page)**:
   - Toàn bộ nội dung phải vừa vặn tuyệt đối trong 1 trang A4 khi in ấn hoặc xuất PDF (`@page { size: A4 portrait; margin: 0; }`).
   - Không được để tràn sang trang thứ 2 (`page-break-after: avoid; page-break-inside: avoid;`).
2. **Nền giấy trắng cố định (`#ffffff`)**:
   - Sử dụng nền trắng, chữ xám đen (`#111827`, `#1f2937`) và màu mực tương phản cao.
   - Hoàn toàn độc lập với chế độ Dark Mode của trình duyệt/IDE để khi in ra giấy hoặc lưu PDF luôn sắc nét.
3. **Typography Khải Thư thanh đậm**:
   - Mọi chữ Hán đều áp dụng font Khải thư: `font-family: 'Kaiti SC', 'STKaiti', 'KaiTi', '楷体', serif;`.
   - Kích thước chữ to, rõ từng nét bút (18px - 22px cho câu ví dụ/cụm từ; 40px - 80px cho ô Mễ tự cách).
4. **Ô Mễ tự cách (米字格) vẽ thuần CSS**:
   - Kẻ đường trục đứng, trục ngang và 2 đường chéo bằng CSS `linear-gradient` màu đỏ nhạt (`#fca5a5`, `#fed7d7`) viền đỏ (`#ef4444`).
   - Tự động thay đổi kích thước và cách bố trí theo số lượng chữ Hán.
5. **Độc lập, không phụ thuộc thư viện ngoài (Zero Dependency)**:
   - File HTML hoàn chỉnh có sẵn `<style>` nội tuyến và script in ấn `window.print()`.

---

## 2. Quy Tắc Bố Cục Thích Ứng Theo Số Lượng Chữ (1, 2, 3, 4, 5+ Chữ)

### A. Nhóm 1 chữ (Ví dụ: 家, 爱, 好)
- **Hero Card**: 1 ô Mễ tự cách lớn (96px × 96px, chữ 75px).
- **Section 1 - Cấu tạo & Nét viết**: Lưới 8–15 nét (`stroke-grid`) hiển thị từng nét (Nét 1, Nét 2,...) kèm tên nét (点, 横, 撇, 捺...) và Hộp mẹo nhớ tượng hình (`memory-box`).
- **Section 4 - Luyện viết tay**: Hàng 8–10 ô Mễ tự cách đơn trống.

### B. Nhóm 2 chữ (Ví dụ: 朋友, 学习, 苹果)
- **Hero Card**: Cặp 2 ô Mễ tự cách liền nhau (78px × 78px, chữ 60px).
- **Section 1 - Chiết tự 2 cột**: Bố cục 2 cột song song đối chiếu Chữ 1 và Chữ 2 (bộ thủ, số nét, ý nghĩa hình tượng, thứ tự nét).
- **Section 4 - Luyện viết tay**: 4–5 cặp ô Mễ tự cách đôi liền nhau.

### C. Nhóm 3 chữ (Ví dụ: 没关系, 科学家, 出租车)
- **Hero Card**: Hàng 3 ô Mễ tự cách (64px × 64px, chữ 48px).
- **Section 1 - Chiết tự 3 cột**: 3 cột song song phân tích ngắn gọn từng chữ: Bộ thủ, số nét, ý nghĩa từ tố.
- **Section 4 - Luyện viết tay**: 2–3 bộ 3 ô liền nhau.

### D. Nhóm 4 chữ / Thành ngữ (成语) (Ví dụ: 一心一意, 莫名其妙, 科学技术)
- **Hero Card**: Hàng 4 ô Mễ tự cách (54px × 54px, chữ 40px) hoặc lưới 2×2.
- **Section 1 - Phân tích thành ngữ & Chiết tự**:
  - Lưới 4 thẻ compact (2×2 hoặc 4 cột) phân tích nhanh 4 chữ.
  - Hộp Điển tích / Ngữ nghĩa thành ngữ: Giải thích nguồn gốc câu chuyện, cấu trúc ngữ pháp thành ngữ và ngữ cảnh dùng.
- **Section 4 - Luyện viết tay**: 2 bộ 4 ô liền nhau.

### E. Nhóm 5+ chữ (Cụm từ dài / Câu tục ngữ) (Ví dụ: 事实胜于雄辩)
- **Hero Card**: Hàng ô Mễ tự cách co giãn linh hoạt (flex-wrap, 46px × 46px).
- **Section 1 - Phân tích cấu trúc câu**: Phân tách các từ tố/từ ghép chính cấu thành câu và ngữ pháp tổng thể.
- **Section 4 - Luyện viết tay**: Hàng ô tương ứng theo các chữ trọng tâm.

---

## 3. Cấu Trúc Khung HTML Chuẩn

```html
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Chi tiết từ vựng: {WORD} ({PINYIN})</title>
  <style>
    @page { size: A4 portrait; margin: 0; }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: transparent;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      color: #1f2937;
      display: flex;
      flex-direction: column;
      align-items: center;
      margin: 0;
      padding: 0;
      -webkit-font-smoothing: antialiased;
    }
    .zh { font-family: 'Kaiti SC', 'STKaiti', 'KaiTi', '楷体', serif; }
    .a4-page {
      width: 210mm;
      height: 297mm;
      padding: 16mm 16mm;
      background: #ffffff;
      box-shadow: 0 10px 30px rgba(0,0,0,0.35);
      position: relative;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      overflow: hidden;
    }
    
    /* Ô Mễ tự cách */
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
    .mizige-char { position: relative; color: #111827; line-height: 1; z-index: 1; }

    /* @media print tối ưu */
    @media print {
      body { background: transparent; padding: 0; }
      .a4-page { box-shadow: none; margin: 0; width: 100%; height: 100%; page-break-after: avoid; }
    }
  </style>
</head>
<body>
  <div class="a4-page">
    <!-- Hero card, Cấu tạo nét, Cụm từ, Ví dụ, Luyện viết tay -->
  </div>
</body>
</html>
```

---

## 4. Tích Hợp Hệ Thống
1. **API Tạo Từ Vựng**: Khi tạo từ vựng có `language == "zh-CN"`, backend tự động kích hoạt Async Action sinh file HTML lưu vào hệ thống (`backend/data/html/{slug}.html`).
2. **Giao Diện CardPreview**:
   - Nếu từ vựng có/chưa có file HTML: nút biểu tượng văn bản `<FileText />` ("Phiếu học A4").
   - Nhấp vào nút sẽ mở **Modal Popup xem trước khổ A4** trực tiếp (không mở tab mới).
   - Modal bố trí thanh dock dọc ở mép bên phải tờ giấy A4 chứa các icon hành động: In phiếu (`Cmd + P`), Tải file HTML, Tạo lại nội dung.
   - Bấm ra ngoài (backdrop) hoặc phím `Esc` để đóng modal (không dùng nút X).
