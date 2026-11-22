import Foundation
import Observation

@MainActor
@Observable
final class MacReviewStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var cards: [MacReviewCard] = []
    private(set) var loadState: LoadState = .idle
    private(set) var submittingCardID: MacReviewCard.ID?
    private(set) var submissionError: String?

    private let repository: MacReviewRepository
    private let ledger: MacActivityLedger

    init(
        repository: MacReviewRepository,
        ledger: MacActivityLedger
    ) {
        self.repository = repository
        self.ledger = ledger
        cards = repository.cachedCards()
    }

    convenience init(
        repository: MacReviewRepository =
            SharedMacReviewRepository()
    ) {
        self.init(
            repository: repository,
            ledger: MacActivityLedger()
        )
    }

    convenience init(ledger: MacActivityLedger) {
        self.init(
            repository: SharedMacReviewRepository(),
            ledger: ledger
        )
    }

    var isLoading: Bool {
        loadState == .loading
    }

    var loadErrorMessage: String? {
        guard case let .failed(message) = loadState else {
            return nil
        }

        return message
    }

    var activeSessionRecovery: MacActivityLedger.ReviewSessionRecovery? {
        ledger.activeReviewSession
    }

    func load() async {
        guard !isLoading else {
            return
        }

        if cards.isEmpty {
            cards = repository.cachedCards()
        }

        loadState = .loading

        await ledger.flushPendingMutations()

        do {
            cards = try await repository.fetchDueCards()
            loadState = .loaded
        } catch {
            if cards.isEmpty {
                loadState = .failed(error.localizedDescription)
            } else {
                loadState = .failed(
                    "Showing cached review cards. "
                    + error.localizedDescription
                )
            }
        }
    }

    func retry() async {
        await load()
    }

    @discardableResult
    func submit(
        cardID: MacReviewCard.ID,
        grade: MacReviewGrade
    ) async -> Bool {
        guard submittingCardID == nil else {
            return false
        }

        submittingCardID = cardID
        submissionError = nil

        defer {
            submittingCardID = nil
        }

        do {
            try await repository.submitReview(
                cardID: cardID,
                grade: grade
            )

            ledger.recordReview(cardID: cardID, grade: grade)
            cards.removeAll(where: { $0.id == cardID })
            return true
        } catch {
            // Persist locally into the offline mutation queue so review pace
            // is never blocked by transient network failures.
            ledger.recordReview(cardID: cardID, grade: grade)
            ledger.enqueueMutation(
                MacActivityLedger.PendingMutation(
                    kind: .submitReview,
                    targetID: cardID,
                    payload: ["grade": grade.rawValue]
                )
            )
            cards.removeAll(where: { $0.id == cardID })
            return true
        }
    }

    func saveSessionProgress(
        currentIndex: Int,
        grades: [MacReviewCard.ID: MacReviewGrade]
    ) {
        ledger.saveActiveReviewSession(
            cardIDs: cards.map(\.id),
            currentIndex: currentIndex,
            grades: grades
        )
    }

    func clearSessionProgress() {
        ledger.clearActiveReviewSession()
    }

    func dismissSubmissionError() {
        submissionError = nil
    }

    func restoreCard(_ card: MacReviewCard, at index: Int) {
        guard !cards.contains(where: { $0.id == card.id }) else {
            return
        }
        let targetIndex = min(max(index, 0), cards.count)
        cards.insert(card, at: targetIndex)
    }

    func replaceCardsForTesting(_ cards: [MacReviewCard]) {
        self.cards = cards
        loadState = .loaded
    }

    func resetForSignOut() {
        cards = []
        submittingCardID = nil
        submissionError = nil
        loadState = .idle
    }
}

protocol MacReviewRepository: Sendable {
    @MainActor
    func cachedCards() -> [MacReviewCard]

    func fetchDueCards() async throws -> [MacReviewCard]

    func submitReview(
        cardID: String,
        grade: MacReviewGrade
    ) async throws
}

struct SharedMacReviewRepository: MacReviewRepository {
    private let service = StudyService()

    @MainActor
    func cachedCards() -> [MacReviewCard] {
        service.cachedDue()?
            .cards
            .map(MacReviewCard.init) ?? []
    }

    func fetchDueCards() async throws -> [MacReviewCard] {
        try await service.due()
            .cards
            .map(MacReviewCard.init)
    }

    func submitReview(
        cardID: String,
        grade: MacReviewGrade
    ) async throws {
        _ = try await service.review(
            slug: cardID,
            grade: grade.reviewGrade
        )
    }
}

extension MacReviewCard {
    init(dueItem: DueItem) {
        let card = dueItem.card

        id = card.slug
        prompt = card.word
        pronunciation = card.phonetic
        meaning = Self.preferredMeaning(from: card)
        example = card.examples?.first
        language = MacVocabularyItem.Language(
            cardLanguage: card.cardLanguage
        )
    }

    private static func preferredMeaning(from card: Card) -> String {
        let candidates = [
            card.meaningVi,
            card.meaningEn,
            card.answer
        ]

        return candidates.compactMap { value in
            guard let value else {
                return nil
            }

            let trimmed = value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            return trimmed.isEmpty ? nil : trimmed
        }.first ?? "No meaning available."
    }
}

extension MacReviewGrade {
    var reviewGrade: ReviewGrade {
        switch self {
        case .again:
            .again
        case .hard:
            .hard
        case .good:
            .good
        case .easy:
            .easy
        }
    }
}

struct PreviewMacReviewRepository: MacReviewRepository {
    var cards: [MacReviewCard] = MacReviewCard.previewCards

    @MainActor
    func cachedCards() -> [MacReviewCard] {
        cards
    }

    func fetchDueCards() async throws -> [MacReviewCard] {
        cards
    }

    func submitReview(
        cardID: String,
        grade: MacReviewGrade
    ) async throws {}
}
