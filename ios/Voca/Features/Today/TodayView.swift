import Observation
import SwiftUI

/// The "Hôm nay" (Today) dashboard tab — personalised daily snapshot, quick actions, and due review launch.
struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AuthStore.self) private var auth
    @Environment(LocalLearnerStore.self) private var learner
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("voca.dictionary.language") private var languageRaw = CardLanguage.english.rawValue

    @State private var model = TodayModel()
    @State private var showSession = false
    @State private var showBrowseSession = false
    @State private var showCreateSheet = false
    @State private var showScanSheet = false
    @State private var dayRefreshToken = UUID()

    private var language: CardLanguage {
        CardLanguage(rawValue: languageRaw) ?? .english
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VocaThemeBackground()

                ScrollView {
                    dashboardContent
                }
            }
            .navigationTitle("Hôm nay")
            .refreshable { await model.load() }
            .onAppear {
                model.syncFromCache()
                if model.shouldRefreshOnAppear {
                    Task { await model.load() }
                }
            }
            .task { await model.load() }
            .task(id: "cache-sync") {
                for await _ in NotificationCenter.default.notifications(named: AppCache.cardsDidChangeNotification) {
                    model.syncFromCache()
                }
            }
            .task(id: "study-sync") {
                for await _ in NotificationCenter.default.notifications(named: AppCache.studyDidChangeNotification) {
                    model.syncFromCache()
                }
            }
            .task(id: "day-change") {
                for await _ in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) {
                    dayRefreshToken = UUID()
                    await model.load()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    dayRefreshToken = UUID()
                    model.syncFromCache()
                    if model.shouldRefreshOnAppear {
                        Task { await model.load() }
                    }
                }
            }
            .fullScreenCover(isPresented: $showSession, onDismiss: {
                Task { await model.load() }
            }) {
                ReviewSessionView(items: model.dueItems(for: language))
            }
            .fullScreenCover(isPresented: $showBrowseSession) {
                ReviewSessionView(
                    browseCards: model.cards(for: language),
                    title: "Thẻ lật · \(language.label)"
                )
            }
            .sheet(isPresented: $showCreateSheet) {
                CardCreateView { Task { await model.load() } }
            }
            .sheet(isPresented: $showScanSheet) {
                ScanWordsView(language: language) { Task { await model.load() } }
            }
        }
    }

    @ViewBuilder private var dashboardContent: some View {
        if horizontalSizeClass == .regular {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .bottom, spacing: 28) {
                    greeting
                    CardLanguagePicker(selection: $languageRaw)
                        .frame(width: 300)
                }

                if let errorMessage = model.errorMessage {
                    errorBanner(errorMessage)
                }

                quickActionsBar

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 20) {
                            dueHero
                            masterySection
                        }
                        .frame(minWidth: 320, maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 20) {
                            statsSection
                            recentSection
                        }
                        .frame(minWidth: 320, maxWidth: .infinity)
                    }

                    VStack(spacing: 20) {
                        dueHero
                        masterySection
                        statsSection
                        recentSection
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                greeting
                CardLanguagePicker(selection: $languageRaw)

                if let errorMessage = model.errorMessage {
                    errorBanner(errorMessage)
                }

                dueHero
                quickActionsBar
                masterySection
                statsSection
                recentSection
            }
            .padding()
        }
    }

    // MARK: - Greeting

    @ViewBuilder private var greeting: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeGreeting)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(greetingName)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            VocaFlowLayout(spacing: 8) {
                if learner.streakDays > 0 {
                    VocaPillBadge(
                        text: "\(learner.streakDays) ngày liên tục",
                        icon: "flame.fill",
                        tint: .orange
                    )
                }
                VocaPillBadge(
                    text: "Hôm nay: \(learner.reviewedTodayCount)/\(learner.dailyGoal) thẻ",
                    icon: learner.reviewedTodayCount >= learner.dailyGoal ? "checkmark.seal.fill" : "target",
                    tint: learner.reviewedTodayCount >= learner.dailyGoal ? Brand.semanticSuccess : Brand.green
                )
            }
            .id(dayRefreshToken)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Chào buổi sáng,"
        case 12..<18: return "Chào buổi chiều,"
        default: return "Chào buổi tối,"
        }
    }

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
        let dueCount = model.dueCount(for: language)

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                VocaIconBadge(
                    systemImage: dueCount > 0 ? "flame.fill" : "checkmark.seal.fill",
                    size: 56,
                    iconSize: 25
                )

                VStack(alignment: .leading, spacing: 2) {
                    if model.isLoading && model.due == nil {
                        ProgressView()
                            .frame(height: 44, alignment: .leading)
                    } else {
                        Text("\(dueCount)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Brand.green)
                            .contentTransition(.numericText())
                    }
                    Text("thẻ cần ôn hôm nay")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if model.totalCards(for: language) > 0 {
                    VocaPillBadge(
                        text: "\(model.totalCards(for: language)) thẻ",
                        icon: "rectangle.stack.fill"
                    )
                }
            }

            if dueCount == 0 && !(model.isLoading && model.due == nil) {
                Text("Tuyệt vời! Bạn đã ôn hết thẻ đến hạn hôm nay. 🎉")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if dueCount > 0 {
                Button {
                    Haptics.impact(.medium)
                    showSession = true
                } label: {
                    Label("Ôn tập ngay", systemImage: "play.fill")
                }
                .buttonStyle(BrandCTAButtonStyle())
            } else {
                let hasCards = !model.cards(for: language).isEmpty
                Button {
                    Haptics.impact(.light)
                    if !hasCards {
                        showCreateSheet = true
                    } else {
                        showBrowseSession = true
                    }
                } label: {
                    Label(
                        hasCards ? "Luyện thẻ lật tự do" : "Thêm từ đầu tiên",
                        systemImage: hasCards ? "sparkles.rectangle.stack.fill" : "plus"
                    )
                }
                .buttonStyle(BrandCTAButtonStyle())
                .disabled(model.isLoading && model.due == nil && !hasCards)
            }
        }
        .brandHeroCard(padding: 18, cornerRadius: 22)
    }

    // MARK: - Quick Actions

    private var quickActionsBar: some View {
        HStack(spacing: 10) {
            quickActionTile(
                title: "Tạo từ AI",
                icon: "wand.and.stars",
                tint: Brand.green
            ) {
                Haptics.selection()
                showCreateSheet = true
            }

            quickActionTile(
                title: "Quét ảnh",
                icon: "camera.viewfinder",
                tint: .indigo
            ) {
                Haptics.selection()
                showScanSheet = true
            }

            quickActionTile(
                title: "Thẻ lật",
                icon: "rectangle.portrait.on.rectangle.portrait.angled.fill",
                tint: .orange
            ) {
                Haptics.selection()
                showBrowseSession = true
            }
            .disabled(model.cards(for: language).isEmpty)
            .opacity(model.cards(for: language).isEmpty ? 0.5 : 1)
        }
    }

    private func quickActionTile(
        title: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                VocaIconBadge(systemImage: icon, tint: tint, size: 38, iconSize: 17)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .brandCard(padding: 12, cornerRadius: 16)
        }
        .buttonStyle(PressableScaleStyle(scale: 0.96))
    }

    // MARK: - Mastery

    @ViewBuilder private var masterySection: some View {
        let total = model.totalCards(for: language)

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                MasteryRing(fraction: model.masteryFraction(for: language))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tiến độ thành thạo")
                        .font(.headline)
                    Text("\(model.count(for: .mastered, language: language))/\(total) thẻ đã thành thạo")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            if total > 0 {
                let segments = CardLevel.allCases.compactMap { level -> (level: CardLevel, count: Int)? in
                    let c = model.count(for: level, language: language)
                    return c > 0 ? (level, c) : nil
                }
                GeometryReader { geo in
                    let widths = Self.normalizedSegmentWidths(
                        counts: segments.map(\.count),
                        totalWidth: geo.size.width,
                        spacing: 2,
                        minSegmentWidth: 8
                    )
                    HStack(spacing: 2) {
                        ForEach(Array(segments.enumerated()), id: \.element.level) { idx, seg in
                            Capsule()
                                .fill(Brand.levelColor(seg.level.rawValue))
                                .frame(width: widths[idx])
                        }
                    }
                }
                .frame(height: 8)
            }
        }
        .brandCard()
    }

    // MARK: - Stats

    @ViewBuilder private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thống kê")
                .font(.headline)

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
                        NavigationLink {
                            CardDetailView(card: card, onDeleted: { Task { await model.load() } })
                                .id(card.slug)
                        } label: {
                            RecentCardRow(card: card)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(PressableScaleStyle(scale: 0.985))

                        if index < recent.count - 1 {
                            Divider().opacity(0.6)
                        }
                    }
                }
                .brandCard(padding: 16, cornerRadius: 18)
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

    private static func normalizedSegmentWidths(
        counts: [Int],
        totalWidth: CGFloat,
        spacing: CGFloat,
        minSegmentWidth: CGFloat
    ) -> [CGFloat] {
        guard !counts.isEmpty else { return [] }
        let usable = max(0, totalWidth - spacing * CGFloat(max(0, counts.count - 1)))
        let sum = CGFloat(counts.reduce(0, +))
        guard sum > 0, usable > 0 else { return Array(repeating: 0, count: counts.count) }
        let effectiveMin = min(minSegmentWidth, usable / CGFloat(counts.count))
        var widths = counts.map { usable * CGFloat($0) / sum }
        var clamped = Set<Int>()
        var deficit: CGFloat = 0
        for i in widths.indices where widths[i] < effectiveMin {
            deficit += effectiveMin - widths[i]
            widths[i] = effectiveMin
            clamped.insert(i)
        }
        if deficit > 0 {
            let flexibleIndices = widths.indices.filter { !clamped.contains($0) }
            let flexTotal = flexibleIndices.reduce(CGFloat(0)) { $0 + max(0, widths[$1] - effectiveMin) }
            if flexTotal > 0 {
                for i in flexibleIndices {
                    let room = max(0, widths[i] - effectiveMin)
                    widths[i] -= deficit * (room / flexTotal)
                }
            }
        }
        return widths
    }
}

// MARK: - View model

@Observable
final class TodayModel {
    var due: DueResponse?
    var cards: [Card] = [] {
        didSet { rebuildLanguageIndex() }
    }
    var isLoading = false
    var errorMessage: String?

    private var cardsByLanguage: [CardLanguage: [Card]] = [:]
    private var levelCountsByLanguage: [CardLanguage: [CardLevel: Int]] = [:]
    private var recentByLanguage: [CardLanguage: [Card]] = [:]

    private let studyService = StudyService()
    private let cardsService = CardsService()
    @ObservationIgnored private var lastLoadedAt: Date?

    var shouldRefreshOnAppear: Bool {
        guard !isLoading else { return false }
        guard let lastLoadedAt else { return true }
        return Date().timeIntervalSince(lastLoadedAt) > 20
    }

    init() {
        due = studyService.cachedDue()
        cards = cardsService.cachedList()
        rebuildLanguageIndex()
    }

    @MainActor
    func syncFromCache() {
        let cachedCards = cardsService.cachedList()
        if cachedCards != cards {
            cards = cachedCards
        }
        let cachedDue = studyService.cachedDue()
        if due?.cards.map(\.id) != cachedDue?.cards.map(\.id) || due?.count != cachedDue?.count {
            due = cachedDue
        }
    }

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil

        async let dueResult: Result<DueResponse, Error> = {
            do { return .success(try await studyService.due()) }
            catch { return .failure(error) }
        }()
        async let cardsResult: Result<[Card], Error> = {
            do { return .success(try await cardsService.list()) }
            catch { return .failure(error) }
        }()

        let (resolvedDue, resolvedCards) = await (dueResult, cardsResult)
        var firstError: Error?

        switch resolvedDue {
        case .success(let loadedDue):
            due = loadedDue
        case .failure(let error):
            if !(error is CancellationError) { firstError = error }
        }

        switch resolvedCards {
        case .success(let loadedCards):
            cards = loadedCards
            WidgetSync.publish(loadedCards)
        case .failure(let error):
            if !(error is CancellationError), firstError == nil { firstError = error }
        }

        if let firstError {
            errorMessage = (firstError as? ApiError)?.message ?? firstError.localizedDescription
        } else {
            lastLoadedAt = Date()
        }
        isLoading = false
    }

    private func rebuildLanguageIndex() {
        var byLanguage: [CardLanguage: [Card]] = [:]
        var levelCounts: [CardLanguage: [CardLevel: Int]] = [:]
        var dates: [String: Date] = [:]

        for card in cards {
            let lang = card.cardLanguage
            byLanguage[lang, default: []].append(card)
            if let lvl = CardLevel(card.level) {
                levelCounts[lang, default: [:]][lvl, default: 0] += 1
            }
            if let parsed = Self.parseDate(card.createdAt) {
                dates[card.slug] = parsed
            }
        }

        var recents: [CardLanguage: [Card]] = [:]
        for (lang, langCards) in byLanguage {
            let sorted = langCards.sorted { lhs, rhs in
                switch (dates[lhs.slug], dates[rhs.slug]) {
                case let (l?, r?): return l > r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return false
                }
            }
            recents[lang] = Array(sorted.prefix(5))
        }

        cardsByLanguage = byLanguage
        levelCountsByLanguage = levelCounts
        recentByLanguage = recents
    }

    func cards(for language: CardLanguage) -> [Card] {
        cardsByLanguage[language] ?? []
    }

    func dueItems(for language: CardLanguage) -> [DueItem] {
        (due?.cards ?? []).filter { $0.card.cardLanguage == language }
    }

    func dueCount(for language: CardLanguage) -> Int { dueItems(for: language).count }

    func totalCards(for language: CardLanguage) -> Int {
        cardsByLanguage[language]?.count ?? 0
    }

    func count(for level: CardLevel, language: CardLanguage) -> Int {
        levelCountsByLanguage[language]?[level] ?? 0
    }

    func masteryFraction(for language: CardLanguage) -> Double {
        let total = totalCards(for: language)
        guard total > 0 else { return 0 }
        return Double(count(for: .mastered, language: language)) / Double(total)
    }

    func recentCards(for language: CardLanguage) -> [Card] {
        recentByLanguage[language] ?? []
    }

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
