import Observation
import SwiftUI
import UIKit

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
    @State private var focusedHanzi: FocusedHanzi?
    @State private var a4Card: Card?
    @State private var navigationPath = NavigationPath()

    private var language: CardLanguage {
        CardLanguage(rawValue: languageRaw) ?? .english
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

    private var topics: [String] {
        let all = store.cards.filter { $0.cardLanguage == language }
            .compactMap { $0.topic }.filter { !$0.isEmpty }
        return Array(Set(all)).sorted()
    }

    private var hasActiveFilters: Bool {
        favoritesOnly || levelFilter != nil || topicFilter != nil || dateFilter != .all
    }

    private var languageCards: [Card] {
        store.cards.filter { $0.cardLanguage == language }
    }

    private var filteredCards: [Card] {
        let query = normalized(searchText)
        let matching = store.cards.filter { card in
            if card.cardLanguage != language { return false }
            if favoritesOnly && !learner.isFavorite(card.slug) { return false }
            if let levelFilter, CardLevel(card.level) != levelFilter { return false }
            if let topicFilter, card.topic != topicFilter { return false }
            if !matchesDate(card) { return false }
            guard !query.isEmpty else { return true }
            let fields = [card.word, card.phonetic, card.meaningVi, card.meaningEn,
                          card.topic, card.tags?.joined(separator: " ")]
            return fields.compactMap { $0 }.contains { normalized($0).contains(query) }
        }

        switch sortOrder {
        case .newest:
            return matching.sorted { lhs, rhs in
                switch (Self.parseDate(lhs.createdAt), Self.parseDate(rhs.createdAt)) {
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
            .sheet(item: $focusedHanzi) { focus in
                HanziFocusSheet(card: focus.card)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $a4Card) { card in
                A4SheetView(card: card)
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
                        ForEach(filteredCards) { card in
                            CardRow(card: card, onWritingFocus: {
                                focusedHanzi = FocusedHanzi(card: card)
                            }, onA4Tap: { tapped in
                                a4Card = tapped
                            })
                            .brandCard(padding: 15, cornerRadius: 18)
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .onTapGesture { navigationPath.append(card) }
                            .contextMenu { cardContextMenu(card) }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 1100)
                    .frame(maxWidth: .infinity)
                }
                .refreshable { await store.refresh() }
            } else {
                List {
                    ForEach(filteredCards) { card in
                        NavigationLink(value: card) {
                            CardRow(card: card, onWritingFocus: {
                                focusedHanzi = FocusedHanzi(card: card)
                            }, onA4Tap: { tapped in
                                a4Card = tapped
                            })
                            .brandCard(padding: 14, cornerRadius: 16)
                        }
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
                        .contextMenu { cardContextMenu(card) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill), in: Capsule())

                Button {
                    Haptics.selection()
                    withAnimation(.easeInOut(duration: 0.18)) { favoritesOnly.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: favoritesOnly ? "star.fill" : "star")
                            .font(.caption2)
                        Text("Yêu thích")
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .foregroundStyle(favoritesOnly ? Color.white : .orange)
                    .background(favoritesOnly ? Color.orange : Color.orange.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)

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
    @Environment(LocalLearnerStore.self) private var learner
    let card: Card
    let onWritingFocus: () -> Void
    var onA4Tap: ((Card) -> Void)? = nil

    var body: some View {
        HStack(alignment: card.isChinese ? .top : .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(card.word)
                        .font(card.isChinese ? VocaTypography.hanziFont(size: 24, weight: .bold) : .headline)
                    if !card.isChinese, let phonetic = card.phonetic {
                        Text(phonetic)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if learner.isFavorite(card.slug) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                if card.isChinese, let pinyin = card.phonetic {
                    Text(pinyin)
                        .font(.subheadline.weight(.medium))
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
                                 onCharacterFocus: { _ in onWritingFocus() })
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        PronounceButton(text: card.word, language: card.cardLanguage)
                        if let onA4Tap {
                            Button {
                                onA4Tap(card)
                            } label: {
                                Image(systemName: "doc.text")
                                    .font(.body)
                                    .foregroundStyle(Brand.green)
                                    .frame(width: 30, height: 30)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Phiếu học A4")
                        }
                    }
                    if let level = CardLevel(card.level) { LevelBadge(level: level) }
                }
            } else {
                PronounceButton(text: card.word, language: card.cardLanguage)
                if let level = CardLevel(card.level) { LevelBadge(level: level) }
            }
        }
    }
}

private struct FocusedHanzi: Identifiable {
    let id = UUID()
    let card: Card
}

/// Interactive Hanzi handwriting + stroke order + pronunciation modal.
private struct HanziFocusSheet: View {
    @Environment(\.dismiss) private var dismiss
    let card: Card

    var body: some View {
        NavigationStack {
            ZStack {
                VocaThemeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.word)
                                    .font(VocaTypography.hanziFont(size: 38, weight: .bold))
                                if let phonetic = card.phonetic {
                                    Text(phonetic)
                                        .font(.headline)
                                        .foregroundStyle(Brand.green)
                                }
                                if let meaning = card.meaningVi, !meaning.isEmpty {
                                    Text(meaning)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            PronounceButton(
                                text: card.word,
                                language: .chinese,
                                size: 46,
                                font: .title2,
                                tintedCapsule: true
                            )
                        }
                        .brandHeroCard(padding: 16, cornerRadius: 18)

                        HanziWritingView(word: card.word)
                    }
                    .padding()
                }
            }
            .navigationTitle("Tập viết Hán tự")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
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
