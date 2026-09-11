import Foundation

/// A vocabulary card slimmed down for the widget. Compiled into BOTH the app and the widget target.
struct WidgetCard: Codable, Hashable {
    let word: String
    let ipa: String?
    let pronunciation: String?
    let language: String?
    let meaningVi: String?
    let partOfSpeech: String?

    var phonetic: String? {
        if language == "zh-CN", let pronunciation, !pronunciation.isEmpty { return pronunciation }
        if let ipa, !ipa.isEmpty { return ipa }
        if let pronunciation, !pronunciation.isEmpty { return pronunciation }
        return nil
    }
}

/// Reads/writes the shared card snapshot in the App Group container (app writes, widget reads).
enum WidgetSharedStore {
    static let appGroup = "group.site.thaonv.voca"
    private static let fileName = "widget-cards.json"
    private static let languageKey = "voca.widget.language"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }

    static func save(_ cards: [WidgetCard]) {
        guard let url = fileURL, let data = try? JSONEncoder().encode(cards) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> [WidgetCard] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let cards = try? JSONDecoder().decode([WidgetCard].self, from: data)
        else { return [] }
        let language = UserDefaults(suiteName: appGroup)?.string(forKey: languageKey) ?? "en"
        return cards.filter { ($0.language ?? "en") == language }
    }

    static func setSelectedLanguage(_ language: String) {
        UserDefaults(suiteName: appGroup)?.set(language, forKey: languageKey)
    }
}
