# V1 → V2 iOS — Gap analysis & port plan

So sánh tính năng bản **V1** (web `src/` + mobile Expo `mobile/`) với **V2** hiện tại (backend Spring Boot +
web React + iOS SwiftUI vừa dựng). Mục tiêu: đưa những gì V1 đã hoàn thiện — nhất là **UI card** và các
**mode AI** — sang iOS V2. Cập nhật 2026-08-23.

## 0. Lỗi "AI gen đều đang lỗi" — nguyên nhân

Gọi thẳng server thật: `/api/agent/chat` và `/api/practice/drills` → **HTTP 503 `LLM_NOT_CONFIGURED`**
("No LLM base URL/API key configured — env app.llm.* or user settings"). Tức **tài khoản chưa cấu hình LLM**
(và server không có default `app.llm.*`).

- **Cách khắc phục (người dùng):** iOS → tab **Cài đặt → Kết nối AI (LLM)** → nhập **Base URL** (OpenAI-compatible),
  **Khóa API**, **Model** → Lưu. Tương tự **Giọng đọc (TTS)** cho phát âm. Sau đó AI chạy.
- **Đã sửa phía iOS:** trước đây SSE lỗi hiện "Máy chủ trả lỗi 503" chung chung. Nay `ApiClient` đọc envelope
  lỗi và map code → thông báo tiếng Việt gợi ý vào Settings (`LLM_NOT_CONFIGURED`, `TTS_NOT_CONFIGURED`).

## 1. Khác biệt kiến trúc quan trọng (V2 đã tốt hơn — giữ nguyên)

| | V1 | V2 |
|---|---|---|
| Auth | **Không có tài khoản** — 1 bearer token dùng chung với Local Bridge | **JWT đa người dùng** (access+refresh) ✅ |
| Khóa LLM/TTS | Client giữ key, gọi thẳng provider `/chat/completions` | **Server giữ key**, client gọi `/api/*` ✅ |
| Backend | Local API Bridge (Node) cổng 22053 | Spring Boot 1 binary, `/api` (JWT) + `/v1` (API key) ✅ |
| SRS | Không có | **FSRS-5 server-side** (V2 mới có) ✅ |

→ Không "port ngược" phần auth/bridge của V1. V2 đã hiện đại hơn.

## 2. Bảng GAP — tính năng V1 chưa có trong iOS V2

Ký hiệu backend: ✅ có sẵn endpoint · ⚠️ cần thêm endpoint · — không cần.

### AI / Practice
| Tính năng V1 | iOS V2 | Backend | Ưu tiên |
|---|---|---|---|
| **Assistant** chat streaming | ✅ có | ✅ `/agent/chat` | — |
| **Drills** (7 kind: scenario/rescue/collocation/error_spotting/trap/reverse/part2_response) | ⚠️ có nhưng đơn giản | ✅ `/practice/drills` | Cao (nâng UI) |
| **Reading** Part 6/7 | ✅ có | ✅ `/practice/reading` | — |
| **Articles** (bài báo + vocab notes + câu hỏi) | ❌ thiếu | ✅ `/practice/article` | Cao (dễ) |
| **Speaking/shadowing** (karaoke IPA + connected speech) | ❌ thiếu | ✅ `/practice/speaking` | TB |
| **Conversation/Listening** (4 format: conversation/radio/announcement/story) + karaoke + đa giọng | ❌ thiếu | ⚠️ **chưa có** `/practice/conversation` | Cao (đặc trưng V1) |
| **Non-stop passive listening** (queue audio nền, khóa màn hình) | ❌ thiếu | — (client) | TB |
| **Per-card AI agent** (hỏi AI về 1 từ) | ❌ thiếu | ✅ `/agent/chat` (đổi prompt) | Cao |
| **Quick quiz** tương tác trong chat | ❌ thiếu | — (parse client) | TB |
| **Context scoping** (all/today/topic/level/custom) cho mọi request AI | ❌ thiếu | ✅ (tham số) | TB |
| Follow-up suggestion chips; drills per-choice audio, badges kind+difficulty, Prev/Next, prefetch | ❌/⚠️ | ✅ | TB |

### Cards / Dictionary
| Tính năng V1 | iOS V2 | Ưu tiên |
|---|---|---|
| Grid + search + filter theo **level** | ✅ | — |
| Filter theo **topic** và **created-date** | ❌ thiếu (chỉ có level) | Cao |
| Search theo **tag** | ⚠️ một phần | TB |
| Card detail: nghĩa EN/VI, IPA, useCases, examples, TOEIC trap, memoryTip, tags, level, TTS | ✅ phần lớn | — |
| **Ảnh thẻ PNG** (A4 in được) + zoom | ❌ thiếu | TB |
| **Mini practice + answer** trong card detail | ❌ thiếu | Thấp |
| **Flashcard study** (vuốt lật thẻ) | ❌ (V2 có FSRS review khác) | TB |

### Dashboard / Nhập liệu / Native
| Tính năng V1 | iOS V2 | Ưu tiên |
|---|---|---|
| **Today dashboard** (hero stats, mastery ring, recent cards, shortcut) | ❌ thiếu | TB |
| **Add word bằng OCR camera** (ML Kit: ảnh→từ→thẻ) | ❌ thiếu | TB (điểm nhấn) |
| **Add word bằng giọng nói** (STT dictation) | ❌ thiếu | Thấp |
| **Clipboard** gợi ý từ | ❌ thiếu | Thấp |
| **Home-screen + lock-screen widget** (từ vựng ngẫu nhiên hằng ngày) | ❌ thiếu | Cao (đặc trưng, học thụ động) |
| **Spotlight indexing** (search iOS ra thẻ) | ❌ thiếu | Thấp |
| Offline cache/sync queue (netinfo, AsyncStorage) | ⚠️ chưa cache | TB |

## 3. UI / thiết kế cần bê từ V1 (phần card đã rất hoàn thiện)

Quan sát từ screenshot + `mobile/src/theme.ts`, `mobile/src/ui.tsx`:
- **Brand màu xanh lá (green/emerald)** — V1 mobile dùng xanh lá làm accent; iOS V2 đang dùng **xanh dương**.
  → Nên đổi accent sang **green** cho đồng bộ thương hiệu.
- **Header chuẩn**: tiêu đề lớn + dòng đếm "N / N words" + hàng **filter chips** ("All words / All vocabulary",
  level/topic/date) ngay dưới header.
- **Card/badge**: bo góc lớn, viền nhẹ, padding rộng; **pill badge** nền xanh nhạt chữ xanh đậm
  (kind, difficulty, POS, level).
- **Drills**: badge *kind* (góc trái) + *difficulty* (góc phải), câu hỏi có nút loa, **mỗi đáp án A/B/C/D có nút loa
  riêng**, điều hướng **Previous/Next** (paginated), highlight đúng/sai + giải thích.
- **Conversation/Listen**: bong bóng chat + avatar tròn (chữ cái speaker), text EN **highlight từ vựng** (nền xanh),
  dòng dịch VI **highlight từ đích** (đỏ), nút loa từng dòng + **Play all** + **Regenerate**.
- **Card grid tile**: word + POS + IPA + nghĩa VI + **level badge** + nút loa; theme theo level/POS.
- **Tab bar**: V1 = Today · Cards · Agent · Listen · More. V2 hiện = Kho từ · Học · Trợ lý · Cài đặt · Hồ sơ.
  → Cân nhắc thêm **Today** và tách **Listen** (hoặc gộp trong Trợ lý).

## 4. Lộ trình đề xuất (đưa V1 → iOS V2)

**Đợt A — nhanh, tận dụng backend sẵn có (giá trị cao):**
1. Đổi **accent → green** + chuẩn hoá header/badge/pill theo V1 (polish toàn app).
2. **Articles** + **Speaking** vào tab Trợ lý (backend đã có, chỉ thêm UI + parser — parser đã có sẵn ở web core).
3. Nâng **Drills UI**: badge kind/difficulty, per-choice audio, Previous/Next.
4. Filter **topic** + **created-date** + tag cho Kho từ.
5. **Per-card AI agent** (nút "Hỏi AI" trong card detail).

**Đợt B — cần thêm việc backend hoặc native:**
6. **Conversation/Listening**: thêm endpoint `/api/practice/conversation` (build prompt server-side, port từ web
   `src/App.tsx:4203`) → UI chat-bubble karaoke + đa giọng TTS. (+ non-stop nền — tùy chọn)
7. **Home-screen Widget** (WidgetKit extension + App Group) — từ vựng ngẫu nhiên hằng ngày.
8. **Add word OCR** (VisionKit/`DataScanner` hoặc Vision) camera→từ→thẻ.
9. **Today dashboard** (hero stats + mastery ring + recent).

**Đợt C — chất lượng sống:**
10. Cache offline (SwiftData) + hàng đợi sync level/attempts.
11. Quick quiz tương tác, context scoping, follow-up chips.

## 5. Ghi chú kỹ thuật
- Web core `packages/voca-core/src/practice/*` (prompts/parsers/types/quality) là nguồn tham chiếu chuẩn cho
  Article/Speaking/Conversation — V2 backend `PracticePrompts.java` đã port drills/reading/article/speaking;
  **conversation chưa port** → cần thêm `conversationPrompt` + endpoint.
- iOS đã có `PracticeParsing` (drills NDJSON, reading JSON). Cần bổ sung parser cho **article**, **speaking**,
  **conversation** (theo schema trong `PracticePrompts`/web core).
