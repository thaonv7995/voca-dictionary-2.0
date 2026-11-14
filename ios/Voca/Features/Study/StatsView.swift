import SwiftUI

/// Visual study progress overview with mastery ring, KPI summary cards, and level breakdown bars.
struct StatsView: View {
    @Environment(LocalLearnerStore.self) private var learner
    @AppStorage("voca.dictionary.language") private var languageRaw = CardLanguage.english.rawValue

    @State private var stats: StudyStats?
    @State private var cards: [Card] = []
    @State private var due: DueResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = StudyService()

    private var language: CardLanguage {
        CardLanguage(rawValue: languageRaw) ?? .english
    }

    private var languageCards: [Card] {
        cards.filter { $0.cardLanguage == language }
    }

    private var dueCount: Int {
        (due?.cards ?? []).filter { $0.card.cardLanguage == language }.count
    }

    private var masteredCount: Int {
        languageCards.filter { CardLevel($0.level) == .mastered }.count
    }

    private var masteryFraction: Double {
        guard !languageCards.isEmpty else { return 0 }
        return Double(masteredCount) / Double(languageCards.count)
    }

    var body: some View {
        ZStack {
            VocaThemeBackground()

            Group {
                if isLoading && stats == nil && cards.isEmpty {
                    ProgressView("Đang tải…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, stats == nil && cards.isEmpty {
                    ContentUnavailableView {
                        Label("Không tải được thống kê", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage).foregroundStyle(.red)
                    } actions: {
                        Button("Thử lại") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    content
                }
            }
        }
        .navigationTitle("Thống kê")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                CardLanguagePicker(selection: $languageRaw)

                HStack(spacing: 20) {
                    MasteryRing(fraction: masteryFraction, size: 96)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mức độ thành thạo")
                            .font(.headline)
                        Text("\(masteredCount)/\(languageCards.count) thẻ đã thành thạo")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            if learner.streakDays > 0 {
                                VocaPillBadge(text: "\(learner.streakDays) ngày liên tục", icon: "flame.fill", tint: .orange)
                            }
                            if let totalReviews = stats?.totalReviews {
                                VocaPillBadge(text: "\(totalReviews) lượt ôn", icon: "checkmark.circle.fill")
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .brandHeroCard(padding: 18, cornerRadius: 20)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    StatTile(title: "Tổng thẻ", value: languageCards.count, color: Brand.green, systemImage: "rectangle.stack.fill")
                    StatTile(title: "Cần ôn ngay", value: dueCount, color: .orange, systemImage: "clock.badge.exclamationmark.fill")
                    StatTile(title: "Hôm nay đã ôn", value: learner.reviewedTodayCount, color: .blue, systemImage: "checkmark.seal.fill")
                    StatTile(title: "Yêu thích", value: languageCards.filter { learner.isFavorite($0.slug) }.count, color: .pink, systemImage: "star.fill")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Phân bố theo cấp độ")
                        .font(.headline)

                    let counts = Dictionary(grouping: languageCards) { CardLevel($0.level) ?? .new }
                        .mapValues(\.count)
                    let maxCount = max(counts.values.max() ?? 0, 1)

                    ForEach(CardLevel.allCases) { level in
                        let count = counts[level] ?? 0
                        let pct = languageCards.isEmpty ? 0 : Int((Double(count) / Double(languageCards.count) * 100).rounded())
                        LevelBarRow(
                            label: level.label,
                            count: count,
                            percentage: pct,
                            maxCount: maxCount,
                            color: Brand.levelColor(level.rawValue)
                        )
                    }
                }
                .brandCard()
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let statsCall = service.stats()
            async let cardsCall = CardsService().list()
            async let dueCall = service.due()
            let loaded = try await (statsCall, cardsCall, dueCall)
            stats = loaded.0
            cards = loaded.1
            due = loaded.2
        } catch {
            errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
        }
        isLoading = false
    }
}

private struct LevelBarRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let label: String
    let count: Int
    let percentage: Int
    let maxCount: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(label).font(.subheadline.weight(.medium))
                }
                Spacer()
                Text("\(count) (\(percentage)%)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Brand.elevatedFill(for: colorScheme))
                    Capsule()
                        .fill(color)
                        .frame(width: max(geo.size.width * fraction, count > 0 ? 8 : 0))
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: fraction)
                }
            }
            .frame(height: 10)
        }
        .padding(.vertical, 2)
    }

    private var fraction: CGFloat {
        guard maxCount > 0 else { return 0 }
        return CGFloat(count) / CGFloat(maxCount)
    }
}
