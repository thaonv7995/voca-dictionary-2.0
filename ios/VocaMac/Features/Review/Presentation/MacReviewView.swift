import SwiftUI

struct MacReviewCard: Identifiable, Equatable, Sendable {
    let id: String
    let prompt: String
    let pronunciation: String?
    let meaning: String
    let example: String?
    let language: MacVocabularyItem.Language

    static let previewCards: [MacReviewCard] = [
        MacReviewCard(
            id: "concise",
            prompt: "concise",
            pronunciation: "/kənˈsaɪs/",
            meaning: "Giving a lot of information clearly in a few words.",
            example: "The report is concise and easy to understand.",
            language: .english
        ),
        MacReviewCard(
            id: "jianchi",
            prompt: "坚持",
            pronunciation: "jiān chí",
            meaning: "To persist; to keep doing something despite difficulty.",
            example: "只要坚持，就会看到进步。",
            language: .chinese
        ),
        MacReviewCard(
            id: "nuance",
            prompt: "nuance",
            pronunciation: "/ˈnuːɑːns/",
            meaning: "A subtle difference in meaning, expression, or sound.",
            example: "She understands the nuances of the language.",
            language: .english
        )
    ]
}

enum MacReviewGrade: String, CaseIterable, Identifiable, Sendable {
    case again
    case hard
    case good
    case easy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .again:
            "Lại"
        case .hard:
            "Khó"
        case .good:
            "Tốt"
        case .easy:
            "Dễ"
        }
    }

    var keyboardKey: KeyEquivalent {
        switch self {
        case .again:
            "1"
        case .hard:
            "2"
        case .good:
            "3"
        case .easy:
            "4"
        }
    }

    var systemImage: String {
        switch self {
        case .again:
            "arrow.counterclockwise"
        case .hard:
            "tortoise"
        case .good:
            "checkmark"
        case .easy:
            "hare"
        }
    }

    var tint: Color {
        switch self {
        case .again:
            .red
        case .hard:
            .orange
        case .good:
            .green
        case .easy:
            .blue
        }
    }

    var intervalHint: String {
        switch self {
        case .again:
            "< 10 phút"
        case .hard:
            "~2 ngày"
        case .good:
            "~5 ngày"
        case .easy:
            "~12 ngày"
        }
    }
}

struct MacReviewView: View {
    enum Phase: Equatable {
        case overview
        case prompt
        case revealed
        case completed
    }

    @Environment(MacReviewStore.self) private var review
    @Environment(MacTodayStore.self) private var today
    @Environment(MacVocabularyStore.self) private var vocabulary
    @Environment(MacSpeechService.self) private var speech
    @Environment(MacPreferencesStore.self) private var preferences
    @Environment(\.openWindow) private var openWindow

    @ViewState private var currentIndex = 0
    @ViewState private var phase: Phase = .overview
    @ViewState private var grades: [MacReviewCard.ID: MacReviewGrade] = [:]
    @ViewState private var undoStack: [(card: MacReviewCard, index: Int)] = []

    private let closeReview: () -> Void
    private let isFocusWindow: Bool

    init(
        isFocusWindow: Bool = false,
        closeReview: @escaping () -> Void = {}
    ) {
        self.isFocusWindow = isFocusWindow
        self.closeReview = closeReview
    }

    private var cards: [MacReviewCard] {
        review.cards
    }

    var body: some View {
        Group {
            switch phase {
            case .overview:
                overview
            case .prompt, .revealed:
                session
            case .completed:
                completion
            }
        }
        .navigationTitle("Ôn tập")
        .background(VocaDesign.subtleWindowBackground)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                if phase == .prompt || phase == .revealed {
                    Button {
                        pauseSession()
                    } label: {
                        Label("Tạm dừng", systemImage: "pause")
                    }
                    .keyboardShortcut(".", modifiers: .command)
                }

                if !undoStack.isEmpty && (phase == .prompt || phase == .revealed || phase == .completed) {
                    Button {
                        undoLastGrade()
                    } label: {
                        Label("Hoàn tác", systemImage: "arrow.uturn.backward")
                    }
                    .keyboardShortcut("z", modifiers: .command)
                    .help("Hoàn tác thẻ vừa chấm (⌘Z)")
                }

                if !isFocusWindow && !cards.isEmpty {
                    Button {
                        openWindow(id: "review-focus")
                    } label: {
                        Label(
                            "Cửa sổ tập trung",
                            systemImage: "macwindow.on.rectangle"
                        )
                    }
                }
            }
        }
        .task {
            await review.load()
            restoreRecoveredSessionIfAvailable()

            if cards.isEmpty {
                phase = .overview
            } else if isFocusWindow && phase == .overview {
                startOrResume()
            }
        }
        .onChange(of: currentIndex) { _, _ in
            maybeAutoPlayAudio()
        }
        .alert(
            "Không lưu được kết quả ôn tập",
            isPresented: Binding(
                get: { review.submissionError != nil },
                set: { isPresented in
                    if !isPresented {
                        review.dismissSubmissionError()
                    }
                }
            )
        ) {
            Button("OK") {
                review.dismissSubmissionError()
            }
        } message: {
            Text(
                review.submissionError
                    ?? "Vui lòng thử gửi lại kết quả ôn tập."
            )
        }
    }

    private var overview: some View {
        VStack(spacing: 28) {
            VocaIconBadge(
                systemImage: cards.isEmpty ? "checkmark.seal.fill" : "rectangle.stack.fill.badge.play",
                tint: cards.isEmpty ? VocaDesign.brandGreen : VocaDesign.accentIndigo,
                size: 76,
                iconSize: 34
            )
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(cards.isEmpty ? "Không có thẻ đến hạn" : "Sẵn sàng ôn tập")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text(overviewDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            if review.isLoading && cards.isEmpty {
                ProgressView("Đang tải danh sách thẻ…")
                    .controlSize(.large)
            } else if let errorMessage = review.loadErrorMessage,
                      cards.isEmpty {
                ContentUnavailableView {
                    Label(
                        "Không tải được thẻ ôn tập",
                        systemImage: "exclamationmark.triangle"
                    )
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Thử lại") {
                        Task {
                            await review.retry()
                        }
                    }
                    .buttonStyle(VocaPrimaryButtonStyle())
                }
            } else if !cards.isEmpty {
                HStack(spacing: 20) {
                    VocaSurfaceCard(padding: 18, cornerRadius: 16) {
                        metric(
                            value: "\(remainingCardCount)",
                            label: "Thẻ đến hạn"
                        )
                    }
                    .frame(width: 150)

                    VocaSurfaceCard(padding: 18, cornerRadius: 16) {
                        metric(
                            value: estimatedDuration,
                            label: "Thời gian ước tính"
                        )
                    }
                    .frame(width: 150)
                }

                HStack(spacing: 14) {
                    Button {
                        startOrResume()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text(
                                currentIndex == 0 && grades.isEmpty
                                    ? "Bắt đầu ôn tập"
                                    : "Tiếp tục ôn tập"
                            )
                        }
                        .frame(minWidth: 140)
                    }
                    .buttonStyle(VocaPrimaryButtonStyle())
                    .keyboardShortcut(.return, modifiers: [])

                    if !isFocusWindow {
                        Button {
                            openWindow(id: "review-focus")
                        } label: {
                            Label(
                                "Cửa sổ tập trung",
                                systemImage: "macwindow.on.rectangle"
                            )
                        }
                        .buttonStyle(VocaSecondaryButtonStyle())
                    }
                }
            } else {
                Button("Quay lại Hôm nay", action: closeReview)
                    .buttonStyle(VocaPrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
    }

    private var session: some View {
        VStack(spacing: 0) {
            sessionHeader

            Divider()
                .opacity(0.5)

            ScrollView {
                VStack(spacing: 20) {
                    reviewCard
                        .frame(maxWidth: 740)

                    sessionControls
                        .frame(maxWidth: 740)

                    // Keyboard Shortcut Hint Strip
                    HStack(spacing: 14) {
                        HStack(spacing: 5) {
                            VocaKeycap(label: "Space")
                            Text("Lật thẻ")
                        }
                        Text("·").foregroundStyle(.quaternary)
                        HStack(spacing: 5) {
                            VocaKeycap(label: "1–4")
                            Text("Chấm điểm")
                        }
                        Text("·").foregroundStyle(.quaternary)
                        HStack(spacing: 5) {
                            VocaKeycap(label: "⌘Z")
                            Text("Hoàn tác")
                        }
                        Text("·").foregroundStyle(.quaternary)
                        HStack(spacing: 5) {
                            VocaKeycap(label: "⌘P")
                            Text("Phát âm")
                        }
                        Text("·").foregroundStyle(.quaternary)
                        HStack(spacing: 5) {
                            VocaKeycap(label: "⌘.")
                            Text("Tạm dừng")
                        }
                    }
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
        }
    }

    private var sessionHeader: some View {
        HStack(spacing: 16) {
            VocaPillBadge(
                text: "Thẻ \(displayedCardNumber) / \(cards.count)",
                icon: "rectangle.stack.fill",
                tint: VocaDesign.brandGreen
            )

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(VocaDesign.brandGradient)
                        .frame(
                            width: geo.size.width * CGFloat(Double(currentIndex) / Double(max(cards.count, 1)))
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
                }
            }
            .frame(height: 8)
            .accessibilityLabel("Tiến độ ôn tập")
            .accessibilityValue(
                "Đã hoàn thành \(currentIndex) / \(cards.count) thẻ"
            )

            Text("Còn lại \(remainingCardCount) thẻ")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
    }

    private var currentVocabularyItem: MacVocabularyItem? {
        vocabulary.items.first(where: { $0.id == currentCard.id })
    }

    private var reviewCard: some View {
        let richItem = currentVocabularyItem
        return VStack(spacing: 22) {
            HStack(spacing: 8) {
                VocaPillBadge(
                    text: currentCard.language == .chinese ? "中文" : "English",
                    icon: "globe",
                    tint: currentCard.language == .chinese ? VocaDesign.accentAmber : VocaDesign.accentSky
                )

                if let pos = richItem?.partOfSpeech, !pos.isEmpty {
                    VocaPillBadge(
                        text: pos,
                        tint: VocaDesign.brandGreen
                    )
                }

                if let topic = richItem?.topic, !topic.isEmpty {
                    Text("· \(topic)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    speech.toggle(
                        currentCard.prompt,
                        language: currentCard.language
                    )
                } label: {
                    HStack(spacing: 6) {
                        Image(
                            systemName: speech.isSpeaking && speech.speakingText == currentCard.prompt
                                ? "stop.fill"
                                : "speaker.wave.2.fill"
                        )
                        Text(
                            speech.isSpeaking && speech.speakingText == currentCard.prompt
                                ? "Dừng"
                                : "Nghe"
                        )
                        .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(VocaDesign.brandGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        VocaDesign.brandGreen.opacity(0.12),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut("p", modifiers: .command)
                .help("Nghe phát âm (⌘P)")
                .accessibilityHint(
                    "Uses the native macOS voice for this review card."
                )
            }

            Spacer(minLength: 8)

            VStack(spacing: 12) {
                Text(currentCard.prompt)
                    .font(
                        currentCard.language == .chinese
                            ? VocaDesign.hanziFont(size: 62, weight: .bold)
                            : .system(size: 46, weight: .bold, design: .rounded)
                    )
                    .tracking(currentCard.language == .chinese ? 3.0 : 0)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)

                if let pronunciation = currentCard.pronunciation {
                    Text(pronunciation)
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .foregroundStyle(currentCard.language == .chinese ? VocaDesign.brandGreen : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .background(
                            Color.primary.opacity(0.05),
                            in: Capsule()
                        )
                        .textSelection(.enabled)
                }

                if phase == .prompt {
                    Text("Nhấn Space hoặc click vào thẻ để xem đáp án")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
            }

            if phase == .revealed {
                Divider()
                    .padding(.horizontal, 24)

                VStack(spacing: 14) {
                    Text(richItem?.displayMeaningVi ?? currentCard.meaning)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(VocaDesign.brandGreen)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)

                    if let meaningEn = richItem?.meaningEn,
                       !meaningEn.isEmpty,
                       meaningEn != (richItem?.displayMeaningVi ?? currentCard.meaning) {
                        Text(meaningEn)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 560)
                    }

                    if let example = currentCard.example {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(VocaDesign.brandGreen.opacity(0.6))
                                .frame(width: 3, height: 28)

                            Text(example)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .italic()
                                .multilineTextAlignment(.leading)
                                .textSelection(.enabled)

                            Button {
                                speech.toggle(example, language: currentCard.language)
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 26, height: 26)
                                    .background(Color.primary.opacity(0.06), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }

                    if let memoryTip = richItem?.memoryTip, !memoryTip.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(VocaDesign.accentAmber)
                            Text(memoryTip)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(VocaDesign.accentAmber.opacity(0.10))
                        )
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .padding(36)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.94))
                .shadow(color: Color.black.opacity(0.07), radius: 20, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    phase == .revealed
                        ? VocaDesign.brandGreen.opacity(0.30)
                        : Color.primary.opacity(0.08),
                    lineWidth: 1.2
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            if phase == .prompt {
                reveal()
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: phase)
    }

    @ViewBuilder
    private var sessionControls: some View {
        if phase == .prompt {
            Button {
                reveal()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "eye.fill")
                    Text("Hiện đáp án")
                    VocaKeycap(label: "Space")
                }
                .frame(maxWidth: 320)
            }
            .buttonStyle(VocaPrimaryButtonStyle(isFullWidth: true))
            .keyboardShortcut(.space, modifiers: [])
        } else {
            HStack(spacing: 12) {
                ForEach(MacReviewGrade.allCases) { grade in
                    Button {
                        submit(grade)
                    } label: {
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: grade.systemImage)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(grade.title)
                                    .font(.headline)
                            }
                            .foregroundStyle(grade.tint)

                            Text(grade.intervalHint)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)

                            VocaKeycap(label: String(grade.keyboardKey.character))
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(grade.tint.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(grade.tint.opacity(0.28), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(grade.keyboardKey, modifiers: [])
                    .accessibilityHint(
                        "Nhấn \(String(grade.keyboardKey.character))"
                    )
                }
            }
        }
    }

    private var completion: some View {
        VStack(spacing: 28) {
            VocaIconBadge(
                systemImage: "checkmark.seal.fill",
                tint: VocaDesign.brandGreen,
                size: 80,
                iconSize: 38
            )
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Hoàn thành phiên ôn tập")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("Bạn đã ôn tập \(grades.count) thẻ trong phiên này.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            gradeSummary

            HStack(spacing: 14) {
                Button("Ôn tập lại") {
                    reset()
                }
                .buttonStyle(VocaSecondaryButtonStyle())

                Button("Quay lại Hôm nay", action: closeReview)
                    .buttonStyle(VocaPrimaryButtonStyle())
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
    }

    private var gradeSummary: some View {
        HStack(spacing: 14) {
            ForEach(MacReviewGrade.allCases) { grade in
                VocaSurfaceCard(padding: 16, cornerRadius: 14) {
                    VStack(spacing: 6) {
                        Image(systemName: grade.systemImage)
                            .font(.title3)
                            .foregroundStyle(grade.tint)

                        Text("\(gradeCount(grade))")
                            .font(.system(size: 26, weight: .bold, design: .rounded))

                        Text(grade.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(width: 110)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.weight(.semibold))

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 90)
        .accessibilityElement(children: .combine)
    }

    private var currentCard: MacReviewCard {
        cards[min(currentIndex, max(cards.count - 1, 0))]
    }

    private var displayedCardNumber: Int {
        min(currentIndex + 1, cards.count)
    }

    private var remainingCardCount: Int {
        max(cards.count - currentIndex, 0)
    }

    private var estimatedDuration: String {
        let minutes = max(Int(ceil(Double(remainingCardCount) * 0.25)), 1)
        return "\(minutes) phút"
    }

    private var overviewDescription: String {
        if cards.isEmpty {
            return "Không có thẻ nào đang chờ ôn tập hôm nay."
        }

        if currentIndex > 0 || !grades.isEmpty {
            return "Phiên học của bạn đang tạm dừng và sẵn sàng tiếp tục."
        }

        return "Ôn tập các từ vựng đến hạn với 4 mức ghi nhớ quen thuộc."
    }

    private func startOrResume() {
        guard !cards.isEmpty else { return }
        phase = grades[currentCard.id] == nil ? .prompt : .revealed
        review.saveSessionProgress(currentIndex: currentIndex, grades: grades)
        maybeAutoPlayAudio()
    }

    private func pauseSession() {
        review.saveSessionProgress(currentIndex: currentIndex, grades: grades)
        phase = .overview
    }

    private func reveal() {
        guard phase == .prompt else { return }
        phase = .revealed
    }

    private func submit(_ grade: MacReviewGrade) {
        guard phase == .revealed, !cards.isEmpty else { return }

        let card = currentCard
        let submittedIndex = currentIndex
        let cardCountBeforeSubmission = cards.count

        Task {
            let wasSubmitted = await review.submit(
                cardID: card.id,
                grade: grade
            )

            guard wasSubmitted else {
                return
            }

            undoStack.append((card: card, index: submittedIndex))
            grades[card.id] = grade
            today.recordCompletedReview()
            vocabulary.markReviewed(cardID: card.id)

            if cardCountBeforeSubmission > 1,
               !review.cards.isEmpty {
                currentIndex = min(
                    currentIndex,
                    review.cards.count - 1
                )
                phase = .prompt
                review.saveSessionProgress(
                    currentIndex: currentIndex,
                    grades: grades
                )
                maybeAutoPlayAudio()
            } else {
                currentIndex = review.cards.count
                review.clearSessionProgress()
                phase = .completed
            }
        }
    }

    private func undoLastGrade() {
        guard let last = undoStack.popLast() else { return }
        grades.removeValue(forKey: last.card.id)
        review.restoreCard(last.card, at: last.index)
        currentIndex = min(max(last.index, 0), max(review.cards.count - 1, 0))
        withAnimation(.snappy(duration: 0.2)) {
            phase = .revealed
        }
        review.saveSessionProgress(currentIndex: currentIndex, grades: grades)
    }

    private func gradeCount(_ grade: MacReviewGrade) -> Int {
        grades.values.filter { $0 == grade }.count
    }

    private func reset() {
        currentIndex = 0
        grades = [:]
        undoStack = []
        review.clearSessionProgress()

        Task {
            await review.load()
            phase = review.cards.isEmpty ? .overview : .prompt
            maybeAutoPlayAudio()
        }
    }

    private func restoreRecoveredSessionIfAvailable() {
        guard let recovery = review.activeSessionRecovery,
              !cards.isEmpty
        else {
            return
        }

        currentIndex = min(max(recovery.currentIndex, 0), cards.count - 1)
        var restoredGrades: [MacReviewCard.ID: MacReviewGrade] = [:]
        for (cardID, rawGrade) in recovery.gradesByCardID {
            if let grade = MacReviewGrade(rawValue: rawGrade) {
                restoredGrades[cardID] = grade
            }
        }
        grades = restoredGrades
    }

    private func maybeAutoPlayAudio() {
        guard preferences.playAudioAutomatically,
              phase == .prompt,
              !cards.isEmpty
        else {
            return
        }

        speech.speak(
            currentCard.prompt,
            language: currentCard.language
        )
    }
}

struct MacReviewView_Previews: PreviewProvider {
    static var previews: some View {
        MacReviewView()
            .environment(
                MacReviewStore(
                    repository: PreviewMacReviewRepository()
                )
            )
            .environment(MacTodayStore())
            .environment(MacVocabularyStore())
            .environment(MacPreferencesStore())
            .environment(MacSpeechService())
            .frame(width: 980, height: 720)
    }
}
