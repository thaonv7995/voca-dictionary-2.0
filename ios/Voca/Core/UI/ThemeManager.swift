import SwiftUI
import UIKit

/// User-selectable color appearance override for iOS.
enum VocaAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Hệ thống"
        case .light: return "Sáng"
        case .dark: return "Tối"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var uiInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Curated brand palettes combining Voca's signature emerald identity with editorial light/dark themes.
enum VocaPalette: String, CaseIterable, Identifiable, Sendable {
    case emerald
    case indigo
    case ocean
    case amber
    case violet
    case rose

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emerald: return "Ngọc bích"
        case .indigo: return "Chàm đêm"
        case .ocean: return "Đại dương"
        case .amber: return "Hổ phách"
        case .violet: return "Thạch anh"
        case .rose: return "Chu sa"
        }
    }

    var subtitle: String {
        switch self {
        case .emerald: return "Tươi mới · Mặc định Voca"
        case .indigo: return "Hiện đại · Tập trung sâu"
        case .ocean: return "Dịu mắt · Thư thái"
        case .amber: return "Ấm áp · Trang giấy"
        case .violet: return "Sáng tạo · Nổi bật"
        case .rose: return "Ấn triện · Hán ngữ"
        }
    }

    var primary: Color {
        switch self {
        case .emerald: return Color(red: 0.086, green: 0.639, blue: 0.463) // #16A376
        case .indigo: return Color(red: 0.310, green: 0.275, blue: 0.898)  // #4F46E5
        case .ocean: return Color(red: 0.008, green: 0.518, blue: 0.780)   // #0284C7
        case .amber: return Color(red: 0.851, green: 0.467, blue: 0.024)   // #D97706
        case .violet: return Color(red: 0.486, green: 0.227, blue: 0.929)  // #7C3AED
        case .rose: return Color(red: 0.882, green: 0.114, blue: 0.282)    // #E11D48
        }
    }

    var deep: Color {
        switch self {
        case .emerald: return Color(red: 0.051, green: 0.580, blue: 0.533) // #0D9488
        case .indigo: return Color(red: 0.388, green: 0.400, blue: 0.945)  // #6366F1
        case .ocean: return Color(red: 0.059, green: 0.463, blue: 0.431)   // #0F766E
        case .amber: return Color(red: 0.706, green: 0.325, blue: 0.035)   // #B45309
        case .violet: return Color(red: 0.576, green: 0.200, blue: 0.918)  // #9333EA
        case .rose: return Color(red: 0.745, green: 0.071, blue: 0.235)    // #BE123C
        }
    }

    var secondaryGlow: Color {
        switch self {
        case .emerald: return Color(red: 0.388, green: 0.400, blue: 0.945)
        case .indigo: return Color(red: 0.055, green: 0.647, blue: 0.914)
        case .ocean: return Color(red: 0.078, green: 0.722, blue: 0.651)
        case .amber: return Color(red: 0.086, green: 0.639, blue: 0.463)
        case .violet: return Color(red: 0.925, green: 0.282, blue: 0.600)
        case .rose: return Color(red: 0.961, green: 0.620, blue: 0.043)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [primary, deep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var soft: Color { primary.opacity(0.14) }
}

/// Shared observable theme, typography, and study-UX preferences for the iOS app.
@MainActor
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    enum Keys {
        static let palette = "voca.ui.palette"
        static let appearance = "voca.ui.appearance"
        static let hapticsEnabled = "voca.ui.haptics"
        static let hanziCalligraphic = "voca.ui.hanziCalligraphic"
        static let autoSpeakFlashcard = "voca.study.autoSpeak"
        static let reverseFlashcardMode = "voca.study.reverseMode"
    }

    var palette: VocaPalette {
        didSet { UserDefaults.standard.set(palette.rawValue, forKey: Keys.palette) }
    }

    var appearance: VocaAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }

    var hanziCalligraphic: Bool {
        didSet { UserDefaults.standard.set(hanziCalligraphic, forKey: Keys.hanziCalligraphic) }
    }

    var autoSpeakFlashcard: Bool {
        didSet { UserDefaults.standard.set(autoSpeakFlashcard, forKey: Keys.autoSpeakFlashcard) }
    }

    var reverseFlashcardMode: Bool {
        didSet { UserDefaults.standard.set(reverseFlashcardMode, forKey: Keys.reverseFlashcardMode) }
    }

    private init() {
        let defaults = UserDefaults.standard
        palette = VocaPalette(rawValue: defaults.string(forKey: Keys.palette) ?? "") ?? .emerald
        appearance = VocaAppearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true
        hanziCalligraphic = defaults.object(forKey: Keys.hanziCalligraphic) as? Bool ?? true
        autoSpeakFlashcard = defaults.object(forKey: Keys.autoSpeakFlashcard) as? Bool ?? false
        reverseFlashcardMode = defaults.object(forKey: Keys.reverseFlashcardMode) as? Bool ?? false
    }

    var accent: Color { palette.primary }
    var deepAccent: Color { palette.deep }
    var accentSoft: Color { palette.soft }
    var secondaryGlow: Color { palette.secondaryGlow }
    var gradient: LinearGradient { palette.gradient }
    var colorScheme: ColorScheme? { appearance.colorScheme }
}

/// Editorial & calligraphic typography helpers tailored for English IPA and Chinese Hanzi.
enum VocaTypography {
    @MainActor
    static func hanziFont(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        guard ThemeStore.shared.hanziCalligraphic else {
            return .system(size: size, weight: weight, design: .rounded)
        }
        let candidates: [String]
        switch weight {
        case .black, .heavy, .bold, .semibold:
            candidates = ["STSongti-SC-Bold", "Songti SC Bold", "PingFangSC-Semibold"]
        case .medium:
            candidates = ["STSongti-SC-Regular", "Songti SC", "PingFangSC-Medium"]
        default:
            candidates = ["STSongti-SC-Regular", "Songti SC", "PingFangSC-Regular"]
        }
        for name in candidates where UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight, design: .serif)
    }
}

/// Lightweight tactile feedback helper respecting the user's Haptics preference.
@MainActor
enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard ThemeStore.shared.hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard ThemeStore.shared.hapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    static func selection() {
        guard ThemeStore.shared.hapticsEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
