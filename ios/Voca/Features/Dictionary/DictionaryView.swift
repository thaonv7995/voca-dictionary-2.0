import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class DictionaryStore {
    private(set) var cards: [Card] = [] {
        didSet { rebuildIndexes() }
    }
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var cardsByLanguage: [CardLanguage: [Card]] = [:]
    private var topicsByLanguage: [CardLanguage: [String]] = [:]
    private var createdDatesBySlug: [String: Date] = [:]

    private let service = CardsService()

    private static let isoFormatter = ISO8601DateFormatter()
    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    init() {
        cards = service.cachedList()
        rebuildIndexes()
    }

    func cards(for language: CardLanguage) -> [Card] {
        cardsByLanguage[language] ?? []
    }

    func topics(for language: CardLanguage) -> [String] {
        topicsByLanguage[language] ?? []
    }

    func createdDate(for card: Card) -> Date? {
        createdDatesBySlug[card.slug]
    }

    private func rebuildIndexes() {
        var byLanguage: [CardLanguage: [Card]] = [:]
        var topicSets: [CardLanguage: Set<String>] = [:]
        var dates: [String: Date] = [:]
        dates.reserveCapacity(cards.count)

        for card in cards {
            let lang = card.cardLanguage
            byLanguage[lang, default: []].append(card)
            if let topic = card.topic, !topic.isEmpty {
                topicSets[lang, default: []].insert(topic)
            }
            if let raw = card.createdAt, !raw.isEmpty,
               let parsed = Self.isoFormatter.date(from: raw) ?? Self.isoFractionalFormatter.date(from: raw) {
                dates[card.slug] = parsed
            }
        }

        cardsByLanguage = byLanguage
        topicsByLanguage = topicSets.mapValues { $0.sorted() }
        createdDatesBySlug = dates
    }

    func syncFromCache() {
        let cached = service.cachedList()
        if cached != cards {
            cards = cached
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            cards = try await service.list()
            WidgetSync.publish(cards)
        } catch {
            errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        do {
            cards = try await service.list()
            WidgetSync.publish(cards)
            errorMessage = nil
        } catch {
            errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
        }
    }
}

enum DateFilter: String, CaseIterable, Identifiable {
    case all, today, week, month
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "Tất cả"
        case .today: return "Hôm nay"
        case .week: return "7 ngày"
        case .month: return "30 ngày"
        }
    }
}

enum DictionarySortOrder: String, CaseIterable, Identifiable {
    case newest, alphabetical, level
    var id: String { rawValue }
    var label: String {
        switch self {
        case .newest: return "Mới nhất"
        case .alphabetical: return "A → Z"
        case .level: return "Cấp độ"
        }
    }
}

/// Root of the Dictionary tab: searchable, filterable, sortable vocabulary cards with quick OCR & favorites.
struct DictionaryView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AppRouter.self) private var router
    @Environment(LocalLearnerStore.self) private var learner
    @AppStorage("voca.dictionary.language") private var languageRaw = CardLanguage.english.rawValue

    @State private var store = DictionaryStore()
    @State private var searchText = ""
    @State private var favoritesOnly = false
    @State private var levelFilter: CardLevel?
    @State private var topicFilter: String?
    @State private var dateFilter: DateFilter = .all
    @State private var sortOrder: DictionarySortOrder = .newest
    @State private var showCreate = false
    @State private var showScan = false
    @State private var showAudioCache = false
    @State private var focusedHanzi: FocusedHanzi?
    @State private var a4Card: Card?
    @State private var navigationPath = NavigationPath()
    @State private var prefetch = AudioPrefetchManager.shared

    private var language: CardLanguage {
        CardLanguage(rawValue: languageRaw) ?? .english
    }

    private var topics: [String] {
        store.topics(for: language)
    }

    private var hasActiveFilters: Bool {
        favoritesOnly || levelFilter != nil || topicFilter != nil || dateFilter != .all
    }

    private var languageCards: [Card] {
        store.cards(for: language)
    }

    private var filterAnimationKey: Int {
        var hasher = Hasher()
        hasher.combine(sortOrder)
        hasher.combine(favoritesOnly)
        hasher.combine(levelFilter?.rawValue)
        hasher.combine(topicFilter)
        hasher.combine(dateFilter)
        hasher.combine(searchText)
        return hasher.finalize()
    }

    private var filteredCards: [Card] {
        let query = normalized(searchText)
        let scoped = languageCards
        let matching = if !hasActiveFilters && query.isEmpty {
            scoped
        } else {
            scoped.filter { card in
                if favoritesOnly && !learner.isFavorite(card.slug) { return false }
                if let levelFilter, CardLevel(card.level) != levelFilter { return false }
                if let topicFilter, card.topic != topicFilter { return false }
                if !matchesDate(card) { return false }
                guard !query.isEmpty else { return true }
                let fields = [card.word, card.phonetic, card.meaningVi, card.meaningEn,
                              card.topic, card.tags?.joined(separator: " ")]
                return fields.compactMap { $0 }.contains { normalized($0).contains(query) }
            }
        }

        switch sortOrder {
        case .newest:
            return matching.sorted { lhs, rhs in
                switch (store.createdDate(for: lhs), store.createdDate(for: rhs)) {
                case let (l?, r?): return l > r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return false
                }
            }
        case .alphabetical:
            return matching.sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
        case .level:
            return matching.sorted { levelRank($0.level) < levelRank($1.level) }
        }
    }

    private func levelRank(_ raw: String?) -> Int {
        switch CardLevel(raw) {
        case .new: return 0
        case .learning: return 1
        case .known: return 2
        case .mastered: return 3
        case nil: return 4
        }
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matchesDate(_ card: Card) -> Bool {
        guard dateFilter != .all else { return true }
        guard let date = store.createdDate(for: card) else { return false }
        let now = Date()
        switch dateFilter {
        case .all: return true
        case .today: return Calendar.current.isDateInToday(date)
        case .week: return date >= now.addingTimeInterval(-7 * 86_400)
        case .month: return date >= now.addingTimeInterval(-30 * 86_400)
        }
    }

    private func resetFilters() {
        favoritesOnly = false
        levelFilter = nil
        topicFilter = nil
        dateFilter = .all
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                VocaThemeBackground()
                content
            }
            .navigationTitle("Kho từ")
            .searchable(text: $searchText, prompt: "Tìm từ, nghĩa, thẻ…")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { sortAndFilterMenu }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Haptics.impact(.light)
                        showAudioCache = true
                    } label: {
                        Image(systemName: prefetch.isRunning ? "arrow.down.circle.fill" : "arrow.down.circle")
                            .foregroundStyle(prefetch.isRunning ? Color.accentColor : Color.primary)
                            .symbolEffect(.pulse, isActive: prefetch.isRunning)
                    }
                    .accessibilityLabel("Cache từ & audio")

                    Button {
                        showScan = true
                    } label: {
                        Label("Quét ảnh", systemImage: "camera.viewfinder")
                    }
                    .accessibilityLabel("Quét ảnh")

                    Button {
                        showCreate = true
                    } label: {
                        Label("Tạo thẻ", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: Card.self) { card in
                CardDetailView(card: card, onDeleted: { Task { await store.load() } })
            }
            .sheet(isPresented: $showCreate) {
                CardCreateView { Task { await store.load() } }
            }
            .sheet(isPresented: $showScan) {
                ScanWordsView(language: language) { Task { await store.load() } }
            }
            .sheet(isPresented: $showAudioCache) {
                AudioCacheSheet(initialCards: store.cards)
            }
            .sheet(item: $focusedHanzi) { focus in
                HanziFocusSheet(word: focus.word)
                    .presentationDetents([.height(320), .medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $a4Card) { card in
                A4SheetView(card: card)
            }
            .onAppear {
                store.syncFromCache()
            }
            .task {
                if store.cards.isEmpty {
                    await store.load()
                } else {
                    await store.refresh()
                }
                openPendingCardIfAvailable()
            }
            .task(id: "cache-sync") {
                for await _ in NotificationCenter.default.notifications(named: AppCache.cardsDidChangeNotification) {
                    store.syncFromCache()
                }
            }
            .onChange(of: router.pendingCardSlug) { _, _ in
                openPendingCardIfAvailable()
            }
            .onChange(of: languageRaw) { _, _ in
                if !searchText.isEmpty { searchText = "" }
                if hasActiveFilters { resetFilters() }
            }
        }
    }

    private func openPendingCardIfAvailable() {
        guard let slug = router.pendingCardSlug,
              let card = store.cards.first(where: { $0.slug == slug })
        else { return }
        languageRaw = card.cardLanguage.rawValue
        navigationPath = NavigationPath()
        navigationPath.append(card)
        router.pendingCardSlug = nil
    }

    @ViewBuilder private var content: some View {
        if store.isLoading && store.cards.isEmpty {
            ProgressView("Đang tải…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = store.errorMessage, store.cards.isEmpty {
            ContentUnavailableView {
                Label("Không tải được", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage).foregroundStyle(.red)
            } actions: {
                Button("Thử lại") { Task { await store.load() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.green)
            }
        } else {
            VStack(spacing: 0) {
                languagePicker
                if languageCards.isEmpty {
                    ContentUnavailableView {
                        Label(
                            language == .chinese ? "Chưa có thẻ Hán ngữ" : "Chưa có thẻ English",
                            systemImage: "tray"
                        )
                    } description: {
                        Text("Nhấn + để tạo thẻ bằng AI hoặc quét ảnh từ vựng.")
                    } actions: {
                        Button("Tạo thẻ đầu tiên") { showCreate = true }
                            .buttonStyle(.borderedProminent)
                            .tint(Brand.green)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    filterBar
                    cardList
                }
            }
        }
    }

    private var languagePicker: some View {
        CardLanguagePicker(selection: $languageRaw)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 6)
    }

    @ViewBuilder private var cardList: some View {
        let visibleCards = filteredCards
        Group {
            if horizontalSizeClass == .regular {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 360, maximum: 540), spacing: 14, alignment: .top)
                        ],
                        alignment: .leading,
                        spacing: 14
                    ) {
                        ForEach(visibleCards) { card in
                            interactiveCardRow(card, padding: 15, cornerRadius: 18)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 1100)
                    .frame(maxWidth: .infinity)
                    .animation(.spring(response: 0.28, dampingFraction: 0.86), value: filterAnimationKey)
                }
                .id(language)
                .refreshable { await store.refresh() }
            } else {
                List {
                    ForEach(visibleCards) { card in
                        interactiveCardRow(card, padding: 14, cornerRadius: 16)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    Haptics.selection()
                                    learner.toggleFavorite(card.slug)
                                } label: {
                                    Label(
                                        learner.isFavorite(card.slug) ? "Bỏ thích" : "Yêu thích",
                                        systemImage: learner.isFavorite(card.slug) ? "star.slash.fill" : "star.fill"
                                    )
                                }
                                .tint(.orange)
                            }
                    }
                }
                .id(language)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .animation(.spring(response: 0.28, dampingFraction: 0.86), value: filterAnimationKey)
                .refreshable { await store.refresh() }
            }
        }
        .overlay {
            if visibleCards.isEmpty {
                if !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ContentUnavailableView {
                        Label("Không có thẻ phù hợp", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("Thử đổi hoặc xóa bộ lọc.")
                    } actions: {
                        if hasActiveFilters {
                            Button("Xóa bộ lọc") {
                                Haptics.selection()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                    resetFilters()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Brand.green)
                        }
                    }
                }
            }
        }
    }

    private func interactiveCardRow(_ card: Card, padding: CGFloat, cornerRadius: CGFloat) -> some View {
        CardRow(card: card, onWritingFocus: { tapped in
            Haptics.impact(.light)
            focusedHanzi = FocusedHanzi(word: tapped)
        }, onA4Tap: { tapped in
            Haptics.impact(.light)
            a4Card = tapped
        })
        .brandCard(padding: padding, cornerRadius: cornerRadius)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture {
            Haptics.impact(.light)
            navigationPath.append(card)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { navigationPath.append(card) }
        .contextMenu { cardContextMenu(card) }
    }

    @ViewBuilder
    private func cardContextMenu(_ card: Card) -> some View {
        Button {
            Task { try? await TTSService().speak(card.word, language: card.cardLanguage) }
        } label: {
            Label("Phát âm", systemImage: "speaker.wave.2")
        }

        Button {
            learner.toggleFavorite(card.slug)
        } label: {
            Label(
                learner.isFavorite(card.slug) ? "Bỏ khỏi Yêu thích" : "Đánh dấu Yêu thích",
                systemImage: learner.isFavorite(card.slug) ? "star.slash" : "star.fill"
            )
        }

        Button {
            UIPasteboard.general.string = card.word
        } label: {
            Label("Sao chép từ", systemImage: "doc.on.doc")
        }

        if card.isChinese {
            Button {
                a4Card = card
            } label: {
                Label("Phiếu học A4", systemImage: "doc.text")
            }
        }
    }

    // MARK: - Filters & Sort

    private var sortAndFilterMenu: some View {
        Menu {
            Picker("Sắp xếp", selection: $sortOrder) {
                ForEach(DictionarySortOrder.allCases) { order in
                    Text(order.label).tag(order)
                }
            }
            Divider()
            Picker("Cấp độ", selection: $levelFilter) {
                Text("Tất cả cấp độ").tag(CardLevel?.none)
                ForEach(CardLevel.allCases) { level in
                    Text(level.label).tag(CardLevel?.some(level))
                }
            }
        } label: {
            Label(
                "Sắp xếp & Lọc",
                systemImage: hasActiveFilters || sortOrder != .newest
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "arrow.up.arrow.down.circle"
            )
        }
        .tint(Brand.green)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("\(filteredCards.count)/\(languageCards.count)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill), in: Capsule())

                Button {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { favoritesOnly.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: favoritesOnly ? "star.fill" : "star")
                            .font(.caption2)
                            .symbolEffect(.bounce, value: favoritesOnly)
                        Text("Yêu thích")
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .foregroundStyle(favoritesOnly ? Color.white : .orange)
                    .background(favoritesOnly ? Color.orange : Color.orange.opacity(0.14), in: Capsule())
                }
                .buttonStyle(PressableScaleStyle(scale: 0.94))

                levelPill
                if !topics.isEmpty { topicPill }
                datePill

                if hasActiveFilters {
                    Button {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { resetFilters() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Xóa lọc")
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .foregroundStyle(.secondary)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                    .buttonStyle(PressableScaleStyle(scale: 0.94))
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var levelPill: some View {
        Menu {
            Picker("Cấp độ", selection: $levelFilter) {
                Text("Tất cả").tag(CardLevel?.none)
                ForEach(CardLevel.allCases) { level in
                    Text(level.label).tag(CardLevel?.some(level))
                }
            }
        } label: {
            pillLabel(levelFilter?.label ?? "Cấp độ", active: levelFilter != nil)
        }
    }

    private var topicPill: some View {
        Menu {
            Picker("Chủ đề", selection: $topicFilter) {
                Text("Tất cả").tag(String?.none)
                ForEach(topics, id: \.self) { topic in
                    Text(topic).tag(String?.some(topic))
                }
            }
        } label: {
            pillLabel(topicFilter ?? "Chủ đề", active: topicFilter != nil)
        }
    }

    private var datePill: some View {
        Menu {
            Picker("Ngày tạo", selection: $dateFilter) {
                ForEach(DateFilter.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
        } label: {
            pillLabel(dateFilter == .all ? "Ngày tạo" : dateFilter.label,
                      active: dateFilter != .all)
        }
    }

    private func pillLabel(_ title: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Image(systemName: "chevron.down").font(.caption2)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundStyle(active ? Color.white : Brand.green)
        .background(active ? Brand.green : Brand.greenSoft, in: Capsule())
    }
}

/// A single row in the dictionary list. Every control and chevron lives strictly inside the card container.
private struct CardRow: View {
    @Environment(LocalLearnerStore.self) private var learner
    let card: Card
    let onWritingFocus: (String) -> Void
    var onA4Tap: ((Card) -> Void)? = nil

    var body: some View {
        if card.isChinese {
            chineseBody
        } else {
            englishBody
        }
    }

    private var chineseBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(card.word)
                            .font(VocaTypography.hanziFont(size: 25, weight: .bold, isCalligraphic: ThemeStore.shared.hanziCalligraphic))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if learner.isFavorite(card.slug) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    if let pinyin = card.phonetic, !pinyin.isEmpty {
                        Text(pinyin)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Brand.green)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    if let level = CardLevel(card.level) {
                        LevelBadge(level: level)
                    }
                    PronounceButton(
                        text: card.word,
                        language: card.cardLanguage,
                        size: 30,
                        font: .footnote,
                        tintedCapsule: true
                    )
                    if let onA4Tap {
                        Button {
                            onA4Tap(card)
                        } label: {
                            Image(systemName: "doc.text")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Brand.green)
                                .frame(width: 30, height: 30)
                                .background(Brand.greenSoft, in: Circle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Phiếu học A4")
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .fixedSize()
            }

            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    if let meaningVi = card.meaningVi, !meaningVi.isEmpty {
                        Text(meaningVi)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if let topic = card.topic, !topic.isEmpty {
                        Badge(text: topic)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HanziWritingView(
                    word: card.word,
                    compact: true,
                    onCharacterFocus: onWritingFocus
                )
            }
        }
    }

    private var englishBody: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(card.word)
                        .font(.headline)
                        .layoutPriority(1)
                    if let phonetic = card.phonetic, !phonetic.isEmpty {
                        Text(phonetic)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if learner.isFavorite(card.slug) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                if let meaningVi = card.meaningVi, !meaningVi.isEmpty {
                    Text(meaningVi)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let topic = card.topic, !topic.isEmpty {
                    Badge(text: topic)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if let level = CardLevel(card.level) {
                    LevelBadge(level: level)
                }
                PronounceButton(
                    text: card.word,
                    language: card.cardLanguage,
                    size: 30,
                    font: .footnote,
                    tintedCapsule: true
                )
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .fixedSize()
        }
    }
}

private struct FocusedHanzi: Identifiable {
    let id = UUID()
    let word: String
}

/// Focused single-character Hanzi zoom popup (tap the character to replay stroke order).
private struct HanziFocusSheet: View {
    let word: String

    var body: some View {
        ZStack {
            VocaThemeBackground()
            HanziWritingView(word: word, displayOnly: true)
                .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LevelBadge: View {
    let level: CardLevel

    var body: some View {
        Text(level.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(level.tint.opacity(0.15), in: Capsule())
            .foregroundStyle(level.tint)
    }
}

extension CardLevel {
    var tint: Color { Brand.levelColor(rawValue) }
}
