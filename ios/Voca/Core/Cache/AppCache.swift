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
    static let studyDidChangeNotification = Notification.Name("voca.cache.studyDidChange")

    private struct Record<Value: Codable>: Codable {
        let version: Int
        let savedAt: Date
        let value: Value
    }

    private static let version = 1
    private static let userKey = "current-user"
    private static let fileManager = FileManager.default
    /// Protects fast in-memory state only (`memoryRecords`, generations, user scope).
    /// Never hold `memoryLock` while acquiring `ioLock` or performing disk I/O.
    private static let memoryLock = NSLock()
    /// Serializes disk reads, writes and directory cleanup.
    /// Lock ordering invariant: `ioLock` may acquire `memoryLock`, never the reverse.
    private static let ioLock = NSLock()
    private static let diskQueue = DispatchQueue(label: "voca.cache.disk", qos: .userInitiated)
    /// Decoded hot records (user, cards, due, stats) reused in memory after the first disk read.
    private static var memoryRecords: [String: Any] = [:]
    /// Bounded cache for large A4 HTML sheets so memory auto-evicts under pressure.
    private static let htmlCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 24
        return cache
    }()
    private static var cachedUserId: Int?
    private static var clearGeneration: UInt64 = 0
    private static var currentSessionEpoch: UInt64 = 0
    private static var keyGenerations: [String: UInt64] = [:]

    /// Monotonically increments whenever the cache is cleared or switches to another user.
    /// Services use this to avoid coalescing or writing stale responses across sessions.
    static var sessionEpoch: UInt64 {
        withMemoryLock { currentSessionEpoch }
    }

    static func loadUser() -> User? {
        load(userKey, as: User.self)
    }

    static func saveUser(_ user: User) {
        let switchedUser: Bool = withMemoryLock {
            let previous = cachedUserId
            cachedUserId = user.id
            if let previous, previous != user.id {
                memoryRecords.removeAll(keepingCapacity: false)
                htmlCache.removeAllObjects()
                currentSessionEpoch &+= 1
                return true
            }
            return false
        }
        save(user, key: userKey)
        if switchedUser {
            notifyCardsDidChange()
        }
    }

    static func loadCards() -> [Card] {
        load(scoped("cards"), as: [Card].self) ?? []
    }

    static func saveCards(_ cards: [Card]) {
        save(cards, key: scoped("cards"))
        notifyCardsDidChange()
    }

    static func upsertCard(_ card: Card) {
        let key = scoped("cards")
        // Warm cache from disk outside memoryLock if not yet loaded.
        _ = loadRecord(key, as: [Card].self)
        let (updated, clearGen, keyGen): (Record<[Card]>, UInt64, UInt64) = withMemoryLock {
            var cards = (memoryRecords[key] as? Record<[Card]>)?.value ?? []
            if let index = cards.firstIndex(where: { $0.slug == card.slug }) {
                cards[index] = card
            } else {
                cards.insert(card, at: 0)
            }
            let record = Record(version: version, savedAt: Date(), value: cards)
            memoryRecords[key] = record
            let nextGen = (keyGenerations[key] ?? 0) &+ 1
            keyGenerations[key] = nextGen
            return (record, clearGeneration, nextGen)
        }
        enqueueDiskWrite(updated, key: key, clearGen: clearGen, keyGen: keyGen)
        notifyCardsDidChange()
    }

    static func removeCard(slug: String) {
        let cardsKey = scoped("cards")
        let dueKey = scoped("study-due")
        let htmlStorageKey = htmlKey(for: slug)
        _ = loadRecord(cardsKey, as: [Card].self)
        _ = loadRecord(dueKey, as: DueResponse.self)

        let pending: (
            cards: (Record<[Card]>, UInt64, UInt64),
            due: (Record<DueResponse>, UInt64, UInt64)?,
            htmlDeleteGen: (UInt64, UInt64)
        ) = withMemoryLock {
            let remainingCards = ((memoryRecords[cardsKey] as? Record<[Card]>)?.value ?? [])
                .filter { $0.slug != slug }
            let cardsRecord = Record(version: version, savedAt: Date(), value: remainingCards)
            memoryRecords[cardsKey] = cardsRecord
            let cardsGen = (keyGenerations[cardsKey] ?? 0) &+ 1
            keyGenerations[cardsKey] = cardsGen

            htmlCache.removeObject(forKey: htmlStorageKey as NSString)
            let htmlGen = (keyGenerations[htmlStorageKey] ?? 0) &+ 1
            keyGenerations[htmlStorageKey] = htmlGen

            var dueUpdate: (Record<DueResponse>, UInt64, UInt64)?
            if let currentDue = (memoryRecords[dueKey] as? Record<DueResponse>)?.value {
                let remainingDue = currentDue.cards.filter { $0.card.slug != slug }
                if remainingDue.count != currentDue.cards.count {
                    let updatedDue = DueResponse(count: max(0, remainingDue.count), cards: remainingDue)
                    let dueRecord = Record(version: version, savedAt: Date(), value: updatedDue)
                    memoryRecords[dueKey] = dueRecord
                    let dueGen = (keyGenerations[dueKey] ?? 0) &+ 1
                    keyGenerations[dueKey] = dueGen
                    dueUpdate = (dueRecord, clearGeneration, dueGen)
                }
            }

            return (
                cards: (cardsRecord, clearGeneration, cardsGen),
                due: dueUpdate,
                htmlDeleteGen: (clearGeneration, htmlGen)
            )
        }

        enqueueDiskWrite(pending.cards.0, key: cardsKey, clearGen: pending.cards.1, keyGen: pending.cards.2)
        if let due = pending.due {
            enqueueDiskWrite(due.0, key: dueKey, clearGen: due.1, keyGen: due.2)
            notifyStudyDidChange()
        }
        enqueueDiskDelete(key: htmlStorageKey, clearGen: pending.htmlDeleteGen.0, keyGen: pending.htmlDeleteGen.1)
        notifyCardsDidChange()
    }

    static func waitForPendingDiskWrites() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            diskQueue.async {
                continuation.resume()
            }
        }
    }

    static func cardsMetadata() -> CacheMetadata {
        let record: Record<[Card]>? = loadRecord(scoped("cards"), as: [Card].self)
        let bytes: Int64 = withIOLock {
            var total: Int64 = 0
            if let dir = directory,
               let enumerator = fileManager.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
                for case let url as URL in enumerator {
                    if let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                       let size = values.fileSize {
                        total += Int64(size)
                    }
                }
            }
            return total
        }
        return CacheMetadata(
            cardCount: record?.value.count ?? 0,
            savedAt: record?.savedAt,
            totalBytes: bytes
        )
    }

    static func loadHtml(slug: String) -> String? {
        let key = htmlKey(for: slug)
        if let cached = htmlCache.object(forKey: key as NSString) {
            return cached as String
        }
        guard let html = loadRecord(key, as: String.self, cacheInMemory: false)?.value else {
            return nil
        }
        htmlCache.setObject(html as NSString, forKey: key as NSString)
        return html
    }

    static func saveHtml(_ html: String, slug: String) {
        let key = htmlKey(for: slug)
        htmlCache.setObject(html as NSString, forKey: key as NSString)
        save(html, key: key, cacheInMemory: false)
    }

    static func loadStudyStats() -> StudyStats? {
        load(scoped("study-stats"), as: StudyStats.self)
    }

    static func saveStudyStats(_ stats: StudyStats) {
        save(stats, key: scoped("study-stats"))
        notifyStudyDidChange()
    }

    static func loadDue() -> DueResponse? {
        load(scoped("study-due"), as: DueResponse.self)
    }

    static func saveDue(_ due: DueResponse) {
        save(due, key: scoped("study-due"))
        notifyStudyDidChange()
    }

    static func removeDueCard(slug: String) {
        let dueKey = scoped("study-due")
        _ = loadRecord(dueKey, as: DueResponse.self)
        let pending: (Record<DueResponse>, UInt64, UInt64)? = withMemoryLock {
            guard let current = (memoryRecords[dueKey] as? Record<DueResponse>)?.value else { return nil }
            let remaining = current.cards.filter { $0.card.slug != slug }
            guard remaining.count != current.cards.count else { return nil }
            let updated = DueResponse(count: max(0, remaining.count), cards: remaining)
            let record = Record(version: version, savedAt: Date(), value: updated)
            memoryRecords[dueKey] = record
            let nextGen = (keyGenerations[dueKey] ?? 0) &+ 1
            keyGenerations[dueKey] = nextGen
            return (record, clearGeneration, nextGen)
        }
        if let pending {
            enqueueDiskWrite(pending.0, key: dueKey, clearGen: pending.1, keyGen: pending.2)
            notifyStudyDidChange()
        }
    }

    static func clearAll() {
        withIOLock {
            withMemoryLock {
                clearGeneration &+= 1
                currentSessionEpoch &+= 1
                cachedUserId = nil
                memoryRecords.removeAll(keepingCapacity: false)
                keyGenerations.removeAll(keepingCapacity: false)
                htmlCache.removeAllObjects()
            }
            if let dir = primaryDirectory {
                try? fileManager.removeItem(at: dir)
            }
            if let legacy = legacyCachesDirectory {
                try? fileManager.removeItem(at: legacy)
            }
        }
        notifyCardsDidChange()
        notifyStudyDidChange()
    }

    // MARK: - Private helpers

    private static func notifyCardsDidChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: cardsDidChangeNotification, object: nil)
        }
    }

    private static func notifyStudyDidChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: studyDidChangeNotification, object: nil)
        }
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

    private static func loadRecord<Value: Codable>(
        _ key: String,
        as type: Value.Type,
        cacheInMemory: Bool = true
    ) -> Record<Value>? {
        let snapshot: (Record<Value>?, UInt64) = withMemoryLock {
            if cacheInMemory,
               let cached = memoryRecords[key] as? Record<Value>,
               cached.version == version {
                return (cached, clearGeneration)
            }
            return (nil, clearGeneration)
        }
        if let cached = snapshot.0 {
            return cached
        }

        let loaded: Record<Value>? = withIOLock {
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

        guard let loaded else { return nil }

        if cacheInMemory {
            withMemoryLock {
                if clearGeneration == snapshot.1, memoryRecords[key] == nil {
                    memoryRecords[key] = loaded
                    if key == userKey, let user = loaded.value as? User, cachedUserId == nil {
                        cachedUserId = user.id
                    }
                }
            }
        }
        return loaded
    }

    private static func save<Value: Codable>(_ value: Value, key: String, cacheInMemory: Bool = true) {
        let record = Record(version: version, savedAt: Date(), value: value)
        let (clearGen, keyGen): (UInt64, UInt64) = withMemoryLock {
            if cacheInMemory {
                memoryRecords[key] = record
            }
            let nextGen = (keyGenerations[key] ?? 0) &+ 1
            keyGenerations[key] = nextGen
            return (clearGeneration, nextGen)
        }
        enqueueDiskWrite(record, key: key, clearGen: clearGen, keyGen: keyGen)
    }

    private static func isLatest(key: String, clearGen: UInt64, keyGen: UInt64) -> Bool {
        withMemoryLock {
            clearGeneration == clearGen && keyGenerations[key] == keyGen
        }
    }

    private static func enqueueDiskWrite<Value: Codable>(
        _ record: Record<Value>,
        key: String,
        clearGen: UInt64,
        keyGen: UInt64
    ) {
        diskQueue.async {
            guard isLatest(key: key, clearGen: clearGen, keyGen: keyGen),
                  let data = try? JSONEncoder().encode(record)
            else { return }

            withIOLock {
                guard isLatest(key: key, clearGen: clearGen, keyGen: keyGen),
                      let url = fileURL(for: key, createDirectory: true)
                else { return }
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    private static func enqueueDiskDelete(key: String, clearGen: UInt64, keyGen: UInt64) {
        diskQueue.async {
            withIOLock {
                guard isLatest(key: key, clearGen: clearGen, keyGen: keyGen) else { return }
                for baseDir in [primaryDirectory, legacyCachesDirectory].compactMap({ $0 }) {
                    let url = baseDir.appendingPathComponent(key).appendingPathExtension("json")
                    try? fileManager.removeItem(at: url)
                }
            }
        }
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

    private static func withMemoryLock<T>(_ work: () -> T) -> T {
        memoryLock.lock()
        defer { memoryLock.unlock() }
        return work()
    }

    private static func withIOLock<T>(_ work: () -> T) -> T {
        ioLock.lock()
        defer { ioLock.unlock() }
        return work()
    }
}
