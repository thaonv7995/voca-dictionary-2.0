# Voca Dictionary

Ứng dụng lưu trữ và học **từ vựng** với spaced repetition (FSRS), phát âm và trợ lý AI — đóng gói thành
**một binary chạy trên một cổng**, hỗ trợ đa người dùng và cung cấp **API cho hệ thống bên thứ ba**.

[![Release](https://img.shields.io/github/v/release/thaonv7995/voca-dictionary-2.0?sort=semver)](https://github.com/thaonv7995/voca-dictionary-2.0/releases)
[![Build](https://github.com/thaonv7995/voca-dictionary-2.0/actions/workflows/release.yml/badge.svg)](https://github.com/thaonv7995/voca-dictionary-2.0/actions/workflows/release.yml)
![Java 21](https://img.shields.io/badge/Java-21-orange)
![Spring Boot 3.4](https://img.shields.io/badge/Spring%20Boot-3.4-6DB33F)
![React 19](https://img.shields.io/badge/React-19-61DAFB)

## Ảnh chụp màn hình

![Lưới từ vựng & Global Agent](docs/web-dictionary.png)
*Lưới từ vựng (lọc/tìm kiếm, chi tiết thẻ) cạnh Global Agent — sinh bài đọc hiểu kèm câu hỏi trắc nghiệm A/B/C/D.*

![Global Agent — Drills & Assistant](docs/web-agent.png)
*Trợ lý AI toàn cục: trắc nghiệm (drills), luyện đọc/nghe hội thoại và hỏi đáp.*

<p align="center">
  <img src="docs/mobile-grid.png" width="31%" alt="Mobile — grid & search" />&nbsp;&nbsp;
  <img src="docs/mobile-preview.png" width="31%" alt="Mobile — card preview" />&nbsp;&nbsp;
  <img src="docs/mobile-assistant.png" width="31%" alt="Mobile — assistant & practice" />
</p>
<p align="center"><sub>Ứng dụng iOS native được phát triển cùng web app và backend hiện tại.</sub></p>

## Tính năng

- **Đa người dùng** — JWT (access + refresh xoay vòng), bcrypt, vai trò `ADMIN`.
- **Kho từ riêng theo user** — mỗi tài khoản có danh sách độc lập (tìm kiếm/lọc, flashcard, cấp độ, tạo thẻ bằng AI, phát âm). Nội dung một từ chỉ sinh bằng LLM **một lần**, user khác thêm cùng từ sẽ được **copy** (tiết kiệm token).
- **English và Hán ngữ** — chuyển nhanh giữa hai kho từ trên cùng giao diện; thẻ Hán ngữ có pinyin, nghĩa Việt, một ví dụ ngắn, phát âm Mandarin và ô tập viết Hán tự.
- **Mobile Hán ngữ** — kế hoạch triển khai parity với web nằm tại [`docs/ios-hanzi-plan.md`](docs/ios-hanzi-plan.md).
- **Spaced repetition (FSRS-5)** — tính phía server: độ ổn định/độ khó, thẻ đến hạn, thống kê.
- **Trợ lý AI (streaming)** — hỏi đáp, quiz, sinh bài luyện tập (drills/reading) qua SSE.
- **API key tự phục vụ** — mỗi user tự tạo/thu hồi/xóa key cho hệ thống khác gọi vào `/v1`, kèm tài liệu API tải về được.
- **Quản trị người dùng** — admin liệt kê / đổi quyền / xóa (có ràng buộc an toàn).
- **Bảo mật** — khóa LLM/TTS lưu server-side theo từng user, không lộ ra trình duyệt.
- **PWA** — cài như ứng dụng, hoạt động offline cơ bản, tự cập nhật.

## Cài đặt nhanh

Chỉ cần **Java 21+**. PostgreSQL sẽ được tự dựng bằng Docker (nếu có), hoặc dùng Postgres sẵn có
(`db=voca user=voca pass=voca` trên `:5432`). App chạy tại **http://localhost:22052**.

**macOS / Linux**
```bash
REPO=thaonv7995/voca-dictionary-2.0
curl -fsSL "https://github.com/$REPO/releases/latest/download/install.sh" | sh -s -- "$REPO"
```

Chạy lại cùng lệnh để update. Installer sẽ dừng tiến trình `voca.jar` cũ, thay file và khởi động bản mới.

**Windows (PowerShell)**
```powershell
$env:VOCA_REPO="thaonv7995/voca-dictionary-2.0"
iwr "https://github.com/$env:VOCA_REPO/releases/latest/download/install.ps1" -UseBasicParsing | iex
```

**Thủ công** (mọi OS có Java 21)
```bash
docker run -d --name voca-db -e POSTGRES_USER=voca -e POSTGRES_PASSWORD=voca -e POSTGRES_DB=voca -p 5432:5432 postgres:16
curl -fL "https://github.com/thaonv7995/voca-dictionary-2.0/releases/latest/download/voca.jar" -o voca.jar
java -jar voca.jar
```

Đăng nhập admin lần đầu: `admin@voca.local` / `change-me`.

## Phát triển

**Yêu cầu:** Java 21 · Node 20+ · PostgreSQL 16 (hoặc `docker compose` trong `backend/`).

```bash
# Database
cd backend && docker compose up -d        # Postgres :5432

# Backend (:22052)
./gradlew bootRun

# Web (:5173 — proxy /api & /v1 sang :22052)
cd ../web && npm install && npm run dev
```

**Build production (một binary):**
```bash
cd web && npm run build                    # → web/dist
cd ../backend && ./gradlew bootJar         # nhúng web/dist vào jar
java -jar build/libs/voca-backend-2.1.1.jar
```

Release được **GitHub Actions** build tự động khi push tag `v*.*.*` (`.github/workflows/release.yml`).

## Kiến trúc

```
voca-dictionary/
├── backend/   Spring Boot 3.4 (Java 21) — API + nhúng SPA, một binary/một port
├── web/       React 19 + Vite 6 + TypeScript (PWA) — UI kế thừa từ v1
└── ios/       SwiftUI native
```

Một cổng, ba vùng định tuyến & bảo mật:

| Vùng | Dành cho | Xác thực |
|------|----------|----------|
| `/v1/**` | Hệ thống bên thứ ba | API key (`X-API-Key` / `Bearer`), có scope & rate-limit |
| `/api/**` | Web/iOS người dùng cuối | JWT (`/api/admin/**` yêu cầu `ROLE_ADMIN`) |
| `/**` | SPA, Swagger, actuator | công khai |

## Cấu hình

Tất cả qua biến môi trường (đều có mặc định để chạy ngay):

| Biến | Mặc định | Mô tả |
|------|----------|-------|
| `PORT` | `22052` | Cổng HTTP |
| `DB_URL` | `jdbc:postgresql://localhost:5432/voca` | Chuỗi kết nối Postgres |
| `DB_USERNAME` / `DB_PASSWORD` | `voca` / `voca` | Thông tin đăng nhập DB |
| `VOCA_ADMIN_EMAIL` / `VOCA_ADMIN_PASSWORD` | `admin@voca.local` / `change-me` | Admin seed lần đầu |
| `VOCA_JWT_ACCESS_TTL` | `43200` | TTL access token (giây, mặc định 12h) |
| `VOCA_LLM_BASE_URL` · `VOCA_LLM_API_KEY` · `VOCA_LLM_MODEL` | — | LLM mặc định (hoặc cấu hình theo user trong Settings) |
| `VOCA_TTS_BASE_URL` · `VOCA_TTS_API_KEY` | — | TTS mặc định |

## API

Tài liệu tích hợp đầy đủ (ví dụ curl, mẫu response) tải trong ứng dụng: **Settings → API Keys →
Tải tài liệu API (.md)** — hoặc `GET /api/docs/v1`. OpenAPI: `/swagger-ui.html`, `/v3/api-docs`.

**Public — `/v1/**`** (API key)

| Method | Path | Scope |
|--------|------|-------|
| GET | `/v1/health` | — |
| GET | `/v1/cards` (`?ifChangedSince=`) | `cards:read` |
| GET | `/v1/cards/lookup?word=` | `cards:read` |
| GET | `/v1/cards/{slug}` | `cards:read` |
| POST | `/v1/cards/create` | `cards:create` |
| GET/POST | `/v1/audio/{id}` | `audio:read` |
| POST | `/v1/practice/{drills,reading}` (SSE) | `practice:generate` |

<details>
<summary><strong>App — <code>/api/**</code></strong> (JWT)</summary>

| Nhóm | Endpoint |
|------|----------|
| Auth | `POST /api/auth/{register,login,refresh,logout}` · `GET /api/auth/me` |
| Cards | `GET/POST /api/cards` · `GET/DELETE /api/cards/{slug}` · `PATCH /api/cards/{slug}/level` · `POST /api/cards/create` · `POST /api/cards/fill-meanings` |
| Học tập | `POST /api/review` · `GET /api/study/due` · `GET /api/study/stats` |
| AI | `POST /api/chat/completions` (SSE) · `POST /api/tts` · `GET/POST /api/audio/{id}` |
| Settings | `GET/PUT /api/user/settings` |
| API key | `GET/POST /api/user/api-keys` · `POST /api/user/api-keys/{id}/revoke` · `DELETE /api/user/api-keys/{id}` |
| Tài liệu | `GET /api/docs/v1` |
| Admin | `POST/GET /api/admin/users` · `PATCH/DELETE /api/admin/users/{id}` · `/api/admin/api-clients` · `/api/admin/api-keys` |

</details>

## Roadmap

- Client iOS (SwiftUI) sinh từ OpenAPI.
- Mã hoá at-rest cho khóa LLM/TTS trong `user_settings`.
- Rate-limit phân tán (Bucket4j + Redis) cho triển khai nhiều instance.
- Bộ test tự động (FSRS, integration).

## License

Dự án cá nhân.
