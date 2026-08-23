import SwiftUI

/// Study progress overview: overall totals plus a per-level breakdown drawn as proportional bars.
/// Pushed from `StudyRootView`, so it relies on the enclosing `NavigationStack`.
struct StatsView: View {
    @State private var stats: StudyStats?
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
            } else if let stats {
                content(stats)
            } else {
                ContentUnavailableView(
                    "Chưa có dữ liệu",
                    systemImage: "chart.bar",
                    description: Text("Chưa có thống kê nào để hiển thị."))
            }
        }
        .navigationTitle("Thống kê")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder private func content(_ stats: StudyStats) -> some View {
        List {
            Section("Tổng quan") {
                LabeledContent("Tổng số thẻ", value: "\(stats.totalCards)")
                LabeledContent("Tổng lượt ôn", value: "\(stats.totalReviews)")
                LabeledContent("Cần ôn hiện tại", value: "\(stats.dueNow)")
            }

            Section("Phân bố theo cấp độ") {
                let maxCount = max(CardLevel.allCases.map { stats.byLevel[$0.rawValue] ?? 0 }.max() ?? 0, 1)
                ForEach(CardLevel.allCases) { level in
                    LevelBarRow(
                        label: level.label,
                        count: stats.byLevel[level.rawValue] ?? 0,
                        maxCount: maxCount,
                        color: color(for: level))
                }
            }
        }
    }

    private func color(for level: CardLevel) -> Color {
        switch level {
        case .new: return .gray
        case .learning: return .orange
        case .known: return .blue
        case .mastered: return .green
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            stats = try await service.stats()
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
