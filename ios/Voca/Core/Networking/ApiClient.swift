import Foundation

/// Type-erased `Encodable` so request bodies can be passed as `Encodable?`.
struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { self.encodeClosure = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeClosure(encoder) }
}

/// One OpenAI-style streaming chunk: `choices[0].delta.content`.
private struct SSEChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta?
    }
    let choices: [Choice]?
}

/// The authenticated JSON client for `/api/**`. Adds the Bearer token, unwraps the response
/// envelope, and performs one automatic token refresh + retry on 401 (mirrors `web/src/lib/api.ts`).
/// Also exposes raw-bytes requests (audio) and SSE streaming (AI).
final class ApiClient {
    static let shared = ApiClient()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// Called (on the main actor) when the session cannot be recovered — the UI should sign out.
    var onSessionExpired: (() -> Void)?

    private lazy var tokens = TokenManager { [weak self] refreshToken in
        await self?.rawRefresh(refreshToken: refreshToken) ?? nil
    }

    private init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Session state

    func hasStoredSession() async -> Bool { await tokens.hasSession }

    func storeTokens(access: String, refresh: String) async {
        await tokens.store(access: access, refresh: refresh)
    }

    func logout() async {
        if let refresh = await tokens.refreshToken {
            let _: OkResponse? = try? await post("/api/auth/logout", body: ["refreshToken": refresh])
        }
        await tokens.clear()
    }

    // MARK: - JSON verbs (envelope-unwrapped)

    func get<T: Decodable>(_ path: String, authorized: Bool = true) async throws -> T {
        try await decoded(method: "GET", path: path, bodyData: nil, authorized: authorized)
    }

    func post<T: Decodable>(_ path: String, body: Encodable? = nil, authorized: Bool = true) async throws -> T {
        try await decoded(method: "POST", path: path, bodyData: try encode(body), authorized: authorized)
    }

    func put<T: Decodable>(_ path: String, body: Encodable? = nil, authorized: Bool = true) async throws -> T {
        try await decoded(method: "PUT", path: path, bodyData: try encode(body), authorized: authorized)
    }

    func patch<T: Decodable>(_ path: String, body: Encodable? = nil, authorized: Bool = true) async throws -> T {
        try await decoded(method: "PATCH", path: path, bodyData: try encode(body), authorized: authorized)
    }

    func delete<T: Decodable>(_ path: String, authorized: Bool = true) async throws -> T {
        try await decoded(method: "DELETE", path: path, bodyData: nil, authorized: authorized)
    }

    /// Public health probe (`GET /v1/health`, no auth). Returns true when the server is reachable.
    func health() async -> Bool {
        guard let url = url(for: "/v1/health") else { return false }
        guard let (_, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }

    // MARK: - Raw bytes (e.g. audio/mpeg from /api/tts, /api/audio/{id})

    func rawData(method: String, path: String, body: Encodable? = nil, authorized: Bool = true) async throws -> Data {
        let (data, http) = try await perform(method: method, path: path, bodyData: try encode(body),
                                             accept: nil, authorized: authorized, retry: true)
        try throwIfError(data: data, http: http)
        return data
    }

    // MARK: - SSE streaming (AI chat + practice)

    /// Streams an OpenAI-style SSE endpoint, yielding successive `delta.content` fragments.
    /// The server may deliver an upstream error as a normal content chunk — it is yielded like any text.
    func streamContent(path: String, body: Encodable) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let work = Task {
                do {
                    try await runStream(path: path, body: body, continuation: continuation, retry: true)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in work.cancel() }
        }
    }

    private func runStream(path: String, body: Encodable,
                           continuation: AsyncThrowingStream<String, Error>.Continuation,
                           retry: Bool) async throws {
        guard let url = url(for: path) else { throw ApiError.badResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(AnyEncodable(body))
        if let token = await tokens.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            throw ApiError.network(error)
        }
        guard let http = response as? HTTPURLResponse else { throw ApiError.badResponse }

        if http.statusCode == 401, retry {
            if await tokens.refresh() {
                return try await runStream(path: path, body: body, continuation: continuation, retry: false)
            }
            await tokens.clear()
            await MainActor.run { onSessionExpired?() }
            throw ApiError.sessionExpired
        }
        guard (200..<300).contains(http.statusCode) else {
            // On failure the stream endpoints return a normal JSON error envelope (NOT SSE) —
            // e.g. 503 LLM_NOT_CONFIGURED. Drain the body and surface the real, friendly message.
            var body = Data()
            for try await byte in bytes { body.append(byte) }
            if let env = try? decoder.decode(ErrorEnvelope.self, from: body) {
                throw Self.friendly(env)
            }
            // Fallback: Spring's default error body { timestamp, status, error, path } / { message }.
            if let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let msg = (obj["message"] as? String) ?? (obj["error"] as? String), !msg.isEmpty {
                throw ApiError(status: http.statusCode, code: "STREAM_ERROR",
                               message: "Không tạo được nội dung AI: \(msg) (\(http.statusCode)).")
            }
            throw ApiError(status: http.statusCode, code: "STREAM_ERROR",
                           message: "Máy chủ trả lỗi \(http.statusCode) khi tạo nội dung AI.")
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            // SSE strips exactly one optional space after the colon; keep the rest (leading spaces
            // are meaningful in plain-text deltas so words don't get glued together).
            var payload = String(line.dropFirst(5))
            if payload.first == " " { payload.removeFirst() }
            if payload.isEmpty || payload == "[DONE]" { continue }

            // Two server formats:
            //  • /chat/completions → OpenAI-style JSON chunks ({choices:[{delta:{content}}]})
            //  • /agent/chat and /practice/* → plain-text delta pieces (LlmClient.streamDeltas)
            if let data = payload.data(using: .utf8),
               let chunk = try? decoder.decode(SSEChunk.self, from: data) {
                if let content = chunk.choices?.first?.delta?.content, !content.isEmpty {
                    continuation.yield(content)
                }
                // A JSON chunk without content (e.g. a role-only opening delta) is ignored.
            } else {
                continuation.yield(payload)
            }
        }
    }

    // MARK: - Core plumbing

    private func encode(_ body: Encodable?) throws -> Data? {
        try body.map { try encoder.encode(AnyEncodable($0)) }
    }

    private func url(for path: String) -> URL? {
        URL(string: AppConfig.baseURL.absoluteString + path)
    }

    private func decoded<T: Decodable>(method: String, path: String, bodyData: Data?, authorized: Bool) async throws -> T {
        let (data, http) = try await perform(method: method, path: path, bodyData: bodyData,
                                             accept: "application/json", authorized: authorized, retry: true)
        try throwIfError(data: data, http: http)
        do {
            return try decoder.decode(Envelope<T>.self, from: data).data
        } catch {
            throw ApiError.badResponse
        }
    }

    /// Performs the request with one automatic 401 refresh+retry; returns the raw body + response.
    private func perform(method: String, path: String, bodyData: Data?, accept: String?,
                         authorized: Bool, retry: Bool) async throws -> (Data, HTTPURLResponse) {
        guard let url = url(for: path) else { throw ApiError.badResponse }

        var request = URLRequest(url: url)
        request.httpMethod = method
        if let accept { request.setValue(accept, forHTTPHeaderField: "Accept") }
        if let bodyData {
            request.httpBody = bodyData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authorized, let token = await tokens.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ApiError.network(error)
        }
        guard let http = response as? HTTPURLResponse else { throw ApiError.badResponse }

        if http.statusCode == 401, authorized, retry {
            if await tokens.refresh() {
                return try await perform(method: method, path: path, bodyData: bodyData,
                                         accept: accept, authorized: authorized, retry: false)
            }
            await tokens.clear()
            await MainActor.run { onSessionExpired?() }
            throw ApiError.sessionExpired
        }
        return (data, http)
    }

    /// Throws a typed `ApiError` (decoding the error envelope when present) for a non-2xx status.
    private func throwIfError(data: Data, http: HTTPURLResponse) throws {
        guard (200..<300).contains(http.statusCode) else {
            if let env = try? decoder.decode(ErrorEnvelope.self, from: data) {
                throw Self.friendly(env)
            }
            throw ApiError(status: http.statusCode, code: "ERROR",
                           message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }
    }

    /// Turns known backend error codes into actionable Vietnamese messages.
    private static func friendly(_ env: ErrorEnvelope) -> ApiError {
        switch env.code {
        case "LLM_NOT_CONFIGURED":
            return ApiError(status: env.status, code: env.code,
                            message: "Chưa cấu hình LLM. Vào Cài đặt → Kết nối AI (LLM) để thêm Base URL + Khóa API.")
        case "TTS_NOT_CONFIGURED":
            return ApiError(status: env.status, code: env.code,
                            message: "Chưa cấu hình TTS. Vào Cài đặt → Giọng đọc (TTS) để thêm Base URL + Khóa API.")
        default:
            return ApiError(status: env.status, code: env.code, message: env.message)
        }
    }

    /// Raw refresh call — deliberately bypasses `perform` (no Bearer, no retry) to avoid recursion.
    private func rawRefresh(refreshToken: String) async -> AuthResponse? {
        guard let url = url(for: "/api/auth/refresh") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? encoder.encode(["refreshToken": refreshToken])

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let env = try? decoder.decode(Envelope<AuthResponse>.self, from: data)
        else { return nil }
        return env.data
    }
}
