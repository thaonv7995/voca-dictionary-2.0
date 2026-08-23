import SwiftUI

/// Full-screen flashcard review flow. Walks through `items`, revealing the back on demand and
/// posting a grade per card. Per-review failures are shown inline so the session never crashes.
struct ReviewSessionView: View {
    let items: [DueItem]

    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var revealed = false
    @State private var gradedCount = 0
    @State private var isGrading = false
    @State private var isSpeaking = false
    @State private var reviewError: String?

    private let service = StudyService()

    private var isFinished: Bool { index >= items.count }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else if isFinished {
                    completionView
                } else {
                    reviewingView
                }
            }
            .navigationTitle("Ôn tập")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }

    // MARK: - States

    @ViewBuilder private var emptyState: some View {
        ContentUnavailableView(
            "Không có thẻ để ôn",
            systemImage: "checkmark.circle",
            description: Text("Hiện chưa có thẻ nào cần ôn tập."))
    }

    @ViewBuilder private var completionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Hoàn thành \(gradedCount) thẻ!")
                .font(.title2.weight(.bold))
            Text("Bạn đã ôn xong phiên này.")
                .foregroundStyle(.secondary)
            Button {
                dismiss()
            } label: {
                Text("Xong").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .padding()
    }

    @ViewBuilder private var reviewingView: some View {
        let item = items[index]
        VStack(spacing: 16) {
            progressHeader

            ScrollView {
                VStack(spacing: 20) {
                    frontFace(item.card)
                    if revealed {
                        Divider()
                        backFace(item.card)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)
            }

            if let reviewError {
                Text(reviewError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            controls(for: item)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Progress

    @ViewBuilder private var progressHeader: some View {
        VStack(spacing: 6) {
            Text("\(index + 1) / \(items.count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ProgressView(value: Double(index), total: Double(max(items.count, 1)))
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Card faces

    @ViewBuilder private func frontFace(_ card: Card) -> some View {
        VStack(spacing: 10) {
            Text(card.word)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            if let ipa = card.ipa, !ipa.isEmpty {
                Text(ipa)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            if let pos = card.partOfSpeech, !pos.isEmpty {
                Text(pos)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.tint.opacity(0.12), in: Capsule())
            }
            Button {
                speak(card.word)
            } label: {
                HStack(spacing: 6) {
                    if isSpeaking {
                        ProgressView()
                    } else {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    Text("Phát âm")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isSpeaking)
            .padding(.top, 4)
        }
    }

    @ViewBuilder private func backFace(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let vi = card.meaningVi, !vi.isEmpty {
                labeledBlock("Nghĩa", vi, prominent: true)
            }
            if let en = card.meaningEn, !en.isEmpty {
                labeledBlock("Meaning", en)
            }
            if let example = card.examples?.first(where: { !$0.isEmpty }) {
                labeledBlock("Ví dụ", example)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func labeledBlock(_ title: String, _ value: String, prominent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(prominent ? .title3.weight(.semibold) : .body)
        }
    }

    // MARK: - Controls

    @ViewBuilder private func controls(for item: DueItem) -> some View {
        if revealed {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(ReviewGrade.allCases) { grade in
                        Button {
                            submitGrade(item: item, grade: grade)
                        } label: {
                            Text(grade.label)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(color(for: grade))
                        .disabled(isGrading)
                    }
                }
                if reviewError != nil {
                    Button("Bỏ qua thẻ này") { advance() }
                        .font(.footnote)
                        .disabled(isGrading)
                }
                if isGrading {
                    ProgressView()
                }
            }
        } else {
            Button {
                revealed = true
            } label: {
                Label("Hiện nghĩa", systemImage: "eye.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func color(for grade: ReviewGrade) -> Color {
        switch grade {
        case .again: return .red
        case .hard: return .orange
        case .good: return .green
        case .easy: return .blue
        }
    }

    // MARK: - Actions

    private func speak(_ text: String) {
        guard !text.isEmpty else { return }
        isSpeaking = true
        Task {
            try? await TTSService().speak(text)
            isSpeaking = false
        }
    }

    private func submitGrade(item: DueItem, grade: ReviewGrade) {
        guard !isGrading else { return }
        isGrading = true
        reviewError = nil
        Task {
            do {
                try await service.review(slug: item.card.slug, grade: grade)
                gradedCount += 1
                isGrading = false
                advance()
            } catch {
                reviewError = (error as? ApiError)?.message ?? error.localizedDescription
                isGrading = false
            }
        }
    }

    private func advance() {
        reviewError = nil
        revealed = false
        index += 1
    }
}
