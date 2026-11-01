import Foundation
import Observation

@MainActor
@Observable
final class MacActivityLedger {
    struct ReviewEventRecord: Codable, Equatable, Identifiable, Sendable {
        let id: UUID
        let cardID: String
        let gradeRawValue: String
        let timestamp: Date

        init(
            id: UUID = UUID(),
            cardID: String,
            gradeRawValue: String,
            timestamp: Date = Date()
        ) {
            self.id = id
            self.cardID = cardID
            self.gradeRawValue = gradeRawValue
            self.timestamp = timestamp
        }
    }

    struct PracticeEventRecord: Codable, Equatable, Identifiable, Sendable {
        let id: UUID
        let activityKindRawValue: String
        let questionCount: Int
        let correctCount: Int
        let timestamp: Date

        init(
            id: UUID = UUID(),
            activityKindRawValue: String,
            questionCount: Int,
            correctCount: Int,
            timestamp: Date = Date()
        ) {
            self.id = id
            self.activityKindRawValue = activityKindRawValue
            self.questionCount = questionCount
            self.correctCount = correctCount
            self.timestamp = timestamp
        }
    }

    struct PendingMutation: Codable, Equatable, Identifiable, Sendable {
        enum Kind: String, Codable, Sendable {
            case createCard
            case deleteCard
            case submitReview
            case updateLevel
        }

        let id: UUID
        let kind: Kind
        let targetID: String
        let payload: [String: String]
        let createdAt: Date
        var attemptCount: Int
        var lastError: String?

        init(
            id: UUID = UUID(),
            kind: Kind,
            targetID: String,
            payload: [String: String] = [:],
            createdAt: Date = Date(),
            attemptCount: Int = 0,
            lastError: String? = nil
        ) {
            self.id = id
            self.kind = kind
            self.targetID = targetID
            self.payload = payload
            self.createdAt = createdAt
            self.attemptCount = attemptCount
            self.lastError = lastError
        }
    }

    struct ReviewSessionRecovery: Codable, Equatable, Sendable {
        let cardIDs: [String]
        let currentIndex: Int
        let gradesByCardID: [String: String]
        let savedAt: Date
    }

    private(set) var favoriteCardIDs: Set<String>
    private(set) var personalNotesByCardID: [String: String]
    private(set) var customTagsByCardID: [String: [String]]
    private(set) var reviewEvents: [ReviewEventRecord]
    private(set) var practiceEvents: [PracticeEventRecord]
    private(set) var pendingMutations: [PendingMutation]
    private(set) var activeReviewSession: ReviewSessionRecovery?
    private(set) var isSyncingMutations = false

    private let persistence: MacActivityLedgerPersistence
    private let calendar: Calendar

    init(
        persistence: MacActivityLedgerPersistence,
        calendar: Calendar = .current
    ) {
        self.persistence = persistence
        self.calendar = calendar

        let state = persistence.load()
        favoriteCardIDs = state.favoriteCardIDs
        personalNotesByCardID = state.personalNotesByCardID
        customTagsByCardID = state.customTagsByCardID
        reviewEvents = state.reviewEvents
        practiceEvents = state.practiceEvents
        pendingMutations = state.pendingMutations
        activeReviewSession = state.activeReviewSession
    }

    convenience init(calendar: Calendar = .current) {
        self.init(
            persistence: UserDefaultsMacActivityLedgerPersistence(),
            calendar: calendar
        )
    }

    // MARK: - Favorites, Notes & Tags

    func isFavorite(_ cardID: String) -> Bool {
        favoriteCardIDs.contains(cardID)
    }

    @discardableResult
    func toggleFavorite(_ cardID: String) -> Bool {
        let isNowFavorite: Bool
        if favoriteCardIDs.contains(cardID) {
            favoriteCardIDs.remove(cardID)
            isNowFavorite = false
        } else {
            favoriteCardIDs.insert(cardID)
            isNowFavorite = true
        }
        save()
        return isNowFavorite
    }

    func setFavorite(_ cardID: String, isFavorite: Bool) {
        if isFavorite {
            favoriteCardIDs.insert(cardID)
        } else {
            favoriteCardIDs.remove(cardID)
        }
        save()
    }

    func personalNote(for cardID: String) -> String {
        personalNotesByCardID[cardID] ?? ""
    }

    func setPersonalNote(_ note: String, for cardID: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            personalNotesByCardID.removeValue(forKey: cardID)
        } else {
            personalNotesByCardID[cardID] = trimmed
        }
        save()
    }

    func customTags(for cardID: String) -> [String] {
        customTagsByCardID[cardID] ?? []
    }

    func setCustomTags(_ tags: [String], for cardID: String) {
        let normalized = Array(
            NSOrderedSet(
                array: tags
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        ) as? [String] ?? []

        if normalized.isEmpty {
            customTagsByCardID.removeValue(forKey: cardID)
        } else {
            customTagsByCardID[cardID] = normalized
        }
        save()
    }

    // MARK: - Learning Activity & Analytics

    func recordReview(
        cardID: String,
        grade: MacReviewGrade,
        at date: Date = Date()
    ) {
        reviewEvents.append(
            ReviewEventRecord(
                cardID: cardID,
                gradeRawValue: grade.rawValue,
                timestamp: date
            )
        )
        save()
    }

    func recordPractice(
        activityKind: MacPracticeActivity.Kind,
        questionCount: Int,
        correctCount: Int,
        at date: Date = Date()
    ) {
        guard questionCount > 0 else { return }

        practiceEvents.append(
            PracticeEventRecord(
                activityKindRawValue: activityKind.rawValue,
                questionCount: questionCount,
                correctCount: min(max(correctCount, 0), questionCount),
                timestamp: date
            )
        )
        save()
    }

    func completedReviewsToday(now: Date = Date()) -> Int {
        reviewEvents.filter {
            calendar.isDate($0.timestamp, inSameDayAs: now)
        }.count
    }

    func completedActivitiesToday(now: Date = Date()) -> Int {
        let reviews = completedReviewsToday(now: now)
        let practices = practiceEvents
            .filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
            .reduce(0) { $0 + $1.questionCount }
        return reviews + practices
    }

    func streakDays(now: Date = Date()) -> Int {
        let activeDays = Set(
            reviewEvents.map { calendar.startOfDay(for: $0.timestamp) }
            + practiceEvents.map { calendar.startOfDay(for: $0.timestamp) }
        )

        guard !activeDays.isEmpty else { return 0 }

        let todayStart = calendar.startOfDay(for: now)
        guard let yesterdayStart = calendar.date(
            byAdding: .day,
            value: -1,
            to: todayStart
        ) else {
            return activeDays.contains(todayStart) ? 1 : 0
        }

        var cursor: Date
        if activeDays.contains(todayStart) {
            cursor = todayStart
        } else if activeDays.contains(yesterdayStart) {
            cursor = yesterdayStart
        } else {
            return 0
        }

        var streak = 0
        while activeDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(
                byAdding: .day,
                value: -1,
                to: cursor
            ) else {
                break
            }
            cursor = previous
        }

        return streak
    }

    func insightsSnapshot(
        difficultWordCount: Int,
        now: Date = Date()
    ) -> MacInsightsSnapshot {
        let todayStart = calendar.startOfDay(for: now)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"

        let idFormatter = DateFormatter()
        idFormatter.locale = Locale(identifier: "en_US_POSIX")
        idFormatter.dateFormat = "yyyy-MM-dd"

        var dailyMetrics: [MacDailyLearningMetric] = []
        var reviewedThisWeek = 0
        var practicedThisWeek = 0

        for dayOffset in stride(from: -6, through: 0, by: 1) {
            guard let dayDate = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: todayStart
            ) else {
                continue
            }

            let reviewedCount = reviewEvents.filter {
                calendar.isDate($0.timestamp, inSameDayAs: dayDate)
            }.count

            let practicedCount = practiceEvents
                .filter { calendar.isDate($0.timestamp, inSameDayAs: dayDate) }
                .reduce(0) { $0 + $1.questionCount }

            reviewedThisWeek += reviewedCount
            practicedThisWeek += practicedCount

            dailyMetrics.append(
                MacDailyLearningMetric(
                    id: idFormatter.string(from: dayDate),
                    day: formatter.string(from: dayDate),
                    reviewedCount: reviewedCount,
                    practicedCount: practicedCount
                )
            )
        }

        let recentReviews = reviewEvents.suffix(50)
        let recentPractices = practiceEvents.suffix(20)

        let successfulReviews = recentReviews.filter {
            $0.gradeRawValue == MacReviewGrade.good.rawValue
            || $0.gradeRawValue == MacReviewGrade.easy.rawValue
        }.count
        let practiceTotal = recentPractices.reduce(0) { $0 + $1.questionCount }
        let practiceCorrect = recentPractices.reduce(0) { $0 + $1.correctCount }

        let totalEvaluated = recentReviews.count + practiceTotal
        let totalSuccessful = successfulReviews + practiceCorrect

        let accuracyPercent: Int
        if totalEvaluated > 0 {
            accuracyPercent = Int(
                (Double(totalSuccessful) / Double(totalEvaluated) * 100.0)
                    .rounded()
            )
        } else {
            accuracyPercent = 100
        }

        return MacInsightsSnapshot(
            reviewedThisWeek: reviewedThisWeek,
            practicedThisWeek: practicedThisWeek,
            accuracyPercent: min(max(accuracyPercent, 0), 100),
            streakDays: streakDays(now: now),
            difficultWordCount: max(difficultWordCount, 0),
            dailyMetrics: dailyMetrics
        )
    }

    // MARK: - Review Session Recovery

    func saveActiveReviewSession(
        cardIDs: [String],
        currentIndex: Int,
        grades: [String: MacReviewGrade],
        now: Date = Date()
    ) {
        guard !cardIDs.isEmpty, currentIndex < cardIDs.count else {
            clearActiveReviewSession()
            return
        }

        activeReviewSession = ReviewSessionRecovery(
            cardIDs: cardIDs,
            currentIndex: max(currentIndex, 0),
            gradesByCardID: grades.mapValues(\.rawValue),
            savedAt: now
        )
        save()
    }

    func clearActiveReviewSession() {
        guard activeReviewSession != nil else { return }
        activeReviewSession = nil
        save()
    }

    // MARK: - Offline Mutation Queue

    func enqueueMutation(_ mutation: PendingMutation) {
        if mutation.kind == .deleteCard {
            pendingMutations.removeAll {
                $0.targetID == mutation.targetID
            }
        }
        pendingMutations.append(mutation)
        save()
    }

    func removeMutation(id: UUID) {
        pendingMutations.removeAll { $0.id == id }
        save()
    }

    func flushPendingMutations(
        cardsService: CardsService = CardsService(),
        studyService: StudyService = StudyService()
    ) async {
        guard !isSyncingMutations, !pendingMutations.isEmpty else {
            return
        }

        isSyncingMutations = true
        defer {
            isSyncingMutations = false
        }

        var remaining: [PendingMutation] = []

        for var mutation in pendingMutations {
            do {
                switch mutation.kind {
                case .createCard:
                    let word = mutation.payload["word"] ?? mutation.targetID
                    let languageRaw = mutation.payload["language"] ?? "en"
                    let language = CardLanguage(rawValue: languageRaw) ?? .english
                    _ = try await cardsService.createWithAI(
                        word: word,
                        language: language
                    )

                case .deleteCard:
                    try await cardsService.delete(slug: mutation.targetID)

                case .submitReview:
                    let gradeString = mutation.payload["grade"] ?? "good"
                    let grade = MacReviewGrade(rawValue: gradeString) ?? .good
                    _ = try await studyService.review(
                        slug: mutation.targetID,
                        grade: grade.reviewGrade
                    )

                case .updateLevel:
                    if let level = mutation.payload["level"] {
                        _ = try await cardsService.setLevel(
                            slug: mutation.targetID,
                            level: level
                        )
                    }
                }
            } catch {
                mutation.attemptCount += 1
                mutation.lastError = error.localizedDescription
                remaining.append(mutation)
            }
        }

        pendingMutations = remaining
        save()
    }

    func clearAll() {
        persistence.clear()
        favoriteCardIDs = []
        personalNotesByCardID = [:]
        customTagsByCardID = [:]
        reviewEvents = []
        practiceEvents = []
        pendingMutations = []
        activeReviewSession = nil
    }

    private func save() {
        persistence.save(
            MacActivityLedgerState(
                favoriteCardIDs: favoriteCardIDs,
                personalNotesByCardID: personalNotesByCardID,
                customTagsByCardID: customTagsByCardID,
                reviewEvents: reviewEvents,
                practiceEvents: practiceEvents,
                pendingMutations: pendingMutations,
                activeReviewSession: activeReviewSession
            )
        )
    }
}

struct MacActivityLedgerState: Codable, Equatable, Sendable {
    var favoriteCardIDs: Set<String>
    var personalNotesByCardID: [String: String]
    var customTagsByCardID: [String: [String]]
    var reviewEvents: [MacActivityLedger.ReviewEventRecord]
    var practiceEvents: [MacActivityLedger.PracticeEventRecord]
    var pendingMutations: [MacActivityLedger.PendingMutation]
    var activeReviewSession: MacActivityLedger.ReviewSessionRecovery?

    static let empty = MacActivityLedgerState(
        favoriteCardIDs: [],
        personalNotesByCardID: [:],
        customTagsByCardID: [:],
        reviewEvents: [],
        practiceEvents: [],
        pendingMutations: [],
        activeReviewSession: nil
    )
}

@MainActor
protocol MacActivityLedgerPersistence {
    func load() -> MacActivityLedgerState
    func save(_ state: MacActivityLedgerState)
    func clear()
}

@MainActor
struct UserDefaultsMacActivityLedgerPersistence: MacActivityLedgerPersistence {
    private let defaults: UserDefaults
    private let baseKey = "mac.activity.ledger.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> MacActivityLedgerState {
        guard let data = defaults.data(forKey: scopedKey),
              let state = try? JSONDecoder().decode(
                  MacActivityLedgerState.self,
                  from: data
              )
        else {
            return .empty
        }

        return state
    }

    func save(_ state: MacActivityLedgerState) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }
        defaults.set(data, forKey: scopedKey)
    }

    func clear() {
        defaults.removeObject(forKey: scopedKey)
    }

    private var scopedKey: String {
        if let accountID = defaults.string(forKey: "mac.session.account.id"),
           !accountID.isEmpty {
            return "\(baseKey).\(accountID)"
        }
        return baseKey
    }
}

@MainActor
final class InMemoryMacActivityLedgerPersistence: MacActivityLedgerPersistence {
    private var state: MacActivityLedgerState

    init(state: MacActivityLedgerState = .empty) {
        self.state = state
    }

    func load() -> MacActivityLedgerState {
        state
    }

    func save(_ state: MacActivityLedgerState) {
        self.state = state
    }

    func clear() {
        state = .empty
    }
}
