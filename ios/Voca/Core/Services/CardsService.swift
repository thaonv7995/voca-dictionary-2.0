import Foundation

/// Stateless wrapper over the `/api/cards` endpoints.
struct CardsService {
    private let api = ApiClient.shared

    private struct ListResponse: Decodable { let version: String?; let cards: [Card] }
    private struct DeleteResponse: Decodable { let ok: Bool?; let slug: String? }

    func list() async throws -> [Card] {
        let res: ListResponse = try await api.get("/api/cards")
        return res.cards
    }

    func get(slug: String) async throws -> Card {
        try await api.get("/api/cards/\(encode(slug))")
    }

    /// Generates a new card from a word via the server-side LLM (`POST /api/cards/create`).
    func createWithAI(word: String) async throws -> Card {
        try await api.post("/api/cards/create", body: ["word": word])
    }

    func setLevel(slug: String, level: String) async throws -> Card {
        try await api.patch("/api/cards/\(encode(slug))/level", body: ["level": level])
    }

    func delete(slug: String) async throws {
        let _: DeleteResponse = try await api.delete("/api/cards/\(encode(slug))")
    }

    private func encode(_ slug: String) -> String {
        slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
    }
}
