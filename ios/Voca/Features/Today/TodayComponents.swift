import SwiftUI

// MARK: - Stat tile

/// A small labelled metric card used in the Today dashboard's stats grid.
/// Tinted by `color` (e.g. `Brand.levelColor` per learning level).
struct StatTile: View {
    let title: String
    let value: Int
    var color: Color = Brand.green
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text("\(value)")
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}

// MARK: - Mastery ring

/// A circular progress ring (Brand green) showing a 0…1 `fraction` with the percentage
/// in the centre. Null-safe: clamps out-of-range values so 0 cards → 0%.
struct MasteryRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 12
    var size: CGFloat = 108

    private var clamped: Double { min(max(fraction, 0), 1) }
    private var percent: Int { Int((clamped * 100).rounded()) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Brand.greenSoft, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    Brand.green,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: clamped)
            VStack(spacing: 0) {
                Text("\(percent)%")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Brand.green)
                    .contentTransition(.numericText())
                Text("thành thạo")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tiến độ thành thạo \(percent) phần trăm")
    }
}

// MARK: - Recent card row

/// One row in the "Thẻ gần đây" list: word + IPA + meaning, a level badge and a speaker button.
struct RecentCardRow: View {
    let card: Card

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(card.word)
                        .font(.headline)
                    if let ipa = card.ipa, !ipa.isEmpty {
                        Text(ipa)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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

            PronounceButton(text: card.word)
        }
        .contentShape(Rectangle())
    }
}
