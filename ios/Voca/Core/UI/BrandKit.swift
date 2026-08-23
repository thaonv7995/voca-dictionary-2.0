import SwiftUI

/// Shared brand styling so every feature looks like one app (green brand, ported from V1).
enum Brand {
    /// Primary brand green (mirrors the asset-catalog AccentColor).
    static let green = Color(red: 0.086, green: 0.639, blue: 0.463)
    /// Soft tint for pill/badge backgrounds.
    static let greenSoft = Color(red: 0.086, green: 0.639, blue: 0.463).opacity(0.14)

    /// Color for a card learning level ("new"/"learning"/"known"/"mastered").
    static func levelColor(_ level: String?) -> Color {
        switch level?.lowercased() {
        case "new": return .blue
        case "learning": return .orange
        case "known": return Brand.green
        case "mastered": return .purple
        default: return .secondary
        }
    }
}

/// A small rounded pill label (kind / difficulty / level / topic tags), V1-style.
struct Badge: View {
    let text: String
    var color: Color = Brand.green
    var soft: Bool = true

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(soft ? color : .white)
            .background(soft ? color.opacity(0.14) : color, in: Capsule())
    }
}

/// Reusable pronunciation button. The icon⇄spinner swap happens inside a FIXED-size frame so
/// tapping it never reflows surrounding content (fixes the "everything shifts down" bug).
struct PronounceButton: View {
    let text: String
    var voiceModel: String? = nil
    var size: CGFloat = 30
    var font: Font = .body

    @State private var speaking = false

    var body: some View {
        Button {
            guard !speaking, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            speaking = true
            Task {
                try? await TTSService().speak(text, voiceModel: voiceModel)
                speaking = false
            }
        } label: {
            ZStack {
                ProgressView().controlSize(.small).opacity(speaking ? 1 : 0)
                Image(systemName: "speaker.wave.2.fill").font(font).opacity(speaking ? 0 : 1)
            }
            .frame(width: size, height: size)          // fixed footprint → no layout shift
            .foregroundStyle(Brand.green)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Phát âm")
    }
}

extension View {
    /// Standard card surface used across practice/detail screens.
    func brandCard() -> some View {
        self
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
