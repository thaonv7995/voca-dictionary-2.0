import Foundation
import Observation

/// Lightweight per-user local learner progress (favorites, daily review counts, streak & daily goal).
/// Complements server FSRS stats without conflicting with backend persistence.
@MainActor
@Observable
final class LocalLearnerStore {
    static let shared = LocalLearnerStore()

    private(set) var favoriteSlugs: Set<String> = []
    private(set) var dailyReviewsByDate: [String: Int] = [:]
    var dailyGoal: Int {
        didSet {
            let clamped = max(5, min(100, dailyGoal))
            if clamped != dailyGoal {
                dailyGoal = clamped
                return
            }
            guard !isReloading else { return }
            UserDefaults.standard.set(clamped, forKey: scopedKey("dailyGoal"))
        }
    }

    private var loadedScope: String = ""
    private var isReloading = false
    private let defaults = UserDefaults.standard

    private static let gregorianCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .autoupdatingCurrent
        return cal
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = gregorianCalendar
        formatter.timeZone = .autoupdatingCurrent
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private init() {
        dailyGoal = 20
        reloadIfNeeded(force: true)
    }

    func reloadIfNeeded(force: Bool = false) {
        let scope = currentScope
        guard force || scope != loadedScope else { return }
        loadedScope = scope

        isReloading = true
        defer { isReloading = false }

        let favorites = defaults.stringArray(forKey: scopedKey("favorites")) ?? []
        favoriteSlugs = Set(favorites)

        let rawCounts = defaults.dictionary(forKey: scopedKey("dailyReviews")) as? [String: Int] ?? [:]
        dailyReviewsByDate = rawCounts

        let storedGoal = defaults.integer(forKey: scopedKey("dailyGoal"))
        dailyGoal = storedGoal > 0 ? max(5, min(100, storedGoal)) : 20
    }

    // MARK: - Favorites

    func isFavorite(_ slug: String) -> Bool {
        favoriteSlugs.contains(slug)
    }

    func removeFavorite(_ slug: String) {
        reloadIfNeeded()
        guard favoriteSlugs.remove(slug) != nil else { return }
        defaults.set(Array(favoriteSlugs).sorted(), forKey: scopedKey("favorites"))
    }

    @discardableResult
    func toggleFavorite(_ slug: String) -> Bool {
        reloadIfNeeded()
        let isNowFavorite: Bool
        if favoriteSlugs.contains(slug) {
            favoriteSlugs.remove(slug)
            isNowFavorite = false
        } else {
            favoriteSlugs.insert(slug)
            isNowFavorite = true
        }
        defaults.set(Array(favoriteSlugs).sorted(), forKey: scopedKey("favorites"))
        return isNowFavorite
    }

    // MARK: - Daily goal & streak

    var reviewedTodayCount: Int {
        dailyReviewsByDate[dayKey(for: Date())] ?? 0
    }

    var dailyGoalProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1, Double(reviewedTodayCount) / Double(dailyGoal))
    }

    var streakDays: Int {
        var calendar = Self.gregorianCalendar
        calendar.timeZone = .autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        let todayCount = dailyReviewsByDate[dayKey(for: today)] ?? 0

        var cursor = today
        if todayCount == 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  (dailyReviewsByDate[dayKey(for: yesterday)] ?? 0) > 0
            else {
                return 0
            }
            cursor = yesterday
        }

        var streak = 0
        while (dailyReviewsByDate[dayKey(for: cursor)] ?? 0) > 0 {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    func recordReviewCompleted(count: Int = 1) {
        guard count > 0 else { return }
        reloadIfNeeded()
        let today = dayKey(for: Date())
        dailyReviewsByDate[today, default: 0] += count

        // Keep at most the most recent 120 days so defaults stay tiny.
        if dailyReviewsByDate.count > 120 {
            let trimmedKeys = dailyReviewsByDate.keys.sorted().suffix(120)
            let keep = Set(trimmedKeys)
            dailyReviewsByDate = dailyReviewsByDate.filter { keep.contains($0.key) }
        }
        defaults.set(dailyReviewsByDate, forKey: scopedKey("dailyReviews"))
    }

    // MARK: - Helpers

    private var currentScope: String {
        if let user = AppCache.loadUser() {
            return "user-\(user.id)"
        }
        return "guest"
    }

    private func scopedKey(_ suffix: String) -> String {
        "voca.learner.\(currentScope).\(suffix)"
    }

    private func dayKey(for date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }
}
