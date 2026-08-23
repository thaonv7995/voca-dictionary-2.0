import Foundation

/// `GET /api/user/settings` (safe DTO — secrets are never returned, only `hasLlmKey`/`hasTtsKey`).
struct UserSettings: Decodable {
    let llmBaseUrl: String?
    let llmModel: String?
    let hasLlmKey: Bool
    let ttsBaseUrl: String?
    let ttsModel: String?
    let hasTtsKey: Bool
    // `voices` and `featureFlags` are free-form JSON maps — intentionally not decoded here.
}

/// `PUT /api/user/settings` body. Nil fields are omitted (server treats blank as "leave unchanged").
struct UpdateSettingsBody: Encodable {
    var llmBaseUrl: String?
    var llmApiKey: String?
    var llmModel: String?
    var ttsBaseUrl: String?
    var ttsApiKey: String?
    var ttsModel: String?
}

// MARK: - Self-service API keys

/// `GET /api/user/api-keys` → `{ keys, scopes }`.
struct ApiKeysResponse: Decodable {
    let keys: [ApiKeyInfo]
    let scopes: [OfferedScope]
}

struct ApiKeyInfo: Decodable, Identifiable {
    let id: Int
    let name: String
    let prefix: String?
    let scopes: [String]?
    let status: String?
    let lastUsedAt: String?
    let createdAt: String?
}

struct OfferedScope: Decodable, Identifiable {
    let value: String
    let label: String
    let endpoints: String
    var id: String { value }
}

/// `POST /api/user/api-keys` response — includes the plaintext `key`, shown exactly once.
struct CreatedKey: Decodable {
    let id: Int
    let name: String
    let key: String
    let prefix: String?
    let scopes: [String]?
}

struct CreateKeyBody: Encodable {
    let name: String
    let scopes: [String]?
}
