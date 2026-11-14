import Observation
import SwiftUI

/// Landing screen for the Study (FSRS + Free Flashcard Browse) tab.
struct StudyRootView: View {
    @Environment(ThemeStore.self) private var theme
    @Environment(LocalLearnerStore.self) private var learner
    @AppStorage("voca.dictionary.language") private var languageRaw = CardLanguage.english.rawValue

    @State private var model = StudyModel()
    @State private var showReviewSession = false
    @State private var browseScope: BrowseScope = .all
    @State private var browseSheetCards: [Card]?

    private enum BrowseScope: String, CaseIterable, Identifiable {
        case all, learning, favorites
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "Tất cả"
            case .learning: return "Chưa vững"
            case .favorites: return "Yêu thích ★"
            }
        }
    }

    private var language: CardLanguage {
        CardLanguage(rawValue: languageRaw) ?? .english
    }

    private var dueItems: [DueItem] {
        (model.due?.cards ?? []).filter { $0.card.cardLanguage == language }
    }

    private var languageCards: [Card] {
        model.cards.filter { $0.cardLanguage == language }
    }

    private var scopedBrowseCards: [Card] {
        switch browseScope {
        case .all:
            return languageCards
        case .learning:
            return languageCards.filter {
                let lvl = CardLevel($0.level)
                return lvl == .new || lvl == .learning || lvl == nil
            }
        case .favorites:
            return languageCards.filter { learner.isFavorite($0.slug) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VocaThemeBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        CardLanguagePicker(selection: $languageRaw)

                        if let errorMessage = model.errorMessage {
                            errorBanner(errorMessage)
                        }

                        dueHeroCard
                        freeBrowseCard
                        preferencesCard
                        statsCard
                    }
                    .padding()
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Học tập")
            .refreshable { await model.load() }
            .onAppear { model.syncFromCache() }
            .task { await model.load() }
            .task {
                for await _ in NotificationCenter.default.notifications(named: AppCache.cardsDidChangeNotification) {
                    model.syncFromCache()
                }
            }
            .fullScreenCover(isPresented: $showReviewSession, onDismiss: {
                Task { await model.load() }
            }) {
                ReviewSessionView(items: dueItems)
            }
            .fullScreenCover(item: Binding(
                get: { browseSheetCards.map { BrowseWrapper(cards: $0, title: "Thẻ lật · \(browseScope.label)") } },
                set: { if $0 == nil { browseSheetCards = nil } }
            )) { wrapper in
                ReviewSessionView(browseCards: wrapper.cards, title: wrapper.title)
            }
        }
    }

    // MARK: - Hero FSRS Card

    @ViewBuilder private var dueHeroCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                VocaIconBadge(systemImage: "rectangle.stack.fill", size: 52, iconSize: 23)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Ôn tập theo lịch FSRS")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if model.isLoading && model.due == nil {
                        ProgressView().padding(.vertical, 4)
                    } else {
                        Text(dueCount == 0 ? "Không có thẻ đến hạn" : "\(dueCount) thẻ cần ôn")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                    }
                }

                Spacer(minLength: 0)

                if learner.streakDays > 0 {
                    VocaPillBadge(text: "\(learner.streakDays) ngày", icon: "flame.fill", tint: .orange)
                }
            }

            if dueCount == 0 && !(model.isLoading && model.due == nil) {
                Text("Tuyệt vời! Bạn đã ôn hết thẻ đến hạn hôm nay. Có thể luyện thêm bằng Thẻ lật tự do bên dưới.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Chạm để lật mặt sau và vuốt trái/phải để chấm mức độ nhớ.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Haptics.impact(.medium)
                showReviewSession = true
            } label: {
                HStack(spacing: 8) {
                    if model.isLoading && model.due != nil {
                        ProgressView().tint(.white)
                    }
                    Label("Bắt đầu ôn tập", systemImage: "play.fill")
                }
            }
            .buttonStyle(BrandCTAButtonStyle())
            .disabled(dueCount == 0 || (model.isLoading && model.due == nil))
        }
        .brandHeroCard(padding: 18, cornerRadius: 22)
    }

    // MARK: - Free Browse Deck

    @ViewBuilder private var freeBrowseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                VocaIconBadge(systemImage: "sparkles.rectangle.stack.fill", tint: .indigo, size: 38, iconSize: 17)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thẻ lật tự do")
                        .font(.headline)
                    Text("Luyện bất kỳ lúc nào mà không ảnh hưởng lịch FSRS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Picker("Bộ thẻ", selection: $browseScope) {
                ForEach(BrowseScope.allCases) { scope in
                    Text(scope.label).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            Button {
                Haptics.impact(.light)
                browseSheetCards = scopedBrowseCards
            } label: {
                HStack {
                    Label("Mở bộ thẻ (\(scopedBrowseCards.count))", systemImage: "rectangle.portrait.on.rectangle.portrait.angled.fill")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(scopedBrowseCards.isEmpty ? .secondary : Brand.green)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Brand.greenSoft.opacity(scopedBrowseCards.isEmpty ? 0.35 : 1),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(scopedBrowseCards.isEmpty)
        }
        .brandCard()
    }

    // MARK: - Study UX Settings Card

    @ViewBuilder private var preferencesCard: some View {
        @Bindable var bindableTheme = theme

        VStack(alignment: .leading, spacing: 12) {
            Text("Tùy chọn phiên học")
                .font(.headline)

            Toggle(isOn: $bindableTheme.reverseFlashcardMode) {
                Label("Đảo mặt thẻ (Nghĩa → Từ)", systemImage: "arrow.left.arrow.right")
                    .font(.subheadline)
            }
            .tint(Brand.green)

            Divider().opacity(0.6)

            Toggle(isOn: $bindableTheme.autoSpeakFlashcard) {
                Label("Tự động phát âm khi mở thẻ", systemImage: "speaker.wave.2")
                    .font(.subheadline)
            }
            .tint(Brand.green)

            Divider().opacity(0.6)

            Toggle(isOn: $bindableTheme.hapticsEnabled) {
                Label("Phản hồi rung (Haptics)", systemImage: "iphone.radiowaves.left.and.right")
                    .font(.subheadline)
            }
            .tint(Brand.green)
        }
        .brandCard()
    }

    // MARK: - Stats Link

    @ViewBuilder private var statsCard: some View {
        NavigationLink {
            StatsView()
        } label: {
            HStack(spacing: 12) {
                VocaIconBadge(systemImage: "chart.bar.xaxis", size: 38, iconSize: 17)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Xem thống kê chi tiết")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(languageCards.count) thẻ · Hôm nay đã ôn \(learner.reviewedTodayCount)/\(learner.dailyGoal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .brandCard()
        }
        .buttonStyle(PressableScaleStyle(scale: 0.985))
    }

    @ViewBuilder private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Button("Thử lại") { Task { await model.load() } }
                .font(.subheadline.weight(.semibold))
        }
        .brandCard()
    }

    private var dueCount: Int { dueItems.count }

    private struct BrowseWrapper: Identifiable {
        let id = UUID()
        let cards: [Card]
        let title: String
    }
}

/// View-model backing the Study landing screen.
@Observable
final class StudyModel {
    var stats: StudyStats?
    var due: DueResponse?
    var cards: [Card] = []
    var isLoading = false
    var errorMessage: String?

    private let service = StudyService()
    private let cardsService = CardsService()

    init() {
        stats = service.cachedStats()
        due = service.cachedDue()
        cards = cardsService.cachedList()
    }

    @MainActor
    func syncFromCache() {
        let cachedCards = cardsService.cachedList()
        if cachedCards != cards {
            cards = cachedCards
        }
        if let cachedDue = service.cachedDue(),
           due?.cards.map(\.id) != cachedDue.cards.map(\.id) || due?.count != cachedDue.count {
            due = cachedDue
        }
        if let cachedStats = service.cachedStats(), stats == nil {
            stats = cachedStats
        }
    }

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let statsCall = service.stats()
            async let dueCall = service.due()
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
}
