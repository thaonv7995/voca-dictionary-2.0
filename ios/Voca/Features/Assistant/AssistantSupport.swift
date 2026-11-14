import SwiftUI

/// Matches a tapped multiple-choice option against the server's `answer` string.
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

/// A->"A.", B->"B.", ... used to label choices.
func choiceLetter(_ index: Int) -> String {
    guard index >= 0, let scalar = UnicodeScalar(65 + index) else { return "\(index + 1)." }
    return "\(Character(scalar))."
}

private func choiceBadgeChar(_ index: Int) -> String {
    guard index >= 0, let scalar = UnicodeScalar(65 + index) else { return "\(index + 1)" }
    return String(Character(scalar))
}

// MARK: - Shared styling

private struct ChipStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
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
            .brandCard(padding: 16, cornerRadius: 16)
    }
}

// MARK: - Shared interactive choices

/// Renders multiple-choice options with circular letter badges, haptic feedback, and explanation reveal.
struct PracticeChoicesView: View {
    @Environment(\.colorScheme) private var colorScheme

    let choices: [String]
    let answer: String
    let explanation: String?
    var whyWrong: [String: String]? = nil
    var speakChoices: Bool = false
    var language: CardLanguage = .english
    var onAnswered: ((Bool) -> Void)? = nil

    @State private var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                if speakChoices {
                    HStack(alignment: .center, spacing: 8) {
                        choiceButton(index: index, choice: choice)
                        PronounceButton(
                            text: choice,
                            language: choice.hasChineseCharacters ? .chinese : language,
                            size: 34,
                            tintedCapsule: true
                        )
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
                if correct {
                    Haptics.notify(.success)
                } else {
                    Haptics.notify(.error)
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { selected = choice }
                onAnswered?(correct)
            }
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text(choiceBadgeChar(index))
                    .font(.caption.weight(.bold))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(badgeForeground(answered: answered, correct: correct, isPicked: isPicked))
                    .background(badgeFill(answered: answered, correct: correct, isPicked: isPicked), in: Circle())

                Text(choice)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                if answered && correct {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Brand.semanticSuccess)
                        .transition(.scale.combined(with: .opacity))
                } else if answered && isPicked {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(11)
            .background(
                fillColor(answered: answered, correct: correct, isPicked: isPicked),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor(answered: answered, correct: correct, isPicked: isPicked), lineWidth: answered && (correct || isPicked) ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .animation(.easeInOut(duration: 0.22), value: selected)
        .allowsHitTesting(!answered)
        .accessibilityLabel("\(choiceLetter(index)) \(choice)")
    }

    private var reveal: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let explanation, !explanation.isEmpty {
                Label {
                    Text(explanation)
                } icon: {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.orange)
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
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.elevatedFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func badgeForeground(answered: Bool, correct: Bool, isPicked: Bool) -> Color {
        guard answered else { return .secondary }
        if correct || isPicked { return .white }
        return .secondary
    }

    private func badgeFill(answered: Bool, correct: Bool, isPicked: Bool) -> Color {
        guard answered else { return Color.primary.opacity(0.08) }
        if correct { return Brand.semanticSuccess }
        if isPicked { return .red }
        return Color.primary.opacity(0.08)
    }

    private func fillColor(answered: Bool, correct: Bool, isPicked: Bool) -> Color {
        guard answered else { return Brand.elevatedFill(for: colorScheme) }
        if correct { return Brand.semanticSuccess.opacity(0.14) }
        if isPicked { return Color.red.opacity(0.14) }
        return Brand.elevatedFill(for: colorScheme)
    }

    private func borderColor(answered: Bool, correct: Bool, isPicked: Bool) -> Color {
        guard answered else { return Brand.hairlineBorder(for: colorScheme) }
        if correct { return Brand.semanticSuccess }
        if isPicked { return .red }
        return Brand.hairlineBorder(for: colorScheme)
    }
}

// MARK: - Typing indicator

/// Three themed dots that pulse in sequence — shown inside an assistant bubble while awaiting chunks.
struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Brand.green.opacity(0.75))
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

/// Circular send button sitting inside the rounded chat composer.
struct ChatSendButton: View {
    var isStreaming: Bool
    var canSend: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(canSend || isStreaming ? Brand.green : Color.secondary.opacity(0.35))
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

// MARK: - Chips

/// A word + IPA capsule used by the speaking view.
struct WordIPAChip: View {
    let word: String
    let ipa: String?

    var body: some View {
        VStack(spacing: 1) {
            Text(word)
                .font(.caption.weight(.semibold))
            if let ipa, !ipa.isEmpty {
                Text(ipa)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Brand.greenSoft, in: Capsule())
        .overlay(Capsule().strokeBorder(Brand.green.opacity(0.22), lineWidth: 0.8))
        .foregroundStyle(Brand.green)
    }
}
