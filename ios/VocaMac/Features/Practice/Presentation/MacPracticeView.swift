import SwiftUI

struct MacPracticeActivity: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case multipleChoice
        case reading
        case listening
        case writing

        var title: String {
            switch self {
            case .multipleChoice:
                "Multiple Choice"
            case .reading:
                "Reading"
            case .listening:
                "Listening"
            case .writing:
                "Writing"
            }
        }

        var systemImage: String {
            switch self {
            case .multipleChoice:
                "checklist"
            case .reading:
                "text.book.closed"
            case .listening:
                "headphones"
            case .writing:
                "pencil.line"
            }
        }

        var description: String {
            switch self {
            case .multipleChoice:
                "Choose the best meaning for each word."
            case .reading:
                "Read short passages using saved vocabulary."
            case .listening:
                "Recognize vocabulary from pronunciation."
            case .writing:
                "Recall and type the correct word."
            }
        }
    }

    let id: String
    let kind: Kind
    let estimatedMinutes: Int
    let itemCount: Int

    static let defaults: [MacPracticeActivity] = [
        MacPracticeActivity(
            id: "multiple-choice",
            kind: .multipleChoice,
            estimatedMinutes: 4,
            itemCount: 10
        ),
        MacPracticeActivity(
            id: "reading",
            kind: .reading,
            estimatedMinutes: 6,
            itemCount: 5
        ),
        MacPracticeActivity(
            id: "listening",
            kind: .listening,
            estimatedMinutes: 5,
            itemCount: 8
        ),
        MacPracticeActivity(
            id: "writing",
            kind: .writing,
            estimatedMinutes: 7,
            itemCount: 8
        )
    ]
}

struct MacPracticeQuestion: Identifiable, Equatable, Sendable {
    let id: String
    let prompt: String
    let detail: String?
    let options: [String]
    let correctAnswer: String
    let language: MacVocabularyItem.Language
    let audioText: String?

    init(
        id: String,
        prompt: String,
        detail: String?,
        options: [String],
        correctAnswer: String,
        language: MacVocabularyItem.Language = .english,
        audioText: String? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.detail = detail
        self.options = options
        self.correctAnswer = correctAnswer
        self.language = language
        self.audioText = audioText
    }

    static let multipleChoice: [MacPracticeQuestion] = [
        MacPracticeQuestion(
            id: "concise",
            prompt: "concise",
            detail: "/kənˈsaɪs/",
            options: [
                "Brief and clear",
                "Difficult to understand",
                "Strongly emotional",
                "Repeated many times"
            ],
            correctAnswer: "Brief and clear",
            language: .english,
            audioText: "concise"
        ),
        MacPracticeQuestion(
            id: "jianchi",
            prompt: "坚持",
            detail: "jiān chí",
            options: [
                "To persist",
                "To simplify",
                "To discover",
                "To compare"
            ],
            correctAnswer: "To persist",
            language: .chinese,
            audioText: "坚持"
        ),
        MacPracticeQuestion(
            id: "nuance",
            prompt: "nuance",
            detail: "/ˈnuːɑːns/",
            options: [
                "A subtle difference",
                "A clear instruction",
                "A common mistake",
                "A final decision"
            ],
            correctAnswer: "A subtle difference",
            language: .english,
            audioText: "nuance"
        )
    ]

    static func generate(
        for kind: MacPracticeActivity.Kind,
        from items: [MacVocabularyItem],
        maxCount: Int = 10
    ) -> [MacPracticeQuestion] {
        let pool = items.count >= 4
            ? items
            : (items + MacVocabularyItem.previewItems)

        var uniquePool: [MacVocabularyItem] = []
        var seenIDs: Set<String> = []
        for item in pool where seenIDs.insert(item.id).inserted {
            uniquePool.append(item)
        }

        guard !uniquePool.isEmpty else {
            return multipleChoice
        }

        let prioritized = uniquePool.sorted { left, right in
            if left.isDue != right.isDue {
                return left.isDue
            }
            if left.isFavorite != right.isFavorite {
                return left.isFavorite
            }
            return left.term < right.term
        }

        let targetItems = Array(prioritized.prefix(max(maxCount, 1)))
        let allMeanings = uniquePool.map(\.meaning)
        let allTerms = uniquePool.map(\.term)

        return targetItems.enumerated().map { index, item in
            switch kind {
            case .multipleChoice:
                let distractors = deterministicDistractors(
                    excluding: item.meaning,
                    candidates: allMeanings,
                    seed: index
                )
                let options = rotatedOptions(
                    correct: item.meaning,
                    distractors: distractors,
                    seed: index
                )
                return MacPracticeQuestion(
                    id: item.id,
                    prompt: item.term,
                    detail: item.pronunciation,
                    options: options,
                    correctAnswer: item.meaning,
                    language: item.language,
                    audioText: item.term
                )

            case .listening:
                let distractors = deterministicDistractors(
                    excluding: item.meaning,
                    candidates: allMeanings,
                    seed: index + 3
                )
                let options = rotatedOptions(
                    correct: item.meaning,
                    distractors: distractors,
                    seed: index + 1
                )
                return MacPracticeQuestion(
                    id: item.id,
                    prompt: "Listen and choose the meaning",
                    detail: item.pronunciation ?? item.language.title,
                    options: options,
                    correctAnswer: item.meaning,
                    language: item.language,
                    audioText: item.term
                )

            case .reading:
                let exampleSentence = item.examples.first
                    ?? "Context: Understanding “\(item.term)” is essential in this passage."
                let masked = exampleSentence.replacingOccurrences(
                    of: item.term,
                    with: "____",
                    options: [.caseInsensitive]
                )
                let distractors = deterministicDistractors(
                    excluding: item.term,
                    candidates: allTerms,
                    seed: index + 5
                )
                let options = rotatedOptions(
                    correct: item.term,
                    distractors: distractors,
                    seed: index + 2
                )
                return MacPracticeQuestion(
                    id: item.id,
                    prompt: masked == exampleSentence
                        ? "\(exampleSentence)\n\nWhich word matches “\(item.meaning)”?"
                        : masked,
                    detail: item.meaning,
                    options: options,
                    correctAnswer: item.term,
                    language: item.language,
                    audioText: item.term
                )

            case .writing:
                let distractors = deterministicDistractors(
                    excluding: item.term,
                    candidates: allTerms,
                    seed: index + 7
                )
                let options = rotatedOptions(
                    correct: item.term,
                    distractors: distractors,
                    seed: index
                )
                return MacPracticeQuestion(
                    id: item.id,
                    prompt: item.meaning,
                    detail: item.pronunciation,
                    options: options,
                    correctAnswer: item.term,
                    language: item.language,
                    audioText: item.term
                )
            }
        }
    }

    private static func deterministicDistractors(
        excluding correct: String,
        candidates: [String],
        seed: Int
    ) -> [String] {
        let filtered = candidates.filter {
            $0.caseInsensitiveCompare(correct) != .orderedSame
        }
        guard !filtered.isEmpty else {
            return ["Option A", "Option B", "Option C"]
        }

        var selected: [String] = []
        var offset = seed
        while selected.count < min(3, filtered.count) {
            let candidate = filtered[offset % filtered.count]
            if !selected.contains(candidate) {
                selected.append(candidate)
            }
            offset += 1
        }
        return selected
    }

    private static func rotatedOptions(
        correct: String,
        distractors: [String],
        seed: Int
    ) -> [String] {
        var list = distractors
        let insertIndex = seed % (list.count + 1)
        list.insert(correct, at: insertIndex)
        return list
    }
}

struct MacPracticeView: View {
    enum Phase: Equatable {
        case activitySelection
        case question
        case answerFeedback
        case completed
    }

    @Environment(MacVocabularyStore.self) private var vocabulary
    @Environment(MacActivityLedger.self) private var ledger
    @Environment(MacTodayStore.self) private var today
    @Environment(MacSpeechService.self) private var speech

    @ViewState private var phase: Phase = .activitySelection
    @ViewState private var practiceLanguageFilter: MacVocabularyItem.Language? = .english
    @ViewState private var selectedActivity: MacPracticeActivity?
    @ViewState private var questions: [MacPracticeQuestion] = []
    @ViewState private var currentQuestionIndex = 0
    @ViewState private var selectedAnswer: String?
    @ViewState private var typedAnswer = ""
    @ViewState private var correctAnswerCount = 0
    @FocusState private var isWritingFieldFocused: Bool

    private let activities: [MacPracticeActivity]
    private let closePractice: () -> Void

    init(
        activities: [MacPracticeActivity] = MacPracticeActivity.defaults,
        closePractice: @escaping () -> Void = {}
    ) {
        self.activities = activities
        self.closePractice = closePractice
    }

    var body: some View {
        Group {
            switch phase {
            case .activitySelection:
                activitySelection
            case .question, .answerFeedback:
                practiceSession
            case .completed:
                completion
            }
        }
        .navigationTitle("Practice")
        .background(VocaDesign.subtleWindowBackground)
        .toolbar {
            if phase == .question || phase == .answerFeedback {
                ToolbarItem(placement: .navigation) {
                    Button {
                        phase = .activitySelection
                    } label: {
                        Label("End Practice", systemImage: "xmark")
                    }
                    .keyboardShortcut(".", modifiers: .command)
                }
            }
        }
        .task {
            if vocabulary.items.isEmpty {
                await vocabulary.load()
            }
        }
    }

    private var filteredPracticeVocabulary: [MacVocabularyItem] {
        guard let practiceLanguageFilter else {
            return vocabulary.items
        }
        return vocabulary.items.filter { $0.language == practiceLanguageFilter }
    }

    private var activitySelection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Practice")
                                .font(.largeTitle.weight(.bold))

                            Text(
                                "Strengthen vocabulary without changing your review schedule."
                            )
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        practiceLanguageSwitcher
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Practice")
                                .font(.largeTitle.weight(.bold))

                            Text(
                                "Strengthen vocabulary without changing your review schedule."
                            )
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        }

                        practiceLanguageSwitcher
                    }
                }

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 270, maximum: 560), spacing: 16)
                    ],
                    spacing: 16
                ) {
                    ForEach(activities) { activity in
                        activityCard(activity)
                    }
                }

                VocaSurfaceCard(padding: 16, cornerRadius: 14) {
                    HStack(spacing: 14) {
                        VocaIconBadge(
                            systemImage: "sparkles",
                            tint: VocaDesign.accentIndigo,
                            size: 36,
                            iconSize: 16
                        )

                        Text(
                            "Practice answers are tracked separately from "
                            + "FSRS Review grades and do not change due dates."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        Spacer()
                    }
                }
            }
            .frame(maxWidth: 1200, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }

    private func activityTint(_ kind: MacPracticeActivity.Kind) -> Color {
        switch kind {
        case .multipleChoice:
            return VocaDesign.brandGreen
        case .reading:
            return VocaDesign.accentIndigo
        case .listening:
            return VocaDesign.accentSky
        case .writing:
            return VocaDesign.accentAmber
        }
    }

    private func activityCard(
        _ activity: MacPracticeActivity
    ) -> some View {
        let tint = activityTint(activity.kind)
        return VocaSurfaceCard(padding: 22, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VocaIconBadge(
                        systemImage: activity.kind.systemImage,
                        tint: tint,
                        size: 46,
                        iconSize: 20
                    )

                    Spacer()

                    VocaPillBadge(
                        text: "\(activity.estimatedMinutes) min",
                        icon: "clock",
                        tint: tint
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(activity.kind.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))

                    Text(activity.kind.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                HStack {
                    Label(
                        "\(min(max(vocabulary.items.count, 3), activity.itemCount)) questions",
                        systemImage: "list.number"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button("Start Session") {
                        start(activity)
                    }
                    .buttonStyle(VocaPrimaryButtonStyle(tint: tint))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 196, alignment: .leading)
        }
    }

    private var practiceSession: some View {
        VStack(spacing: 0) {
            sessionHeader

            Divider().opacity(0.6)

            ScrollView {
                VStack(spacing: 24) {
                    // Elevated Question Card
                    VocaSurfaceCard(padding: 28, cornerRadius: 22) {
                        VStack(spacing: 14) {
                            HStack {
                                VocaPillBadge(
                                    text: currentQuestion.language == .chinese ? "中文" : "English",
                                    icon: "globe",
                                    tint: currentQuestion.language == .chinese
                                        ? VocaDesign.accentAmber
                                        : VocaDesign.accentSky
                                )

                                Spacer()

                                if let audioText = currentQuestion.audioText {
                                    Button {
                                        speech.toggle(
                                            audioText,
                                            language: currentQuestion.language
                                        )
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(
                                                systemName: speech.isSpeaking
                                                    && speech.speakingText == audioText
                                                    ? "stop.fill"
                                                    : "speaker.wave.2.fill"
                                            )
                                            Text(
                                                speech.isSpeaking
                                                    && speech.speakingText == audioText
                                                    ? "Stop"
                                                    : "Listen"
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
                                }
                            }

                            Text(currentQuestion.prompt)
                                .font(
                                    .system(
                                        size: promptFontSize(for: currentQuestion.prompt),
                                        weight: .bold,
                                        design: .rounded
                                    )
                                )
                                .multilineTextAlignment(.center)
                                .textSelection(.enabled)
                                .padding(.top, 4)

                            if let detail = currentQuestion.detail {
                                Text(detail)
                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(0.05), in: Capsule())
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: 640)

                    if selectedActivity?.kind == .writing {
                        writingInputSection
                            .frame(maxWidth: 480)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(
                                Array(currentQuestion.options.enumerated()),
                                id: \.element
                            ) { index, option in
                                answerButton(
                                    option,
                                    keyboardNumber: index + 1
                                )
                            }
                        }
                        .frame(maxWidth: 640)
                    }

                    if phase == .answerFeedback {
                        feedback
                            .frame(maxWidth: 640)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(36)
            }

            Divider().opacity(0.6)

            sessionFooter
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(.bar)
        }
        .onChange(of: currentQuestionIndex) { _, _ in
            if selectedActivity?.kind == .listening,
               let audio = currentQuestion.audioText {
                speech.speak(audio, language: currentQuestion.language)
            }
        }
    }

    private var writingInputSection: some View {
        VStack(spacing: 14) {
            VocaInputField(
                icon: "pencil.line",
                placeholder: "Type the matching word…",
                text: $typedAnswer,
                isFocused: isWritingFieldFocused,
                onSubmit: {
                    submitTypedAnswer()
                }
            )
            .focused($isWritingFieldFocused)
            .disabled(phase == .answerFeedback)

            if phase == .question {
                Button("Check Answer") {
                    submitTypedAnswer()
                }
                .buttonStyle(VocaPrimaryButtonStyle(isFullWidth: true))
                .disabled(
                    typedAnswer
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                )
            }
        }
    }

    private var sessionHeader: some View {
        HStack(spacing: 16) {
            VocaPillBadge(
                text: selectedActivity?.kind.title ?? "Practice",
                icon: selectedActivity?.kind.systemImage ?? "sparkles",
                tint: selectedActivity.map { activityTint($0.kind) } ?? VocaDesign.brandGreen
            )

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(VocaDesign.brandGradient)
                        .frame(
                            width: geo.size.width * CGFloat(Double(currentQuestionIndex) / Double(max(questions.count, 1)))
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentQuestionIndex)
                }
            }
            .frame(height: 8)

            Text(
                "\(currentQuestionIndex + 1) of \(questions.count)"
            )
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private func answerButton(
        _ option: String,
        keyboardNumber: Int
    ) -> some View {
        let tint = answerTint(for: option)
        return Button {
            selectAnswer(option)
        } label: {
            HStack(spacing: 14) {
                VocaKeycap(label: "\(keyboardNumber)")

                Text(option)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if phase == .answerFeedback {
                    answerIndicator(for: option)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        tint != nil
                            ? tint!.opacity(0.12)
                            : Color(nsColor: .controlBackgroundColor).opacity(0.92)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        tint != nil
                            ? tint!.opacity(0.45)
                            : Color.primary.opacity(0.10),
                        lineWidth: tint != nil ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(phase == .answerFeedback)
        .keyboardShortcut(
            KeyEquivalent(Character(String(keyboardNumber))),
            modifiers: []
        )
    }

    @ViewBuilder
    private func answerIndicator(for option: String) -> some View {
        if option == currentQuestion.correctAnswer {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Correct answer")
        } else if option == selectedAnswer {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel("Incorrect answer")
        }
    }

    private var feedback: some View {
        let isCorrect = isAnswerCorrect(selectedAnswer)
        let tint = isCorrect ? VocaDesign.brandGreen : VocaDesign.accentAmber

        return HStack(spacing: 10) {
            Image(
                systemName: isCorrect
                    ? "checkmark.circle.fill"
                    : "info.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(tint)

            Text(
                isCorrect
                    ? "Correct! Great recall."
                    : "Correct answer: \(currentQuestion.correctAnswer)"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.32), lineWidth: 1)
        )
    }

    private var sessionFooter: some View {
        HStack {
            VocaPillBadge(
                text: "\(correctAnswerCount) correct",
                icon: "checkmark.circle.fill",
                tint: VocaDesign.brandGreen
            )

            Spacer()

            if phase == .answerFeedback {
                Button {
                    advance()
                } label: {
                    HStack(spacing: 6) {
                        Text(isLastQuestion ? "Finish Session" : "Next Question")
                        Image(
                            systemName: isLastQuestion
                                ? "checkmark.circle.fill"
                                : "arrow.right"
                        )
                    }
                }
                .buttonStyle(VocaPrimaryButtonStyle())
                .keyboardShortcut(.return, modifiers: [])
            } else if selectedActivity?.kind == .writing {
                Text("Type the matching word and press Return")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Choose an answer or press 1–4")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var completion: some View {
        let scoreRatio = Double(correctAnswerCount) / Double(max(questions.count, 1))
        return VStack(spacing: 28) {
            ZStack {
                Circle()
                    .stroke(VocaDesign.brandGreen.opacity(0.16), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: scoreRatio)
                    .stroke(
                        VocaDesign.brandGradient,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(Int(round(scoreRatio * 100)))%")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Accuracy")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 112, height: 112)

            VStack(spacing: 8) {
                Text("Practice Complete")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text(
                    "You answered \(correctAnswerCount) of "
                    + "\(questions.count) correctly."
                )
                .font(.title3)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                Button("Practice Again") {
                    restart()
                }
                .buttonStyle(VocaSecondaryButtonStyle())

                Button("Back to Today", action: closePractice)
                    .buttonStyle(VocaPrimaryButtonStyle())
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
    }

    private var currentQuestion: MacPracticeQuestion {
        questions[
            min(
                currentQuestionIndex,
                max(questions.count - 1, 0)
            )
        ]
    }

    private var isLastQuestion: Bool {
        currentQuestionIndex + 1 >= questions.count
    }

    private var practiceLanguageSwitcher: some View {
        let options: [(label: String, lang: MacVocabularyItem.Language)] = [
            ("English", .english),
            ("中文", .chinese)
        ]

        return HStack(spacing: 3) {
            ForEach(options, id: \.label) { opt in
                let isSelected = practiceLanguageFilter == opt.lang
                let count = vocabulary.items.filter { $0.language == opt.lang }.count

                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        practiceLanguageFilter = opt.lang
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(opt.label)
                            .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                        Text("\(count)")
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.white.opacity(0.22) : Color.primary.opacity(0.08))
                            )
                    }
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                isSelected
                                    ? (opt.lang == .chinese ? VocaDesign.accentAmber : VocaDesign.brandGreen)
                                    : Color.clear
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }

    private func start(_ activity: MacPracticeActivity) {
        selectedActivity = activity

        let sourceItems = filteredPracticeVocabulary.isEmpty ? vocabulary.items : filteredPracticeVocabulary
        questions = MacPracticeQuestion.generate(
            for: activity.kind,
            from: sourceItems,
            maxCount: activity.itemCount
        )
        currentQuestionIndex = 0
        correctAnswerCount = 0
        selectedAnswer = nil
        typedAnswer = ""
        phase = questions.isEmpty ? .completed : .question

        if activity.kind == .writing {
            isWritingFieldFocused = true
        } else if activity.kind == .listening,
                  let first = questions.first,
                  let audioText = first.audioText {
            speech.speak(audioText, language: first.language)
        }
    }

    private func selectAnswer(_ answer: String) {
        guard phase == .question else { return }

        selectedAnswer = answer

        if isAnswerCorrect(answer) {
            correctAnswerCount += 1
        }

        phase = .answerFeedback
    }

    private func submitTypedAnswer() {
        let trimmed = typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, phase == .question else { return }
        selectAnswer(trimmed)
    }

    private func isAnswerCorrect(_ answer: String?) -> Bool {
        guard let answer else { return false }
        return answer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .compare(
                currentQuestion.correctAnswer,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
    }

    private func advance() {
        guard phase == .answerFeedback else { return }

        if isLastQuestion {
            if let activity = selectedActivity {
                ledger.recordPractice(
                    activityKind: activity.kind,
                    questionCount: questions.count,
                    correctCount: correctAnswerCount
                )
                today.refreshFromLocalLedger()
            }
            phase = .completed
        } else {
            currentQuestionIndex += 1
            selectedAnswer = nil
            typedAnswer = ""
            phase = .question

            if selectedActivity?.kind == .writing {
                isWritingFieldFocused = true
            } else if selectedActivity?.kind == .listening,
                      let audioText = currentQuestion.audioText {
                speech.speak(audioText, language: currentQuestion.language)
            }
        }
    }

    private func restart() {
        guard let selectedActivity else {
            phase = .activitySelection
            return
        }

        start(selectedActivity)
    }

    private func answerTint(for option: String) -> Color? {
        guard phase == .answerFeedback else { return nil }

        if option == currentQuestion.correctAnswer {
            return .green
        }

        if option == selectedAnswer {
            return .red
        }

        return nil
    }

    private func promptFontSize(for value: String) -> CGFloat {
        if value.count > 24 {
            return 24
        }
        return containsHanCharacters(value) ? 48 : 40
    }

    private func containsHanCharacters(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
    }
}

struct MacPracticeView_Previews: PreviewProvider {
    static var previews: some View {
        MacPracticeView()
            .environment(
                MacVocabularyStore(
                    repository: PreviewMacVocabularyRepository()
                )
            )
            .environment(MacActivityLedger())
            .environment(MacTodayStore())
            .environment(MacSpeechService())
            .frame(width: 1040, height: 760)
    }
}
