import Foundation

/// Small, versioned disk cache used to paint the signed-in UI immediately at launch.
/// Every screen still refreshes from the server; cached values are only the first frame.
enum AppCache {
    private struct Record<Value: Codable>: Codable {
        let version: Int
        let savedAt: Date
        let value: Value
    }

    private static let version = 1
    private static let userKey = "current-user"
    private static let fileManager = FileManager.default

    static func loadUser() -> User? { load(userKey, as: User.self) }

    static func saveUser(_ user: User) {
        save(user, key: userKey)
    }

    static func loadCards() -> [Card] {
        load(scoped("cards"), as: [Card].self) ?? []
    }

    static func saveCards(_ cards: [Card]) {
        save(cards, key: scoped("cards"))
    }

    static func upsertCard(_ card: Card) {
        var cards = loadCards()
        if let index = cards.firstIndex(where: { $0.slug == card.slug }) {
            cards[index] = card
        } else {
            cards.insert(card, at: 0)
        }
        saveCards(cards)
    }

    static func removeCard(slug: String) {
        saveCards(loadCards().filter { $0.slug != slug })
    }

    static func loadStudyStats() -> StudyStats? {
        load(scoped("study-stats"), as: StudyStats.self)
    }

    static func saveStudyStats(_ stats: StudyStats) {
        save(stats, key: scoped("study-stats"))
    }

    static func loadDue() -> DueResponse? {
        load(scoped("study-due"), as: DueResponse.self)
    }

    static func saveDue(_ due: DueResponse) {
        save(due, key: scoped("study-due"))
    }

    static func clearAll() {
        guard let directory else { return }
        try? fileManager.removeItem(at: directory)
    }

    private static func scoped(_ key: String) -> String {
        guard let user = loadUser() else { return key }
        return "user-\(user.id)-\(key)"
    }

    private static func load<Value: Codable>(_ key: String, as type: Value.Type) -> Value? {
        guard let url = fileURL(for: key),
              let data = try? Data(contentsOf: url),
              let record = try? JSONDecoder().decode(Record<Value>.self, from: data),
              record.version == version
        else { return nil }
        return record.value
    }

    private static func save<Value: Codable>(_ value: Value, key: String) {
        guard let url = fileURL(for: key, createDirectory: true),
              let data = try? JSONEncoder().encode(
                Record(version: version, savedAt: Date(), value: value))
        else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static var directory: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("VocaAppCache", isDirectory: true)
    }

    private static func fileURL(for key: String, createDirectory: Bool = false) -> URL? {
        guard let directory else { return nil }
        if createDirectory {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent(key).appendingPathExtension("json")
    }
}
