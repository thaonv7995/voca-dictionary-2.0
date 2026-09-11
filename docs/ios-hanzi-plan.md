# Kế hoạch Hán ngữ cho iOS

Mục tiêu là đưa trải nghiệm Hán ngữ trên web sang ứng dụng iOS native, dùng chung API và dữ liệu với backend hiện tại. Phạm vi này không thay đổi luồng học English; người dùng chuyển nhanh giữa hai kho `English` và `中文`.

## Trải nghiệm đích

- Kho từ có bộ chuyển ngôn ngữ giữ lại lựa chọn gần nhất.
- Card Hán ngữ hiển thị theo thứ tự: Hán tự, pinyin, loại từ, nghĩa Việt và trạng thái học.
- Tìm kiếm nhận Hán tự, pinyin có hoặc không có dấu thanh, nghĩa Việt, chủ đề và tag.
- Tạo thẻ gửi `language: "zh-CN"`; kết quả ngắn gọn gồm Hán tự, pinyin, nghĩa Việt và một ví dụ `Hán tự | pinyin | nghĩa Việt`.
- Chi tiết thẻ chỉ giữ các phần cần học: nghĩa, một ví dụ, phát âm và tập viết.
- Phát âm Mandarin dùng voice `zh-CN`; English tiếp tục dùng cấu hình hiện tại.
- Mỗi Hán tự có ô 田字格, nét mẫu đậm, animation thứ tự nét và chế độ viết theo nét.
- Flashcard, ôn tập FSRS, màn Hôm nay và widget hiển thị đúng Hán tự/pinyin theo ngôn ngữ của card.

## Thiết kế kỹ thuật

### 1. Model và API

- Thêm `CardLanguage` (`en`, `zh-CN`) và trường `language` vào `Card`, mặc định `en` để tương thích dữ liệu cũ.
- Mở rộng `CardsService.createWithAI` nhận ngôn ngữ và gửi cùng request tạo card.
- Lọc hai kho từ ở client sau một lần tải `/api/cards`, giống web.
- Chuẩn hóa tìm kiếm bằng cách bỏ dấu Unicode khi so khớp pinyin và tiếng Việt.
- Thêm helper chọn transcription: pinyin dùng `pronunciation`, fallback `ipa`; English giữ hành vi hiện tại.

### 2. Kho từ và tạo thẻ

- Đặt segmented control `English | 中文` ở đầu màn Kho từ.
- Khi đổi ngôn ngữ: xóa lựa chọn card hiện tại, reset bộ lọc và dùng đúng placeholder nhập từ.
- Card Hán ngữ dùng font hệ thống CJK lớn hơn; pinyin là dòng riêng ngay dưới Hán tự.
- Sheet tạo thẻ kế thừa ngôn ngữ đang chọn; bàn phím không tự viết hoa và không autocorrect.
- OCR gắn ngôn ngữ trước khi tạo hàng loạt; cho phép người dùng kiểm tra danh sách nhận dạng.

### 3. Chi tiết và phát âm

- Tạo nhánh giao diện `ChineseCardDetail` ngắn gọn thay vì tái dùng toàn bộ nội dung TOEIC.
- Parse ví dụ thành ba dòng Hán tự, pinyin và nghĩa Việt; dữ liệu lỗi định dạng vẫn hiển thị nguyên văn.
- `PronounceButton` nhận ngôn ngữ/voice model; card `zh-CN` mặc định dùng Mandarin nhưng vẫn tôn trọng cấu hình TTS phía server.

### 4. Tập viết Hán tự

- Tạo `HanziWritingView` và `HanziCharacterCanvas`, mỗi ký tự là một ô độc lập.
- Bundle dữ liệu path/nét cần thiết trong app hoặc cache xuống thiết bị; màn tập viết không phụ thuộc CDN lúc sử dụng.
- Vẽ ô 田字格 bằng SwiftUI `Canvas`; scale path theo kích thước ô và hỗ trợ Dynamic Type mà không làm biến dạng chữ.
- Icon Play chạy từng nét theo thứ tự; icon bút vào chế độ luyện viết.
- Trong chế độ luyện viết, thu gesture bằng `DragGesture`, so sánh điểm đầu/cuối và khoảng cách với nét chuẩn, gợi ý sau hai lần sai, báo hoàn thành khi đủ nét.
- Kiểm tra license và attribution của bộ dữ liệu nét trước khi đóng gói bản phát hành.

### 5. Các bề mặt học tập

- Flashcard và ReviewSession hiển thị pinyin ở mặt trước; nghĩa Việt và ví dụ ở mặt sau.
- Today và Widget dùng pinyin thay cho IPA với card Hán ngữ.
- Trợ lý AI nhận ngôn ngữ đang chọn trong context; nội dung luyện English hiện tại không tự chuyển sang tiếng Trung.

## Thứ tự triển khai

1. **M1 — Dữ liệu và kho từ:** model, API create, switch ngôn ngữ, card, tìm kiếm.
2. **M2 — Chi tiết và audio:** giao diện ngắn gọn, ví dụ ba dòng, Mandarin TTS.
3. **M3 — Tập viết:** dữ liệu nét local, animation, gesture quiz và trạng thái hoàn thành.
4. **M4 — Đồng bộ bề mặt:** flashcard, FSRS review, Today, OCR và Widget.
5. **M5 — QA và release:** unit test parsing/search, UI test chuyển ngôn ngữ/tạo card, test gesture, offline test dữ liệu nét, VoiceOver và thiết bị thật.

## Điều kiện hoàn thành

- Card tạo trên web xuất hiện đúng trong iOS và ngược lại, không trộn hai kho ngôn ngữ.
- Hán tự và pinyin không bị cắt ở các cỡ màn hình hỗ trợ.
- Mandarin TTS phát đúng giọng; lỗi mạng có trạng thái rõ ràng.
- Animation luôn theo đúng thứ tự nét và chế độ luyện viết chặn nét sai.
- Dữ liệu nét đã tải vẫn hoạt động khi offline.
- Toàn bộ luồng English và các bài test hiện tại tiếp tục đạt.
