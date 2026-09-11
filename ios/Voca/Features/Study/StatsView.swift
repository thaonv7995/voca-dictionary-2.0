import SwiftUI

/// Study progress overview: overall totals plus a per-level breakdown drawn as proportional bars.
/// Pushed from `StudyRootView`, so it relies on the enclosing `NavigationStack`.
struct StatsView: View {
    @AppStorage("voca.dictionary.language") private var languageRaw = CardLanguage.english.rawValue
    @State private var stats: StudyStats?
    @State private var cards: [Card] = []
    @State private var due: DueResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = StudyService()

    var body: some View {
        Group {
            if isLoading && stats == nil {
                ProgressView("Đang tải…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, stats == nil {
                ContentUnavailableView {
                    Label("Không tải được thống kê", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage).foregroundStyle(.red)
                } actions: {
                    Button("Thử lại") { Task { await load() } }
                }
            } else if stats != nil {
                content
            } else {
                ContentUnavailableView(
                    "Chưa có dữ liệu",
                    systemImage: "chart.bar",
                    description: Text("Chưa có thống kê nào để hiển thị."))
            }
        }
        .navigationTitle("Thống kê")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Brand.green)
        .task { await load() }
        .refreshable { await load() }
    }

    private var language: CardLanguage {
        CardLanguage(rawValue: languageRaw) ?? .english
    }

    private var languageCards: [Card] {
        cards.filter { $0.cardLanguage == language }
    }

    private var content: some View {
        List {
            Section {
                CardLanguagePicker(selection: $languageRaw)
            }

            Section("Tổng quan") {
                LabeledContent("Tổng số thẻ", value: "\(languageCards.count)")
                LabeledContent("Cần ôn hiện tại") {
                    Text("\((due?.cards ?? []).filter { $0.card.cardLanguage == language }.count)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Brand.green)
                }
            }

            Section("Phân bố theo cấp độ") {
                let counts = Dictionary(grouping: languageCards) { CardLevel($0.level) ?? .new }
                    .mapValues(\.count)
                let maxCount = max(counts.values.max() ?? 0, 1)
                ForEach(CardLevel.allCases) { level in
                    LevelBarRow(
                        label: level.label,
                        count: counts[level] ?? 0,
                        maxCount: maxCount,
                        color: Brand.levelColor(level.rawValue))
                }
            }
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

/// A single level row: label, count and a proportional bar (width relative to the largest count).
private struct LevelBarRow: View {
    let label: String
    let count: Int
    let maxCount: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                    Capsule()
                        .fill(color)
                        .frame(width: max(geo.size.width * fraction, count > 0 ? 6 : 0))
                }
            }
            .frame(height: 10)
        }
        .padding(.vertical, 4)
    }

    private var fraction: CGFloat {
        guard maxCount > 0 else { return 0 }
        return CGFloat(count) / CGFloat(maxCount)
    }
}
