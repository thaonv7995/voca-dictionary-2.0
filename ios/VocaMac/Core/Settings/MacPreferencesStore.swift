import Foundation
import Observation

@MainActor
@Observable
final class MacPreferencesStore {
    enum Appearance: String, CaseIterable, Identifiable, Sendable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system:
                "Theo hệ thống"
            case .light:
                "Giao diện sáng"
            case .dark:
                "Giao diện tối"
            }
        }
    }

    enum DefaultDestination: String, CaseIterable, Identifiable, Sendable {
        case today
        case vocabulary
        case review
        case practice

        var id: String { rawValue }

        var title: String {
            switch self {
            case .today:
                "Hôm nay"
            case .vocabulary:
                "Kho từ vựng"
            case .review:
                "Ôn tập"
            case .practice:
                "Luyện tập"
            }
        }

        var destination: MacDestination {
            switch self {
            case .today:
                .today
            case .vocabulary:
                .vocabulary
            case .review:
                .review
            case .practice:
                .practice
            }
        }
    }

    enum MenuBarBadgeStyle: String, CaseIterable, Identifiable, Sendable {
        case dueCount
        case dotOnly
        case iconOnly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dueCount:
                "Biểu tượng & Số thẻ đến hạn"
            case .dotOnly:
                "Biểu tượng & Chấm trạng thái"
            case .iconOnly:
                "Chỉ biểu tượng Voca"
            }
        }
    }

    enum QuickLookupHotkey: String, CaseIterable, Identifiable, Sendable {
        case optionSpace
        case commandShiftSpace
        case controlOptionSpace
        case disabled

        var id: String { rawValue }

        var title: String {
            switch self {
            case .optionSpace:
                "Option + Space (⌥Space)"
            case .commandShiftSpace:
                "Shift + Command + Space (⇧⌘Space)"
            case .controlOptionSpace:
                "Control + Option + Space (⌃⌥Space)"
            case .disabled:
                "Tắt phím tắt toàn hệ thống"
            }
        }

        var badgeLabel: String {
            switch self {
            case .optionSpace:
                "⌥Space"
            case .commandShiftSpace:
                "⇧⌘Space"
            case .controlOptionSpace:
                "⌃⌥Space"
            case .disabled:
                "⇧⌘K"
            }
        }
    }

    private(set) var appearance: Appearance
    private(set) var defaultDestination: DefaultDestination
    private(set) var showInMenuBar: Bool
    private(set) var menuBarBadgeStyle: MenuBarBadgeStyle
    private(set) var quickLookupHotkey: QuickLookupHotkey
    private(set) var launchAtLogin: Bool
    private(set) var launchAtLoginError: String?
    private(set) var hideDockIcon: Bool
    private(set) var dailyGoal: Int
    private(set) var playAudioAutomatically: Bool
    private(set) var enableAssistantFeatures: Bool

    private let persistence: MacPreferencesPersistence

    init(
        persistence: MacPreferencesPersistence
    ) {
        self.persistence = persistence

        let preferences = persistence.load()
        appearance = preferences.appearance
        defaultDestination = preferences.defaultDestination
        showInMenuBar = preferences.showInMenuBar
        menuBarBadgeStyle = preferences.menuBarBadgeStyle
        quickLookupHotkey = preferences.quickLookupHotkey
        launchAtLogin = preferences.launchAtLogin
        hideDockIcon = preferences.hideDockIcon
        dailyGoal = preferences.dailyGoal
        playAudioAutomatically = preferences.playAudioAutomatically
        enableAssistantFeatures = preferences.enableAssistantFeatures

        let result = MacSystemIntegrations.updateLaunchAtLogin(enabled: launchAtLogin)
        launchAtLoginError = result.success ? nil : result.error
        MacSystemIntegrations.updateDockIconVisibility(hideDockIcon: hideDockIcon)
        MacQuickLookupPanelController.shared.applyHotKeyPreference(quickLookupHotkey)
    }

    convenience init() {
        self.init(
            persistence: UserDefaultsMacPreferencesPersistence()
        )
    }

    func setAppearance(_ appearance: Appearance) {
        self.appearance = appearance
        save()
    }

    func setDefaultDestination(
        _ destination: DefaultDestination
    ) {
        defaultDestination = destination
        save()
    }

    func setShowInMenuBar(_ isEnabled: Bool) {
        showInMenuBar = isEnabled
        if !isEnabled && hideDockIcon {
            hideDockIcon = false
            MacSystemIntegrations.updateDockIconVisibility(hideDockIcon: false)
        }
        save()
    }

    func setMenuBarBadgeStyle(_ style: MenuBarBadgeStyle) {
        menuBarBadgeStyle = style
        save()
    }

    func setQuickLookupHotkey(_ hotkey: QuickLookupHotkey) {
        quickLookupHotkey = hotkey
        MacQuickLookupPanelController.shared.applyHotKeyPreference(hotkey)
        save()
    }

    func setLaunchAtLogin(_ isEnabled: Bool) {
        launchAtLogin = isEnabled
        let result = MacSystemIntegrations.updateLaunchAtLogin(enabled: isEnabled)
        launchAtLoginError = result.success ? nil : result.error
        save()
    }

    func setHideDockIcon(_ isEnabled: Bool) {
        hideDockIcon = isEnabled
        if isEnabled && !showInMenuBar {
            showInMenuBar = true
        }
        MacSystemIntegrations.updateDockIconVisibility(hideDockIcon: isEnabled)
        save()
    }

    func setDailyGoal(_ value: Int) {
        dailyGoal = min(max(value, 1), 100)
        save()
    }

    func setPlayAudioAutomatically(_ isEnabled: Bool) {
        playAudioAutomatically = isEnabled
        save()
    }

    func setEnableAssistantFeatures(_ isEnabled: Bool) {
        enableAssistantFeatures = isEnabled
        save()
    }

    func reset() {
        persistence.clear()

        let defaults = MacPreferences.default
        appearance = defaults.appearance
        defaultDestination = defaults.defaultDestination
        showInMenuBar = defaults.showInMenuBar
        menuBarBadgeStyle = defaults.menuBarBadgeStyle
        quickLookupHotkey = defaults.quickLookupHotkey
        launchAtLogin = defaults.launchAtLogin
        hideDockIcon = defaults.hideDockIcon
        dailyGoal = defaults.dailyGoal
        playAudioAutomatically = defaults.playAudioAutomatically
        enableAssistantFeatures = defaults.enableAssistantFeatures

        let result = MacSystemIntegrations.updateLaunchAtLogin(enabled: launchAtLogin)
        launchAtLoginError = result.success ? nil : result.error
        MacSystemIntegrations.updateDockIconVisibility(hideDockIcon: hideDockIcon)
        MacQuickLookupPanelController.shared.applyHotKeyPreference(quickLookupHotkey)
        save()
    }

    private func save() {
        persistence.save(
            MacPreferences(
                appearance: appearance,
                defaultDestination: defaultDestination,
                showInMenuBar: showInMenuBar,
                menuBarBadgeStyle: menuBarBadgeStyle,
                quickLookupHotkey: quickLookupHotkey,
                launchAtLogin: launchAtLogin,
                hideDockIcon: hideDockIcon,
                dailyGoal: dailyGoal,
                playAudioAutomatically: playAudioAutomatically,
                enableAssistantFeatures: enableAssistantFeatures
            )
        )
    }
}

struct MacPreferences: Equatable, Sendable {
    let appearance: MacPreferencesStore.Appearance
    let defaultDestination: MacPreferencesStore.DefaultDestination
    let showInMenuBar: Bool
    let menuBarBadgeStyle: MacPreferencesStore.MenuBarBadgeStyle
    let quickLookupHotkey: MacPreferencesStore.QuickLookupHotkey
    let launchAtLogin: Bool
    let hideDockIcon: Bool
    let dailyGoal: Int
    let playAudioAutomatically: Bool
    let enableAssistantFeatures: Bool

    init(
        appearance: MacPreferencesStore.Appearance = .system,
        defaultDestination: MacPreferencesStore.DefaultDestination = .today,
        showInMenuBar: Bool = true,
        menuBarBadgeStyle: MacPreferencesStore.MenuBarBadgeStyle = .dueCount,
        quickLookupHotkey: MacPreferencesStore.QuickLookupHotkey = .optionSpace,
        launchAtLogin: Bool = false,
        hideDockIcon: Bool = false,
        dailyGoal: Int = 20,
        playAudioAutomatically: Bool = false,
        enableAssistantFeatures: Bool = true
    ) {
        self.appearance = appearance
        self.defaultDestination = defaultDestination
        self.showInMenuBar = showInMenuBar
        self.menuBarBadgeStyle = menuBarBadgeStyle
        self.quickLookupHotkey = quickLookupHotkey
        self.launchAtLogin = launchAtLogin
        self.hideDockIcon = hideDockIcon
        self.dailyGoal = dailyGoal
        self.playAudioAutomatically = playAudioAutomatically
        self.enableAssistantFeatures = enableAssistantFeatures
    }

    static let `default` = MacPreferences()
}

@MainActor
protocol MacPreferencesPersistence {
    func load() -> MacPreferences
    func save(_ preferences: MacPreferences)
    func clear()
}

@MainActor
struct UserDefaultsMacPreferencesPersistence:
    MacPreferencesPersistence {

    private enum Key {
        static let appearance = "mac.preferences.appearance"
        static let defaultDestination =
            "mac.preferences.defaultDestination"
        static let showInMenuBar = "mac.preferences.showInMenuBar.v2"
        static let menuBarBadgeStyle = "mac.preferences.menuBarBadgeStyle"
        static let quickLookupHotkey = "mac.preferences.quickLookupHotkey"
        static let launchAtLogin = "mac.preferences.launchAtLogin.v2"
        static let hideDockIcon = "mac.preferences.hideDockIcon.v2"
        static let dailyGoal = "mac.preferences.dailyGoal"
        static let playAudioAutomatically =
            "mac.preferences.playAudioAutomatically"
        static let enableAssistantFeatures =
            "mac.preferences.enableAssistantFeatures"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> MacPreferences {
        let fallback = MacPreferences.default

        let appearance = defaults
            .string(forKey: Key.appearance)
            .flatMap(MacPreferencesStore.Appearance.init(rawValue:))
            ?? fallback.appearance

        let defaultDestination = defaults
            .string(forKey: Key.defaultDestination)
            .flatMap(
                MacPreferencesStore.DefaultDestination.init(rawValue:)
            )
            ?? fallback.defaultDestination

        let menuBarBadgeStyle = defaults
            .string(forKey: Key.menuBarBadgeStyle)
            .flatMap(
                MacPreferencesStore.MenuBarBadgeStyle.init(rawValue:)
            )
            ?? fallback.menuBarBadgeStyle

        let quickLookupHotkey = defaults
            .string(forKey: Key.quickLookupHotkey)
            .flatMap(
                MacPreferencesStore.QuickLookupHotkey.init(rawValue:)
            )
            ?? fallback.quickLookupHotkey

        let dailyGoal: Int
        if defaults.object(forKey: Key.dailyGoal) == nil {
            dailyGoal = fallback.dailyGoal
        } else {
            dailyGoal = min(
                max(defaults.integer(forKey: Key.dailyGoal), 1),
                100
            )
        }

        return MacPreferences(
            appearance: appearance,
            defaultDestination: defaultDestination,
            showInMenuBar: bool(
                forKey: Key.showInMenuBar,
                fallback: fallback.showInMenuBar
            ),
            menuBarBadgeStyle: menuBarBadgeStyle,
            quickLookupHotkey: quickLookupHotkey,
            launchAtLogin: bool(
                forKey: Key.launchAtLogin,
                fallback: fallback.launchAtLogin
            ),
            hideDockIcon: bool(
                forKey: Key.hideDockIcon,
                fallback: fallback.hideDockIcon
            ),
            dailyGoal: dailyGoal,
            playAudioAutomatically: bool(
                forKey: Key.playAudioAutomatically,
                fallback: fallback.playAudioAutomatically
            ),
            enableAssistantFeatures: bool(
                forKey: Key.enableAssistantFeatures,
                fallback: fallback.enableAssistantFeatures
            )
        )
    }

    func save(_ preferences: MacPreferences) {
        defaults.set(
            preferences.appearance.rawValue,
            forKey: Key.appearance
        )
        defaults.set(
            preferences.defaultDestination.rawValue,
            forKey: Key.defaultDestination
        )
        defaults.set(
            preferences.showInMenuBar,
            forKey: Key.showInMenuBar
        )
        defaults.set(
            preferences.menuBarBadgeStyle.rawValue,
            forKey: Key.menuBarBadgeStyle
        )
        defaults.set(
            preferences.quickLookupHotkey.rawValue,
            forKey: Key.quickLookupHotkey
        )
        defaults.set(
            preferences.launchAtLogin,
            forKey: Key.launchAtLogin
        )
        defaults.set(
            preferences.hideDockIcon,
            forKey: Key.hideDockIcon
        )
        defaults.set(
            preferences.dailyGoal,
            forKey: Key.dailyGoal
        )
        defaults.set(
            preferences.playAudioAutomatically,
            forKey: Key.playAudioAutomatically
        )
        defaults.set(
            preferences.enableAssistantFeatures,
            forKey: Key.enableAssistantFeatures
        )
    }

    func clear() {
        defaults.removeObject(forKey: Key.appearance)
        defaults.removeObject(forKey: Key.defaultDestination)
        defaults.removeObject(forKey: Key.showInMenuBar)
        defaults.removeObject(forKey: Key.menuBarBadgeStyle)
        defaults.removeObject(forKey: Key.quickLookupHotkey)
        defaults.removeObject(forKey: Key.launchAtLogin)
        defaults.removeObject(forKey: Key.hideDockIcon)
        defaults.removeObject(forKey: Key.dailyGoal)
        defaults.removeObject(forKey: Key.playAudioAutomatically)
        defaults.removeObject(forKey: Key.enableAssistantFeatures)
    }

    private func bool(
        forKey key: String,
        fallback: Bool
    ) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return fallback
        }

        return defaults.bool(forKey: key)
    }
}

@MainActor
final class InMemoryMacPreferencesPersistence:
    MacPreferencesPersistence {

    private var preferences: MacPreferences

    init(preferences: MacPreferences = .default) {
        self.preferences = preferences
    }

    func load() -> MacPreferences {
        preferences
    }

    func save(_ preferences: MacPreferences) {
        self.preferences = preferences
    }

    func clear() {
        preferences = .default
    }
}
