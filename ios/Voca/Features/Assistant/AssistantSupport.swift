import SwiftUI

/// Matches a tapped multiple-choice option against the server's `answer` string.
/// The backend may report the answer either as the full choice text or as a
/// letter label ("A"/"B"/…), so we tolerate both.
enum AnswerMatcher {
    static func isCorrect(choice: String, index: Int, answer: String) -> Bool {
        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = choice.trimmingCharacters(in: .whitespacesAndNewlines)
        if !a.isEmpty, c.caseInsensitiveCompare(a) == .orderedSame { return true }
        if a.count == 1, let scalar = a.uppercased().unicodeScalars.first,
           (65...90).contains(scalar.value) {
            return Int(scalar.value) - 65 == index
        }
        return false
    }
}

/// A→"A.", B→"B.", … used to label choices.
func choiceLetter(_ index: Int) -> String {
    guard index >= 0, let scalar = UnicodeScalar(65 + index) else { return "\(index + 1)." }
    return "\(Character(scalar))."
}

// MARK: - Shared styling

private struct ChipStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(.tertiarySystemFill), in: Capsule())
            .foregroundStyle(.secondary)
    }
}

extension View {
    /// A small capsule caption used for difficulty / skill / target-word tags.
    func chip() -> some View { modifier(ChipStyle()) }

    /// A padded rounded card background used across practice content.
    func practiceCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Shared interactive choices

/// Renders a list of multiple-choice options with single-shot selection.
/// After a tap it locks in, highlights the correct answer green and a wrong
/// pick red, then reveals the explanation (and `whyWrong` for the wrong pick).
/// Owns its own selection state so it can be reused per drill / reading question.
struct PracticeChoicesView: View {
    let choices: [String]
    let answer: String
    let explanation: String?
    var whyWrong: [String: String]? = nil
    /// When true, each choice gets a trailing speaker button that reads it aloud (TTS).
    var speakChoices: Bool = false

    @State private var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                if speakChoices {
                    HStack(alignment: .center, spacing: 8) {
                        choiceButton(index: index, choice: choice)
                        SpeakerButton(text: choice)
                    }
                } else {
                    choiceButton(index: index, choice: choice)
                }
            }
            if selected != nil { reveal }
        }
    }

    private func choiceButton(index: Int, choice: String) -> some View {
        let answered = selected != nil
        let correct = AnswerMatcher.isCorrect(choice: choice, index: index, answer: answer)
        let isPicked = selected == choice

        return Button {
            if selected == nil { selected = choice }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text(choiceLetter(index))
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(choice)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if answered && correct {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else if answered && isPicked {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                }
            }
            .padding(10)
            .background(fillColor(answered: answered, correct: correct, isPicked: isPicked),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(borderColor(answered: answered, correct: correct, isPicked: isPicked)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .allowsHitTesting(!answered)
    }

    private var reveal: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let explanation, !explanation.isEmpty {
                Label {
                    Text(explanation)
                } icon: {
                    Image(systemName: "lightbulb")
                }
                .font(.footnote)
            }
            if let sel = selected,
               let why = whyWrong?[sel], !why.isEmpty,
               !AnswerMatcher.isCorrect(choice: sel,
                                        index: choices.firstIndex(of: sel) ?? -1,
                                        answer: answer) {
                Text(why)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fillColor(answered: Bool, correct: Bool, isPicked: Bool) -> Color {
        guard answered else { return Color(.tertiarySystemBackground) }
        if correct { return .green.opacity(0.15) }
        if isPicked { return .red.opacity(0.15) }
        return Color(.tertiarySystemBackground)
    }

    private func borderColor(answered: Bool, correct: Bool, isPicked: Bool) -> Color {
        guard answered else { return Color(.separator) }
        if correct { return .green }
        if isPicked { return .red }
        return Color(.separator)
    }
}

// MARK: - Text-to-speech button

/// A small speaker button that synthesises `text` and plays it via `TTSService`.
/// Shows a spinner while the clip is being fetched and disables itself for empty text.
/// Failures (e.g. 503 TTS not configured) are swallowed silently so they don't break layout.
struct SpeakerButton: View {
    let text: String
    var font: Font = .body

    @State private var isBusy = false

    private var cleaned: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Button {
            play()
        } label: {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "speaker.wave.2.fill")
                    .font(font)
                    .foregroundStyle(Brand.green)
                    .frame(width: 22, height: 22)
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy || cleaned.isEmpty)
        .accessibilityLabel("Phát âm")
    }

    private func play() {
        let value = cleaned
        guard !value.isEmpty else { return }
        isBusy = true
        Task { @MainActor in
            defer { isBusy = false }
            try? await TTSService().speak(value)
        }
    }
}

// MARK: - Chips

/// A word + IPA capsule used by the speaking view (word on top, IPA below).
struct WordIPAChip: View {
    let word: String
    let ipa: String?

    var body: some View {
        VStack(spacing: 1) {
            Text(word)
                .font(.caption2.weight(.semibold))
            if let ipa, !ipa.isEmpty {
                Text(ipa)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Brand.greenSoft, in: Capsule())
        .foregroundStyle(Brand.green)
    }
}
