import Foundation

/// Stateless wrapper over the `/api/cards` endpoints.
struct CardsService {
    private let api = ApiClient.shared

    private struct ListResponse: Decodable { let version: String?; let cards: [Card] }
    private struct DeleteResponse: Decodable { let ok: Bool?; let slug: String? }

    func list() async throws -> [Card] {
        let res: ListResponse = try await api.get("/api/cards")
        AppCache.saveCards(res.cards)
        return res.cards
    }

    func cachedList() -> [Card] { AppCache.loadCards() }

    func get(slug: String) async throws -> Card {
        try await api.get("/api/cards/\(encode(slug))")
    }

    /// Generates a new card from a word via the server-side LLM (`POST /api/cards/create`).
    func createWithAI(word: String, language: CardLanguage = .english) async throws -> Card {
        let card: Card = try await api.post("/api/cards/create", body: [
            "word": word,
            "language": language.rawValue,
        ])
        AppCache.upsertCard(card)
        return card
    }

    func setLevel(slug: String, level: String) async throws -> Card {
        let card: Card = try await api.patch(
            "/api/cards/\(encode(slug))/level", body: ["level": level])
        AppCache.upsertCard(card)
        return card
    }

    func delete(slug: String) async throws {
        let _: DeleteResponse = try await api.delete("/api/cards/\(encode(slug))")
        AppCache.removeCard(slug: slug)
    }

    private func encode(_ slug: String) -> String {
        slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
    }
}
