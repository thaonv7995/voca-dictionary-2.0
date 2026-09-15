import Observation
import SwiftUI

/// Loads and holds the user's vocabulary cards for the Dictionary tab.
@MainActor
@Observable
final class DictionaryStore {
    private(set) var cards: [Card] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let service = CardsService()

    init() {
        cards = service.cachedList()
    }

    /// Full load with the loading spinner (used on first appear and retry).
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

    /// Silent reload for pull-to-refresh (no full-screen spinner).
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

/// Created-date filter options for the Dictionary list.
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

/// Root of the Dictionary tab: a searchable, filterable list of vocabulary cards.
struct DictionaryView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AppRouter.self) private var router
    @AppStorage("voca.dictionary.language") private var languageRaw = CardLanguage.english.rawValue
    @State private var store = DictionaryStore()
    @State private var searchText = ""
    @State private var levelFilter: CardLevel?
    @State private var topicFilter: String?
    @State private var dateFilter: DateFilter = .all
    @State private var showCreate = false
    @State private var focusedHanzi: FocusedHanzi?
    @State private var navigationPath = NavigationPath()

    private var language: CardLanguage {
        CardLanguage(rawValue: languageRaw) ?? .english
    }

    // MARK: - Date parsing (null-safe)

    /// Standard ISO-8601 (`2026-08-15T10:20:30Z`).
    private static let isoFormatter = ISO8601DateFormatter()
    /// Fallback for timestamps that carry fractional seconds.
    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return isoFormatter.date(from: raw) ?? isoFractionalFormatter.date(from: raw)
    }

    // MARK: - Derived data

    /// Distinct, sorted topics present in the loaded cards.
    private var topics: [String] {
        let all = store.cards.filter { $0.cardLanguage == language }
            .compactMap { $0.topic }.filter { !$0.isEmpty }
        return Array(Set(all)).sorted()
    }

    private var hasActiveFilters: Bool {
        levelFilter != nil || topicFilter != nil || dateFilter != .all
    }

    private var filteredCards: [Card] {
        let query = normalized(searchText)
        return store.cards.filter { card in
            if card.cardLanguage != language { return false }
            if let levelFilter, CardLevel(card.level) != levelFilter { return false }
            if let topicFilter, card.topic != topicFilter { return false }
            if !matchesDate(card) { return false }
            guard !query.isEmpty else { return true }
            let fields = [card.word, card.phonetic, card.meaningVi, card.meaningEn,
                          card.topic, card.tags?.joined(separator: " ")]
            return fields.compactMap { $0 }.contains { normalized($0).contains(query) }
        }
    }

    private var languageCards: [Card] {
        store.cards.filter { $0.cardLanguage == language }
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matchesDate(_ card: Card) -> Bool {
        guard dateFilter != .all else { return true }
        // With a date filter active, cards without a parseable date are excluded.
        guard let date = Self.parseDate(card.createdAt) else { return false }
        let now = Date()
        switch dateFilter {
        case .all: return true
        case .today: return Calendar.current.isDateInToday(date)
        case .week: return date >= now.addingTimeInterval(-7 * 86_400)
        case .month: return date >= now.addingTimeInterval(-30 * 86_400)
        }
    }

    private func resetFilters() {
        levelFilter = nil
        topicFilter = nil
        dateFilter = .all
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationTitle("Kho từ")
                .searchable(text: $searchText, prompt: "Tìm từ, nghĩa, thẻ…")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { filterMenu }
                    ToolbarItem(placement: .primaryAction) {
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
                .sheet(item: $focusedHanzi) { focus in
                    HanziFocusSheet(word: focus.word)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
                .task {
                    if store.cards.isEmpty { await store.load() }
                    openPendingCardIfAvailable()
                }
                .onChange(of: router.pendingCardSlug) { _, _ in
                    openPendingCardIfAvailable()
                }
                .onChange(of: languageRaw) { _, _ in
                    searchText = ""
                    resetFilters()
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
                    ContentUnavailableView(
                        language == .chinese ? "Chưa có thẻ Hán ngữ" : "Chưa có thẻ English",
                        systemImage: "tray",
                        description: Text("Nhấn + để tạo thẻ từ vựng đầu tiên."))
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
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder private var cardList: some View {
        Group {
            if horizontalSizeClass == .regular {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 360, maximum: 540), spacing: 16, alignment: .top)
                        ],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        ForEach(filteredCards) { card in
                            CardRow(card: card) { character in
                                focusedHanzi = FocusedHanzi(word: character)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                            .background(
                                Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .onTapGesture { navigationPath.append(card) }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 1100)
                    .frame(maxWidth: .infinity)
                }
                .background(Color(.systemGroupedBackground))
                .refreshable { await store.refresh() }
            } else {
                List {
                    ForEach(filteredCards) { card in
                        NavigationLink(value: card) {
                            CardRow(card: card) { character in
                                focusedHanzi = FocusedHanzi(word: character)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await store.refresh() }
            }
        }
        .overlay {
            if filteredCards.isEmpty {
                if !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ContentUnavailableView(
                        "Không có thẻ phù hợp",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Thử đổi hoặc xóa bộ lọc."))
                }
            }
        }
    }

    // MARK: - Filters

    /// Level filter kept in the toolbar (unchanged behaviour).
    private var filterMenu: some View {
        Menu {
            Picker("Cấp độ", selection: $levelFilter) {
                Text("Tất cả").tag(CardLevel?.none)
                ForEach(CardLevel.allCases) { level in
                    Text(level.label).tag(CardLevel?.some(level))
                }
            }
        } label: {
            Label("Lọc cấp độ",
                  systemImage: levelFilter == nil
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill")
        }
        .tint(Brand.green)
    }

    /// Compact, scrollable row of filter pills under the search bar.
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Image(systemName: hasActiveFilters
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .foregroundStyle(hasActiveFilters ? Brand.green : .secondary)
                    .accessibilityLabel(hasActiveFilters ? "Đang lọc" : "Bộ lọc")

                levelPill
                if !topics.isEmpty { topicPill }
                datePill

                if hasActiveFilters {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { resetFilters() }
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
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
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

/// A single row in the dictionary list.
private struct CardRow: View {
    let card: Card
    let onWritingFocus: (String) -> Void

    var body: some View {
        HStack(alignment: card.isChinese ? .top : .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(card.word)
                        .font(card.isChinese ? .title2.bold() : .headline)
                    if !card.isChinese, let phonetic = card.phonetic {
                        Text(phonetic)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if card.isChinese, let pinyin = card.phonetic {
                    Text(pinyin)
                        .font(.subheadline)
                        .foregroundStyle(Brand.green)
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

            if card.isChinese {
                HanziWritingView(word: card.word, compact: true,
                                 onCharacterFocus: onWritingFocus)
                VStack(spacing: 5) {
                    PronounceButton(text: card.word, language: card.cardLanguage)
                    if let level = CardLevel(card.level) { LevelBadge(level: level) }
                }
            } else {
                PronounceButton(text: card.word, language: card.cardLanguage)
                if let level = CardLevel(card.level) { LevelBadge(level: level) }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct FocusedHanzi: Identifiable {
    let id = UUID()
    let word: String
}

private struct HanziFocusSheet: View {
    let word: String

    var body: some View {
        HanziWritingView(word: word, displayOnly: true)
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A small coloured badge showing a card's learning level.
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
    /// Accent colour used by badges and pickers in the Dictionary feature.
    var tint: Color {
        switch self {
        case .new: return .blue
        case .learning: return .orange
        case .known: return Brand.green
        case .mastered: return .purple
        }
    }
}
