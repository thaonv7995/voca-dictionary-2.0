import Observation
import SwiftUI

/// The "Hôm nay" (Today) dashboard tab — a quick daily snapshot of the learner's progress.
///
/// Loads study `stats()` + `due()` and the full card list concurrently on appear, then surfaces:
/// a personalised greeting, a due-review hero that launches a full-screen review session,
/// a mastery ring, per-level stat tiles and the most recently added cards.
struct TodayView: View {
    @Environment(AuthStore.self) private var auth
    @AppStorage("voca.dictionary.language") private var languageRaw = CardLanguage.english.rawValue

    @State private var model = TodayModel()
    @State private var showSession = false

    private var language: CardLanguage {
        CardLanguage(rawValue: languageRaw) ?? .english
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    greeting
                    CardLanguagePicker(selection: $languageRaw)

                    if let errorMessage = model.errorMessage {
                        errorBanner(errorMessage)
                    }

                    dueHero
                    masterySection
                    statsSection
                    recentSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Hôm nay")
            .tint(Brand.green)
            .refreshable { await model.load() }
            .task { await model.load() }
            .fullScreenCover(isPresented: $showSession, onDismiss: {
                Task { await model.load() }
            }) {
                ReviewSessionView(items: model.dueItems(for: language))
            }
        }
    }

    // MARK: - Greeting

    @ViewBuilder private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Xin chào,")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(greetingName)
                .font(.largeTitle.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Display name → email prefix → "bạn".
    private var greetingName: String {
        if let name = auth.user?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        if let email = auth.user?.email,
           let prefix = email.split(separator: "@").first, !prefix.isEmpty {
            return String(prefix)
        }
        return "bạn"
    }

    // MARK: - Due hero

    @ViewBuilder private var dueHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle().fill(Brand.greenSoft).frame(width: 60, height: 60)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Brand.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if model.isLoading && model.stats == nil {
                        ProgressView()
                            .frame(height: 44, alignment: .leading)
                    } else {
                        Text("\(model.dueCount(for: language))")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(Brand.green)
                            .contentTransition(.numericText())
                    }
                    Text("thẻ cần ôn hôm nay")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            if model.dueCount(for: language) == 0 && !(model.isLoading && model.stats == nil) {
                Text("Tuyệt vời! Bạn đã ôn hết thẻ hôm nay. 🎉")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                showSession = true
            } label: {
                Label("Ôn tập ngay", systemImage: "play.fill")
            }
            .buttonStyle(BrandCTAButtonStyle())
            .disabled(model.dueCount(for: language) == 0)
        }
        .brandCard()
    }

    // MARK: - Mastery

    @ViewBuilder private var masterySection: some View {
        HStack(spacing: 20) {
            MasteryRing(fraction: model.masteryFraction(for: language))

            VStack(alignment: .leading, spacing: 6) {
                Text("Tiến độ thành thạo")
                    .font(.headline)
                Text("\(model.count(for: .mastered, language: language))/\(model.totalCards(for: language)) thẻ đã thành thạo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .brandCard()
    }

    // MARK: - Stats

    @ViewBuilder private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thống kê")
                .font(.headline)

            StatTile(
                title: "Tổng thẻ",
                value: model.totalCards(for: language),
                color: Brand.green,
                systemImage: "rectangle.stack.fill")
                .frame(maxWidth: .infinity)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(CardLevel.allCases) { level in
                    StatTile(
                        title: level.label,
                        value: model.count(for: level, language: language),
                        color: Brand.levelColor(level.rawValue),
                        systemImage: "circle.fill")
                }
            }
        }
    }

    // MARK: - Recent cards

    @ViewBuilder private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thẻ gần đây")
                .font(.headline)

            let recent = model.recentCards(for: language)
            if recent.isEmpty {
                Text(model.isLoading ? "Đang tải thẻ…" : "Chưa có thẻ nào. Hãy thêm thẻ mới nhé!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brandCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, card in
                        RecentCardRow(card: card)
                            .padding(.vertical, 10)
                        if index < recent.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(
                    Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    // MARK: - Error

    @ViewBuilder private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Thử lại") {
                    Task { await model.load() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.green)
            }
            Spacer(minLength: 0)
        }
        .brandCard()
    }
}

// MARK: - View model

/// Backs the Today dashboard. Loads server state (`StudyService` + `CardsService`) concurrently
/// and exposes the derived values the dashboard renders.
@Observable
final class TodayModel {
    var stats: StudyStats?
    var due: DueResponse?
    var cards: [Card] = []
    var isLoading = false
    var errorMessage: String?

    private let studyService = StudyService()
    private let cardsService = CardsService()

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let statsCall = studyService.stats()
            async let dueCall = studyService.due()
            async let cardsCall = cardsService.list()
            let (loadedStats, loadedDue, loadedCards) = try await (statsCall, dueCall, cardsCall)
            stats = loadedStats
            due = loadedDue
            cards = loadedCards
        } catch {
            errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
        }
        isLoading = false
    }

    // MARK: Derived

    /// Prefer the live `due` count, fall back to the stats snapshot.
    func dueItems(for language: CardLanguage) -> [DueItem] {
        (due?.cards ?? []).filter { $0.card.cardLanguage == language }
    }

    func dueCount(for language: CardLanguage) -> Int { dueItems(for: language).count }

    func totalCards(for language: CardLanguage) -> Int {
        cards.filter { $0.cardLanguage == language }.count
    }

    func count(for level: CardLevel, language: CardLanguage) -> Int {
        cards.filter { $0.cardLanguage == language && CardLevel($0.level) == level }.count
    }

    /// Mastered / total, clamped and null-safe (0 when there are no cards).
    func masteryFraction(for language: CardLanguage) -> Double {
        let total = totalCards(for: language)
        guard total > 0 else { return 0 }
        return Double(count(for: .mastered, language: language)) / Double(total)
    }

    /// The 5 most recently created cards. Cards without a parseable date sink to the bottom.
    func recentCards(for language: CardLanguage) -> [Card] {
        let sorted = cards.filter { $0.cardLanguage == language }.sorted { lhs, rhs in
            switch (Self.parseDate(lhs.createdAt), Self.parseDate(rhs.createdAt)) {
            case let (l?, r?): return l > r
            case (_?, nil): return true      // dated cards rank above undated
            case (nil, _?): return false
            case (nil, nil): return false
            }
        }
        return Array(sorted.prefix(5))
    }

    // MARK: Date parsing (null-safe, ISO-8601)

    private static let isoFormatter = ISO8601DateFormatter()
    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return isoFormatter.date(from: raw) ?? isoFractionalFormatter.date(from: raw)
    }
}
