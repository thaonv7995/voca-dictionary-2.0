import SwiftUI

// MARK: - Stat tile

/// A compact labelled metric card used in Today and Stats dashboards.
struct StatTile: View {
    let title: String
    let value: Int
    var color: Color = Brand.semanticSuccess
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text("\(value)")
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard(padding: 14, cornerRadius: 16)
    }
}

// MARK: - Mastery ring

/// A circular themed progress ring showing a 0...1 `fraction` with percentage inside.
struct MasteryRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 11
    var size: CGFloat = 100

    private var clamped: Double { min(max(fraction, 0), 1) }
    private var percent: Int { Int((clamped * 100).rounded()) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Brand.greenSoft, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    Brand.gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: clamped)
            VStack(spacing: 0) {
                Text("\(percent)%")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Brand.green)
                    .contentTransition(.numericText())
                Text("thành thạo")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tiến độ thành thạo \(percent) phần trăm")
    }
}

// MARK: - Recent card row

/// One row in the "Thẻ gần đây" list with Chinese calligraphy support, star indicator, and TTS button.
struct RecentCardRow: View {
    @Environment(LocalLearnerStore.self) private var learner
    let card: Card

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(card.word)
                        .font(card.isChinese ? VocaTypography.hanziFont(size: 20, weight: .bold, isCalligraphic: ThemeStore.shared.hanziCalligraphic) : .headline)
                    if let phonetic = card.phonetic {
                        Text(phonetic)
                            .font(.subheadline)
                            .foregroundStyle(card.isChinese ? Brand.green : .secondary)
                            .lineLimit(1)
                    }
                    if learner.isFavorite(card.slug) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                if let meaningVi = card.meaningVi, !meaningVi.isEmpty {
                    Text(meaningVi)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if let level = CardLevel(card.level) {
                Badge(text: level.label, color: Brand.levelColor(level.rawValue))
            }

            PronounceButton(text: card.word, language: card.cardLanguage)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
