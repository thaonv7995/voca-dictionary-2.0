import CryptoKit
import Foundation

struct AudioCacheStats: Sendable, Equatable {
    let fileCount: Int
    let totalBytes: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}

/// Thread-safe, two-level (memory + persistent disk) cache for synthesised TTS MP3 clips.
/// Stored in `Application Support/VocaAudioCache` (`isExcludedFromBackup = true`) so downloaded
/// pronunciation audio survives storage-pressure sweeps and remains playable offline.
actor AudioCacheStore {
    static let shared = AudioCacheStore()

    private struct InFlight {
        let id: UUID
        let generation: UInt64
        var waiterCount: Int
        let task: Task<Data, Error>
    }

    private let fileManager = FileManager.default
    private let maxDiskBytes: Int64 = 200 * 1024 * 1024 // 200 MB persistent cap
    private let memoryCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.totalCostLimit = 16 * 1024 * 1024 // ~16 MB hot audio buffer
        return cache
    }()

    private var fileSizesByKey: [String: Int64] = [:]
    private var totalDiskBytes: Int64 = 0
    private var isIndexed = false
    private var clearGeneration: UInt64 = 0
    private var inFlight: [String: InFlight] = [:]

    private init() {}

    static func cacheKey(text: String, voiceModel: String) -> String {
        let normalizedVoice = voiceModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = "v1|\(normalizedVoice)|\(normalizedText)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func contains(text: String, voiceModel: String) -> Bool {
        let key = Self.cacheKey(text: text, voiceModel: voiceModel)
        if memoryCache.object(forKey: key as NSString) != nil {
            return true
        }
        ensureIndexed()
        return fileSizesByKey[key] != nil
    }

    func cachedKeys(for items: [(text: String, voiceModel: String)]) -> Set<String> {
        ensureIndexed()
        var matched = Set<String>()
        matched.reserveCapacity(items.count)
        for item in items {
            let key = Self.cacheKey(text: item.text, voiceModel: item.voiceModel)
            if memoryCache.object(forKey: key as NSString) != nil || fileSizesByKey[key] != nil {
                matched.insert(key)
            }
        }
        return matched
    }

    func cachedCount(for items: [(text: String, voiceModel: String)]) -> Int {
        ensureIndexed()
        var count = 0
        for item in items {
            let key = Self.cacheKey(text: item.text, voiceModel: item.voiceModel)
            if memoryCache.object(forKey: key as NSString) != nil || fileSizesByKey[key] != nil {
                count += 1
            }
        }
        return count
    }

    func cachedData(text: String, voiceModel: String) -> Data? {
        let key = Self.cacheKey(text: text, voiceModel: voiceModel)
        if let hot = memoryCache.object(forKey: key as NSString) {
            return hot as Data
        }
        ensureIndexed()
        guard fileSizesByKey[key] != nil,
              let url = fileURL(for: key, createDirectory: false),
              let data = try? Data(contentsOf: url), data.count >= 64
        else {
            removeIndexEntry(forKey: key)
            return nil
        }
        // Touch modification date for LRU eviction tracking.
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        return data
    }

    /// Removes a specific cached entry (e.g. if AVAudioPlayer failed to decode corrupted audio).
    func remove(text: String, voiceModel: String) {
        let key = Self.cacheKey(text: text, voiceModel: voiceModel)
        memoryCache.removeObject(forKey: key as NSString)
        removeIndexEntry(forKey: key)
        if let url = fileURL(for: key, createDirectory: false) {
            try? fileManager.removeItem(at: url)
        }
    }

    /// Returns cached audio if already persisted, coalesces identical concurrent requests, or fetches via `loader` and persists to disk.
    func getOrFetchAudio(
        text: String,
        voiceModel: String,
        loader: @escaping @Sendable () async throws -> Data
    ) async throws -> (data: Data, fromCache: Bool) {
        try Task.checkCancellation()
        if let existing = cachedData(text: text, voiceModel: voiceModel) {
            return (existing, true)
        }

        let key = Self.cacheKey(text: text, voiceModel: voiceModel)
        let entryID: UUID
        let task: Task<Data, Error>
        let joinedExisting: Bool

        if var running = inFlight[key], running.generation == clearGeneration {
            running.waiterCount += 1
            inFlight[key] = running
            entryID = running.id
            task = running.task
            joinedExisting = true
        } else {
            let id = UUID()
            let requestGeneration = clearGeneration
            let newTask = Task<Data, Error> {
                do {
                    let data = try await loader()
                    guard data.count >= 64 else {
                        throw ApiError(status: 0, code: "EMPTY_AUDIO", message: "Dữ liệu âm thanh từ máy chủ không hợp lệ.")
                    }
                    self.finishInFlight(id: id, key: key, generation: requestGeneration, data: data)
                    return data
                } catch {
                    self.clearInFlightIfCurrent(id: id, key: key)
                    throw error
                }
            }
            inFlight[key] = InFlight(id: id, generation: requestGeneration, waiterCount: 1, task: newTask)
            entryID = id
            task = newTask
            joinedExisting = false
        }

        let data = try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            Task {
                await self.decrementWaiter(id: entryID, key: key)
            }
        }
        try Task.checkCancellation()
        return (data, joinedExisting)
    }

    func stats() -> AudioCacheStats {
        ensureIndexed()
        return AudioCacheStats(fileCount: fileSizesByKey.count, totalBytes: totalDiskBytes)
    }

    func clearAll() {
        clearGeneration &+= 1
        for (_, entry) in inFlight {
            entry.task.cancel()
        }
        inFlight.removeAll()
        memoryCache.removeAllObjects()
        fileSizesByKey.removeAll()
        totalDiskBytes = 0
        isIndexed = true
        if let dir = cacheDirectory {
            try? fileManager.removeItem(at: dir)
        }
    }

    // MARK: - Private helpers

    private func finishInFlight(id: UUID, key: String, generation: UInt64, data: Data) {
        if inFlight[key]?.id == id {
            inFlight[key] = nil
        }
        guard generation == clearGeneration else { return }
        persist(data, forKey: key)
    }

    private func clearInFlightIfCurrent(id: UUID, key: String) {
        if inFlight[key]?.id == id {
            inFlight[key] = nil
        }
    }

    private func decrementWaiter(id: UUID, key: String) {
        guard var entry = inFlight[key], entry.id == id else { return }
        entry.waiterCount -= 1
        if entry.waiterCount <= 0 {
            inFlight[key] = nil
            entry.task.cancel()
        } else {
            inFlight[key] = entry
        }
    }

    private func persist(_ data: Data, forKey key: String) {
        ensureIndexed()
        memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        guard let url = fileURL(for: key, createDirectory: true) else { return }
        if (try? data.write(to: url, options: .atomic)) != nil {
            let newSize = Int64(data.count)
            if let oldSize = fileSizesByKey[key] {
                totalDiskBytes = max(0, totalDiskBytes - oldSize)
            }
            fileSizesByKey[key] = newSize
            totalDiskBytes += newSize
            if totalDiskBytes > maxDiskBytes {
                evictIfNeeded()
            }
        }
    }

    private func removeIndexEntry(forKey key: String) {
        if let size = fileSizesByKey.removeValue(forKey: key) {
            totalDiskBytes = max(0, totalDiskBytes - size)
        }
    }

    private func evictIfNeeded() {
        guard totalDiskBytes > maxDiskBytes,
              let dir = cacheDirectory,
              let urls = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
              )
        else { return }

        let targetBytes = Int64(Double(maxDiskBytes) * 0.8)
        let sorted = urls
            .filter { $0.pathExtension.lowercased() == "mp3" }
            .compactMap { url -> (url: URL, key: String, size: Int64, date: Date)? in
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let size = Int64(values?.fileSize ?? 0)
                let date = values?.contentModificationDate ?? .distantPast
                return (url, url.deletingPathExtension().lastPathComponent, size, date)
            }
            .sorted { $0.date < $1.date }

        for item in sorted {
            guard totalDiskBytes > targetBytes else { break }
            try? fileManager.removeItem(at: item.url)
            memoryCache.removeObject(forKey: item.key as NSString)
            removeIndexEntry(forKey: item.key)
        }
    }

    private func ensureIndexed() {
        guard !isIndexed else { return }
        isIndexed = true
        fileSizesByKey.removeAll()
        totalDiskBytes = 0
        guard let dir = cacheDirectory,
              let urls = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
              )
        else { return }
        for url in urls where url.pathExtension.lowercased() == "mp3" {
            let key = url.deletingPathExtension().lastPathComponent
            let size = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            fileSizesByKey[key] = size
            totalDiskBytes += size
        }
    }

    private var cacheDirectory: URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("VocaAudioCache", isDirectory: true)
    }

    private func fileURL(for key: String, createDirectory: Bool) -> URL? {
        guard var dir = cacheDirectory else { return nil }
        if createDirectory {
            let existed = fileManager.fileExists(atPath: dir.path)
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            if !existed {
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try? dir.setResourceValues(values)
            }
        }
        return dir.appendingPathComponent(key).appendingPathExtension("mp3")
    }
}
