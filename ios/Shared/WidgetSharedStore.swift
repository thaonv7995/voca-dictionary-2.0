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
    static let rotationInterval: TimeInterval = 5 * 60
    private static let fileName = "widget-cards.json"
    private static let languageKey = "voca.widget.language"
    private static let selectedIndexKey = "voca.widget.selectedIndex"
    private static let selectedAtKey = "voca.widget.selectedAt"
    private static let pendingCardSlugKey = "voca.widget.pendingCardSlug"

    private static let appGroupContainerURL: URL? = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: appGroup)

    private static let sharedDefaults: UserDefaults? = {
        guard appGroupContainerURL != nil else { return nil }
        return UserDefaults(suiteName: appGroup)
    }()

    private static var fileURL: URL? {
        if let container = appGroupContainerURL {
            return container.appendingPathComponent(fileName)
        }
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Voca")
        if let fallback {
            try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
            return fallback.appendingPathComponent(fileName)
        }
        return nil
    }

    static func save(_ cards: [WidgetCard]) {
        guard let url = fileURL else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(cards) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> [WidgetCard] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let cards = try? JSONDecoder().decode([WidgetCard].self, from: data)
        else { return [] }
        if let language = sharedDefaults?.string(forKey: languageKey) {
            let matched = cards.filter { ($0.language ?? "en") == language }
            if !matched.isEmpty { return matched }
        }
        return cards
    }

    static func clear() {
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
        sharedDefaults?.removeObject(forKey: selectedIndexKey)
        sharedDefaults?.removeObject(forKey: selectedAtKey)
        sharedDefaults?.removeObject(forKey: pendingCardSlugKey)
    }

    static func setSelectedLanguage(_ language: String) {
        if sharedDefaults?.string(forKey: languageKey) != language {
            sharedDefaults?.set(0, forKey: selectedIndexKey)
            sharedDefaults?.set(Date().timeIntervalSince1970, forKey: selectedAtKey)
        }
        sharedDefaults?.set(language, forKey: languageKey)
    }

    static func setPendingCardSlug(_ slug: String?) {
        guard let slug, !slug.isEmpty else { return }
        sharedDefaults?.set(slug, forKey: pendingCardSlugKey)
    }

    static func takePendingCardSlug() -> String? {
        guard let defaults = sharedDefaults,
              let slug = defaults.string(forKey: pendingCardSlugKey), !slug.isEmpty
        else { return nil }
        defaults.removeObject(forKey: pendingCardSlugKey)
        return slug
    }

    static func selectedIndex(cardCount: Int) -> Int? {
        guard cardCount > 0,
              let defaults = sharedDefaults,
              defaults.object(forKey: selectedIndexKey) != nil
        else { return nil }
        return normalized(defaults.integer(forKey: selectedIndexKey), count: cardCount)
    }

    static func scheduledIndex(cardCount: Int, at date: Date) -> Int? {
        guard cardCount > 0 else { return nil }
        guard let defaults = sharedDefaults,
              defaults.object(forKey: selectedIndexKey) != nil
        else {
            let slot = Int(date.timeIntervalSince1970 / rotationInterval)
            let slotsPerDay = Int(24 * 60 * 60 / rotationInterval)
            let daySeed = slot / slotsPerDay
            let step = randomCoprimeStep(count: cardCount, seed: daySeed)
            return normalized(daySeed + (slot % slotsPerDay) * step, count: cardCount)
        }

        let base = normalized(defaults.integer(forKey: selectedIndexKey), count: cardCount)
        guard defaults.object(forKey: selectedAtKey) != nil else {
            defaults.set(date.timeIntervalSince1970, forKey: selectedAtKey)
            return base
        }
        let selectedAt = Date(timeIntervalSince1970: defaults.double(forKey: selectedAtKey))
        let elapsedSlots = max(0, Int(date.timeIntervalSince(selectedAt) / rotationInterval))
        let step = randomCoprimeStep(count: cardCount, seed: Int(selectedAt.timeIntervalSince1970))
        return normalized(base + (elapsedSlots % cardCount) * step, count: cardCount)
    }

    @discardableResult
    static func selectNext(cardCount: Int, currentIndex: Int? = nil) -> Int {
        guard cardCount > 0 else { return 0 }
        let current = currentIndex.map { normalized($0, count: cardCount) }
            ?? selectedIndex(cardCount: cardCount) ?? 0
        let next = (current + 1) % cardCount
        sharedDefaults?.set(next, forKey: selectedIndexKey)
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: selectedAtKey)
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
        sharedDefaults?.set(next, forKey: selectedIndexKey)
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: selectedAtKey)
        return next
    }

    private static func normalized(_ index: Int, count: Int) -> Int {
        ((index % count) + count) % count
    }

    private static func randomCoprimeStep(count: Int, seed: Int) -> Int {
        guard count > 2 else { return 1 }
        var step = 1 + abs(seed % (count - 1))
        while greatestCommonDivisor(step, count) != 1 {
            step = step % (count - 1) + 1
        }
        return step
    }

    private static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var a = lhs
        var b = rhs
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return a
    }
}
