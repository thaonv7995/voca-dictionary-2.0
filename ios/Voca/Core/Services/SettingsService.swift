import Foundation

/// Stateless wrapper over `/api/user/settings` and `/api/user/api-keys`.
struct SettingsService {
    private let api = ApiClient.shared

    private struct RevokeResponse: Decodable { let id: Int?; let status: String? }
    private struct DeleteResponse: Decodable { let id: Int?; let deleted: Bool? }

    func get() async throws -> UserSettings {
        try await api.get("/api/user/settings")
    }

    func update(_ body: UpdateSettingsBody) async throws -> UserSettings {
        try await api.put("/api/user/settings", body: body)
    }

    // MARK: API keys

    func listKeys() async throws -> ApiKeysResponse {
        try await api.get("/api/user/api-keys")
    }

    func createKey(name: String, scopes: [String]? = nil) async throws -> CreatedKey {
        try await api.post("/api/user/api-keys", body: CreateKeyBody(name: name, scopes: scopes))
    }

    func revokeKey(id: Int) async throws {
        let _: RevokeResponse = try await api.post("/api/user/api-keys/\(id)/revoke")
    }

    func deleteKey(id: Int) async throws {
        let _: DeleteResponse = try await api.delete("/api/user/api-keys/\(id)")
    }
}
