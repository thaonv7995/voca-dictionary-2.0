import Foundation

/// A vocabulary card slimmed down for the widget. Compiled into BOTH the app and the widget target.
struct WidgetCard: Codable, Hashable {
    let slug: String?
    let word: String
    let ipa: String?
    let pronunciation: String?
    let language: String?
    let meaningVi: String?
    let partOfSpeech: String?

    init(slug: String? = nil, word: String, ipa: String?, pronunciation: String?,
         language: String?, meaningVi: String?, partOfSpeech: String?) {
        self.slug = slug
        self.word = word
        self.ipa = ipa
        self.pronunciation = pronunciation
        self.language = language
        self.meaningVi = meaningVi
        self.partOfSpeech = partOfSpeech
    }

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
    private static let selectedIndexKey = "voca.widget.selectedIndex"

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
        let defaults = UserDefaults(suiteName: appGroup)
        if defaults?.string(forKey: languageKey) != language {
            defaults?.set(0, forKey: selectedIndexKey)
        }
        defaults?.set(language, forKey: languageKey)
    }

    static func selectedIndex(cardCount: Int) -> Int? {
        guard cardCount > 0,
              let defaults = UserDefaults(suiteName: appGroup),
              defaults.object(forKey: selectedIndexKey) != nil
        else { return nil }
        return normalized(defaults.integer(forKey: selectedIndexKey), count: cardCount)
    }

    @discardableResult
    static func selectNext(cardCount: Int, currentIndex: Int? = nil) -> Int {
        guard cardCount > 0 else { return 0 }
        let current = currentIndex.map { normalized($0, count: cardCount) }
            ?? selectedIndex(cardCount: cardCount) ?? 0
        let next = (current + 1) % cardCount
        UserDefaults(suiteName: appGroup)?.set(next, forKey: selectedIndexKey)
        return next
    }

    @discardableResult
    static func selectRandom(cardCount: Int, currentIndex: Int? = nil) -> Int {
        guard cardCount > 0 else { return 0 }
        let current = currentIndex.map { normalized($0, count: cardCount) }
            ?? selectedIndex(cardCount: cardCount) ?? 0
        let next: Int
        if cardCount == 1 {
            next = 0
        } else {
            let offset = Int.random(in: 1..<cardCount)
            next = (current + offset) % cardCount
        }
        UserDefaults(suiteName: appGroup)?.set(next, forKey: selectedIndexKey)
        return next
    }

    private static func normalized(_ index: Int, count: Int) -> Int {
        ((index % count) + count) % count
    }
}
