import AppKit
import CoreText
import SwiftUI

enum VocaDesign {
    // MARK: - Brand Palette
    static let brandGreen = Color(red: 0.086, green: 0.714, blue: 0.388)      // #16B663
    static let brandGreenDark = Color(red: 0.055, green: 0.588, blue: 0.314)  // #0E9650
    static let brandTeal = Color(red: 0.078, green: 0.647, blue: 0.549)       // #14A58C
    static let accentIndigo = Color(red: 0.388, green: 0.400, blue: 0.945)    // #6366F1
    static let accentAmber = Color(red: 0.961, green: 0.620, blue: 0.043)     // #F59E0B
    static let accentRose = Color(red: 0.957, green: 0.247, blue: 0.369)      // #F43F5E
    static let accentSky = Color(red: 0.055, green: 0.647, blue: 0.914)       // #0EA5E9

    // MARK: - Gradients
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [brandGreen, brandTeal],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroBannerGradient: LinearGradient {
        LinearGradient(
            colors: [
                brandGreen.opacity(0.16),
                brandTeal.opacity(0.08),
                accentIndigo.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var subtleWindowBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(
                colors: [
                    brandGreen.opacity(0.06),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 520
            )
            RadialGradient(
                colors: [
                    accentIndigo.opacity(0.04),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Chinese Calligraphic Typography ("Nét Thanh Đậm" — Songti SC)
    // Uses `/System/Library/Fonts/Supplemental/Songti.ttc` (`STSongti-SC-Bold`),
    // which is pre-installed on macOS (loads in <4ms and never triggers MobileAsset font download dialogs).

    private static let didRegisterChineseFonts: Bool = {
        let songtiURL = URL(fileURLWithPath: "/System/Library/Fonts/Supplemental/Songti.ttc")
        if FileManager.default.fileExists(atPath: songtiURL.path) {
            CTFontManagerRegisterFontsForURL(songtiURL as CFURL, .process, nil)
        }
        return true
    }()

    static func ensureChineseFontsRegistered() {
        _ = didRegisterChineseFonts
    }

    static func hanziFont(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        _ = didRegisterChineseFonts
        let postscriptName: String
        switch weight {
        case .black, .heavy:
            postscriptName = "STSongti-SC-Black"
        case .bold, .semibold, .medium:
            postscriptName = "STSongti-SC-Bold"
        case .light, .ultraLight, .thin:
            postscriptName = "STSongti-SC-Light"
        default:
            postscriptName = "STSongti-SC-Regular"
        }
        if let nsFont = NSFont(name: postscriptName, size: size) {
            return Font(nsFont)
        }
        return .custom(postscriptName, size: size)
    }

    static func kaitiFont(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        hanziFont(size: size, weight: weight)
    }

    static func containsHanCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3400...0x4DBF).contains(scalar.value)
                || (0x4E00...0x9FFF).contains(scalar.value)
                || (0xF900...0xFAFF).contains(scalar.value)
                || (0x20000...0x323AF).contains(scalar.value)
        }
    }

    // MARK: - Custom macOS Menu Bar Status Icon (Template NSImage)
    static let menuBarStatusImage: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            NSColor.black.setFill()
            NSColor.black.setStroke()

            // 1. Subtle back flashcard layer (top-right offset outline)
            let backRect = CGRect(x: 4.4, y: 4.2, width: 12.0, height: 12.0)
            let backCard = NSBezierPath(roundedRect: backRect, xRadius: 3.2, yRadius: 3.2)
            backCard.lineWidth = 1.25
            NSColor.black.withAlphaComponent(0.45).setStroke()
            backCard.stroke()

            // 2. Main front squircle card with negative-space "V" monogram cutout (Even-Odd fill)
            let frontRect = CGRect(x: 1.6, y: 1.6, width: 13.4, height: 13.4)
            let frontPath = CGMutablePath()
            frontPath.addRoundedRect(in: frontRect, cornerWidth: 3.6, cornerHeight: 3.6)

            // Bold "V" ribbon cutout inside the front card
            let vCutout = CGMutablePath()
            vCutout.move(to: CGPoint(x: 4.5, y: 11.7))
            vCutout.addLine(to: CGPoint(x: 6.5, y: 11.7))
            vCutout.addLine(to: CGPoint(x: 8.3, y: 6.7))
            vCutout.addLine(to: CGPoint(x: 10.1, y: 11.7))
            vCutout.addLine(to: CGPoint(x: 12.1, y: 11.7))
            vCutout.addLine(to: CGPoint(x: 9.2, y: 4.5))
            vCutout.addLine(to: CGPoint(x: 7.4, y: 4.5))
            vCutout.closeSubpath()
            frontPath.addPath(vCutout)

            // Small accent dot inside top-right of card
            frontPath.addEllipse(in: CGRect(x: 11.4, y: 4.3, width: 1.8, height: 1.8))

            ctx.saveGState()
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.addPath(frontPath)
            ctx.fillPath(using: .evenOdd)
            ctx.restoreGState()

            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Voca Dictionary"
        return image
    }()
}

// MARK: - Voca Brand Logo Mark (Matches AppIcon.icns)

struct VocaBrandMark: View {
    var size: CGFloat = 30

    var body: some View {
        let corner = size * 0.24
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.11, green: 0.80, blue: 0.45),
                            Color(red: 0.05, green: 0.45, blue: 0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: max(1, size * 0.035))
                )

            // Back tilted card
            RoundedRectangle(cornerRadius: size * 0.13, style: .continuous)
                .fill(Color.white.opacity(0.24))
                .frame(width: size * 0.56, height: size * 0.62)
                .rotationEffect(.degrees(9))
                .offset(x: size * 0.06, y: -size * 0.04)

            // Main front white flashcard with "V"
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                    .fill(Color.white)
                    .frame(width: size * 0.58, height: size * 0.62)
                    .shadow(color: Color.black.opacity(0.18), radius: size * 0.06, x: 0, y: size * 0.03)
                    .overlay {
                        Text("V")
                            .font(.system(size: size * 0.38, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.05, green: 0.52, blue: 0.31))
                            .offset(y: -size * 0.01)
                    }

                // Red Hanzi seal stamp ("文")
                Text("文")
                    .font(.system(size: size * 0.19, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.27, height: size * 0.27)
                    .background(
                        RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                            .fill(Color(red: 0.92, green: 0.24, blue: 0.30))
                    )
                    .offset(x: size * 0.07, y: size * 0.05)
            }
            .offset(x: -size * 0.03, y: size * 0.01)
        }
        .frame(width: size, height: size)
        .shadow(color: VocaDesign.brandGreen.opacity(0.22), radius: size * 0.15, x: 0, y: size * 0.06)
    }
}

// MARK: - Modern Surface Card (Replaces rigid GroupBox)

struct VocaSurfaceCard<Content: View>: View {
    var title: String?
    var subtitle: String?
    var icon: String?
    var iconTint: Color = VocaDesign.brandGreen
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 16
    @ViewBuilder var content: () -> Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        icon: String? = nil,
        iconTint: Color = VocaDesign.brandGreen,
        padding: CGFloat = 20,
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconTint = iconTint
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if title != nil || icon != nil {
                HStack(spacing: 10) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(iconTint)
                            .frame(width: 28, height: 28)
                            .background(
                                iconTint.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if let title {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                        if let subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }

            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.88))
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}

// MARK: - Soft Tinted Icon Medallion

struct VocaIconBadge: View {
    let systemImage: String
    var tint: Color = VocaDesign.brandGreen
    var size: CGFloat = 40
    var iconSize: CGFloat = 18

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [tint.opacity(0.18), tint.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .strokeBorder(tint.opacity(0.22), lineWidth: 1)
            )
    }
}

// MARK: - Modern Text Field & Secure Field

struct VocaInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var isFocused: Bool = false
    var onSubmit: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isFocused ? VocaDesign.brandGreen : .secondary)
                .frame(width: 20)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .onSubmit { onSubmit?() }
                } else {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .onSubmit { onSubmit?() }
                }
            }
            .font(.body)

            if !text.isEmpty && !isSecure {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isFocused
                        ? VocaDesign.brandGreen.opacity(0.85)
                        : Color.primary.opacity(0.10),
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .shadow(
            color: isFocused ? VocaDesign.brandGreen.opacity(0.12) : .clear,
            radius: 6,
            x: 0,
            y: 2
        )
        .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}

// MARK: - Pill Badge & Keycap

struct VocaPillBadge: View {
    let text: String
    var icon: String?
    var tint: Color = VocaDesign.brandGreen

    var body: some View {
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
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            tint.opacity(0.13),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(tint.opacity(0.22), lineWidth: 0.8)
        )
    }
}

struct VocaKeycap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
            )
    }
}

// MARK: - Modern Button Styles

struct VocaPrimaryButtonStyle: ButtonStyle {
    var tint: Color = VocaDesign.brandGreen
    var isFullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        VocaPrimaryButtonBody(
            configuration: configuration,
            tint: tint,
            isFullWidth: isFullWidth
        )
    }

    private struct VocaPrimaryButtonBody: View {
        let configuration: Configuration
        let tint: Color
        let isFullWidth: Bool
        @ViewState private var isHovered = false

        var body: some View {
            configuration.label
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .background(
                    LinearGradient(
                        colors: [
                            tint.opacity(isHovered ? 1.0 : 0.96),
                            tint.opacity(isHovered ? 0.92 : 0.84)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(isHovered ? 0.28 : 0.18), lineWidth: 1)
                )
                .shadow(
                    color: tint.opacity(configuration.isPressed ? 0.14 : (isHovered ? 0.36 : 0.24)),
                    radius: configuration.isPressed ? 4 : (isHovered ? 12 : 8),
                    x: 0,
                    y: configuration.isPressed ? 1 : (isHovered ? 5 : 3)
                )
                .scaleEffect(configuration.isPressed ? 0.975 : (isHovered ? 1.012 : 1.0))
                .animation(.spring(response: 0.22, dampingFraction: 0.76), value: configuration.isPressed)
                .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isHovered)
                .onHover { hovering in
                    isHovered = hovering
                }
        }
    }
}

struct VocaSecondaryButtonStyle: ButtonStyle {
    var tint: Color = .primary
    var isFullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        VocaSecondaryButtonBody(
            configuration: configuration,
            tint: tint,
            isFullWidth: isFullWidth
        )
    }

    private struct VocaSecondaryButtonBody: View {
        let configuration: Configuration
        let tint: Color
        let isFullWidth: Bool
        @ViewState private var isHovered = false

        var body: some View {
            configuration.label
                .font(.body.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(tint)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            Color(nsColor: .controlBackgroundColor)
                                .opacity(configuration.isPressed ? 0.65 : (isHovered ? 1.0 : 0.92))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isHovered
                                ? VocaDesign.brandGreen.opacity(0.35)
                                : Color.primary.opacity(0.12),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(isHovered ? 0.06 : 0.02),
                    radius: isHovered ? 6 : 2,
                    y: 2
                )
                .scaleEffect(configuration.isPressed ? 0.975 : (isHovered ? 1.01 : 1.0))
                .animation(.spring(response: 0.22, dampingFraction: 0.76), value: configuration.isPressed)
                .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isHovered)
                .onHover { hovering in
                    isHovered = hovering
                }
        }
    }
}

// MARK: - Floating Toast HUD Banner

struct VocaToastBanner: View {
    let icon: String
    let message: String
    var tint: Color = VocaDesign.brandGreen

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.16), in: Circle())

            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
    }
}

// MARK: - Keyboard Shortcuts Cheatsheet Sheet (`⌘/`)

struct MacShortcutCheatsheetSheet: View {
    @Environment(\.dismiss) private var dismiss

    private struct ShortcutItem: Identifiable {
        let id = UUID()
        let keys: [String]
        let description: String
    }

    private struct ShortcutSection: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let tint: Color
        let items: [ShortcutItem]
    }

    private let sections: [ShortcutSection] = [
        ShortcutSection(
            title: "Toàn hệ thống & Điều hướng",
            icon: "command",
            tint: VocaDesign.brandGreen,
            items: [
                ShortcutItem(keys: ["⌘", "1…6"], description: "Chuyển nhanh các màn hình (Hôm nay → Thống kê)"),
                ShortcutItem(keys: ["⌥", "Space"], description: "Mở Tra từ nổi toàn hệ thống (tùy chỉnh trong Cài đặt)"),
                ShortcutItem(keys: ["⌘", "⇧", "K"], description: "Mở Tra từ nhanh trong ứng dụng"),
                ShortcutItem(keys: ["⌘", "N"], description: "Thêm từ vựng mới bằng AI"),
                ShortcutItem(keys: ["⌘", "⇧", "I"], description: "Mở bảng Nhập từ / Quét ảnh OCR"),
                ShortcutItem(keys: ["⌘", "/"], description: "Xem bảng tổng hợp phím tắt")
            ]
        ),
        ShortcutSection(
            title: "Thanh Menu Bar & Tra từ nổi",
            icon: "menubar.rectangle",
            tint: VocaDesign.brandTeal,
            items: [
                ShortcutItem(keys: ["⌘", "F"], description: "Đặt con trỏ vào ô tìm kiếm Menu Bar"),
                ShortcutItem(keys: ["↑", "↓", "↩"], description: "Di chuyển & Xem nhanh nghĩa (Quick Peek)"),
                ShortcutItem(keys: ["⇧", "↩"], description: "Mở chi tiết từ trong cửa sổ chính hoặc Tạo AI"),
                ShortcutItem(keys: ["⌘", "R"], description: "Bắt đầu Ôn nhanh 5 thẻ ngay trên Menu Bar"),
                ShortcutItem(keys: ["⌘", "L"], description: "Chuyển ngôn ngữ tạo từ AI (🇺🇸 EN / 🇨🇳 中文)"),
                ShortcutItem(keys: ["⇧", "⌘", "R"], description: "Đổi từ vựng nổi bật trong ngày"),
                ShortcutItem(keys: ["⌘", "P", "D", "C"], description: "Phát âm / Yêu thích / Sao chép thẻ đang xem"),
                ShortcutItem(keys: ["⌘", "O"], description: "Mở cửa sổ chính Voca")
            ]
        ),
        ShortcutSection(
            title: "Kho từ vựng",
            icon: "books.vertical.fill",
            tint: VocaDesign.accentSky,
            items: [
                ShortcutItem(keys: ["⌘", "F"], description: "Đặt con trỏ vào ô Tìm kiếm"),
                ShortcutItem(keys: ["⌘", "↩"], description: "Tạo từ bằng AI (nếu chưa có) hoặc Phát âm"),
                ShortcutItem(keys: ["↑", "↓"], description: "Di chuyển qua lại giữa các thẻ từ vựng"),
                ShortcutItem(keys: ["⌘", "P"], description: "Phát âm từ đang chọn"),
                ShortcutItem(keys: ["⌘", "D"], description: "Đánh dấu / Bỏ đánh dấu Yêu thích (★)"),
                ShortcutItem(keys: ["⌘", "I"], description: "Mở / Đóng Gia sư AI cho từ đang chọn"),
                ShortcutItem(keys: ["⌘", "L"], description: "Mở bộ thẻ lật (Thẻ lật)"),
                ShortcutItem(keys: ["⌘", "C"], description: "Sao chép từ vựng & nghĩa vào bộ nhớ tạm"),
                ShortcutItem(keys: ["Esc"], description: "Đóng Gia sư AI / Xem trước hoặc xóa lọc")
            ]
        ),
        ShortcutSection(
            title: "Ôn tập FSRS & Luyện tập",
            icon: "rectangle.stack.fill",
            tint: VocaDesign.accentIndigo,
            items: [
                ShortcutItem(keys: ["Space"], description: "Lật thẻ / Hiện đáp án"),
                ShortcutItem(keys: ["1", "2", "3", "4"], description: "Chấm mức độ nhớ (Quên / Khó / Tốt / Dễ)"),
                ShortcutItem(keys: ["⌘", "Z"], description: "Hoàn tác thẻ vừa chấm"),
                ShortcutItem(keys: ["←", "→"], description: "Chuyển thẻ Trước / Tiếp theo (Thẻ lật)"),
                ShortcutItem(keys: ["⌘", "P"], description: "Nghe lại phát âm của thẻ hiện tại"),
                ShortcutItem(keys: ["⌘", "↩"], description: "Gửi tin nhắn cho Gia sư AI")
            ]
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                VocaIconBadge(
                    systemImage: "keyboard.fill",
                    tint: VocaDesign.brandGreen,
                    size: 40,
                    iconSize: 18
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bảng Phím tắt macOS")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Tối ưu tốc độ tra cứu, học từ và ôn tập trên Menu Bar & toàn hệ thống")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    VocaKeycap(label: "ESC")
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }

            Divider().opacity(0.6)

            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 290, maximum: 440), spacing: 14)
                    ],
                    spacing: 14
                ) {
                    ForEach(sections) { section in
                        VocaSurfaceCard(
                            title: section.title,
                            icon: section.icon,
                            iconTint: section.tint,
                            padding: 16,
                            cornerRadius: 14
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(section.items) { item in
                                    HStack(spacing: 10) {
                                        Text(item.description)
                                            .font(.system(size: 12.5))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)

                                        Spacer(minLength: 6)

                                        HStack(spacing: 3) {
                                            ForEach(item.keys, id: \.self) { key in
                                                VocaKeycap(label: key)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 640, idealWidth: 740, maxWidth: 820, minHeight: 460, idealHeight: 540)
        .background(VocaDesign.subtleWindowBackground)
    }
}
