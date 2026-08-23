# Voca iOS

Client iOS native (SwiftUI) cho Voca Dictionary v2. Xem kế hoạch đầy đủ: [`../docs/ios-plan.md`](../docs/ios-plan.md).

## Yêu cầu
- Xcode 16+ (repo này build & verify bằng Xcode 27 / iOS 27 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Chạy
```bash
cd ios
xcodegen generate          # sinh Voca.xcodeproj từ project.yml
open Voca.xcodeproj        # mở bằng Xcode rồi Run (⌘R) vào simulator
```

Backend cần chạy để đăng nhập:
```bash
cd ../backend && docker compose up -d && ./gradlew bootRun   # http://localhost:22052
```

**Base URL mặc định:** Simulator → `http://localhost:22052` (dev với backend local); máy thật →
`https://voca.thaonv.online` (server production). Ghi đè bằng biến môi trường `VOCA_BASE_URL`
(Scheme → Run → Arguments → Environment Variables).

## Build lên máy thật (device) để test

```bash
cd ios && xcodegen generate && open Voca.xcodeproj
```
Trong Xcode:
1. Chọn target **Voca** → tab **Signing & Capabilities** → tick **Automatically manage signing** →
   chọn **Team** (Apple ID cá nhân là đủ để chạy thử trên máy mình). Nếu `site.thaonv.voca` bị trùng,
   đổi **Bundle Identifier** cho duy nhất.
2. Cắm iPhone (bật Developer Mode trong Settings → Privacy & Security), chọn nó làm run destination.
3. **⌘R**. Máy thật sẽ tự trỏ vào `https://voca.thaonv.online` — đăng nhập bằng tài khoản của bạn.

Lần đầu chạy trên máy: vào iPhone **Settings → General → VPN & Device Management** → tin cậy
(trust) developer certificate.

App icon (chữ **V** trên nền xanh gradient) và **launch screen** (nền xanh + chữ "Voca") đã có sẵn.

## Trạng thái
- **M0** Scaffold + ApiClient (envelope, refresh-rotation, raw bytes, SSE, health) ✅
- **M1** Auth: Keychain, đăng nhập/đăng ký, hồ sơ, đổi mật khẩu ✅
- **M2** Kho từ: grid, `.searchable`, lọc theo level, chi tiết thẻ, phát âm TTS, tạo thẻ AI, đổi level, xóa ✅
- **M3** Học FSRS: màn ôn tập (Again/Hard/Good/Easy → `/review`), thống kê theo level ✅
- **M4** Trợ lý AI: chat streaming (`/agent/chat`), drills + reading (`/practice/*`) render trắc nghiệm ✅
- **M5** Cài đặt: LLM/TTS (`/api/user/settings`) + quản lý API keys ✅
- **M6** Release: app icon + launch screen ✅ · TestFlight/App Store metadata — còn lại.
- **Đợt A** (parity V1): brand xanh lá; Trợ lý 6 mode (Trò chuyện/Trắc nghiệm/Đọc hiểu/Bài báo/Nói/Hội thoại);
  Drills badge + loa từng đáp án + Prev/Next; Kho từ lọc topic/ngày/tag + nút loa từng dòng; per-card "Hỏi AI" ✅
- **Đợt B**: tab **Hôm nay** (dashboard); **quét ảnh OCR** tạo thẻ (Vision); **Hội thoại** (client-side qua
  `/api/chat/completions`); **Widget** màn hình chính (WidgetKit + App Group) ✅

### Widget (WidgetKit)
Target `VocaWidgetExtension` + App Group `group.site.thaonv.voca`. Để chạy trên **máy thật**: mở Xcode →
chọn **Team cho CẢ HAI** target (Voca + VocaWidgetExtension) ở Signing & Capabilities (App Group tự cấp) →
mở app một lần (vào tab Kho từ để đồng bộ thẻ) → giữ màn hình chính → thêm widget **"Từ vựng Voca"**.

Đã verify end-to-end bằng XCUITest (`VocaUITests`) đăng nhập vào server thật `voca.thaonv.online`
và đi qua cả 5 tab. Chạy lại:
```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcodebuild test -project Voca.xcodeproj -scheme Voca \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```
Lưu ý: `VocaUITests/VocaSmokeUITests.swift` đang hard-code tài khoản test throwaway — đổi/bỏ khi cần.
