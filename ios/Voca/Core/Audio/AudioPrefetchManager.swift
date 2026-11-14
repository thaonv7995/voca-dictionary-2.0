import Foundation
import Observation

enum PrefetchLanguageScope: String, CaseIterable, Identifiable, Sendable {
    case all, english, chinese

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Tất cả"
        case .english: return "English"
        case .chinese: return "Tiếng Trung"
        }
    }
}

struct AudioPrefetchTarget: Sendable, Hashable {
    let text: String
    let voiceModel: String
}

/// Manages concurrent multi-worker preloading of vocabulary & example TTS audio into `AudioCacheStore`.
/// Runs a bounded `TaskGroup` worker pool (`threadCount`, default 4) so large decks download quickly
/// without overwhelming the TTS backend, and skips any clips already cached on disk.
@MainActor
@Observable
final class AudioPrefetchManager {
    static let shared = AudioPrefetchManager()

    private enum Keys {
        static let threadCount = "voca.audio.prefetch.threads"
        static let includeExamples = "voca.audio.prefetch.includeExamples"
        static let languageScope = "voca.audio.prefetch.scope"
        static let autoCacheNewCards = "voca.audio.prefetch.autoNewCards"
    }

    var threadCount: Int {
        didSet {
            let clamped = max(2, min(6, threadCount))
            if clamped != threadCount {
                threadCount = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: Keys.threadCount)
        }
    }

    var includeExamples: Bool {
        didSet { UserDefaults.standard.set(includeExamples, forKey: Keys.includeExamples) }
    }

    var languageScope: PrefetchLanguageScope {
        didSet { UserDefaults.standard.set(languageScope.rawValue, forKey: Keys.languageScope) }
    }

    var autoCacheNewCards: Bool {
        didSet { UserDefaults.standard.set(autoCacheNewCards, forKey: Keys.autoCacheNewCards) }
    }

    private(set) var isRunning = false
    private(set) var totalCount = 0
    private(set) var processedCount = 0
    private(set) var cachedHitCount = 0
    private(set) var downloadedCount = 0
    private(set) var failedCount = 0
    private(set) var downloadedBytes: Int64 = 0
    private(set) var currentSampleText = ""
    private(set) var lastError: String?
    private(set) var finishedAt: Date?
    private(set) var cacheStats = AudioCacheStats(fileCount: 0, totalBytes: 0)
    private(set) var coverage: (cached: Int, total: Int) = (0, 0)

    private var activeTask: Task<Void, Never>?

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return min(1, Double(processedCount) / Double(totalCount))
    }

    private init() {
        let defaults = UserDefaults.standard
        let storedThreads = defaults.integer(forKey: Keys.threadCount)
        threadCount = storedThreads >= 2 ? min(6, storedThreads) : 4
        includeExamples = defaults.object(forKey: Keys.includeExamples) as? Bool ?? true
        languageScope = PrefetchLanguageScope(rawValue: defaults.string(forKey: Keys.languageScope) ?? "") ?? .all
        autoCacheNewCards = defaults.object(forKey: Keys.autoCacheNewCards) as? Bool ?? false
    }

    func refreshStats(cards: [Card]? = nil) async {
        let statsTask = Task { await AudioCacheStore.shared.stats() }
        let sourceCards = cards ?? AppCache.loadCards()
        let targets = await buildTargets(from: sourceCards, scope: languageScope, includeExamples: includeExamples)
        let pairList = targets.map { ($0.text, $0.voiceModel) }
        let cached = await AudioCacheStore.shared.cachedCount(for: pairList)
        cacheStats = await statsTask.value
        coverage = (cached: cached, total: targets.count)
    }

    func start(cards: [Card]? = nil) {
        guard !isRunning else { return }

        isRunning = true
        finishedAt = nil
        lastError = nil
        totalCount = 0
        processedCount = 0
        cachedHitCount = 0
        downloadedCount = 0
        failedCount = 0
        downloadedBytes = 0
        currentSampleText = ""

        let workers = max(2, min(6, threadCount))
        let includeExamplesSnapshot = includeExamples
        let scopeSnapshot = languageScope

        activeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isRunning = false
                self.currentSampleText = ""
                self.activeTask = nil
            }

            await VoiceSettingsStore.shared.refreshIfNeeded()

            var sourceCards = cards ?? AppCache.loadCards()
            if sourceCards.isEmpty {
                sourceCards = (try? await CardsService().list()) ?? []
            }

            let allTargets = await buildTargets(
                from: sourceCards,
                scope: scopeSnapshot,
                includeExamples: includeExamplesSnapshot
            )
            totalCount = allTargets.count

            guard !allTargets.isEmpty else {
                finishedAt = Date()
                await refreshStats(cards: sourceCards)
                return
            }

            // Skip clips already persisted on disk before launching concurrent download workers.
            var pending: [AudioPrefetchTarget] = []
            for target in allTargets {
                if Task.isCancelled { break }
                if await AudioCacheStore.shared.contains(text: target.text, voiceModel: target.voiceModel) {
                    cachedHitCount += 1
                    processedCount += 1
                } else {
                    pending.append(target)
                }
            }

            if pending.isEmpty || Task.isCancelled {
                finishedAt = Date()
                await refreshStats(cards: sourceCards)
                return
            }

            let tts = TTSService()
            await withTaskGroup(of: WorkerOutcome.self) { group in
                var nextIndex = 0
                let initialCount = min(workers, pending.count)
                for _ in 0..<initialCount {
                    let item = pending[nextIndex]
                    nextIndex += 1
                    group.addTask {
                        await Self.downloadOne(target: item, tts: tts)
                    }
                }

                while let outcome = await group.next() {
                    self.applyOutcome(outcome)

                    if self.processedCount % 6 == 0 {
                        self.cacheStats = await AudioCacheStore.shared.stats()
                    }

                    if !Task.isCancelled && nextIndex < pending.count {
                        let nextItem = pending[nextIndex]
                        nextIndex += 1
                        group.addTask {
                            await Self.downloadOne(target: nextItem, tts: tts)
                        }
                    }
                }
            }

            finishedAt = Date()
            await refreshStats(cards: sourceCards)
        }
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
        isRunning = false
        currentSampleText = ""
    }

    func clearAudioCache(cards: [Card]? = nil) async {
        cancel()
        await AudioCacheStore.shared.clearAll()
        totalCount = 0
        processedCount = 0
        cachedHitCount = 0
        downloadedCount = 0
        failedCount = 0
        downloadedBytes = 0
        lastError = nil
        finishedAt = nil
        await refreshStats(cards: cards)
    }

    /// Quietly caches a newly created card's headword + examples in the background when enabled.
    func cacheCardInBackgroundIfEnabled(_ card: Card) {
        guard autoCacheNewCards, !VoiceSettingsStore.shared.useDeviceSpeech else { return }
        Task {
            await VoiceSettingsStore.shared.refreshIfNeeded()
            let targets = await buildTargets(from: [card], scope: .all, includeExamples: includeExamples)
            let tts = TTSService()
            await withTaskGroup(of: WorkerOutcome.self) { group in
                for target in targets {
                    group.addTask {
                        await Self.downloadOne(target: target, tts: tts)
                    }
                }
                for await _ in group {}
            }
            await refreshStats()
        }
    }

    // MARK: - Helpers

    private struct WorkerOutcome: Sendable {
        let text: String
        let fromCache: Bool
        let byteCount: Int
        let errorMessage: String?
    }

    nonisolated private static func downloadOne(target: AudioPrefetchTarget, tts: TTSService) async -> WorkerOutcome {
        if Task.isCancelled {
            return WorkerOutcome(text: target.text, fromCache: false, byteCount: 0, errorMessage: nil)
        }
        do {
            let result = try await tts.ensureCached(cleanText: target.text, voiceModel: target.voiceModel)
            return WorkerOutcome(
                text: target.text,
                fromCache: result.fromCache,
                byteCount: result.byteCount,
                errorMessage: nil
            )
        } catch is CancellationError {
            return WorkerOutcome(text: target.text, fromCache: false, byteCount: 0, errorMessage: nil)
        } catch {
            let message = (error as? ApiError)?.message ?? error.localizedDescription
            return WorkerOutcome(text: target.text, fromCache: false, byteCount: 0, errorMessage: message)
        }
    }

    private func applyOutcome(_ outcome: WorkerOutcome) {
        processedCount += 1
        currentSampleText = outcome.text
        if let err = outcome.errorMessage {
            failedCount += 1
            if lastError == nil { lastError = err }
        } else if outcome.fromCache {
            cachedHitCount += 1
        } else {
            downloadedCount += 1
            downloadedBytes += Int64(outcome.byteCount)
        }
    }

    private func buildTargets(
        from cards: [Card],
        scope: PrefetchLanguageScope,
        includeExamples: Bool
    ) async -> [AudioPrefetchTarget] {
        let filteredCards = cards.filter { card in
            switch scope {
            case .all: return true
            case .english: return card.cardLanguage == .english
            case .chinese: return card.cardLanguage == .chinese
            }
        }

        let tts = TTSService()
        var seen = Set<AudioPrefetchTarget>()
        var targets: [AudioPrefetchTarget] = []

        func appendIfValid(rawText: String, language: CardLanguage) async {
            let resolved = await tts.resolveInput(rawText, language: language)
            guard !resolved.text.isEmpty else { return }
            let target = AudioPrefetchTarget(text: resolved.text, voiceModel: resolved.voice)
            if seen.insert(target).inserted {
                targets.append(target)
            }
        }

        for card in filteredCards {
            let lang = card.cardLanguage
            await appendIfValid(rawText: card.word, language: lang)

            if includeExamples, let examples = card.examples {
                for rawExample in examples where !rawExample.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let spoken = card.isChinese ? ChineseExample(rawExample).hanzi : rawExample
                    await appendIfValid(rawText: spoken, language: lang)
                }
            }
        }

        return targets
    }
}
