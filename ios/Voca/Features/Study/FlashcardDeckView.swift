import SwiftUI

/// The interactive, draggable flashcard stack.
///
/// - Shows the top card plus 1-2 peeking cards behind for depth.
/// - The top card is draggable (follows the finger with rotation) and tap-to-flip.
/// - Releasing past a horizontal threshold grades the card and flings it off-screen:
///   right = Tốt (good), far right = Dễ (easy); left = Lại (again), far left = Khó (hard).
/// - The four grade buttons below are an explicit alternative to the swipe.
///
/// Owns the per-card review call and advancement so the animation stays in a single transaction.
struct FlashcardDeckView: View {
    let items: [DueItem]
    @Binding var index: Int
    @Binding var gradedCount: Int

    @State private var drag: CGSize = .zero
    /// When non-nil the top card is flying off-screen (mid-commit).
    @State private var flyAway: CGSize?
    @State private var flipped = false
    @State private var isGrading = false
    @State private var isSpeaking = false
    @State private var reviewError: String?
    @State private var lastGrade: ReviewGrade?

    private let service = StudyService()

    private let swipeThreshold: CGFloat = 100
    private let farThreshold: CGFloat = 220
    private let flingDistance: CGFloat = 900

    private let commitSpring = Animation.spring(response: 0.4, dampingFraction: 0.85)
    private let advanceSpring = Animation.spring(response: 0.45, dampingFraction: 0.8)
    private let flipSpring = Animation.spring(response: 0.5, dampingFraction: 0.8)
    private let snapSpring = Animation.spring(response: 0.35, dampingFraction: 0.7)

    var body: some View {
        VStack(spacing: 14) {
            deckArea
            if let reviewError {
                errorBanner(reviewError)
            }
            gradeButtons
        }
    }

    // MARK: - Deck

    @ViewBuilder private var deckArea: some View {
        ZStack {
            ForEach(visibleEntries) { entry in
                card(for: entry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
    }

    @ViewBuilder private func card(for entry: DeckEntry) -> some View {
        let depth = entry.offset
        let isTop = depth == 0
        let currentOffset = flyAway ?? drag

        let base = FlashcardCardView(
            card: entry.item.card,
            flipped: isTop && flipped,
            isTop: isTop,
            isSpeaking: isTop && isSpeaking,
            onSpeak: { speak(entry.item.card.word) }
        )
        .frame(maxWidth: 520)
        .scaleEffect(1 - CGFloat(depth) * 0.05)
        .offset(y: CGFloat(depth) * 14)
        .offset(isTop ? currentOffset : .zero)
        .rotationEffect(.degrees(isTop ? angle(for: currentOffset.width) : 0))
        .overlay { if isTop { swipeSticker(for: currentOffset.width) } }
        .zIndex(Double(-depth))
        .allowsHitTesting(isTop && !isGrading)

        if isTop {
            base
                .gesture(dragGesture(for: entry.item))
                .onTapGesture {
                    withAnimation(flipSpring) { flipped.toggle() }
                }
        } else {
            base
        }
    }

    /// The colored "sticker" hint (TỐT / DỄ / LẠI / KHÓ) shown while dragging or flinging.
    @ViewBuilder private func swipeSticker(for width: CGFloat) -> some View {
        if let grade = grade(for: width) {
            let goesRight = grade.goesRight
            Text(grade.label.uppercased())
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(grade.gradeColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(grade.gradeColor, lineWidth: 4)
                )
                .rotationEffect(.degrees(goesRight ? -12 : 12))
                .opacity(min(1, Double(abs(width)) / Double(swipeThreshold)))
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: goesRight ? .topLeading : .topTrailing)
                .padding(30)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Drag

    private func dragGesture(for item: DueItem) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isGrading, flyAway == nil else { return }
                drag = value.translation
            }
            .onEnded { value in
                guard !isGrading, flyAway == nil else { return }
                if let grade = grade(for: value.translation.width) {
                    commit(grade, for: item)
                } else {
                    withAnimation(snapSpring) { drag = .zero }
                }
            }
    }

    private func angle(for width: CGFloat) -> Double {
        Double(max(-15, min(15, width / 14)))
    }

    private func grade(for width: CGFloat) -> ReviewGrade? {
        if width >= farThreshold { return .easy }
        if width >= swipeThreshold { return .good }
        if width <= -farThreshold { return .hard }
        if width <= -swipeThreshold { return .again }
        return nil
    }

    // MARK: - Grade buttons (explicit alternative to swipe)

    @ViewBuilder private var gradeButtons: some View {
        VStack(spacing: 10) {
            Text("Vuốt thẻ hoặc chọn mức độ")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(ReviewGrade.allCases) { grade in
                    Button {
                        guard let item = currentItem else { return }
                        commit(grade, for: item)
                    } label: {
                        Text(grade.label)
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(grade.gradeColor)
                    .disabled(isGrading)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    @ViewBuilder private func errorBanner(_ message: String) -> some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Button("Thử lại") {
                    guard let item = currentItem, let grade = lastGrade else { return }
                    commit(grade, for: item)
                }
                Button("Bỏ qua") { skip() }
                    .foregroundStyle(.secondary)
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Session state

    private var currentItem: DueItem? {
        items.indices.contains(index) ? items[index] : nil
    }

    /// One entry per visible card. `offset` is depth from the top (0 = top card).
    private struct DeckEntry: Identifiable {
        let offset: Int
        let item: DueItem
        var id: String { item.id }
    }

    /// Up to three visible cards, ordered back-to-front so the top card draws last.
    private var visibleEntries: [DeckEntry] {
        guard !items.isEmpty else { return [] }
        let end = min(index + 3, items.count)
        guard index < end else { return [] }
        return (index..<end).reversed().map { DeckEntry(offset: $0 - index, item: items[$0]) }
    }

    // MARK: - Actions

    private func commit(_ grade: ReviewGrade, for item: DueItem) {
        guard !isGrading else { return }
        isGrading = true
        reviewError = nil
        lastGrade = grade

        withAnimation(commitSpring) {
            flyAway = CGSize(width: grade.goesRight ? flingDistance : -flingDistance, height: drag.height)
        }

        Task { @MainActor in
            do {
                try await service.review(slug: item.card.slug, grade: grade)
                isGrading = false
                withAnimation(advanceSpring) {
                    gradedCount += 1
                    advanceState()
                }
            } catch {
                isGrading = false
                reviewError = (error as? ApiError)?.message ?? error.localizedDescription
                // Bring the card back so the user can retry or skip.
                withAnimation(commitSpring) {
                    flyAway = nil
                    drag = .zero
                }
            }
        }
    }

    /// Advance past the current card without recording a review (used after a failed save).
    private func skip() {
        withAnimation(advanceSpring) {
            reviewError = nil
            advanceState()
        }
    }

    /// Move to the next card and reset the top-card transform. Call inside a `withAnimation`.
    private func advanceState() {
        index += 1
        flyAway = nil
        drag = .zero
        flipped = false
    }

    private func speak(_ text: String) {
        guard !text.isEmpty, !isSpeaking else { return }
        isSpeaking = true
        Task { @MainActor in
            try? await TTSService().speak(text)
            isSpeaking = false
        }
    }
}

// MARK: - Grade presentation (feature-local; Core `ReviewGrade` stays untouched)

private extension ReviewGrade {
    /// Again = red / Hard = orange / Good = green / Easy = blue.
    var gradeColor: Color {
        switch self {
        case .again: return .red
        case .hard: return .orange
        case .good: return Brand.green
        case .easy: return .blue
        }
    }

    /// Good/Easy fling to the right; Again/Hard fling to the left.
    var goesRight: Bool { self == .good || self == .easy }
}
