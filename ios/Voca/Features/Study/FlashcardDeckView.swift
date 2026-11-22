import SwiftUI

/// The interactive, draggable flashcard stack for FSRS review sessions.
struct FlashcardDeckView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeStore.self) private var theme
    let items: [DueItem]
    @Binding var index: Int
    @Binding var gradedCount: Int
    @Binding var isGrading: Bool
    var reverseMode: Bool = false
    var autoSpeak: Bool = false
    var onGradeRecorded: (ReviewGrade) -> Void = { _ in }

    @State private var drag: CGSize = .zero
    @State private var flyAway: CGSize?
    @State private var flipped = false
    @State private var reviewError: String?
    @State private var lastGrade: ReviewGrade?
    @State private var crossedThresholdGrade: ReviewGrade?
    @State private var autoFlipTask: Task<Void, Never>?
    @State private var speakTask: Task<Void, Never>?

    private let service = StudyService()

    private let swipeThreshold: CGFloat = 95
    private let farThreshold: CGFloat = 205
    private let flingDistance: CGFloat = 900

    private let commitSpring = Animation.spring(response: 0.38, dampingFraction: 0.85)
    private let advanceSpring = Animation.spring(response: 0.42, dampingFraction: 0.8)
    private let flipSpring = Animation.spring(response: 0.48, dampingFraction: 0.8)
    private let snapSpring = Animation.spring(response: 0.34, dampingFraction: 0.72)

    var body: some View {
        VStack(spacing: 14) {
            deckArea
            if let reviewError {
                errorBanner(reviewError)
            }
            gradeButtons
        }
        .onAppear {
            speakCurrentIfNeeded(justFlipped: false)
            scheduleReviewAutoFlip()
        }
        .onChange(of: index) { _, _ in
            speakCurrentIfNeeded(justFlipped: false)
            scheduleReviewAutoFlip()
        }
        .onChange(of: flipped) { _, nowFlipped in
            if nowFlipped && reverseMode {
                speakCurrentIfNeeded(justFlipped: true)
            }
            if nowFlipped {
                cancelReviewAutomation()
            }
        }
        .onChange(of: theme.autoFlipFlashcard) { _, isEnabled in
            if isEnabled {
                scheduleReviewAutoFlip()
            } else {
                cancelReviewAutomation()
            }
        }
        .onChange(of: theme.autoFlipDelaySeconds) { _, _ in
            if theme.autoFlipFlashcard {
                scheduleReviewAutoFlip()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                scheduleReviewAutoFlip()
            } else {
                cancelReviewAutomation()
            }
        }
        .onDisappear {
            cancelReviewAutomation()
            stopSpeech()
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
        let dragProgress = min(1, abs(currentOffset.width) / swipeThreshold)
        let depthLift = (depth == 1) ? dragProgress * 0.035 : 0
        let yLift = (depth == 1) ? dragProgress * 8 : 0
        let previewGrade = isTop ? grade(for: currentOffset.width) : nil

        let base = FlashcardCardView(
            card: entry.item.card,
            flipped: isTop && flipped,
            isTop: isTop,
            reverseMode: reverseMode
        )
        .frame(maxWidth: 520)
        .overlay {
            if let previewGrade {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(previewGrade.gradeColor.opacity(0.65), lineWidth: 3)
                    .allowsHitTesting(false)
            }
        }
        .overlay { if isTop { swipeSticker(for: currentOffset.width) } }
        .scaleEffect((1 - CGFloat(depth) * 0.045) + depthLift)
        .offset(y: CGFloat(depth) * 12 - yLift)
        .offset(isTop ? currentOffset : .zero)
        .rotationEffect(.degrees(isTop ? angle(for: currentOffset.width) : 0))
        .zIndex(Double(-depth))
        .allowsHitTesting(isTop && !isGrading)
        .accessibilityHidden(!isTop)

        if isTop {
            base
                .gesture(dragGesture(for: entry.item))
                .onTapGesture {
                    Haptics.impact(.light)
                    cancelReviewAutomation()
                    withAnimation(flipSpring) { flipped.toggle() }
                }
                .accessibilityHint("Chạm đúp để lật thẻ")
                .accessibilityAction(named: "Lật thẻ") {
                    cancelReviewAutomation()
                    withAnimation(flipSpring) { flipped.toggle() }
                }
        } else {
            base
        }
    }

    @ViewBuilder private func swipeSticker(for width: CGFloat) -> some View {
        if let grade = grade(for: width) {
            let goesRight = grade.goesRight
            HStack(spacing: 6) {
                Image(systemName: grade.icon)
                Text(grade.label.uppercased())
            }
            .font(.system(size: 24, weight: .heavy, design: .rounded))
            .foregroundStyle(grade.gradeColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(grade.gradeColor, lineWidth: 3)
            )
            .rotationEffect(.degrees(goesRight ? -10 : 10))
            .opacity(min(1, Double(abs(width)) / Double(swipeThreshold)))
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: goesRight ? .topLeading : .topTrailing)
            .padding(26)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Drag

    private func dragGesture(for item: DueItem) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isGrading, flyAway == nil else { return }
                cancelReviewAutomation()
                drag = value.translation
                let current = grade(for: value.translation.width)
                if current != crossedThresholdGrade {
                    crossedThresholdGrade = current
                    if current != nil { Haptics.selection() }
                }
            }
            .onEnded { value in
                guard !isGrading, flyAway == nil else { return }
                crossedThresholdGrade = nil
                if let grade = grade(for: value.translation.width) {
                    commit(grade, for: item)
                } else {
                    withAnimation(snapSpring) { drag = .zero }
                    scheduleReviewAutoFlip()
                }
            }
    }

    private func angle(for width: CGFloat) -> Double {
        Double(max(-14, min(14, width / 15)))
    }

    private func grade(for width: CGFloat) -> ReviewGrade? {
        if width >= farThreshold { return .easy }
        if width >= swipeThreshold { return .good }
        if width <= -farThreshold { return .again }
        if width <= -swipeThreshold { return .hard }
        return nil
    }

    // MARK: - Grade buttons

    @ViewBuilder private var gradeButtons: some View {
        VStack(spacing: 8) {
            Text("Vuốt thẻ trái/phải hoặc chọn mức nhớ")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(ReviewGrade.allCases) { grade in
                    Button {
                        guard let item = currentItem else { return }
                        commit(grade, for: item)
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: grade.icon)
                                .font(.caption.weight(.bold))
                            Text(grade.label)
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(grade.gradeColor, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(PressableScaleStyle(scale: 0.94))
                    .disabled(isGrading)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
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

    private struct DeckEntry: Identifiable {
        let offset: Int
        let item: DueItem
        var id: String { item.id }
    }

    private var visibleEntries: [DeckEntry] {
        guard !items.isEmpty else { return [] }
        let end = min(index + 3, items.count)
        guard index < end else { return [] }
        return (index..<end).reversed().map { DeckEntry(offset: $0 - index, item: items[$0]) }
    }

    // MARK: - Actions

    private func speakCurrentIfNeeded(justFlipped: Bool) {
        stopSpeech()
        guard autoSpeak, let item = currentItem else { return }
        if reverseMode && !justFlipped { return }
        let card = item.card
        speakTask = Task {
            try? await TTSService().speak(card.word, language: card.cardLanguage)
        }
    }

    private func stopSpeech() {
        speakTask?.cancel()
        speakTask = nil
        AudioPlayer.shared.stop()
    }

    private func commit(_ grade: ReviewGrade, for item: DueItem) {
        guard !isGrading else { return }
        cancelReviewAutomation()
        stopSpeech()
        isGrading = true
        reviewError = nil
        lastGrade = grade
        Haptics.impact(grade == .again ? .rigid : .medium)

        withAnimation(commitSpring) {
            flyAway = CGSize(width: grade.goesRight ? flingDistance : -flingDistance, height: drag.height)
        }

        Task { @MainActor in
            do {
                try await service.review(slug: item.card.slug, grade: grade)
                isGrading = false
                LocalLearnerStore.shared.recordReviewCompleted(count: 1)
                onGradeRecorded(grade)
                withAnimation(advanceSpring) {
                    gradedCount += 1
                    advanceState()
                }
            } catch {
                isGrading = false
                Haptics.notify(.error)
                reviewError = (error as? ApiError)?.message ?? error.localizedDescription
                withAnimation(commitSpring) {
                    flyAway = nil
                    drag = .zero
                }
            }
        }
    }

    private func skip() {
        withAnimation(advanceSpring) {
            reviewError = nil
            advanceState()
        }
    }

    private func advanceState() {
        cancelReviewAutomation()
        stopSpeech()
        index += 1
        flyAway = nil
        drag = .zero
        flipped = false
        crossedThresholdGrade = nil
    }

    private func scheduleReviewAutoFlip() {
        cancelReviewAutomation()
        guard theme.autoFlipFlashcard,
              scenePhase == .active,
              currentItem != nil,
              !flipped,
              !isGrading else { return }

        let delayMs = Int((theme.autoFlipDelaySeconds * 1000).rounded())
        autoFlipTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMs))
            guard !Task.isCancelled,
                  theme.autoFlipFlashcard,
                  scenePhase == .active,
                  currentItem != nil,
                  !flipped,
                  !isGrading else { return }
            withAnimation(flipSpring) {
                flipped = true
            }
        }
    }

    private func cancelReviewAutomation() {
        autoFlipTask?.cancel()
        autoFlipTask = nil
    }
}

// MARK: - Free Browse Deck (No FSRS mutation)

/// Free-study deck allowing users to flip, favorite, shuffle, and browse any card set freely.
struct FreeFlashcardDeckView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeStore.self) private var theme
    @Binding var cards: [Card]
    @Binding var index: Int
    var shuffleToken: UUID = UUID()
    var reverseMode: Bool = false
    var autoSpeak: Bool = false

    @State private var flipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var flyAwayOffset: CGSize?
    @State private var isTransitioning = false
    @State private var autoFlipTask: Task<Void, Never>?
    @State private var autoAdvanceTask: Task<Void, Never>?
    @State private var transitionTask: Task<Void, Never>?
    @State private var speakTask: Task<Void, Never>?

    private let flipSpring = Animation.spring(response: 0.48, dampingFraction: 0.8)

    private var allowsVerticalSwipe: Bool {
        !flipped && !reverseMode
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(visibleCards, id: \.card.id) { depth, card in
                    let isTop = depth == 0
                    let activeOffset = flyAwayOffset ?? dragOffset
                    let activeDistance = max(abs(activeOffset.width), abs(activeOffset.height))
                    let dragProgress = min(1, activeDistance / 75)
                    let depthLift = (depth == 1) ? dragProgress * 0.035 : 0
                    let yLift = (depth == 1) ? dragProgress * 8 : 0
                    FlashcardCardView(
                        card: card,
                        flipped: isTop && flipped,
                        isTop: isTop,
                        reverseMode: reverseMode
                    )
                    .frame(maxWidth: 520)
                    .scaleEffect((1 - CGFloat(depth) * 0.045) + depthLift)
                    .offset(y: CGFloat(depth) * 12 - yLift)
                    .offset(isTop ? activeOffset : .zero)
                    .rotationEffect(.degrees(isTop ? Double(activeOffset.width / 22) : 0))
                    .zIndex(Double(-depth))
                    .allowsHitTesting(isTop && !isTransitioning)
                    .accessibilityHidden(!isTop)
                    .gesture(isTop ? browseDragGesture : nil)
                    .onTapGesture {
                        guard isTop, !isTransitioning else { return }
                        Haptics.impact(.light)
                        autoFlipTask?.cancel()
                        autoFlipTask = nil
                        withAnimation(flipSpring) { flipped.toggle() }
                    }
                    .accessibilityHint(isTop ? "Chạm đúp để lật thẻ" : "")
                    .accessibilityAction(named: "Lật thẻ") {
                        guard isTop, !isTransitioning else { return }
                        autoFlipTask?.cancel()
                        autoFlipTask = nil
                        withAnimation(flipSpring) { flipped.toggle() }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)

            controlsBar
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
        }
        .onAppear {
            speakCurrentIfNeeded(justFlipped: false)
            scheduleAutoFlip()
        }
        .onChange(of: index) { _, _ in
            speakCurrentIfNeeded(justFlipped: false)
            scheduleAutoFlip()
        }
        .onChange(of: shuffleToken) { _, _ in
            cancelAutomation()
            transitionTask?.cancel()
            transitionTask = nil
            isTransitioning = false
            stopSpeech()
            flyAwayOffset = nil
            dragOffset = .zero
            flipped = false
            speakCurrentIfNeeded(justFlipped: false)
            scheduleAutoFlip()
        }
        .onChange(of: flipped) { _, nowFlipped in
            if nowFlipped && reverseMode {
                speakCurrentIfNeeded(justFlipped: true)
            }

            if nowFlipped {
                scheduleAutoAdvance()
            } else {
                autoAdvanceTask?.cancel()
                autoAdvanceTask = nil
            }
        }
        .onChange(of: theme.autoFlipFlashcard) { _, isEnabled in
            if isEnabled {
                scheduleAutoFlip()
            } else {
                autoFlipTask?.cancel()
                autoFlipTask = nil
            }
        }
        .onChange(of: theme.autoFlipDelaySeconds) { _, _ in
            if theme.autoFlipFlashcard && !flipped {
                scheduleAutoFlip()
            }
        }
        .onChange(of: theme.autoAdvanceFlashcard) { _, isEnabled in
            if isEnabled && flipped {
                scheduleAutoAdvance()
            } else {
                autoAdvanceTask?.cancel()
                autoAdvanceTask = nil
            }
        }
        .onChange(of: theme.autoAdvanceDelaySeconds) { _, _ in
            if theme.autoAdvanceFlashcard && flipped {
                scheduleAutoAdvance()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if flipped {
                    scheduleAutoAdvance()
                } else {
                    scheduleAutoFlip()
                }
            } else {
                cancelAutomation()
            }
        }
        .onDisappear {
            cancelAutomation()
            transitionTask?.cancel()
            transitionTask = nil
            stopSpeech()
        }
    }

    private var visibleCards: [(offset: Int, card: Card)] {
        guard !cards.isEmpty, index < cards.count else { return [] }
        let end = min(index + 3, cards.count)
        return (index..<end).reversed().map { ($0 - index, cards[$0]) }
    }

    private var browseDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isTransitioning else { return }
                cancelAutomation()
                let t = value.translation
                if allowsVerticalSwipe {
                    if abs(t.height) > abs(t.width) * 1.15 {
                        dragOffset = CGSize(width: t.width * 0.25, height: t.height)
                    } else {
                        dragOffset = CGSize(width: t.width, height: t.height * 0.25)
                    }
                } else {
                    dragOffset = CGSize(width: t.width, height: 0)
                }
            }
            .onEnded { value in
                guard !isTransitioning else { return }
                let t = value.translation
                let pred = value.predictedEndTranslation

                if allowsVerticalSwipe && abs(t.height) >= abs(t.width) {
                    if (t.height < -65 || pred.height < -170) && cards.count > 1 {
                        advanceNext(exitOffset: CGSize(width: dragOffset.width, height: -820))
                        return
                    }
                    if (t.height > 65 || pred.height > 170) && index > 0 {
                        move(to: index - 1, exitOffset: CGSize(width: dragOffset.width, height: 820))
                        return
                    }
                } else {
                    if (t.width < -65 || pred.width < -170) && cards.count > 1 {
                        advanceNext(exitOffset: CGSize(width: -650, height: dragOffset.height))
                        return
                    }
                    if (t.width > 65 || pred.width > 170) && index > 0 {
                        move(to: index - 1, exitOffset: CGSize(width: 650, height: dragOffset.height))
                        return
                    }
                }

                withAnimation(.spring(response: 0.3, dampingFraction: 0.76)) {
                    dragOffset = .zero
                }
                if flipped {
                    scheduleAutoAdvance()
                } else {
                    scheduleAutoFlip()
                }
            }
    }

    private var controlsBar: some View {
        HStack(spacing: 12) {
            Button {
                move(to: max(0, index - 1))
            } label: {
                Label("Trước", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(index == 0 || isTransitioning)

            Button {
                Haptics.impact(.light)
                autoFlipTask?.cancel()
                autoFlipTask = nil
                withAnimation(flipSpring) { flipped.toggle() }
            } label: {
                Label("Lật thẻ", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.green)
            .disabled(isTransitioning)

            Button {
                advanceNext()
            } label: {
                Label("Sau", systemImage: "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(cards.count <= 1 || isTransitioning)
        }
    }

    private func advanceNext(exitOffset: CGSize? = nil) {
        guard cards.count > 1 else { return }
        if index < cards.count - 1 {
            move(to: index + 1, exitOffset: exitOffset)
        } else {
            reshuffleForNextCycle(exitOffset: exitOffset)
        }
    }

    private func reshuffleForNextCycle(exitOffset: CGSize? = nil) {
        guard cards.count > 1 else { return }
        let previousID = cards.indices.contains(index) ? cards[index].id : nil
        var nextDeck = cards.shuffled()
        if let previousID, nextDeck.first?.id == previousID, nextDeck.count > 1 {
            nextDeck.swapAt(0, Int.random(in: 1..<nextDeck.count))
        }
        performTransition(exitOffset: exitOffset) {
            cards = nextDeck
            index = 0
        }
    }

    private func move(to newIndex: Int, exitOffset: CGSize? = nil) {
        guard cards.indices.contains(newIndex) else { return }
        performTransition(exitOffset: exitOffset) {
            index = newIndex
        }
    }

    private func performTransition(exitOffset: CGSize?, apply: @escaping () -> Void) {
        Haptics.selection()
        cancelAutomation()
        stopSpeech()
        transitionTask?.cancel()
        transitionTask = nil

        if let exitOffset {
            isTransitioning = true
            withAnimation(.easeOut(duration: 0.17)) {
                flyAwayOffset = exitOffset
            }
            transitionTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(165))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    flyAwayOffset = nil
                    dragOffset = .zero
                    flipped = false
                    apply()
                }
                isTransitioning = false
                transitionTask = nil
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                flyAwayOffset = nil
                dragOffset = .zero
                flipped = false
                apply()
            }
        }
    }

    private func scheduleAutoFlip() {
        autoFlipTask?.cancel()
        autoFlipTask = nil

        guard theme.autoFlipFlashcard,
              scenePhase == .active,
              cards.indices.contains(index),
              !flipped else {
            if flipped {
                scheduleAutoAdvance()
            }
            return
        }

        let delayMs = Int((theme.autoFlipDelaySeconds * 1000).rounded())
        autoFlipTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMs))
            guard !Task.isCancelled,
                  theme.autoFlipFlashcard,
                  scenePhase == .active,
                  cards.indices.contains(index),
                  !flipped else { return }

            withAnimation(flipSpring) {
                flipped = true
            }
        }
    }

    private func scheduleAutoAdvance() {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil

        guard theme.autoAdvanceFlashcard,
              scenePhase == .active,
              flipped,
              cards.count > 1 else { return }

        let delayMs = Int((theme.autoAdvanceDelaySeconds * 1000).rounded())
        autoAdvanceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMs))
            guard !Task.isCancelled,
                  theme.autoAdvanceFlashcard,
                  scenePhase == .active,
                  flipped,
                  cards.count > 1 else { return }

            advanceNext(exitOffset: CGSize(width: 0, height: -760))
        }
    }

    private func cancelAutomation() {
        autoFlipTask?.cancel()
        autoAdvanceTask?.cancel()
        autoFlipTask = nil
        autoAdvanceTask = nil
    }

    private func speakCurrentIfNeeded(justFlipped: Bool) {
        stopSpeech()
        guard autoSpeak, cards.indices.contains(index) else { return }
        if reverseMode && !justFlipped { return }
        let card = cards[index]
        speakTask = Task {
            try? await TTSService().speak(card.word, language: card.cardLanguage)
        }
    }

    private func stopSpeech() {
        speakTask?.cancel()
        speakTask = nil
        AudioPlayer.shared.stop()
    }
}

// MARK: - Grade presentation

extension ReviewGrade {
    var gradeColor: Color {
        switch self {
        case .again: return Color(red: 0.918, green: 0.247, blue: 0.314)
        case .hard: return Color(red: 0.945, green: 0.553, blue: 0.055)
        case .good: return Brand.semanticSuccess
        case .easy: return Color(red: 0.055, green: 0.565, blue: 0.914)
        }
    }

    var icon: String {
        switch self {
        case .again: return "arrow.counterclockwise"
        case .hard: return "tortoise.fill"
        case .good: return "checkmark"
        case .easy: return "hare.fill"
        }
    }

    var goesRight: Bool { self == .good || self == .easy }
}
