import Foundation
import Observation

@MainActor
@Observable
final class MacTodayStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var snapshot: MacTodaySnapshot
    private(set) var loadState: LoadState = .idle

    private let repository: MacTodayRepository
    private let ledger: MacActivityLedger

    init(
        dailyGoal: Int = 20,
        repository: MacTodayRepository,
        ledger: MacActivityLedger
    ) {
        self.repository = repository
        self.ledger = ledger

        let initial = repository.cachedSnapshot(
            dailyGoal: dailyGoal
        ) ?? MacTodaySnapshot(
            dueCount: 0,
            completedToday: 0,
            dailyGoal: dailyGoal,
            streakDays: 0,
            difficultWordCount: 0,
            recentlyAddedCount: 0
        )

        snapshot = Self.enrich(initial, with: ledger)
    }

    convenience init(
        dailyGoal: Int = 20,
        repository: MacTodayRepository = SharedMacTodayRepository()
    ) {
        self.init(
            dailyGoal: dailyGoal,
            repository: repository,
            ledger: MacActivityLedger()
        )
    }

    convenience init(
        dailyGoal: Int = 20,
        ledger: MacActivityLedger
    ) {
        self.init(
            dailyGoal: dailyGoal,
            repository: SharedMacTodayRepository(),
            ledger: ledger
        )
    }

    var isLoading: Bool {
        loadState == .loading
    }

    var errorMessage: String? {
        guard case let .failed(message) = loadState else {
            return nil
        }

        return message
    }

    func load(dailyGoal: Int) async {
        guard !isLoading else {
            return
        }

        snapshot.dailyGoal = max(dailyGoal, 0)
        loadState = .loading

        do {
            let fetched = try await repository.fetchSnapshot(
                dailyGoal: dailyGoal
            )
            snapshot = Self.enrich(fetched, with: ledger)
            MacSystemIntegrations.scheduleDailyReviewReminderIfAuthorized(
                dueCount: snapshot.dueCount
            )
            loadState = .loaded
        } catch {
            if let cachedSnapshot = repository.cachedSnapshot(
                dailyGoal: dailyGoal
            ) {
                snapshot = Self.enrich(cachedSnapshot, with: ledger)
                loadState = .failed(
                    "Showing cached learning progress. "
                    + error.localizedDescription
                )
            } else {
                snapshot = Self.enrich(snapshot, with: ledger)
                loadState = .failed(error.localizedDescription)
            }
        }
    }

    func retry(dailyGoal: Int) async {
        await load(dailyGoal: dailyGoal)
    }

    func updateDailyGoal(_ dailyGoal: Int) {
        snapshot.dailyGoal = max(dailyGoal, 0)
        snapshot = Self.enrich(snapshot, with: ledger)
    }

    func refreshFromLocalLedger() {
        snapshot = Self.enrich(snapshot, with: ledger)
    }

    func recordCompletedReview() {
        snapshot.dueCount = max(snapshot.dueCount - 1, 0)
        snapshot = Self.enrich(snapshot, with: ledger)
    }

    func replaceSnapshotForTesting(
        _ snapshot: MacTodaySnapshot
    ) {
        self.snapshot = snapshot
        loadState = .loaded
    }

    func resetForSignOut(dailyGoal: Int = 20) {
        snapshot = MacTodaySnapshot(
            dueCount: 0,
            completedToday: 0,
            dailyGoal: max(dailyGoal, 0),
            streakDays: 0,
            difficultWordCount: 0,
            recentlyAddedCount: 0
        )
        loadState = .idle
    }

    private static func enrich(
        _ raw: MacTodaySnapshot,
        with ledger: MacActivityLedger
    ) -> MacTodaySnapshot {
        var updated = raw
        let ledgerCompleted = ledger.completedActivitiesToday()
        let ledgerStreak = ledger.streakDays()

        if ledgerCompleted > updated.completedToday {
            updated.completedToday = ledgerCompleted
        }
        if ledgerStreak > updated.streakDays {
            updated.streakDays = ledgerStreak
        }
        return updated
    }
}

protocol MacTodayRepository: Sendable {
    @MainActor
    func cachedSnapshot(
        dailyGoal: Int
    ) -> MacTodaySnapshot?

    func fetchSnapshot(
        dailyGoal: Int
    ) async throws -> MacTodaySnapshot
}

struct SharedMacTodayRepository: MacTodayRepository {
    private let studyService = StudyService()
    private let cardsService = CardsService()

    @MainActor
    func cachedSnapshot(
        dailyGoal: Int
    ) -> MacTodaySnapshot? {
        let due = studyService.cachedDue()
        let stats = studyService.cachedStats()
        let cards = cardsService.cachedList()

        guard due != nil || stats != nil || !cards.isEmpty else {
            return nil
        }

        return makeSnapshot(
            due: due,
            stats: stats,
            cards: cards,
            dailyGoal: dailyGoal
        )
    }

    func fetchSnapshot(
        dailyGoal: Int
    ) async throws -> MacTodaySnapshot {
        async let dueRequest = studyService.due()
        async let statsRequest = studyService.stats()
        async let cardsRequest = cardsService.list()

        let (due, stats, cards) = try await (
            dueRequest,
            statsRequest,
            cardsRequest
        )

        return makeSnapshot(
            due: due,
            stats: stats,
            cards: cards,
            dailyGoal: dailyGoal
        )
    }

    private func makeSnapshot(
        due: DueResponse?,
        stats: StudyStats?,
        cards: [Card],
        dailyGoal: Int
    ) -> MacTodaySnapshot {
        let learningCount = stats?.byLevel["learning"] ?? 0
        let dueDifficult = difficultCardCount(dueItems: due?.cards ?? [])

        return MacTodaySnapshot(
            dueCount: due?.count ?? stats?.dueNow ?? 0,
            completedToday: 0,
            dailyGoal: max(dailyGoal, 0),
            streakDays: (stats?.totalReviews ?? 0) > 0 ? 1 : 0,
            difficultWordCount: max(dueDifficult, learningCount),
            recentlyAddedCount: cards.count
        )
    }

    private func difficultCardCount(
        dueItems: [DueItem]
    ) -> Int {
        dueItems.filter { item in
            let lapses = item.review.lapses ?? 0
            let level = item.review.level?.lowercased()

            return lapses > 0 || level == "learning"
        }.count
    }
}

struct PreviewMacTodayRepository: MacTodayRepository {
    var snapshot: MacTodaySnapshot = .preview

    @MainActor
    func cachedSnapshot(
        dailyGoal: Int
    ) -> MacTodaySnapshot? {
        var value = snapshot
        value.dailyGoal = dailyGoal
        return value
    }

    func fetchSnapshot(
        dailyGoal: Int
    ) async throws -> MacTodaySnapshot {
        var value = snapshot
        value.dailyGoal = dailyGoal
        return value
    }
}
