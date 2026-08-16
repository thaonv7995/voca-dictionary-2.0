package site.thaonv.voca.apikey;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

/**
 * Generates a self-contained Markdown integration guide for the public /v1 API, so a Voca user can
 * download it and hand it to a third party. The base URL is taken from the incoming request so the
 * examples point at whatever host actually served this app.
 */
@RestController
@RequestMapping("/api/docs")
public class ApiDocsController {

    @GetMapping(value = "/v1", produces = "text/markdown;charset=UTF-8")
    public ResponseEntity<String> v1Docs() {
        String base = ServletUriComponentsBuilder.fromCurrentContextPath().build().toUriString();
        String md = TEMPLATE.replace("__BASE__", base);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("text/markdown;charset=UTF-8"))
                .header("Content-Disposition", "attachment; filename=\"voca-api-v1.md\"")
                .body(md);
    }

    private static final String TEMPLATE = """
            # Voca Dictionary — Tài liệu API tích hợp (v1)

            Hướng dẫn cho hệ thống bên thứ ba (ví dụ *bilingual-app*) tích hợp với Voca. Tất cả endpoint
            dưới đây dùng chung một **API key** do người dùng Voca cấp; key đại diện cho **quyền của
            chính người dùng đó** (toàn quyền trên API /v1).

            | | |
            |---|---|
            | **Base URL** | `__BASE__/v1` |
            | **Giao thức** | HTTPS (hoặc HTTP nếu chạy nội bộ) |
            | **Định dạng** | JSON (UTF-8); audio trả `audio/mpeg`; practice trả SSE `text/event-stream` |
            | **Xác thực** | API key qua header `X-API-Key` hoặc `Authorization: Bearer` |
            | **Rate limit** | 120 request / phút / key |
            | **Phiên bản** | 2.0 |

            ---

            ## Mục lục

            1. Bắt đầu nhanh
            2. Xác thực
            3. Quy ước chung (định dạng, lỗi, mã HTTP, rate limit)
            4. Danh sách endpoint
            5. Định dạng streaming (SSE)
            6. Đối tượng Card
            7. Ví dụ tích hợp (JavaScript / Python / Java)
            8. Công thức thường dùng
            9. Ghi chú bảo mật & vận hành

            ---

            ## 1. Bắt đầu nhanh

            1. Đăng nhập Voca → **Settings → API Keys → Tạo API key**. Sao chép chuỗi `voca_...`
               (chỉ hiện **một lần**).
            2. Gắn key vào header của mỗi request.
            3. Gọi thử:

            ```
            curl -H "X-API-Key: voca_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" "__BASE__/v1/cards/lookup?word=retain"
            ```

            Nếu trả về JSON có `"found": true` là đã kết nối thành công.

            ---

            ## 2. Xác thực

            Mọi request (trừ `GET /v1/health`) phải kèm API key theo **một trong hai** cách:

            ```
            X-API-Key: voca_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
            ```
            hoặc
            ```
            Authorization: Bearer voca_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
            ```

            - Key có tiền tố `voca_`. Server chỉ lưu **bản băm SHA-256** của key — không thể lấy lại
              chuỗi gốc; mất thì tạo key mới.
            - Có thể **Thu hồi** (vô hiệu hóa) hoặc **Xóa** key bất cứ lúc nào trong Settings → API Keys;
              key ngừng hoạt động ngay lập tức (các request tiếp theo nhận HTTP 401).
            - Không nhúng key vào mã nguồn phía client (web/mobile công khai). Chỉ dùng ở phía server
              của bên tích hợp.

            ---

            ## 3. Quy ước chung

            ### 3.1. Định dạng dữ liệu
            - Request/response body là JSON UTF-8, trừ:
              - `GET /v1/audio/{id}` → nhị phân `audio/mpeg`.
              - `POST /v1/practice/*` → luồng SSE `text/event-stream`.
            - Thời gian theo chuẩn **ISO-8601 UTC** (ví dụ `2026-08-15T10:20:30Z`).
            - Trường chuỗi có thể là `null` nếu chưa có dữ liệu.

            ### 3.2. Định dạng lỗi
            Mọi lỗi trả về JSON đồng nhất:
            ```json
            { "error": { "code": "UNAUTHORIZED", "message": "Invalid or inactive API key." } }
            ```

            ### 3.3. Mã HTTP & mã lỗi
            | HTTP | code | Ý nghĩa | Cách xử lý |
            |------|------|---------|------------|
            | 200 | — | Thành công | — |
            | 400 | MISSING_WORD, INVALID_LEVEL, ... | Tham số không hợp lệ | Kiểm tra tham số/body |
            | 401 | UNAUTHORIZED | Thiếu / sai / key đã bị thu hồi | Kiểm tra header & tính hợp lệ của key |
            | 403 | FORBIDDEN | Key không đủ quyền cho endpoint | Tạo key với quyền phù hợp |
            | 404 | NOT_FOUND, AUDIO_NOT_FOUND | Không tìm thấy tài nguyên | Kiểm tra slug/id; audio cần POST tạo trước |
            | 429 | RATE_LIMITED | Vượt giới hạn tần suất | Chờ hết phút hiện tại rồi thử lại |
            | 503 | LLM_NOT_CONFIGURED, TTS_NOT_CONFIGURED | Server chưa cấu hình LLM/TTS | Liên hệ chủ Voca cấu hình |

            ### 3.4. Rate limiting
            - Giới hạn mặc định **120 request/phút cho mỗi key** (cửa sổ cố định theo phút).
            - Vượt giới hạn → HTTP **429** `RATE_LIMITED`. Hiện chưa trả header `X-RateLimit-*`;
              hãy chờ sang phút kế tiếp rồi thử lại (khuyến nghị backoff luỹ thừa).

            ---

            ## 4. Danh sách endpoint

            ### 4.1. GET /v1/health
            Kiểm tra tình trạng dịch vụ. **Không cần key.**

            ```
            curl "__BASE__/v1/health"
            ```
            **200 OK**
            ```json
            { "status": "ok", "service": "voca-api", "storage": "postgres", "version": "2.0" }
            ```

            ---

            ### 4.2. GET /v1/cards
            Lấy toàn bộ danh sách thẻ từ. Hỗ trợ **đồng bộ tăng tiến** qua `ifChangedSince`.

            | Tham số (query) | Bắt buộc | Kiểu | Mô tả |
            |-----------------|----------|------|-------|
            | ifChangedSince | không | string | Chuỗi `version` nhận từ lần gọi trước. Nếu không đổi → server trả `changed:false` và bỏ qua mảng `cards`. |

            ```
            curl -H "X-API-Key: voca_..." "__BASE__/v1/cards"
            ```
            **200 OK** — có thay đổi:
            ```json
            {
              "version": "cards:40:1734300000000",
              "changed": true,
              "cards": [
                {
                  "id": 12,
                  "slug": "retain",
                  "word": "retain",
                  "ipa": "/rɪˈteɪn/",
                  "meaningEn": "to keep or continue to have something",
                  "meaningVi": "giữ lại, duy trì",
                  "partOfSpeech": "verb",
                  "level": "learning",
                  "audioUrl": "/v1/audio/retain",
                  "createdAt": "2026-08-15T10:20:30Z"
                }
              ]
            }
            ```
            **200 OK** — khi `ifChangedSince` trùng version hiện tại (client dùng để poll rẻ):
            ```json
            { "version": "cards:40:1734300000000", "changed": false }
            ```
            > Quy trình đồng bộ: lần đầu gọi không tham số, lưu lại `version`. Các lần sau gọi kèm
            > `?ifChangedSince=<version đã lưu>`; chỉ tải lại toàn bộ khi `changed:true`.

            ---

            ### 4.3. GET /v1/cards/lookup
            Tra cứu nhanh một từ (ưu tiên khớp chính xác, sau đó khớp gần đúng).

            | Tham số (query) | Bắt buộc | Kiểu | Mô tả |
            |-----------------|----------|------|-------|
            | word | có | string | Từ cần tra |

            ```
            curl -H "X-API-Key: voca_..." "__BASE__/v1/cards/lookup?word=retain"
            ```
            **200 OK** — tìm thấy:
            ```json
            {
              "found": true,
              "word": "retain",
              "matchType": "exact",
              "card": { "slug": "retain", "word": "retain", "meaningVi": "giữ lại, duy trì" },
              "cards": [ { "slug": "retain", "word": "retain" } ]
            }
            ```
            - `matchType`: `exact` (khớp chính xác) hoặc `partial` (khớp gần đúng).
            - `card`: kết quả tốt nhất; `cards`: tối đa 8 kết quả liên quan.

            **200 OK** — không tìm thấy:
            ```json
            { "found": false, "word": "xyzzy" }
            ```
            **400** nếu thiếu `word`:
            ```json
            { "error": { "code": "MISSING_WORD", "message": "Missing word query parameter." } }
            ```

            ---

            ### 4.4. GET /v1/cards/{slug}
            Lấy chi tiết một thẻ theo `slug`. Trả về **Card object** (mục 6). **404** nếu không tồn tại.

            ```
            curl -H "X-API-Key: voca_..." "__BASE__/v1/cards/retain"
            ```

            ---

            ### 4.5. POST /v1/cards/create
            Sinh một thẻ từ mới bằng LLM (không tạo ảnh). Trả về **Card object** vừa tạo.

            | Trường (body) | Bắt buộc | Kiểu | Mô tả |
            |---------------|----------|------|-------|
            | word | có | string | Từ/cụm từ cần tạo thẻ |

            ```
            curl -X POST -H "X-API-Key: voca_..." -H "Content-Type: application/json" -d '{"word":"resilient"}' "__BASE__/v1/cards/create"
            ```
            > Endpoint này gọi LLM phía server; nếu chủ Voca chưa cấu hình LLM sẽ trả **503**
            > `LLM_NOT_CONFIGURED`. Thời gian phản hồi có thể vài giây.

            ---

            ### 4.6. GET /v1/audio/{id}
            Lấy file audio phát âm **đã cache** (`audio/mpeg`). `id` thường là `slug` của thẻ.

            ```
            curl -H "X-API-Key: voca_..." "__BASE__/v1/audio/retain" --output retain.mp3
            ```
            - **200 OK** → thân phản hồi là dữ liệu MP3.
            - **404** `AUDIO_NOT_FOUND` nếu chưa có cache → hãy `POST` để sinh trước (mục 4.7).

            ---

            ### 4.7. POST /v1/audio/{id}
            Sinh (và cache) audio cho `id`. Sau khi gọi, có thể `GET /v1/audio/{id}` để tải file.

            | Trường (body) | Bắt buộc | Kiểu | Mô tả |
            |---------------|----------|------|-------|
            | text | không | string | Văn bản cần đọc. Bỏ trống → dùng từ của thẻ có slug `id`. |
            | voiceModel | không | string | Model giọng, ví dụ `edge-tts/en-US-AndrewNeural`. |

            ```
            curl -X POST -H "X-API-Key: voca_..." -H "Content-Type: application/json" -d '{"text":"retain"}' "__BASE__/v1/audio/retain"
            ```
            **200 OK**
            ```json
            { "audioUrl": "/v1/audio/retain", "id": "retain" }
            ```
            > Cơ chế **cache-first**: gọi `POST` một lần để sinh & cache, các lần sau chỉ cần `GET`.

            ---

            ### 4.8. POST /v1/practice/drills
            Sinh bộ câu hỏi luyện tập (trắc nghiệm). Trả về **SSE** (`text/event-stream`) — xem mục 5.

            | Trường (body) | Bắt buộc | Kiểu | Mặc định | Mô tả |
            |---------------|----------|------|----------|-------|
            | count | không | number | 5 | Số câu hỏi |
            | selectedWord | không | string | — | Ưu tiên tạo quanh một từ cụ thể |

            ```
            curl -N -X POST -H "X-API-Key: voca_..." -H "Content-Type: application/json" -d '{"count":5}' "__BASE__/v1/practice/drills"
            ```

            ---

            ### 4.9. POST /v1/practice/reading
            Sinh đoạn đọc hiểu kèm câu hỏi (dạng TOEIC Part 6/7). Trả về **SSE** — xem mục 5.

            | Trường (body) | Bắt buộc | Kiểu | Mặc định | Mô tả |
            |---------------|----------|------|----------|-------|
            | format | không | string | part6 | `part6` hoặc `part7` |
            | selectedWord | không | string | — | Ưu tiên tạo quanh một từ cụ thể |

            ```
            curl -N -X POST -H "X-API-Key: voca_..." -H "Content-Type: application/json" -d '{"format":"part7"}' "__BASE__/v1/practice/reading"
            ```

            ---

            ## 5. Định dạng streaming (SSE)

            Hai endpoint `practice/*` trả **Server-Sent Events**. Server chuyển tiếp nguyên văn luồng SSE
            của nhà cung cấp LLM, mỗi dòng là một event dạng:

            ```
            data: {"id":"chatcmpl-...","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"..."}}]}
            data: {"choices":[{"index":0,"delta":{"content":"..."}}]}
            data: [DONE]
            ```

            Cách tiêu thụ:
            - Đọc từng dòng bắt đầu bằng `data:`.
            - Bỏ qua dòng rỗng và `data: [DONE]` (đánh dấu kết thúc).
            - Với mỗi chunk JSON, lấy `choices[0].delta.content` và **nối lại** để có toàn bộ kết quả.
            - Kết quả sau khi nối là một **payload JSON** mô tả bộ drills / bài đọc (do prompt @voca/core
              định nghĩa) — parse chuỗi đã nối để dùng.

            Ví dụ đọc SSE bằng JavaScript (fetch):
            ```js
            const res = await fetch("__BASE__/v1/practice/drills", {
              method: "POST",
              headers: { "X-API-Key": "voca_...", "Content-Type": "application/json" },
              body: JSON.stringify({ count: 5 }),
            });

            const reader = res.body.getReader();
            const decoder = new TextDecoder();
            let buffer = "";
            let content = "";

            while (true) {
              const { done, value } = await reader.read();
              if (done) break;
              buffer += decoder.decode(value, { stream: true });
              const lines = buffer.split("\\n");
              buffer = lines.pop() || "";
              for (const line of lines) {
                const s = line.trim();
                if (!s.startsWith("data:")) continue;
                const data = s.slice(5).trim();
                if (!data || data === "[DONE]") continue;
                const chunk = JSON.parse(data);
                content += chunk.choices?.[0]?.delta?.content || "";
              }
            }
            // `content` giờ chứa toàn bộ payload (chuỗi JSON) của bộ drills
            ```

            > Lưu ý: dùng cờ `-N` với curl (tắt buffering) để thấy luồng chảy theo thời gian thực.

            ---

            ## 6. Đối tượng Card

            | Trường | Kiểu | Mô tả |
            |--------|------|-------|
            | id | number | Khóa nội bộ |
            | slug | string | Định danh URL-safe (dùng cho `/cards/{slug}`, `/audio/{id}`) |
            | word | string | Từ vựng |
            | ipa | string | Phiên âm IPA |
            | pronunciation | string | Phiên âm hiển thị |
            | frequency | string | Mức độ phổ biến |
            | meaningEn | string | Nghĩa tiếng Anh |
            | meaningVi | string | Nghĩa tiếng Việt |
            | useCases | string[] | Các tình huống dùng |
            | examples | string[] | Câu ví dụ |
            | memoryTip | string | Mẹo ghi nhớ |
            | toeicTrap | string | Bẫy thường gặp trong TOEIC |
            | partOfSpeech | string | Từ loại |
            | topic | string | Chủ đề |
            | tags | string[] | Nhãn |
            | keyword | string | Từ khóa |
            | practicePrompt | string | Gợi ý luyện tập |
            | answer | string | Đáp án luyện tập |
            | level | string | Trạng thái học: `new` / `learning` / `known` / `mastered` |
            | audioUrl | string | Đường dẫn audio (`/v1/audio/{slug}`) |
            | createdAt | string | Thời điểm tạo (ISO-8601 UTC) |

            Ví dụ đầy đủ:
            ```json
            {
              "id": 12,
              "slug": "retain",
              "word": "retain",
              "ipa": "/rɪˈteɪn/",
              "pronunciation": "/rɪˈteɪn/",
              "frequency": "high",
              "meaningEn": "to keep or continue to have something",
              "meaningVi": "giữ lại, duy trì",
              "useCases": ["Business", "HR"],
              "examples": ["The company works hard to retain talented employees."],
              "memoryTip": "re- (again) + tain (hold): giữ lại",
              "toeicTrap": "Đừng nhầm với 'retrain' (đào tạo lại).",
              "partOfSpeech": "verb",
              "topic": "HR",
              "tags": ["toeic", "business"],
              "keyword": "keep",
              "practicePrompt": "Điền từ: The firm offers bonuses to ___ staff.",
              "answer": "retain",
              "level": "learning",
              "audioUrl": "/v1/audio/retain",
              "createdAt": "2026-08-15T10:20:30Z"
            }
            ```

            ---

            ## 7. Ví dụ tích hợp

            ### JavaScript / Node (fetch)
            ```js
            const BASE = "__BASE__";
            const KEY = "voca_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";

            async function lookup(word) {
              const res = await fetch(`${BASE}/v1/cards/lookup?word=${encodeURIComponent(word)}`, {
                headers: { "X-API-Key": KEY },
              });
              if (!res.ok) throw new Error(`HTTP ${res.status}`);
              return res.json();
            }

            lookup("retain").then((r) => console.log(r.card?.meaningVi));
            ```

            ### Python (requests)
            ```python
            import requests

            BASE = "__BASE__"
            KEY = "voca_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

            r = requests.get(
                f"{BASE}/v1/cards/lookup",
                params={"word": "retain"},
                headers={"X-API-Key": KEY},
                timeout=10,
            )
            r.raise_for_status()
            print(r.json()["card"]["meaningVi"])
            ```

            ### Java (java.net.http.HttpClient)
            ```java
            var client = HttpClient.newHttpClient();
            var request = HttpRequest.newBuilder()
                    .uri(URI.create("__BASE__/v1/cards/lookup?word=retain"))
                    .header("X-API-Key", "voca_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
                    .GET()
                    .build();
            var response = client.send(request, HttpResponse.BodyHandlers.ofString());
            System.out.println(response.body());
            ```

            ---

            ## 8. Công thức thường dùng

            **Đồng bộ toàn bộ từ vựng (poll rẻ):**
            1. `GET /v1/cards` → lưu `version` và mảng `cards`.
            2. Định kỳ `GET /v1/cards?ifChangedSince=<version>`.
            3. Nếu `changed:true` → cập nhật kho cục bộ và lưu `version` mới.

            **Tra từ rồi phát âm:**
            1. `GET /v1/cards/lookup?word=retain` → lấy `card.slug`.
            2. `GET /v1/audio/{slug}` → nếu 404, `POST /v1/audio/{slug}` rồi `GET` lại.

            **Tạo bài quiz:**
            1. `POST /v1/practice/drills` với `{"count":5}`.
            2. Đọc SSE (mục 5), nối `delta.content`, parse JSON để lấy bộ câu hỏi.

            ---

            ## 9. Ghi chú bảo mật & vận hành

            - **Giữ key ở phía server** của bên tích hợp; không lộ ra client công khai.
            - Key bị **thu hồi/xóa** sẽ ngừng hoạt động ngay (HTTP 401) — không có thời gian ân hạn.
            - Endpoint SSE nên đọc theo **luồng**; đừng chờ toàn bộ response mới xử lý.
            - Tôn trọng **rate limit** (120 req/phút/key); áp dụng backoff khi gặp 429.
            - Base URL trong tài liệu này (`__BASE__`) được lấy theo host đã phục vụ file — nếu Voca đổi
              domain, hãy tải lại tài liệu để có URL mới.
            """;
}
