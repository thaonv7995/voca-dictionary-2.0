import SwiftUI

/// Visual study progress overview with mastery ring, KPI summary cards, and level breakdown bars.
struct StatsView: View {
    @Environment(LocalLearnerStore.self) private var learner
    @AppStorage("voca.dictionary.language") private var languageRaw = CardLanguage.english.rawValue

    @State private var stats: StudyStats? = AppCache.loadStudyStats()
    @State private var cards: [Card] = AppCache.loadCards()
    @State private var due: DueResponse? = AppCache.loadDue()
    @State private var isLoading = false
    @State private var hasCompletedInitialLoad = false
    @State private var errorMessage: String?

    private let service = StudyService()

    private var language: CardLanguage {
        CardLanguage(rawValue: languageRaw) ?? .english
    }

    private var dueCount: Int {
        (due?.cards ?? []).filter { $0.card.cardLanguage == language }.count
    }

    var body: some View {
        ZStack {
            VocaThemeBackground()

            Group {
                if (isLoading || !hasCompletedInitialLoad) && stats == nil && cards.isEmpty {
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
        .task(id: "cache-sync") {
            for await _ in NotificationCenter.default.notifications(named: AppCache.cardsDidChangeNotification) {
                cards = AppCache.loadCards()
            }
        }
        .task(id: "study-sync") {
            for await _ in NotificationCenter.default.notifications(named: AppCache.studyDidChangeNotification) {
                due = AppCache.loadDue()
                stats = AppCache.loadStudyStats()
            }
        }
        .refreshable { await load() }
    }

    private var content: some View {
        let scopedCards = cards.filter { $0.cardLanguage == language }
        let total = scopedCards.count
        let counts = Dictionary(grouping: scopedCards) { CardLevel($0.level) ?? .new }
            .mapValues(\.count)
        let mastered = counts[.mastered] ?? 0
        let masteryFraction = total > 0 ? Double(mastered) / Double(total) : 0
        let favoritesCount = scopedCards.filter { learner.isFavorite($0.slug) }.count
        let maxCount = max(counts.values.max() ?? 0, 1)

        return ScrollView {
            VStack(spacing: 16) {
                CardLanguagePicker(selection: $languageRaw)

                if let errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Thử lại") { Task { await load() } }
                            .font(.footnote.weight(.semibold))
                    }
                    .brandCard(padding: 12, cornerRadius: 14)
                }

                HStack(spacing: 20) {
                    MasteryRing(fraction: masteryFraction, size: 96)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mức độ thành thạo")
                            .font(.headline)
                        Text("\(mastered)/\(total) thẻ đã thành thạo")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        VocaFlowLayout(spacing: 8) {
                            if learner.streakDays > 0 {
                                VocaPillBadge(text: "\(learner.streakDays) ngày liên tục", icon: "flame.fill", tint: .orange)
                            }
                            if let totalReviews = stats?.totalReviews {
                                VocaPillBadge(text: "\(totalReviews) tổng lượt ôn", icon: "checkmark.circle.fill")
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
                    StatTile(title: "Tổng thẻ", value: total, color: Brand.green, systemImage: "rectangle.stack.fill")
                    StatTile(title: "Cần ôn ngay", value: dueCount, color: .orange, systemImage: "clock.badge.exclamationmark.fill")
                    StatTile(title: "Đã ôn hôm nay", value: learner.reviewedTodayCount, color: .blue, systemImage: "checkmark.seal.fill")
                    StatTile(title: "Yêu thích", value: favoritesCount, color: .pink, systemImage: "star.fill")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Phân bố theo cấp độ")
                        .font(.headline)

                    ForEach(CardLevel.allCases) { level in
                        let count = counts[level] ?? 0
                        let pct = total == 0 ? 0 : Int((Double(count) / Double(total) * 100).rounded())
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

        async let statsResult: Result<StudyStats, Error> = {
            do { return .success(try await service.stats()) }
            catch { return .failure(error) }
        }()
        async let cardsResult: Result<[Card], Error> = {
            do { return .success(try await CardsService().list()) }
            catch { return .failure(error) }
        }()
        async let dueResult: Result<DueResponse, Error> = {
            do { return .success(try await service.due()) }
            catch { return .failure(error) }
        }()

        let (resolvedStats, resolvedCards, resolvedDue) = await (statsResult, cardsResult, dueResult)
        var firstError: Error?

        switch resolvedStats {
        case .success(let value): stats = value
        case .failure(let error):
            if !(error is CancellationError) { firstError = error }
        }
        switch resolvedCards {
        case .success(let value): cards = value
        case .failure(let error):
            if !(error is CancellationError), firstError == nil { firstError = error }
        }
        switch resolvedDue {
        case .success(let value): due = value
        case .failure(let error):
            if !(error is CancellationError), firstError == nil { firstError = error }
        }

        if let firstError {
            errorMessage = (firstError as? ApiError)?.message ?? firstError.localizedDescription
        }
        hasCompletedInitialLoad = true
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
