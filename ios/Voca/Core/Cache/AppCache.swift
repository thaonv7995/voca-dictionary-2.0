import Foundation

/// Persistent offline cache for user profile, vocabulary cards, A4 study HTML, and study progress.
/// Marked `isExcludedFromBackup` so offline vocabulary stays available across storage pressure without
/// inflating iCloud backups. Screens paint immediately from cache and refresh from the server.
enum AppCache {
    struct CacheMetadata: Sendable {
        let cardCount: Int
        let savedAt: Date?
        let totalBytes: Int64
    }

    static let cardsDidChangeNotification = Notification.Name("voca.cache.cardsDidChange")

    private struct Record<Value: Codable>: Codable {
        let version: Int
        let savedAt: Date
        let value: Value
    }

    private static let version = 1
    private static let userKey = "current-user"
    private static let fileManager = FileManager.default
    private static let lock = NSLock()

    static func loadUser() -> User? {
        withLock { load(userKey, as: User.self) }
    }

    static func saveUser(_ user: User) {
        withLock { save(user, key: userKey) }
    }

    static func loadCards() -> [Card] {
        withLock { load(scoped("cards"), as: [Card].self) ?? [] }
    }

    static func saveCards(_ cards: [Card]) {
        withLock { save(cards, key: scoped("cards")) }
        notifyCardsDidChange()
    }

    static func upsertCard(_ card: Card) {
        withLock {
            var cards = load(scoped("cards"), as: [Card].self) ?? []
            if let index = cards.firstIndex(where: { $0.slug == card.slug }) {
                cards[index] = card
            } else {
                cards.insert(card, at: 0)
            }
            save(cards, key: scoped("cards"))
        }
        notifyCardsDidChange()
    }

    static func removeCard(slug: String) {
        withLock {
            let cards = (load(scoped("cards"), as: [Card].self) ?? []).filter { $0.slug != slug }
            save(cards, key: scoped("cards"))
            if let url = fileURL(for: htmlKey(for: slug)) {
                try? fileManager.removeItem(at: url)
            }
            removeDueCardLocked(slug: slug)
        }
        notifyCardsDidChange()
    }

    static func cardsMetadata() -> CacheMetadata {
        withLock {
            let record: Record<[Card]>? = loadRecord(scoped("cards"), as: [Card].self)
            var bytes: Int64 = 0
            if let dir = directory,
               let enumerator = fileManager.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                for case let url as URL in enumerator {
                    if let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                       let size = values.fileSize {
                        bytes += Int64(size)
                    }
                }
            }
            return CacheMetadata(
                cardCount: record?.value.count ?? 0,
                savedAt: record?.savedAt,
                totalBytes: bytes
            )
        }
    }

    static func loadHtml(slug: String) -> String? {
        withLock { load(htmlKey(for: slug), as: String.self) }
    }

    static func saveHtml(_ html: String, slug: String) {
        withLock { save(html, key: htmlKey(for: slug)) }
    }

    static func loadStudyStats() -> StudyStats? {
        withLock { load(scoped("study-stats"), as: StudyStats.self) }
    }

    static func saveStudyStats(_ stats: StudyStats) {
        withLock { save(stats, key: scoped("study-stats")) }
    }

    static func loadDue() -> DueResponse? {
        withLock { load(scoped("study-due"), as: DueResponse.self) }
    }

    static func saveDue(_ due: DueResponse) {
        withLock { save(due, key: scoped("study-due")) }
    }

    static func removeDueCard(slug: String) {
        withLock { removeDueCardLocked(slug: slug) }
    }

    static func clearAll() {
        withLock {
            if let dir = primaryDirectory {
                try? fileManager.removeItem(at: dir)
            }
            if let legacy = legacyCachesDirectory {
                try? fileManager.removeItem(at: legacy)
            }
        }
        notifyCardsDidChange()
    }

    // MARK: - Private helpers

    private static func notifyCardsDidChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: cardsDidChangeNotification, object: nil)
        }
    }

    private static func removeDueCardLocked(slug: String) {
        guard let current = load(scoped("study-due"), as: DueResponse.self) else { return }
        let remaining = current.cards.filter { $0.card.slug != slug }
        guard remaining.count != current.cards.count else { return }
        let updated = DueResponse(count: max(0, remaining.count), cards: remaining)
        save(updated, key: scoped("study-due"))
    }

    private static func htmlKey(for slug: String) -> String {
        let safe = Data(slug.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return scoped("a4-\(safe)")
    }

    private static func scoped(_ key: String) -> String {
        guard let user = load(userKey, as: User.self) else { return key }
        return "user-\(user.id)-\(key)"
    }

    private static func load<Value: Codable>(_ key: String, as type: Value.Type) -> Value? {
        loadRecord(key, as: type)?.value
    }

    private static func loadRecord<Value: Codable>(_ key: String, as type: Value.Type) -> Record<Value>? {
        for baseDir in [primaryDirectory, legacyCachesDirectory].compactMap({ $0 }) {
            let url = baseDir.appendingPathComponent(key).appendingPathExtension("json")
            guard let data = try? Data(contentsOf: url),
                  let record = try? JSONDecoder().decode(Record<Value>.self, from: data),
                  record.version == version
            else { continue }
            return record
        }
        return nil
    }

    private static func save<Value: Codable>(_ value: Value, key: String) {
        guard let url = fileURL(for: key, createDirectory: true),
              let data = try? JSONEncoder().encode(
                Record(version: version, savedAt: Date(), value: value))
        else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static var directory: URL? {
        primaryDirectory ?? legacyCachesDirectory
    }

    private static var primaryDirectory: URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("VocaAppCache", isDirectory: true)
    }

    private static var legacyCachesDirectory: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("VocaAppCache", isDirectory: true)
    }

    private static func fileURL(for key: String, createDirectory: Bool = false) -> URL? {
        guard var dir = directory else { return nil }
        if createDirectory {
            let existed = fileManager.fileExists(atPath: dir.path)
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            if !existed {
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try? dir.setResourceValues(values)
            }
        }
        return dir.appendingPathComponent(key).appendingPathExtension("json")
    }

    private static func withLock<T>(_ work: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }
}
