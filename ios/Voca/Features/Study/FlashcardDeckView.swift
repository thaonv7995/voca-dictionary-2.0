import SwiftUI

/// The interactive flashcard deck for FSRS due review sessions, combining TikTok-style
/// vertical browsing & flip→flip-back→glide automation with FSRS swipe/button grading.
struct FlashcardDeckView: View {
    private enum SlideDirection {
        case forward
        case backward
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeStore.self) private var theme
    @Binding var items: [DueItem]
    @Binding var index: Int
    @Binding var gradedCount: Int
    @Binding var isGrading: Bool
    var shuffleToken: UUID = UUID()
    var reverseMode: Bool = false
    var autoSpeak: Bool = false
    var onGradeRecorded: (ReviewGrade) -> Void = { _ in }

    @State private var drag: CGSize = .zero
    @State private var flyAway: CGSize?
    @State private var animatedShift: CGSize = .zero
    @State private var isVerticalTransitioning = false
    @State private var activeSlideDirection: SlideDirection?
    @State private var isAutoAdvancing = false
    @State private var nextCycleItems: [DueItem] = []
    @State private var deckPageHeight: CGFloat = 560
    @State private var flipped = false
    @State private var reviewError: String?
    @State private var lastGrade: ReviewGrade?
    @State private var crossedThresholdGrade: ReviewGrade?
    @State private var autoFlipTask: Task<Void, Never>?
    @State private var autoAdvanceTask: Task<Void, Never>?
    @State private var transitionTask: Task<Void, Never>?
    @State private var speakTask: Task<Void, Never>?

    private let service = StudyService()

    private let swipeThreshold: CGFloat = 95
    private let farThreshold: CGFloat = 205
    private let flingDistance: CGFloat = 900

    private let commitSpring = Animation.spring(response: 0.38, dampingFraction: 0.85)
    private let advanceSpring = Animation.spring(response: 0.42, dampingFraction: 0.8)
    private let flipSpring = Animation.spring(response: 0.44, dampingFraction: 0.82)
    private let snapSpring = Animation.spring(response: 0.34, dampingFraction: 0.74)
    private let tiktokSlideCurve = Animation.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.38)

    private var allowsVerticalSwipe: Bool {
        !flipped && !reverseMode && !isGrading
    }

    private var currentItem: DueItem? {
        items.indices.contains(index) ? items[index] : nil
    }

    private var nextItem: DueItem? {
        guard items.count > 1 else { return nil }
        if index < items.count - 1 {
            return items[index + 1]
        }
        return nextCycleItems.first
    }

    private var previousItem: DueItem? {
        guard index > 0, items.indices.contains(index - 1) else { return nil }
        return items[index - 1]
    }

    private var activeDragOrFly: CGSize {
        if isVerticalTransitioning { return animatedShift }
        return flyAway ?? drag
    }

    private var isVerticalMode: Bool {
        if isVerticalTransitioning { return true }
        if flyAway != nil { return false }
        let off = drag
        return allowsVerticalSwipe && abs(off.height) >= abs(off.width) * 1.05 && abs(off.height) > 1
    }

    var body: some View {
        VStack(spacing: 14) {
            deckArea
            if let reviewError {
                errorBanner(reviewError)
            }
            gradeButtons
        }
        .onAppear {
            prepareNextCycleIfNeeded()
            speakCurrentIfNeeded(justFlipped: false)
            scheduleReviewAutoFlip()
        }
        .onChange(of: index) { _, _ in
            prepareNextCycleIfNeeded()
            speakCurrentIfNeeded(justFlipped: false)
            scheduleReviewAutoFlip()
        }
        .onChange(of: shuffleToken) { _, _ in
            cancelReviewAutomation()
            transitionTask?.cancel()
            transitionTask = nil
            isVerticalTransitioning = false
            activeSlideDirection = nil
            stopSpeech()
            flyAway = nil
            animatedShift = .zero
            drag = .zero
            flipped = false
            reviewError = nil
            crossedThresholdGrade = nil
            nextCycleItems = []
            prepareNextCycleIfNeeded()
            speakCurrentIfNeeded(justFlipped: false)
            scheduleReviewAutoFlip()
        }
        .onChange(of: flipped) { _, nowFlipped in
            if nowFlipped && reverseMode {
                speakCurrentIfNeeded(justFlipped: true)
            }
            if nowFlipped {
                scheduleReviewAutoAdvance()
            } else if !isAutoAdvancing {
                autoAdvanceTask?.cancel()
                autoAdvanceTask = nil
            }
        }
        .onChange(of: theme.autoFlipFlashcard) { _, isEnabled in
            if isEnabled {
                scheduleReviewAutoFlip()
            } else if !theme.autoAdvanceFlashcard {
                autoFlipTask?.cancel()
                autoFlipTask = nil
            }
        }
        .onChange(of: theme.autoFlipDelaySeconds) { _, _ in
            if (theme.autoFlipFlashcard || theme.autoAdvanceFlashcard) && !flipped {
                scheduleReviewAutoFlip()
            }
        }
        .onChange(of: theme.autoAdvanceFlashcard) { _, isEnabled in
            if isEnabled {
                if flipped {
                    scheduleReviewAutoAdvance()
                } else {
                    scheduleReviewAutoFlip()
                }
            } else {
                autoAdvanceTask?.cancel()
                autoAdvanceTask = nil
                isAutoAdvancing = false
                if !theme.autoFlipFlashcard {
                    autoFlipTask?.cancel()
                    autoFlipTask = nil
                }
            }
        }
        .onChange(of: theme.autoAdvanceDelaySeconds) { _, _ in
            if theme.autoAdvanceFlashcard && flipped && !isAutoAdvancing {
                scheduleReviewAutoAdvance()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if flipped {
                    scheduleReviewAutoAdvance()
                } else {
                    scheduleReviewAutoFlip()
                }
            } else {
                cancelReviewAutomation()
            }
        }
        .onDisappear {
            cancelReviewAutomation()
            transitionTask?.cancel()
            transitionTask = nil
            stopSpeech()
        }
    }

    // MARK: - Deck

    @ViewBuilder private var deckArea: some View {
        GeometryReader { geo in
            let pageHeight = max(geo.size.height + 24, 420)
            let off = activeDragOrFly
            let vertical = isVerticalMode
            let verticalY = vertical ? off.height : 0
            let showPrev = (activeSlideDirection == .backward) || (vertical && verticalY > 0)
            let verticalProgress = min(1, abs(verticalY) / max(pageHeight, 1))
            let horizontalProgress = min(1, abs(off.width) / swipeThreshold)
            let previewGrade = vertical ? nil : grade(for: off.width)

            ZStack {
                if showPrev, let prev = previousItem {
                    FlashcardCardView(
                        card: prev.card,
                        flipped: false,
                        isTop: false,
                        reverseMode: reverseMode
                    )
                    .frame(maxWidth: 520)
                    .scaleEffect(0.95 + 0.05 * verticalProgress)
                    .offset(y: -pageHeight + verticalY)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .id(prev.id)
                } else if let next = nextItem {
                    let nextScale = vertical
                        ? (0.95 + 0.05 * verticalProgress)
                        : (0.955 + 0.045 * horizontalProgress)
                    let nextY = vertical
                        ? (pageHeight + verticalY)
                        : (12 - horizontalProgress * 12)
                    FlashcardCardView(
                        card: next.card,
                        flipped: false,
                        isTop: false,
                        reverseMode: reverseMode
                    )
                    .frame(maxWidth: 520)
                    .scaleEffect(nextScale)
                    .offset(y: nextY)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .id(next.id)
                }

                if let current = currentItem {
                    let currentScale = vertical ? (1.0 - 0.04 * verticalProgress) : 1.0
                    FlashcardCardView(
                        card: current.card,
                        flipped: flipped,
                        isTop: true,
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
                    .overlay { if !vertical { swipeSticker(for: off.width) } }
                    .scaleEffect(currentScale)
                    .offset(x: vertical ? off.width * 0.18 : off.width, y: vertical ? verticalY : off.height)
                    .rotationEffect(.degrees(vertical ? 0 : angle(for: off.width)))
                    .zIndex(1)
                    .allowsHitTesting(!isGrading && !isVerticalTransitioning)
                    .gesture(dragGesture(for: current, pageHeight: pageHeight))
                    .onTapGesture {
                        guard !isGrading, !isVerticalTransitioning else { return }
                        Haptics.impact(.light)
                        cancelReviewAutomation()
                        withAnimation(flipSpring) { flipped.toggle() }
                    }
                    .accessibilityHint("Chạm đúp để lật thẻ")
                    .accessibilityAction(named: "Lật thẻ") {
                        guard !isGrading, !isVerticalTransitioning else { return }
                        cancelReviewAutomation()
                        withAnimation(flipSpring) { flipped.toggle() }
                    }
                    .id(current.id)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
            .clipped()
            .onAppear { deckPageHeight = pageHeight }
            .onChange(of: pageHeight) { _, newHeight in deckPageHeight = newHeight }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func dragGesture(for item: DueItem, pageHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isGrading, !isVerticalTransitioning, flyAway == nil else { return }
                cancelReviewAutomation()
                let t = value.translation
                if allowsVerticalSwipe && abs(t.height) >= abs(t.width) * 1.05 {
                    let clampedHeight = (index == 0 && t.height > 0) ? t.height * 0.28 : t.height
                    drag = CGSize(width: t.width * 0.15, height: clampedHeight)
                    crossedThresholdGrade = nil
                } else {
                    drag = t
                    let current = grade(for: t.width)
                    if current != crossedThresholdGrade {
                        crossedThresholdGrade = current
                        if current != nil { Haptics.selection() }
                    }
                }
            }
            .onEnded { value in
                guard !isGrading, !isVerticalTransitioning, flyAway == nil else { return }
                crossedThresholdGrade = nil
                let t = value.translation
                let pred = value.predictedEndTranslation

                if allowsVerticalSwipe && abs(t.height) >= abs(t.width) * 1.05 {
                    if (t.height < -65 || pred.height < -170) && items.count > 1 {
                        browseNextDue(verticalExit: -pageHeight)
                        return
                    }
                    if (t.height > 65 || pred.height > 170) && index > 0 {
                        browsePreviousDue(verticalExit: pageHeight)
                        return
                    }
                } else if let grade = grade(for: t.width) {
                    commit(grade, for: item)
                    return
                }

                withAnimation(snapSpring) { drag = .zero }
                if flipped {
                    scheduleReviewAutoAdvance()
                } else {
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
            Text("Vuốt lên lướt thẻ · Vuốt trái/phải hoặc chọn mức nhớ")
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
                    .disabled(isGrading || isVerticalTransitioning)
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

    private func prepareNextCycleIfNeeded() {
        guard items.count > 1, index >= items.count - 1 else { return }
        let lastID = items[index].id
        if let existingFirst = nextCycleItems.first?.id,
           nextCycleItems.count == items.count,
           existingFirst != lastID {
            return
        }
        var shuffled = items.shuffled()
        if shuffled.first?.id == lastID, shuffled.count > 1 {
            shuffled.swapAt(0, Int.random(in: 1..<shuffled.count))
        }
        nextCycleItems = shuffled
    }

    private func browseNextDue(verticalExit: CGFloat) {
        guard items.count > 1, !isGrading, !isVerticalTransitioning else { return }
        prepareNextCycleIfNeeded()
        if index < items.count - 1 {
            let nextIndex = index + 1
            performVerticalReelTransition(direction: .forward, targetY: verticalExit) {
                index = nextIndex
            }
        } else {
            let committed = nextCycleItems.count == items.count ? nextCycleItems : items.shuffled()
            performVerticalReelTransition(direction: .forward, targetY: verticalExit) {
                items = committed
                nextCycleItems = []
                index = 0
            }
        }
    }

    private func browsePreviousDue(verticalExit: CGFloat) {
        guard index > 0, !isGrading, !isVerticalTransitioning else { return }
        let prevIndex = index - 1
        performVerticalReelTransition(direction: .backward, targetY: verticalExit) {
            index = prevIndex
        }
    }

    private func performVerticalReelTransition(
        direction: SlideDirection,
        targetY: CGFloat,
        apply: @escaping () -> Void
    ) {
        Haptics.selection()
        cancelReviewAutomation()
        stopSpeech()
        transitionTask?.cancel()
        transitionTask = nil

        animatedShift = drag
        drag = .zero
        reviewError = nil
        crossedThresholdGrade = nil
        activeSlideDirection = direction
        isVerticalTransitioning = true

        withAnimation(tiktokSlideCurve) {
            animatedShift = CGSize(width: 0, height: targetY)
        }

        transitionTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(390))
            guard !Task.isCancelled else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                apply()
                animatedShift = .zero
                drag = .zero
                flipped = false
                activeSlideDirection = nil
                isVerticalTransitioning = false
            }
            transitionTask = nil
        }
    }

    private func commit(_ grade: ReviewGrade, for item: DueItem) {
        guard !isGrading, !isVerticalTransitioning else { return }
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
                    removeCurrentAndAdvance(slug: item.card.slug)
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
        reviewError = nil
        if items.count > 1 {
            browseNextDue(verticalExit: -deckPageHeight)
        } else if let current = currentItem {
            withAnimation(advanceSpring) {
                removeCurrentAndAdvance(slug: current.card.slug)
            }
        }
    }

    private func removeCurrentAndAdvance(slug: String) {
        cancelReviewAutomation()
        stopSpeech()
        let previousIndex = index
        if let removalIdx = items.firstIndex(where: { $0.card.slug == slug }) {
            items.remove(at: removalIdx)
            if items.isEmpty {
                index = 0
            } else if index >= items.count {
                index = 0
            }
        }
        nextCycleItems = []
        flyAway = nil
        drag = .zero
        flipped = false
        crossedThresholdGrade = nil
        prepareNextCycleIfNeeded()
        if index == previousIndex && !items.isEmpty {
            speakCurrentIfNeeded(justFlipped: false)
            scheduleReviewAutoFlip()
        }
    }

    private func scheduleReviewAutoFlip() {
        autoFlipTask?.cancel()
        autoFlipTask = nil

        guard (theme.autoFlipFlashcard || theme.autoAdvanceFlashcard),
              scenePhase == .active,
              currentItem != nil,
              !flipped,
              !isGrading,
              !isVerticalTransitioning else {
            if flipped {
                scheduleReviewAutoAdvance()
            }
            return
        }

        let delayMs = Int((theme.autoFlipDelaySeconds * 1000).rounded())
        autoFlipTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMs))
            guard !Task.isCancelled,
                  (theme.autoFlipFlashcard || theme.autoAdvanceFlashcard),
                  scenePhase == .active,
                  currentItem != nil,
                  !flipped,
                  !isGrading,
                  !isVerticalTransitioning else { return }
            withAnimation(flipSpring) {
                flipped = true
            }
        }
    }

    private func scheduleReviewAutoAdvance() {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil

        guard theme.autoAdvanceFlashcard,
              scenePhase == .active,
              flipped,
              !isGrading,
              !isVerticalTransitioning,
              items.count > 1 else { return }

        let delayMs = Int((theme.autoAdvanceDelaySeconds * 1000).rounded())
        autoAdvanceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMs))
            guard !Task.isCancelled,
                  theme.autoAdvanceFlashcard,
                  scenePhase == .active,
                  flipped,
                  !isGrading,
                  !isVerticalTransitioning,
                  items.count > 1 else { return }

            // 1. Flip back to front face before gliding upward like TikTok.
            isAutoAdvancing = true
            withAnimation(flipSpring) {
                flipped = false
            }

            try? await Task.sleep(for: .milliseconds(460))
            guard !Task.isCancelled,
                  theme.autoAdvanceFlashcard,
                  scenePhase == .active,
                  !isGrading,
                  !isVerticalTransitioning,
                  items.count > 1 else {
                isAutoAdvancing = false
                return
            }

            isAutoAdvancing = false
            browseNextDue(verticalExit: -deckPageHeight)
        }
    }

    private func cancelReviewAutomation() {
        autoFlipTask?.cancel()
        autoAdvanceTask?.cancel()
        autoFlipTask = nil
        autoAdvanceTask = nil
        isAutoAdvancing = false
    }
}

// MARK: - Free Browse Deck (No FSRS mutation)

/// Free-study deck with TikTok-style vertical random browsing, synchronized card reels,
/// and flip → read → flip-back → vertical-glide automation.
struct FreeFlashcardDeckView: View {
    private enum SlideDirection {
        case forward
        case backward
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeStore.self) private var theme
    @Binding var cards: [Card]
    @Binding var index: Int
    var shuffleToken: UUID = UUID()
    var reverseMode: Bool = false
    var autoSpeak: Bool = false

    @State private var flipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var animatedShift: CGSize = .zero
    @State private var isTransitioning = false
    @State private var activeSlideDirection: SlideDirection?
    @State private var isAutoAdvancing = false
    @State private var nextCycleDeck: [Card] = []
    @State private var deckPageHeight: CGFloat = 560
    @State private var autoFlipTask: Task<Void, Never>?
    @State private var autoAdvanceTask: Task<Void, Never>?
    @State private var transitionTask: Task<Void, Never>?
    @State private var speakTask: Task<Void, Never>?

    private let flipSpring = Animation.spring(response: 0.44, dampingFraction: 0.82)
    private let tiktokSlideCurve = Animation.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.38)

    private var allowsVerticalSwipe: Bool {
        !flipped && !reverseMode
    }

    private var currentCard: Card? {
        cards.indices.contains(index) ? cards[index] : nil
    }

    private var nextCard: Card? {
        guard cards.count > 1 else { return nil }
        if index < cards.count - 1 {
            return cards[index + 1]
        }
        return nextCycleDeck.first
    }

    private var previousCard: Card? {
        guard index > 0, cards.indices.contains(index - 1) else { return nil }
        return cards[index - 1]
    }

    private var effectiveOffset: CGSize {
        isTransitioning ? animatedShift : dragOffset
    }

    private var isDraggingHorizontally: Bool {
        let off = effectiveOffset
        return abs(off.width) > abs(off.height) && abs(off.width) > 1
    }

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { geo in
                let pageHeight = max(geo.size.height + 24, 420)
                let off = effectiveOffset
                let horizontalMode = isDraggingHorizontally
                let verticalY = horizontalMode ? 0 : off.height
                let showPrev = (activeSlideDirection == .backward)
                    || (!horizontalMode && verticalY > 0)
                    || (horizontalMode && off.width > 0)
                let verticalProgress = min(1, abs(verticalY) / max(pageHeight, 1))
                let horizontalProgress = min(1, abs(off.width) / 140)

                ZStack {
                    if showPrev, let prev = previousCard {
                        let prevScale = horizontalMode
                            ? (0.955 + 0.045 * horizontalProgress)
                            : (0.95 + 0.05 * verticalProgress)
                        let prevY = horizontalMode
                            ? (12 - horizontalProgress * 12)
                            : (-pageHeight + verticalY)
                        FlashcardCardView(
                            card: prev,
                            flipped: false,
                            isTop: false,
                            reverseMode: reverseMode
                        )
                        .frame(maxWidth: 520)
                        .scaleEffect(prevScale)
                        .offset(y: prevY)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .id(prev.id)
                    } else if let next = nextCard {
                        let nextScale = horizontalMode
                            ? (0.955 + 0.045 * horizontalProgress)
                            : (0.95 + 0.05 * verticalProgress)
                        let nextY = horizontalMode
                            ? (12 - horizontalProgress * 12)
                            : (pageHeight + verticalY)
                        FlashcardCardView(
                            card: next,
                            flipped: false,
                            isTop: false,
                            reverseMode: reverseMode
                        )
                        .frame(maxWidth: 520)
                        .scaleEffect(nextScale)
                        .offset(y: nextY)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .id(next.id)
                    }

                    if let current = currentCard {
                        let currentScale = horizontalMode ? 1.0 : (1.0 - 0.04 * verticalProgress)
                        FlashcardCardView(
                            card: current,
                            flipped: flipped,
                            isTop: true,
                            reverseMode: reverseMode
                        )
                        .frame(maxWidth: 520)
                        .scaleEffect(currentScale)
                        .offset(x: horizontalMode ? off.width : off.width * 0.18, y: verticalY)
                        .rotationEffect(.degrees(horizontalMode ? Double(off.width / 24) : 0))
                        .zIndex(1)
                        .allowsHitTesting(!isTransitioning)
                        .gesture(browseDragGesture(pageHeight: pageHeight))
                        .onTapGesture {
                            guard !isTransitioning else { return }
                            Haptics.impact(.light)
                            cancelAutomation()
                            withAnimation(flipSpring) { flipped.toggle() }
                        }
                        .accessibilityHint("Chạm đúp để lật thẻ")
                        .accessibilityAction(named: "Lật thẻ") {
                            guard !isTransitioning else { return }
                            cancelAutomation()
                            withAnimation(flipSpring) { flipped.toggle() }
                        }
                        .id(current.id)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .clipped()
                .onAppear { deckPageHeight = pageHeight }
                .onChange(of: pageHeight) { _, newHeight in deckPageHeight = newHeight }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            controlsBar
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
        }
        .onAppear {
            prepareNextCycleIfNeeded()
            speakCurrentIfNeeded(justFlipped: false)
            scheduleAutoFlip()
        }
        .onChange(of: index) { _, _ in
            prepareNextCycleIfNeeded()
            speakCurrentIfNeeded(justFlipped: false)
            scheduleAutoFlip()
        }
        .onChange(of: shuffleToken) { _, _ in
            cancelAutomation()
            transitionTask?.cancel()
            transitionTask = nil
            isTransitioning = false
            activeSlideDirection = nil
            stopSpeech()
            animatedShift = .zero
            dragOffset = .zero
            flipped = false
            nextCycleDeck = []
            prepareNextCycleIfNeeded()
            speakCurrentIfNeeded(justFlipped: false)
            scheduleAutoFlip()
        }
        .onChange(of: flipped) { _, nowFlipped in
            if nowFlipped && reverseMode {
                speakCurrentIfNeeded(justFlipped: true)
            }

            if nowFlipped {
                scheduleAutoAdvance()
            } else if !isAutoAdvancing {
                autoAdvanceTask?.cancel()
                autoAdvanceTask = nil
            }
        }
        .onChange(of: theme.autoFlipFlashcard) { _, isEnabled in
            if isEnabled {
                scheduleAutoFlip()
            } else if !theme.autoAdvanceFlashcard {
                autoFlipTask?.cancel()
                autoFlipTask = nil
            }
        }
        .onChange(of: theme.autoFlipDelaySeconds) { _, _ in
            if (theme.autoFlipFlashcard || theme.autoAdvanceFlashcard) && !flipped {
                scheduleAutoFlip()
            }
        }
        .onChange(of: theme.autoAdvanceFlashcard) { _, isEnabled in
            if isEnabled {
                if flipped {
                    scheduleAutoAdvance()
                } else {
                    scheduleAutoFlip()
                }
            } else {
                autoAdvanceTask?.cancel()
                autoAdvanceTask = nil
                isAutoAdvancing = false
                if !theme.autoFlipFlashcard {
                    autoFlipTask?.cancel()
                    autoFlipTask = nil
                }
            }
        }
        .onChange(of: theme.autoAdvanceDelaySeconds) { _, _ in
            if theme.autoAdvanceFlashcard && flipped && !isAutoAdvancing {
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

    private func browseDragGesture(pageHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isTransitioning else { return }
                cancelAutomation()
                let t = value.translation
                if allowsVerticalSwipe {
                    if abs(t.height) >= abs(t.width) * 0.9 {
                        // Gentle resistance when pulling down on the very first card.
                        let clampedHeight = (index == 0 && t.height > 0) ? t.height * 0.28 : t.height
                        dragOffset = CGSize(width: t.width * 0.15, height: clampedHeight)
                    } else {
                        dragOffset = CGSize(width: t.width, height: 0)
                    }
                } else {
                    dragOffset = CGSize(width: t.width, height: 0)
                }
            }
            .onEnded { value in
                guard !isTransitioning else { return }
                let t = value.translation
                let pred = value.predictedEndTranslation

                if allowsVerticalSwipe && abs(t.height) >= abs(t.width) * 0.9 {
                    if (t.height < -65 || pred.height < -170) && cards.count > 1 {
                        advanceNext(verticalExit: -pageHeight)
                        return
                    }
                    if (t.height > 65 || pred.height > 170) && index > 0 {
                        moveBackward(verticalExit: pageHeight)
                        return
                    }
                } else {
                    if (t.width < -65 || pred.width < -170) && cards.count > 1 {
                        advanceNext(horizontalExit: -560)
                        return
                    }
                    if (t.width > 65 || pred.width > 170) && index > 0 {
                        moveBackward(horizontalExit: 560)
                        return
                    }
                }

                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
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
                moveBackward(verticalExit: deckPageHeight)
            } label: {
                Label("Trước", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(index == 0 || isTransitioning)

            Button {
                Haptics.impact(.light)
                cancelAutomation()
                withAnimation(flipSpring) { flipped.toggle() }
            } label: {
                Label("Lật thẻ", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.green)
            .disabled(isTransitioning)

            Button {
                advanceNext(verticalExit: -deckPageHeight)
            } label: {
                Label("Sau", systemImage: "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(cards.count <= 1 || isTransitioning)
        }
    }

    private func prepareNextCycleIfNeeded() {
        guard cards.count > 1, index >= cards.count - 1 else { return }
        let lastID = cards[index].id
        if let existingFirst = nextCycleDeck.first?.id,
           nextCycleDeck.count == cards.count,
           existingFirst != lastID {
            return
        }
        var shuffled = cards.shuffled()
        if shuffled.first?.id == lastID, shuffled.count > 1 {
            shuffled.swapAt(0, Int.random(in: 1..<shuffled.count))
        }
        nextCycleDeck = shuffled
    }

    private func advanceNext(verticalExit: CGFloat? = nil, horizontalExit: CGFloat? = nil) {
        guard cards.count > 1, !isTransitioning else { return }
        prepareNextCycleIfNeeded()
        let target: CGSize
        if let verticalExit {
            target = CGSize(width: 0, height: verticalExit)
        } else if let horizontalExit {
            target = CGSize(width: horizontalExit, height: 0)
        } else {
            target = CGSize(width: 0, height: -deckPageHeight)
        }

        if index < cards.count - 1 {
            let nextIndex = index + 1
            performReelTransition(direction: .forward, targetShift: target) {
                index = nextIndex
            }
        } else {
            let committedDeck = nextCycleDeck.count == cards.count ? nextCycleDeck : cards.shuffled()
            performReelTransition(direction: .forward, targetShift: target) {
                cards = committedDeck
                nextCycleDeck = []
                index = 0
            }
        }
    }

    private func moveBackward(verticalExit: CGFloat? = nil, horizontalExit: CGFloat? = nil) {
        guard index > 0, !isTransitioning else { return }
        let target: CGSize
        if let verticalExit {
            target = CGSize(width: 0, height: verticalExit)
        } else if let horizontalExit {
            target = CGSize(width: horizontalExit, height: 0)
        } else {
            target = CGSize(width: 0, height: deckPageHeight)
        }
        let prevIndex = index - 1
        performReelTransition(direction: .backward, targetShift: target) {
            index = prevIndex
        }
    }

    private func performReelTransition(
        direction: SlideDirection,
        targetShift: CGSize,
        apply: @escaping () -> Void
    ) {
        Haptics.selection()
        cancelAutomation()
        stopSpeech()
        transitionTask?.cancel()
        transitionTask = nil

        // Seed animatedShift from the user's current finger drag so the glide continues smoothly with no jump.
        animatedShift = dragOffset
        dragOffset = .zero
        activeSlideDirection = direction
        isTransitioning = true

        withAnimation(tiktokSlideCurve) {
            animatedShift = targetShift
        }

        transitionTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(390))
            guard !Task.isCancelled else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                apply()
                animatedShift = .zero
                dragOffset = .zero
                flipped = false
                activeSlideDirection = nil
                isTransitioning = false
            }
            transitionTask = nil
        }
    }

    private func scheduleAutoFlip() {
        autoFlipTask?.cancel()
        autoFlipTask = nil

        guard (theme.autoFlipFlashcard || theme.autoAdvanceFlashcard),
              scenePhase == .active,
              cards.indices.contains(index),
              !isTransitioning,
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
                  (theme.autoFlipFlashcard || theme.autoAdvanceFlashcard),
                  scenePhase == .active,
                  cards.indices.contains(index),
                  !isTransitioning,
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
              !isTransitioning,
              cards.count > 1 else { return }

        let delayMs = Int((theme.autoAdvanceDelaySeconds * 1000).rounded())
        autoAdvanceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMs))
            guard !Task.isCancelled,
                  theme.autoAdvanceFlashcard,
                  scenePhase == .active,
                  flipped,
                  !isTransitioning,
                  cards.count > 1 else { return }

            // 1. Flip back from meaning to front face so the word is reinforced cleanly.
            isAutoAdvancing = true
            withAnimation(flipSpring) {
                flipped = false
            }

            // 2. Let the 3D flip-back finish before gliding upward like TikTok to the next random card.
            try? await Task.sleep(for: .milliseconds(460))
            guard !Task.isCancelled,
                  theme.autoAdvanceFlashcard,
                  scenePhase == .active,
                  !isTransitioning,
                  cards.count > 1 else {
                isAutoAdvancing = false
                return
            }

            isAutoAdvancing = false
            advanceNext(verticalExit: -deckPageHeight)
        }
    }

    private func cancelAutomation() {
        autoFlipTask?.cancel()
        autoAdvanceTask?.cancel()
        autoFlipTask = nil
        autoAdvanceTask = nil
        isAutoAdvancing = false
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
