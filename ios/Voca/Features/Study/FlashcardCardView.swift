import SwiftUI

/// A single flashcard surface with a smooth 3D flip between front and back, supporting reverse recall mode.
struct FlashcardCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let card: Card
    var flipped: Bool = false
    var isTop: Bool = false
    var reverseMode: Bool = false

    var body: some View {
        ZStack {
            cardSurface {
                if reverseMode { meaningFace(isFront: true) } else { wordFace(isFront: true) }
            }
            .opacity(flipped ? 0 : 1)

            cardSurface {
                if reverseMode { wordFace(isFront: false) } else { meaningFace(isFront: false) }
            }
            .opacity(flipped ? 1 : 0)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
    }

    // MARK: - Surface

    @ViewBuilder private func cardSurface<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Brand.cardFill(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Brand.green.opacity(colorScheme == .dark ? 0.10 : 0.05),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Brand.green.opacity(colorScheme == .dark ? 0.22 : 0.16), lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 18, x: 0, y: 10)
    }

    // MARK: - Card Metadata Header

    private var metaStrip: some View {
        HStack(spacing: 6) {
            VocaPillBadge(
                text: card.isChinese ? "中文" : "English",
                tint: card.isChinese ? .orange : Brand.green
            )

            if let pos = card.partOfSpeech, !pos.isEmpty {
                Badge(text: pos, color: Brand.green)
            }

            Spacer(minLength: 4)

            if let level = CardLevel(card.level) {
                Badge(text: level.label, color: Brand.levelColor(level.rawValue))
            }
        }
    }

    // MARK: - Word Face

    @ViewBuilder private func wordFace(isFront: Bool) -> some View {
        VStack(spacing: 14) {
            metaStrip

            Spacer(minLength: 0)

            Text(card.word)
                .font(card.isChinese
                      ? VocaTypography.hanziFont(size: 62, weight: .bold)
                      : .system(size: 40, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.45)
                .lineLimit(3)

            if let phonetic = card.phonetic {
                Text(phonetic)
                    .font(card.isChinese ? .title3.weight(.medium) : .system(.title3, design: .monospaced))
                    .foregroundStyle(card.isChinese ? Brand.green : .secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        Brand.elevatedFill(for: colorScheme),
                        in: Capsule()
                    )
            }

            if isTop {
                PronounceButton(
                    text: card.word,
                    language: card.cardLanguage,
                    size: 48,
                    font: .title2,
                    tintedCapsule: true
                )
                .padding(.top, 4)
            }

            if !isFront {
                if let meaning = card.meaningVi, !meaning.isEmpty {
                    Text(meaning)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)

            if isTop && isFront {
                Label("Chạm để lật", systemImage: "hand.tap.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Meaning Face

    @ViewBuilder private func meaningFace(isFront: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                if !isFront {
                    Text(card.word)
                        .font(card.isChinese ? VocaTypography.hanziFont(size: 26, weight: .bold) : .title3.weight(.bold))
                        .foregroundStyle(.primary)
                    if let phonetic = card.phonetic {
                        Text(phonetic)
                            .font(.subheadline)
                            .foregroundStyle(card.isChinese ? Brand.green : .secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if isTop {
                        PronounceButton(
                            text: card.word,
                            language: card.cardLanguage,
                            size: 34,
                            font: .body,
                            tintedCapsule: true
                        )
                    }
                } else {
                    metaStrip
                }
            }

            Divider().opacity(0.6)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if let vi = card.meaningVi, !vi.isEmpty {
                        block("Nghĩa tiếng Việt", titleColor: Brand.green) {
                            Text(vi)
                                .font(isFront ? .title2.weight(.bold) : .title3.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !card.isChinese, let en = card.meaningEn, !en.isEmpty {
                        block("English Meaning") {
                            Text(en)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !isFront, let examples = card.examples?.filter({ !$0.isEmpty }), !examples.isEmpty {
                        block("Ví dụ") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(examples.prefix(2).enumerated()), id: \.offset) { _, raw in
                                    if card.isChinese {
                                        let parsed = ChineseExample(raw)
                                        HStack(alignment: .top, spacing: 8) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(parsed.hanzi)
                                                    .font(.subheadline.weight(.semibold))
                                                if let pinyin = parsed.pinyin {
                                                    Text(pinyin)
                                                        .font(.caption)
                                                        .foregroundStyle(Brand.green)
                                                }
                                                if let meaning = parsed.meaningVi {
                                                    Text(meaning)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            Spacer(minLength: 4)
                                            if isTop {
                                                PronounceButton(
                                                    text: parsed.hanzi,
                                                    language: .chinese,
                                                    size: 28,
                                                    font: .caption
                                                )
                                            }
                                        }
                                    } else {
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("“\(raw)”")
                                                .font(.callout)
                                                .italic()
                                                .foregroundStyle(.secondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            if isTop {
                                                PronounceButton(
                                                    text: raw,
                                                    language: .english,
                                                    size: 28,
                                                    font: .caption
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !isFront, let tip = card.memoryTip, !tip.isEmpty {
                        block("Mẹo ghi nhớ") {
                            Text(tip)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if isFront && isTop {
                HStack {
                    Spacer()
                    Label("Chạm để xem từ gốc", systemImage: "hand.tap.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
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
                .font(.caption.weight(.bold))
                .foregroundStyle(titleColor)
            content()
        }
    }
}
