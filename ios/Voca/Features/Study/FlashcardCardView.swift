import SwiftUI

/// A single flashcard surface with a 3D flip between a word "front" and a meaning "back".
/// Purely presentational: the owning `FlashcardDeckView` drives `flipped` and the drag transform.
struct FlashcardCardView: View {
    let card: Card
    /// Whether the back face is showing. Only meaningful for the top card.
    var flipped: Bool = false
    /// The interactive top card shows the speaker + hint affordances; peeking cards don't.
    var isTop: Bool = false
    var isSpeaking: Bool = false
    var onSpeak: () -> Void = {}

    var body: some View {
        ZStack {
            cardSurface { frontFace }
                .opacity(flipped ? 0 : 1)

            cardSurface { backFace }
                .opacity(flipped ? 1 : 0)
                // Pre-rotate the back so its content reads correctly once the container hits 180°.
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }

    // MARK: - Surface (brandCard-style, larger radius + shadow)

    @ViewBuilder private func cardSurface<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Brand.green.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
    }

    // MARK: - Front

    @ViewBuilder private var frontFace: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            if let pos = card.partOfSpeech, !pos.isEmpty {
                Badge(text: pos, color: Brand.green)
            }

            Text(card.word)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(3)

            if let phonetic = frontPhonetic {
                Text(phonetic)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if isTop {
                Button(action: onSpeak) {
                    HStack(spacing: 8) {
                        if isSpeaking {
                            ProgressView()
                        } else {
                            Image(systemName: "speaker.wave.2.fill")
                        }
                        Text("Phát âm")
                    }
                }
                .buttonStyle(.bordered)
                .tint(Brand.green)
                .disabled(isSpeaking)
                .padding(.top, 4)
            }

            Spacer(minLength: 0)

            if isTop {
                Label("Chạm để lật", systemImage: "hand.tap.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var frontPhonetic: String? {
        if let ipa = card.ipa, !ipa.isEmpty { return ipa }
        if let pron = card.pronunciation, !pron.isEmpty { return pron }
        return nil
    }

    // MARK: - Back

    @ViewBuilder private var backFace: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(card.word)
                .font(.headline)
                .foregroundStyle(.secondary)

            if let vi = card.meaningVi, !vi.isEmpty {
                block("Nghĩa", titleColor: Brand.green) {
                    Text(vi).font(.title2.weight(.semibold))
                }
            }

            if let en = card.meaningEn, !en.isEmpty {
                block("Meaning") {
                    Text(en).font(.body)
                }
            }

            if let example = card.examples?.first(where: { !$0.isEmpty }) {
                block("Ví dụ") {
                    Text(example).font(.callout).italic()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private func block<V: View>(
        _ title: String,
        titleColor: Color = .secondary,
        @ViewBuilder _ content: () -> V
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(titleColor)
            content()
        }
    }
}
