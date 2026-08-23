# Voca iOS — Plan build (SwiftUI native, full parity)

> Client iOS native cho Voca Dictionary v2. Bám theo API `/api/**` (JWT) đã có sẵn của backend.
> Quyết định: **SwiftUI native**, **full parity** (gồm cả AI assistant). Tạo ngày 2026-08-23.

## 0. Tư tưởng kiến trúc

**Giữ client "mỏng", đẩy độ phức tạp về server.** Web build prompt AI ở client
(`web/src/core/practice/*` — prompts/parsers/quality/judge, ~700 dòng TS). iOS **không** port lại
toàn bộ: backend đã có nhóm endpoint build prompt phía server:

- `POST /api/agent/chat {message}` (SSE) — assistant, server tự thêm system prompt.
- `POST /api/practice/{drills,reading,article,speaking}` (SSE) — server build prompt.

→ iOS chỉ cần: stream & hiển thị text, và **parse output có cấu trúc** (drills/reading).
Phần parse là chỗ phức tạp nhất còn lại ở client — xem mục 6 (nên thêm endpoint trả JSON có cấu trúc
ở backend để iOS khỏi port `parsers.ts`).

## 1. Tech stack

| Hạng mục | Lựa chọn | Ghi chú |
|---|---|---|
| UI | SwiftUI, deployment target **iOS 17+** | `@Observable` cần iOS 17 |
| Kiến trúc | MVVM + Observation framework | |
| Networking | URLSession + async/await | Không thêm lib |
| SSE | `URLSession.bytes(for:)`, parse dòng `data:` thủ công | Handle error-as-content-chunk |
| Token | **Keychain** (access + refresh) | Không để secret trong UserDefaults |
| Cache | SwiftData | Cache kho từ để xem offline |
| Audio | AVFoundation (`AVAudioPlayer`) | TTS trả `audio/mpeg` bytes |
| Project gen | **XcodeGen** (`ios/project.yml`) | Project reproducible, dễ diff |
| Bundle id | `site.thaonv.voca` | Khớp package backend |

## 2. Cấu trúc `ios/`

```
ios/
├── project.yml            XcodeGen
├── Voca.xcodeproj         (sinh ra, không commit nếu muốn — hiện có commit)
└── Voca/
    ├── App/               VocaApp.swift, RootView
    ├── Core/
    │   ├── Networking/    AppConfig, Envelope, ApiError, ApiClient, SSEClient
    │   ├── Auth/          KeychainStore, AuthStore
    │   ├── Models/        User, Card, Settings, StudyStats, Drill, Reading…
    │   └── Audio/         AudioPlayer, TTSService
    ├── Features/
    │   ├── Auth/          LoginView, RegisterView, ProfileView, ChangePasswordView
    │   ├── Dictionary/    CardGridView, CardDetailView, CardCreateView
    │   ├── Study/         StudyView, StatsView
    │   ├── Assistant/     AssistantView, DrillsView, ReadingView
    │   └── Settings/      SettingsView, ApiKeysView
    └── Resources/         Assets.xcassets, Localizable (vi/en)
```

## 3. API contract (đã verify từ backend)

**Envelope:** JSON dưới `/api/**` và `/v1/**` bọc `{ status, code, message, data }`.
SSE, audio bytes, markdown docs **không** bọc.

**Auth** `/api/auth` → `{ accessToken, refreshToken, user{id,email,displayName,admin} }`
- `POST login|register|refresh|logout`, `GET me`, `POST change-password`, `PATCH me {displayName}`
- Public (không cần JWT): `register`, `login`, `refresh`. Refresh **xoay vòng token**.

**Cards** `/api/cards` — `CardDto` (id, slug, word, ipa, pronunciation, frequency, meaningEn, meaningVi,
useCases[], examples[], memoryTip, toeicTrap, partOfSpeech, topic, tags[], keyword, practicePrompt,
answer, level, audioUrl, createdAt)
- `GET /`, `GET/DELETE /{slug}`, `POST /` (CardInput), `POST /create` (AI), `PATCH /{slug}/level {level}`,
  `POST /fill-meanings {updates[]}`, `DELETE /` (xóa hết).

**SRS** `/api` — `POST /review {slug, grade:1..4}` (Again/Hard/Good/Easy), `GET /study/due`, `GET /study/stats`.

**AI** `/api`
- `POST /agent/chat {message}` (SSE) · `POST /practice/{drills,reading,article,speaking}` (SSE)
- `POST /chat/completions {model, messages[], settings}` (SSE, OpenAI-style; chỉ dùng nếu cần prompt riêng)
- `POST /tts {text, voiceModel}` → bytes `audio/mpeg` · `GET/POST /audio/{id}`

**Settings** `/api/user/settings` `GET/PUT` (key LLM/TTS server-side, DTO ẩn secret).
**API keys** `/api/user/api-keys` list/create + `/{id}/revoke` + `DELETE /{id}`.

**Public/health** `GET /v1/health` (permitAll) — dùng để kiểm tra kết nối.

## 4. Milestones

| # | Milestone | Nội dung |
|---|---|---|
| M0 | Scaffold | ios/ project, ApiClient + Envelope + ApiError, health check |
| M1 | Auth | Keychain, AuthStore, refresh-rotation, Login/Register/Profile/Đổi mật khẩu, RootView |
| M2 | Dictionary | Grid + search/filter (port `search.ts`), CardDetail, TTS phát âm, tạo thẻ AI, level, xóa, cache SwiftData |
| M3 | Study FSRS | Màn ôn tập due → `/review`, Stats |
| M4 | AI Assistant | SSEClient; chat `/agent/chat`; drills+reading `/practice/*`, render trắc nghiệm A/B/C/D, ghi attempt |
| M5 | Settings & polish | Settings LLM/TTS, API keys, dark mode, i18n vi/en, empty/error states |
| M6 | Release | App icon, launch screen, TestFlight, App Store metadata |

## 5. Phần khó cần lưu ý

1. **SSE trên URLSession** — không có API sẵn; đọc `bytes`, tách `\n`, gom dòng `data: {...}`, bỏ `[DONE]`,
   decode `choices[0].delta.content`. Server có thể gửi **lỗi như 1 content chunk**
   (`ChatController.errorChunk`) → hiển thị như lời assistant, không coi là crash.
2. **Parse drills/reading** — nếu không thêm endpoint structured (mục 6) thì phải port `parsers.ts`
   (369 dòng, mong manh) sang Swift. Rủi ro lớn nhất của M4.
3. **Refresh token đua nhau** — nhiều 401 đồng thời chỉ refresh 1 lần (serialize bằng actor).
4. **TTS trả bytes** — không envelope, content-type `audio/mpeg`, phát bằng AVAudioPlayer.

## 6. Việc backend (nhỏ, tùy chọn nhưng nên làm)

- **Không cần CORS** (native app).
- **Nên thêm** biến thể `/api/practice/drills|reading` trả **JSON có cấu trúc** (parse server-side bằng
  logic đã có) để iOS khỏi port `parsers.ts`. ~0.5–1 ngày backend, tiết kiệm nhiều ngày iOS + ít bug.
- OpenAPI có sẵn (`/v3/api-docs`) → có thể sinh model Swift bằng `swift-openapi-generator` (cân nhắc).

## 7. Build & chạy (môi trường dev)

```bash
# Sinh project
cd ios && xcodegen generate

# Build cho simulator (máy này dùng Xcode-beta, chưa xcode-select)
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcodebuild -project ios/Voca.xcodeproj -scheme Voca \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Backend chạy thật để login e2e
cd backend && docker compose up -d && ./gradlew bootRun   # :22052
```

App dev trỏ `AppConfig.baseURL` = `http://localhost:22052` (simulator dùng chung localhost với máy host).
