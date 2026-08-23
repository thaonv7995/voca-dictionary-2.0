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

    /// Full load with the loading spinner (used on first appear and retry).
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            cards = try await service.list()
        } catch {
            errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
        }
        isLoading = false
    }

    /// Silent reload for pull-to-refresh (no full-screen spinner).
    func refresh() async {
        do {
            cards = try await service.list()
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
    @State private var store = DictionaryStore()
    @State private var searchText = ""
    @State private var levelFilter: CardLevel?
    @State private var topicFilter: String?
    @State private var dateFilter: DateFilter = .all
    @State private var showCreate = false

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
        let all = store.cards.compactMap { $0.topic }.filter { !$0.isEmpty }
        return Array(Set(all)).sorted()
    }

    private var hasActiveFilters: Bool {
        levelFilter != nil || topicFilter != nil || dateFilter != .all
    }

    private var filteredCards: [Card] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return store.cards.filter { card in
            if let levelFilter, CardLevel(card.level) != levelFilter { return false }
            if let topicFilter, card.topic != topicFilter { return false }
            if !matchesDate(card) { return false }
            guard !query.isEmpty else { return true }
            return card.word.lowercased().contains(query)
                || (card.meaningVi?.lowercased().contains(query) ?? false)
                || (card.meaningEn?.lowercased().contains(query) ?? false)
                || (card.tags?.contains { $0.lowercased().contains(query) } ?? false)
        }
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
        NavigationStack {
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
                .task { if store.cards.isEmpty { await store.load() } }
        }
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
        } else if store.cards.isEmpty {
            ContentUnavailableView(
                "Chưa có thẻ nào",
                systemImage: "tray",
                description: Text("Nhấn + để tạo thẻ từ vựng đầu tiên."))
        } else {
            VStack(spacing: 0) {
                filterBar
                cardList
            }
        }
    }

    private var cardList: some View {
        List {
            ForEach(filteredCards) { card in
                NavigationLink(value: card) { CardRow(card: card) }
            }
        }
        .listStyle(.plain)
        .refreshable { await store.refresh() }
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
    @State private var speaking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(card.word)
                    .font(.headline)
                if let ipa = card.ipa, !ipa.isEmpty {
                    Text(ipa)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                speakButton
                if let level = CardLevel(card.level) {
                    LevelBadge(level: level)
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
        .padding(.vertical, 2)
    }

    /// Inline pronunciation button — `.borderless` so it taps independently of the row's NavigationLink.
    private var speakButton: some View {
        Button {
            guard !speaking else { return }
            speaking = true
            Task {
                try? await TTSService().speak(card.word)
                speaking = false
            }
        } label: {
            Group {
                if speaking {
                    ProgressView()
                } else {
                    Image(systemName: "speaker.wave.2.fill")
                }
            }
            .frame(width: 30, height: 30)
            .foregroundStyle(Brand.green)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Phát âm \(card.word)")
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
