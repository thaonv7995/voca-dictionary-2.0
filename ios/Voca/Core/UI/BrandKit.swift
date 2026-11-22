import SwiftUI
import WidgetKit

/// Shared brand tokens and surface styling that adapt dynamically to the active `ThemeStore` palette.
enum Brand {
    /// Active primary brand accent (mirrors selected `VocaPalette`, defaults to Voca Emerald).
    @MainActor static var green: Color { ThemeStore.shared.accent }
    /// Secondary deep gradient shade for the active palette.
    @MainActor static var deep: Color { ThemeStore.shared.deepAccent }
    /// Secondary ambient glow tint.
    @MainActor static var secondaryGlow: Color { ThemeStore.shared.secondaryGlow }
    /// Soft tint for pill/badge/chip backgrounds.
    @MainActor static var greenSoft: Color { ThemeStore.shared.accentSoft }
    /// Linear gradient across primary -> deep accent.
    @MainActor static var gradient: LinearGradient { ThemeStore.shared.gradient }

    /// Constant emerald for semantic success/confirmation independent of selected theme palette.
    static let semanticSuccess = Color(red: 0.086, green: 0.639, blue: 0.463)

    /// Color for a card learning level ("new"/"learning"/"known"/"mastered").
    static func levelColor(_ level: String?) -> Color {
        switch level?.lowercased() {
        case "new": return Color(red: 0.055, green: 0.565, blue: 0.914)
        case "learning": return Color(red: 0.945, green: 0.553, blue: 0.055)
        case "known": return semanticSuccess
        case "mastered": return Color(red: 0.545, green: 0.361, blue: 0.965)
        default: return .secondary
        }
    }

    static func canvasBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.055, green: 0.071, blue: 0.118) // #0E121E (Inkwell midnight slate)
            : Color(red: 0.953, green: 0.957, blue: 0.969) // #F3F4F7
    }

    static func cardFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.094, green: 0.122, blue: 0.192) // #181F31
            : Color(.systemBackground)
    }

    static func elevatedFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.129, green: 0.165, blue: 0.251)
            : Color(.secondarySystemBackground)
    }

    static func hairlineBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.09)
            : Color.black.opacity(0.06)
    }

    static func readingPaper(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.082, green: 0.106, blue: 0.173)
            : Color(red: 0.976, green: 0.957, blue: 0.918) // #F9F4EA warm editorial paper
    }

    static func readingPaperBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color(red: 0.855, green: 0.808, blue: 0.725)
    }
}

// MARK: - Ambient Theme Background

struct VocaThemeBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    private var theme = ThemeStore.shared

    var body: some View {
        ZStack {
            Brand.canvasBackground(for: colorScheme)

            LinearGradient(
                colors: [
                    theme.accent.opacity(colorScheme == .dark ? 0.08 : 0.035),
                    Color.clear,
                    theme.secondaryGlow.opacity(colorScheme == .dark ? 0.05 : 0.02)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Brand Logo Mark

struct VocaBrandMark: View {
    var size: CGFloat = 44

    var body: some View {
        let corner = size * 0.25
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.11, green: 0.78, blue: 0.49),
                            Color(red: 0.05, green: 0.45, blue: 0.34)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.24), lineWidth: max(1, size * 0.032))
                )

            RoundedRectangle(cornerRadius: size * 0.13, style: .continuous)
                .fill(Color.white.opacity(0.24))
                .frame(width: size * 0.56, height: size * 0.62)
                .rotationEffect(.degrees(9))
                .offset(x: size * 0.06, y: -size * 0.04)

            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                    .fill(Color.white)
                    .frame(width: size * 0.58, height: size * 0.62)
                    .shadow(color: .black.opacity(0.18), radius: size * 0.06, y: size * 0.03)
                    .overlay {
                        Text("V")
                            .font(.system(size: size * 0.38, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.05, green: 0.52, blue: 0.34))
                            .offset(y: -size * 0.01)
                    }

                Text("文")
                    .font(.system(size: size * 0.19, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.27, height: size * 0.27)
                    .background(
                        RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                            .fill(Color(red: 0.90, green: 0.22, blue: 0.29))
                    )
                    .offset(x: size * 0.07, y: size * 0.05)
            }
            .offset(x: -size * 0.03, y: size * 0.01)
        }
        .frame(width: size, height: size)
        .shadow(color: Brand.semanticSuccess.opacity(0.24), radius: size * 0.16, y: size * 0.07)
    }
}

// MARK: - Language Switcher

struct CardLanguagePicker: View {
    @Binding var selection: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var visualSelection: String = ""

    private var activeValue: String {
        visualSelection.isEmpty ? selection : visualSelection
    }

    private var selectedIndex: Int {
        CardLanguage.allCases.firstIndex(where: { $0.rawValue == activeValue }) ?? 0
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CardLanguage.allCases) { language in
                let isSelected = activeValue == language.rawValue
                Button {
                    guard selection != language.rawValue else { return }
                    Haptics.selection()
                    visualSelection = language.rawValue
                    selection = language.rawValue
                } label: {
                    HStack(spacing: 6) {
                        Text(language == .chinese ? "🇨🇳" : "🇺🇸")
                            .font(.subheadline)
                        Text(language.label)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(isSelected ? .white : .primary.opacity(0.75))
                    .animation(.easeOut(duration: 0.16), value: isSelected)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .background {
            GeometryReader { geo in
                let count = max(1, CardLanguage.allCases.count)
                let spacing: CGFloat = 4
                let pillWidth = max(0, (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
                Capsule()
                    .fill(Brand.gradient)
                    .shadow(color: Brand.green.opacity(0.24), radius: 5, y: 2)
                    .frame(width: pillWidth, height: geo.size.height)
                    .offset(x: CGFloat(selectedIndex) * (pillWidth + spacing))
                    .animation(.spring(response: 0.28, dampingFraction: 0.86), value: selectedIndex)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Brand.elevatedFill(for: colorScheme))
                .overlay(Capsule().strokeBorder(Brand.hairlineBorder(for: colorScheme), lineWidth: 1))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chọn ngôn ngữ học")
        .onAppear {
            if visualSelection != selection { visualSelection = selection }
            WidgetSync.setSelectedLanguage(selection)
        }
        .onChange(of: selection) { _, value in
            if visualSelection != value { visualSelection = value }
            WidgetSync.setSelectedLanguage(value)
        }
    }
}

// MARK: - Badges & Medallions

/// A small rounded pill label (kind / difficulty / level / topic tags).
struct Badge: View {
    let text: String
    var soft: Bool = true
    var customColor: Color?

    init(text: String, color: Color? = nil, soft: Bool = true) {
        self.text = text
        self.customColor = color
        self.soft = soft
    }

    @MainActor
    private var resolvedColor: Color {
        customColor ?? Brand.green
    }

    var body: some View {
        let tint = resolvedColor
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(soft ? tint : .white)
            .background(soft ? tint.opacity(0.14) : tint, in: Capsule())
    }
}

struct VocaIconBadge: View {
    let systemImage: String
    var tint: Color?
    var size: CGFloat = 38
    var iconSize: CGFloat = 17

    @MainActor
    private var resolvedTint: Color { tint ?? Brand.green }

    var body: some View {
        let color = resolvedTint
        Image(systemName: systemImage)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [color.opacity(0.18), color.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                    .strokeBorder(color.opacity(0.22), lineWidth: 1)
            )
    }
}

struct VocaPillBadge: View {
    let text: String
    var icon: String? = nil
    var tint: Color?

    @MainActor
    private var resolvedTint: Color { tint ?? Brand.green }

    var body: some View {
        let color = resolvedTint
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.13), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.22), lineWidth: 0.8))
    }
}

// MARK: - Pronounce Button

/// Reusable pronunciation button. The icon <-> spinner swap happens inside a FIXED-size frame so
/// tapping it never reflows surrounding content.
struct PronounceButton: View {
    let text: String
    var voiceModel: String? = nil
    var language: CardLanguage = .english
    var size: CGFloat = 32
    var font: Font = .body
    var tintedCapsule: Bool = false

    @State private var speaking = false

    var body: some View {
        Button {
            guard !speaking, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            Haptics.impact(.light)
            speaking = true
            Task {
                try? await TTSService().speak(text, language: language, voiceModel: voiceModel)
                speaking = false
            }
        } label: {
            ZStack {
                if tintedCapsule {
                    Circle()
                        .fill(Brand.greenSoft)
                        .overlay(
                            Circle()
                                .strokeBorder(Brand.green.opacity(speaking ? 0.55 : 0), lineWidth: 1.5)
                        )
                        .scaleEffect(speaking ? 1.08 : 1)
                }
                Image(systemName: speaking ? "waveform" : "speaker.wave.2.fill")
                    .font(font)
                    .symbolEffect(.variableColor.iterative, isActive: speaking)
            }
            .frame(width: size, height: size)
            .foregroundStyle(Brand.green)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: speaking)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Phát âm")
    }
}

// MARK: - Surface Cards

struct BrandCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 18
    var isHero: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                if isHero {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Brand.cardFill(for: colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Brand.green.opacity(colorScheme == .dark ? 0.18 : 0.11),
                                            Brand.secondaryGlow.opacity(colorScheme == .dark ? 0.10 : 0.05),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Brand.cardFill(for: colorScheme))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isHero ? Brand.green.opacity(0.24) : Brand.hairlineBorder(for: colorScheme),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isHero
                    ? Color.black.opacity(colorScheme == .dark ? 0.14 : 0.05)
                    : .clear,
                radius: isHero ? 7 : 0,
                x: 0,
                y: isHero ? 3 : 0
            )
    }
}

extension View {
    /// Standard themed card surface across the app.
    func brandCard(padding: CGFloat = 16, cornerRadius: CGFloat = 18) -> some View {
        modifier(BrandCardModifier(padding: padding, cornerRadius: cornerRadius, isHero: false))
    }

    /// Elevated accent hero surface for primary banners.
    func brandHeroCard(padding: CGFloat = 18, cornerRadius: CGFloat = 22) -> some View {
        modifier(BrandCardModifier(padding: padding, cornerRadius: cornerRadius, isHero: true))
    }
}

// MARK: - Wrapping Flow Layout

/// Multi-line wrapping layout shared across OCR chips, speaking word chips, and tags.
struct VocaFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                widestRow = max(widestRow, x - spacing)
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        widestRow = max(widestRow, x - spacing)
        let width = maxWidth.isFinite ? maxWidth : max(widestRow, 0)
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Floating Toast Banner

struct VocaToastBanner: View {
    let icon: String
    let message: String
    var tint: Color? = nil

    @MainActor
    private var resolvedTint: Color { tint ?? Brand.green }

    var body: some View {
        let color = resolvedTint
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.32), lineWidth: 1))
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
    }
}

// MARK: - Button Styles

/// Subtle press feedback for interactive cards and CTAs: scales down gently on touch.
struct PressableScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Primary themed gradient CTA with gentle press scale, soft elevation, and disabled fade.
struct BrandCTAButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                Brand.gradient,
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(
                color: isEnabled ? Brand.green.opacity(configuration.isPressed ? 0.16 : 0.28) : .clear,
                radius: configuration.isPressed ? 2 : 5,
                y: configuration.isPressed ? 1 : 2
            )
            .opacity(isEnabled ? 1 : 0.48)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isEnabled)
    }
}
