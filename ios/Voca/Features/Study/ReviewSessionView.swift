import SwiftUI

/// Full-screen swipeable flashcard review session.
///
/// Owns the session-wide state (which card we're on + how many were graded) and the chrome —
/// progress bar, close button and the celebratory completion screen — while `FlashcardDeckView`
/// handles the interactive stack and per-card grading. Presented as a `.fullScreenCover`.
struct ReviewSessionView: View {
    let items: [DueItem]

    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var gradedCount = 0

    private var total: Int { items.count }
    private var isFinished: Bool { index >= items.count }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if items.isEmpty {
                emptyState
            } else if isFinished {
                completionView
            } else {
                sessionView
            }
        }
        .tint(Brand.green)
    }

    // MARK: - Active session

    @ViewBuilder private var sessionView: some View {
        VStack(spacing: 12) {
            header
            FlashcardDeckView(items: items, index: $index, gradedCount: $gradedCount)
        }
        .padding(.top, 8)
    }

    @ViewBuilder private var header: some View {
        VStack(spacing: 10) {
            HStack {
                closeButton
                Spacer()
                Text("\(min(index + 1, total)) / \(total)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Spacer()
                // Invisible twin keeps the counter centered.
                closeButton
                    .opacity(0)
                    .accessibilityHidden(true)
            }
            progressBar
        }
        .padding(.horizontal, 20)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: Circle())
        }
        .accessibilityLabel("Đóng")
    }

    @ViewBuilder private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Brand.greenSoft)
                Capsule()
                    .fill(Brand.green)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 6)
    }

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(index) / CGFloat(total)
    }

    // MARK: - Completion

    @ViewBuilder private var completionView: some View {
        VStack(spacing: 20) {
            Text("🎉")
                .font(.system(size: 72))
            Text("Hoàn thành \(gradedCount) thẻ! 🎉")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Bạn đã ôn xong phiên này.")
                .foregroundStyle(.secondary)
            Button {
                dismiss()
            } label: {
                Text("Xong").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.green)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Empty

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: 0) {
            HStack {
                closeButton
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()
            ContentUnavailableView(
                "Không có thẻ để ôn",
                systemImage: "checkmark.circle",
                description: Text("Hiện chưa có thẻ nào cần ôn tập."))
            Spacer()
        }
    }
}
