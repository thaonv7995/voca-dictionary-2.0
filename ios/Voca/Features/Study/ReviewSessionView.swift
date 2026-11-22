import SwiftUI

/// Full-screen swipeable flashcard session supporting both FSRS due reviews and free browse decks.
struct ReviewSessionView: View {
    private enum Mode {
        case dueReview
        case freeBrowse(title: String)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var theme
    @Environment(LocalLearnerStore.self) private var learner

    private let mode: Mode

    @State private var dueItems: [DueItem]
    @State private var browseCards: [Card]
    @State private var index = 0
    @State private var gradedCount = 0
    @State private var isGrading = false
    @State private var shuffleToken = UUID()
    @State private var gradeBreakdown: [ReviewGrade: Int] = [:]
    @State private var reverseMode = ThemeStore.shared.reverseFlashcardMode
    @State private var autoSpeak = ThemeStore.shared.autoSpeakFlashcard

    init(items: [DueItem]) {
        self.mode = .dueReview
        _dueItems = State(initialValue: items)
        _browseCards = State(initialValue: [])
    }

    init(browseCards: [Card], title: String = "Thẻ lật tự do") {
        self.mode = .freeBrowse(title: title)
        _dueItems = State(initialValue: [])
        _browseCards = State(initialValue: browseCards)
    }

    private var total: Int {
        switch mode {
        case .dueReview: return dueItems.count
        case .freeBrowse: return browseCards.count
        }
    }

    private var isFinished: Bool {
        switch mode {
        case .dueReview: return index >= dueItems.count
        case .freeBrowse: return false
        }
    }

    private var currentCard: Card? {
        switch mode {
        case .dueReview: return dueItems.indices.contains(index) ? dueItems[index].card : nil
        case .freeBrowse: return browseCards.indices.contains(index) ? browseCards[index] : nil
        }
    }

    var body: some View {
        ZStack {
            VocaThemeBackground()

            if total == 0 {
                emptyState
            } else if isFinished {
                completionView
                    .onAppear { Haptics.notify(.success) }
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

            switch mode {
            case .dueReview:
                FlashcardDeckView(
                    items: dueItems,
                    index: $index,
                    gradedCount: $gradedCount,
                    isGrading: $isGrading,
                    reverseMode: reverseMode,
                    autoSpeak: autoSpeak,
                    onGradeRecorded: { grade in
                        gradeBreakdown[grade, default: 0] += 1
                    }
                )
            case .freeBrowse:
                FreeFlashcardDeckView(
                    cards: $browseCards,
                    index: $index,
                    shuffleToken: shuffleToken,
                    reverseMode: reverseMode,
                    autoSpeak: autoSpeak
                )
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                closeButton

                Spacer(minLength: 4)

                VStack(spacing: 2) {
                    if case .freeBrowse(let title) = mode {
                        Text(title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Brand.green)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    Text("\(min(index + 1, total)) / \(total)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .contentTransition(.numericText())
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    if let currentCard {
                        let starred = learner.isFavorite(currentCard.slug)
                        headerIconButton(
                            starred ? "star.fill" : "star",
                            active: starred,
                            label: "Yêu thích"
                        ) {
                            Haptics.selection()
                            learner.toggleFavorite(currentCard.slug)
                        }
                    }

                    headerIconButton(
                        "arrow.left.arrow.right",
                        active: reverseMode,
                        label: "Đảo mặt thẻ"
                    ) {
                        Haptics.selection()
                        reverseMode.toggle()
                        theme.reverseFlashcardMode = reverseMode
                    }

                    headerIconButton(
                        autoSpeak ? "speaker.wave.2.fill" : "speaker.slash",
                        active: autoSpeak,
                        label: "Tự động phát âm"
                    ) {
                        Haptics.selection()
                        autoSpeak.toggle()
                        theme.autoSpeakFlashcard = autoSpeak
                    }

                    if case .freeBrowse = mode, browseCards.count > 1 {
                        headerIconButton("shuffle", active: false, label: "Xáo trộn") {
                            Haptics.impact(.light)
                            browseCards.shuffle()
                            index = 0
                            shuffleToken = UUID()
                        }
                    }
                }
            }
            progressBar
        }
        .padding(.horizontal, 16)
    }

    private func headerIconButton(_ systemImage: String, active: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(active ? .white : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    active ? AnyShapeStyle(Brand.green) : AnyShapeStyle(Color(.secondarySystemBackground)),
                    in: Circle()
                )
                .frame(minWidth: 40, minHeight: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var closeButton: some View {
        Button {
            AudioPlayer.shared.stop()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color(.secondarySystemBackground), in: Circle())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isGrading)
        .opacity(isGrading ? 0.5 : 1)
        .accessibilityLabel("Đóng")
    }

    @ViewBuilder private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Brand.greenSoft)
                Capsule()
                    .fill(Brand.gradient)
                    .frame(width: max(0, geo.size.width * progress))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: 6)
    }

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        if case .freeBrowse = mode {
            return CGFloat(index + 1) / CGFloat(total)
        }
        return CGFloat(index) / CGFloat(total)
    }

    // MARK: - Completion

    @ViewBuilder private var completionView: some View {
        let goodOrEasy = (gradeBreakdown[.good] ?? 0) + (gradeBreakdown[.easy] ?? 0)
        let accuracyText = gradedCount > 0
            ? "\(Int((Double(goodOrEasy) / Double(gradedCount) * 100).rounded()))%"
            : "—"

        VStack(spacing: 20) {
            VocaIconBadge(systemImage: "checkmark.seal.fill", tint: Brand.green, size: 84, iconSize: 40)

            VStack(spacing: 6) {
                Text(gradedCount > 0 ? "Hoàn thành \(gradedCount) thẻ! 🎉" : "Đã kết thúc phiên ôn")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(gradedCount > 0 ? "Bạn đã ôn xong phiên này." : "Chưa có thẻ nào được chấm điểm trong phiên này.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text(accuracyText)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Brand.green)
                        Text("Nhớ vững")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 36)

                    VStack(spacing: 2) {
                        Text("\(learner.streakDays) ngày")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.orange)
                        Text("Chuỗi học")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                Divider().opacity(0.6)

                HStack(spacing: 8) {
                    ForEach(ReviewGrade.allCases) { grade in
                        let count = gradeBreakdown[grade] ?? 0
                        VStack(spacing: 2) {
                            Text("\(count)")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(grade.gradeColor)
                            Text(grade.label)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(grade.gradeColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .brandCard(padding: 18, cornerRadius: 20)
            .frame(maxWidth: 420)

            Button {
                dismiss()
            } label: {
                Text("Xong")
            }
            .buttonStyle(BrandCTAButtonStyle())
            .frame(maxWidth: 320)
            .padding(.top, 8)
        }
        .padding(24)
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
                description: Text("Hiện chưa có thẻ nào trong bộ này."))
            Spacer()
        }
    }
}
