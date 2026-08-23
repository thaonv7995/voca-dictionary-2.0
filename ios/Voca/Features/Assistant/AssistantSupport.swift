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
            .lineLimit(1)
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
                        PronounceButton(text: choice)
                    }
                } else {
                    choiceButton(index: index, choice: choice)
                }
            }
            if selected != nil {
                reveal
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func choiceButton(index: Int, choice: String) -> some View {
        let answered = selected != nil
        let correct = AnswerMatcher.isCorrect(choice: choice, index: index, answer: answer)
        let isPicked = selected == choice

        return Button {
            if selected == nil {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { selected = choice }
            }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text(choiceLetter(index))
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(choice)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if answered && correct {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else if answered && isPicked {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .transition(.scale.combined(with: .opacity))
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
        .animation(.easeInOut(duration: 0.22), value: selected)
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

// MARK: - Typing indicator

/// Three green dots that pulse in sequence — shown inside an assistant bubble while
/// awaiting the first streamed chunk. Replaces a plain spinner for a livelier "typing…" feel.
struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Brand.green.opacity(0.7))
                    .frame(width: 7, height: 7)
                    .scaleEffect(animating ? 1 : 0.5)
                    .opacity(animating ? 1 : 0.35)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                        value: animating)
            }
        }
        .onAppear { animating = true }
        .accessibilityLabel("Đang soạn trả lời")
    }
}

// MARK: - Chat send button

/// V1-style circular send button that sits inside the rounded chat composer:
/// a filled `Brand.green` circle (dimmed when disabled) with a white arrow, or a
/// white spinner while the reply is streaming. Fixed size so the composer never reflows.
struct ChatSendButton: View {
    var isStreaming: Bool
    var canSend: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(canSend || isStreaming ? Brand.green : Color.secondary.opacity(0.4))
                if isStreaming {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 36, height: 36)
            .animation(.easeInOut(duration: 0.18), value: canSend)
        }
        .buttonStyle(PressableScaleStyle(scale: 0.88))
        .disabled(!canSend)
        .accessibilityLabel("Gửi")
    }
}

// MARK: - Button styles

/// Subtle press feedback for primary CTAs: scales down slightly and dims while pressed.
struct PressableScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Primary filled-green CTA (generate / "Ôn tập ngay" style) with a gentle press scale
/// and an animated disabled fade. Replaces `.borderedProminent` where we want that extra polish.
struct BrandCTAButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Brand.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.2), value: isEnabled)
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
