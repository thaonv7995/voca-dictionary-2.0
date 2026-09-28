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

    /// Fetches the A4 study sheet HTML for the card.
    func getHtml(slug: String) async throws -> String {
        let data = try await api.rawData(method: "GET", path: "/api/cards/\(encode(slug))/html")
        guard let html = String(data: data, encoding: .utf8) else {
            throw ApiError.badResponse
        }
        return html
    }

    /// Requests regeneration of the A4 study sheet HTML, then returns the fresh HTML.
    func generateHtml(slug: String) async throws -> String {
        _ = try await api.rawData(method: "POST", path: "/api/cards/\(encode(slug))/html")
        return try await getHtml(slug: slug)
    }

    private func encode(_ slug: String) -> String {
        slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
    }
}
