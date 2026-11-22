import Foundation

/// Coalesces simultaneous `/api/cards` requests within the same session and
/// mutation generation. Invalidation on card mutations or session/cache clear
/// prevents stale pre-mutation or cross-account responses from being reused or
/// overwriting fresher cache entries.
private actor CardsListRequestPool {
    static let shared = CardsListRequestPool()

    private struct InFlight {
        let id: UUID
        let epoch: UInt64
        let generation: UInt64
        let task: Task<[Card], Error>
    }

    private var current: InFlight?
    private var generation: UInt64 = 0

    func invalidate() {
        generation &+= 1
        current = nil
    }

    func fetch(
        epoch: UInt64,
        operation: @escaping @Sendable () async throws -> [Card],
        onSuccess: @escaping @Sendable ([Card]) -> Void
    ) async throws -> [Card] {
        if let existing = current,
           existing.epoch == epoch,
           existing.generation == generation {
            return try await existing.task.value
        }

        let id = UUID()
        let requestGeneration = generation
        let task = Task<[Card], Error> {
            do {
                let cards = try await operation()
                self.finish(
                    id: id,
                    epoch: epoch,
                    generation: requestGeneration,
                    cards: cards,
                    onSuccess: onSuccess
                )
                return cards
            } catch {
                self.clearIfCurrent(id: id)
                throw error
            }
        }
        current = InFlight(id: id, epoch: epoch, generation: requestGeneration, task: task)
        return try await task.value
    }

    private func finish(
        id: UUID,
        epoch: UInt64,
        generation requestGeneration: UInt64,
        cards: [Card],
        onSuccess: @Sendable ([Card]) -> Void
    ) {
        if current?.id == id {
            current = nil
        }
        guard requestGeneration == generation, AppCache.sessionEpoch == epoch else { return }
        onSuccess(cards)
    }

    private func clearIfCurrent(id: UUID) {
        if current?.id == id {
            current = nil
        }
    }
}

/// Stateless wrapper over the `/api/cards` endpoints.
struct CardsService {
    private let api = ApiClient.shared

    private struct ListResponse: Decodable { let version: String?; let cards: [Card] }
    private struct DeleteResponse: Decodable { let ok: Bool?; let slug: String? }

    func list() async throws -> [Card] {
        let epoch = AppCache.sessionEpoch
        return try await CardsListRequestPool.shared.fetch(
            epoch: epoch,
            operation: {
                let res: ListResponse = try await ApiClient.shared.get("/api/cards")
                return res.cards
            },
            onSuccess: { cards in
                AppCache.saveCards(cards)
            }
        )
    }

    func cachedList() -> [Card] { AppCache.loadCards() }

    func cachedHtml(slug: String) -> String? { AppCache.loadHtml(slug: slug) }

    func get(slug: String) async throws -> Card {
        let card: Card = try await api.get("/api/cards/\(encode(slug))")
        await CardsListRequestPool.shared.invalidate()
        AppCache.upsertCard(card)
        return card
    }

    /// Generates a new card from a word via the server-side LLM (`POST /api/cards/create`).
    func createWithAI(word: String, language: CardLanguage = .english) async throws -> Card {
        let card: Card = try await api.post("/api/cards/create", body: [
            "word": word,
            "language": language.rawValue,
        ])
        await CardsListRequestPool.shared.invalidate()
        await StudyService.invalidatePendingRequests()
        AppCache.upsertCard(card)
        return card
    }

    func setLevel(slug: String, level: String) async throws -> Card {
        let card: Card = try await api.patch(
            "/api/cards/\(encode(slug))/level", body: ["level": level])
        await CardsListRequestPool.shared.invalidate()
        await StudyService.invalidatePendingRequests()
        AppCache.upsertCard(card)
        return card
    }

    func delete(slug: String) async throws {
        let _: DeleteResponse = try await api.delete("/api/cards/\(encode(slug))")
        await CardsListRequestPool.shared.invalidate()
        await StudyService.invalidatePendingRequests()
        AppCache.removeCard(slug: slug)
    }

    /// Fetches the A4 study sheet HTML for the card, caching it offline and falling back to cache on error.
    func getHtml(slug: String) async throws -> String {
        do {
            let data = try await api.rawData(method: "GET", path: "/api/cards/\(encode(slug))/html")
            guard let html = String(data: data, encoding: .utf8) else {
                throw ApiError.badResponse
            }
            AppCache.saveHtml(html, slug: slug)
            return html
        } catch {
            if let cached = AppCache.loadHtml(slug: slug) {
                return cached
            }
            throw error
        }
    }

    /// Requests regeneration of the A4 study sheet HTML, then returns and caches the fresh HTML.
    func generateHtml(slug: String) async throws -> String {
        _ = try await api.rawData(method: "POST", path: "/api/cards/\(encode(slug))/html")
        let data = try await api.rawData(method: "GET", path: "/api/cards/\(encode(slug))/html")
        guard let html = String(data: data, encoding: .utf8) else {
            throw ApiError.badResponse
        }
        AppCache.saveHtml(html, slug: slug)
        return html
    }

    private func encode(_ slug: String) -> String {
        slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
    }
}
