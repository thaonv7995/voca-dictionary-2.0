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

    private let fileManager = FileManager.default
    private let memoryCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.totalCostLimit = 16 * 1024 * 1024 // ~16 MB hot audio buffer
        return cache
    }()

    private var knownKeys: Set<String> = []
    private var isIndexed = false
    private var inFlight: [String: Task<Data, Error>] = [:]

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
        return knownKeys.contains(key)
    }

    func cachedCount(for items: [(text: String, voiceModel: String)]) -> Int {
        ensureIndexed()
        var count = 0
        for item in items {
            let key = Self.cacheKey(text: item.text, voiceModel: item.voiceModel)
            if memoryCache.object(forKey: key as NSString) != nil || knownKeys.contains(key) {
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
        guard knownKeys.contains(key), let url = fileURL(for: key, createDirectory: false),
              let data = try? Data(contentsOf: url), data.count >= 64
        else {
            knownKeys.remove(key)
            return nil
        }
        memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        return data
    }

    /// Returns cached audio if already persisted, coalesces identical concurrent requests, or fetches via `loader` and persists to disk.
    func getOrFetchAudio(
        text: String,
        voiceModel: String,
        loader: @escaping @Sendable () async throws -> Data
    ) async throws -> (data: Data, fromCache: Bool) {
        if let existing = cachedData(text: text, voiceModel: voiceModel) {
            return (existing, true)
        }

        let key = Self.cacheKey(text: text, voiceModel: voiceModel)
        if let running = inFlight[key] {
            let data = try await running.value
            return (data, true)
        }

        let task = Task<Data, Error> {
            try await loader()
        }
        inFlight[key] = task

        do {
            let data = try await task.value
            inFlight[key] = nil
            guard data.count >= 64 else {
                throw ApiError(status: 0, code: "EMPTY_AUDIO", message: "Dữ liệu âm thanh từ máy chủ không hợp lệ.")
            }
            persist(data, forKey: key)
            return (data, false)
        } catch {
            inFlight[key] = nil
            throw error
        }
    }

    func stats() -> AudioCacheStats {
        ensureIndexed()
        guard let dir = cacheDirectory,
              let urls = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
              )
        else {
            return AudioCacheStats(fileCount: 0, totalBytes: 0)
        }

        var count = 0
        var totalBytes: Int64 = 0
        for url in urls where url.pathExtension.lowercased() == "mp3" {
            count += 1
            if let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                totalBytes += Int64(size)
            }
        }
        return AudioCacheStats(fileCount: count, totalBytes: totalBytes)
    }

    func clearAll() {
        for (_, task) in inFlight {
            task.cancel()
        }
        inFlight.removeAll()
        memoryCache.removeAllObjects()
        knownKeys.removeAll()
        isIndexed = true
        if let dir = cacheDirectory {
            try? fileManager.removeItem(at: dir)
        }
    }

    // MARK: - Private helpers

    private func persist(_ data: Data, forKey key: String) {
        memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        guard let url = fileURL(for: key, createDirectory: true) else { return }
        if (try? data.write(to: url, options: .atomic)) != nil {
            knownKeys.insert(key)
        }
    }

    private func ensureIndexed() {
        guard !isIndexed else { return }
        isIndexed = true
        guard let dir = cacheDirectory,
              let urls = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        else { return }
        for url in urls where url.pathExtension.lowercased() == "mp3" {
            knownKeys.insert(url.deletingPathExtension().lastPathComponent)
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
