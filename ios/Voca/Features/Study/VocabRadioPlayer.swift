import AVFoundation
import Foundation
import MediaPlayer
import Observation
import UIKit

/// Sequential hands-free vocabulary radio player supporting background audio, Lock Screen / Control Center /
/// Dynamic Island (`MPNowPlayingInfoCenter`), and AirPods / headphone controls (`MPRemoteCommandCenter`).
///
/// Audio timeline per card:
/// 1. Speak headword (1st time)
/// 2. Short pause → Speak headword (2nd / Nth time)
/// 3. Active-recall thinking pause (default 2s, using hardware silent PCM WAV so iOS never suspends in background)
/// 4. Speak Vietnamese meaning (`vi-VN`)
/// 5. Speak example sentence (optional)
/// 6. Transition pause → Advance to next card (auto-reshuffling endlessly or until Sleep Timer finishes)
@MainActor
@Observable
final class VocabRadioPlayer {
    static let shared = VocabRadioPlayer()

    enum PlaybackStep: Equatable {
        case idle
        case word(attempt: Int, total: Int)
        case thinkingPause
        case meaningVi
        case example
        case transition

        var title: String {
            switch self {
            case .idle:
                return "Sẵn sàng phát"
            case let .word(attempt, total):
                return total > 1 ? "Đọc từ vựng (Lần \(attempt)/\(total))" : "Đọc từ vựng"
            case .thinkingPause:
                return "Nghỉ tự nhẩm nghĩa…"
            case .meaningVi:
                return "Đọc nghĩa tiếng Việt"
            case .example:
                return "Đọc câu ví dụ"
            case .transition:
                return "Chuyển qua từ tiếp theo…"
            }
        }

        var icon: String {
            switch self {
            case .idle: return "headphones"
            case .word: return "speaker.wave.2.fill"
            case .thinkingPause: return "brain.head.profile"
            case .meaningVi: return "character.book.closed.fill"
            case .example: return "text.quote"
            case .transition: return "forward.fill"
            }
        }

        var isMeaningRevealed: Bool {
            switch self {
            case .meaningVi, .example, .transition:
                return true
            case .idle, .word, .thinkingPause:
                return false
            }
        }
    }

    enum SleepTimerOption: String, CaseIterable, Identifiable {
        case off
        case cards10
        case cards20
        case cards50
        case minutes15
        case minutes30
        case minutes45

        var id: String { rawValue }

        var label: String {
            switch self {
            case .off: return "Không giới hạn"
            case .cards10: return "Sau 10 từ"
            case .cards20: return "Sau 20 từ"
            case .cards50: return "Sau 50 từ"
            case .minutes15: return "15 phút"
            case .minutes30: return "30 phút"
            case .minutes45: return "45 phút"
            }
        }
    }

    private enum Keys {
        static let wordRepeatCount = "voca.radio.wordRepeatCount"
        static let thinkingDelaySeconds = "voca.radio.thinkingDelaySeconds"
        static let speakMeaningVi = "voca.radio.speakMeaningVi"
        static let speakExample = "voca.radio.speakExample"
        static let hideMeaningDuringPause = "voca.radio.hideMeaningDuringPause"
    }

    static let thinkingDelayRange: ClosedRange<Double> = 1.0...10.0

    // MARK: - Persisted Settings

    var wordRepeatCount: Int {
        didSet {
            let clamped = max(1, min(3, wordRepeatCount))
            if clamped != wordRepeatCount {
                wordRepeatCount = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: Keys.wordRepeatCount)
        }
    }

    var thinkingDelaySeconds: Double {
        didSet {
            let stepped = ((thinkingDelaySeconds * 2).rounded() / 2)
            let clamped = min(max(stepped, Self.thinkingDelayRange.lowerBound), Self.thinkingDelayRange.upperBound)
            if clamped != thinkingDelaySeconds {
                thinkingDelaySeconds = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: Keys.thinkingDelaySeconds)
        }
    }

    var speakMeaningVi: Bool {
        didSet { UserDefaults.standard.set(speakMeaningVi, forKey: Keys.speakMeaningVi) }
    }

    var speakExample: Bool {
        didSet { UserDefaults.standard.set(speakExample, forKey: Keys.speakExample) }
    }

    var hideMeaningDuringPause: Bool {
        didSet { UserDefaults.standard.set(hideMeaningDuringPause, forKey: Keys.hideMeaningDuringPause) }
    }

    var sleepTimer: SleepTimerOption = .off {
        didSet { resetSleepTimerBounds() }
    }

    // MARK: - Playback State

    private(set) var queue: [Card] = []
    private(set) var deckTitle: String = "Đài từ vựng"
    private(set) var currentIndex: Int = 0
    private(set) var isPlaying: Bool = false
    private(set) var isPaused: Bool = false
    private(set) var step: PlaybackStep = .idle
    private(set) var playedCardsCount: Int = 0
    private(set) var sessionStartedAt: Date?

    private var loopTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var remoteCommandsConfigured = false
    private var wasPlayingBeforeInterruption = false
    private var sleepTimerDeadline: Date?
    private var sleepTimerMaxCards: Int?
    private let tts = TTSService()

    var isActive: Bool {
        !queue.isEmpty && (isPlaying || isPaused)
    }

    var currentCard: Card? {
        queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    }

    var nextCardPreview: Card? {
        guard queue.count > 1 else { return nil }
        let nextIdx = (currentIndex + 1) % queue.count
        return queue[nextIdx]
    }

    var shouldShowMeaningNow: Bool {
        if !hideMeaningDuringPause { return true }
        return step.isMeaningRevealed
    }

    var remainingSleepSummary: String? {
        switch sleepTimer {
        case .off:
            return nil
        case .cards10, .cards20, .cards50:
            guard let maxCards = sleepTimerMaxCards else { return nil }
            let left = max(0, maxCards - playedCardsCount)
            return "Còn \(left) từ"
        case .minutes15, .minutes30, .minutes45:
            guard let deadline = sleepTimerDeadline else { return nil }
            let remainingSec = max(0, Int(deadline.timeIntervalSinceNow.rounded()))
            let mins = Int(ceil(Double(remainingSec) / 60.0))
            return "Còn ~\(max(1, mins)) phút"
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        let storedRepeats = defaults.integer(forKey: Keys.wordRepeatCount)
        wordRepeatCount = (1...3).contains(storedRepeats) ? storedRepeats : 2
        let storedDelay = defaults.object(forKey: Keys.thinkingDelaySeconds) as? Double ?? 2.0
        thinkingDelaySeconds = min(max((storedDelay * 2).rounded() / 2, 1.0), 10.0)
        speakMeaningVi = defaults.object(forKey: Keys.speakMeaningVi) as? Bool ?? true
        speakExample = defaults.object(forKey: Keys.speakExample) as? Bool ?? true
        hideMeaningDuringPause = defaults.object(forKey: Keys.hideMeaningDuringPause) as? Bool ?? false

        observeAudioSessionEvents()
    }

    // MARK: - Public Controls

    func start(cards: [Card], title: String, shuffle: Bool = true) {
        guard !cards.isEmpty else { return }
        stop(clearQueue: false)

        deckTitle = title
        queue = shuffle ? cards.shuffled() : cards
        currentIndex = 0
        playedCardsCount = 0
        sessionStartedAt = Date()
        resetSleepTimerBounds()

        configureRemoteCommandsIfNeeded()
        AudioPlayer.shared.keepSessionActiveInBackground = true
        isPaused = false
        isPlaying = true
        startLoopFromCurrentIndex()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if isPaused || !queue.isEmpty {
            resume()
        }
    }

    func pause() {
        guard isPlaying else { return }
        loopTask?.cancel()
        loopTask = nil
        isPlaying = false
        isPaused = true
        AudioPlayer.shared.stop()
        updateNowPlayingInfo()
    }

    func resume() {
        guard !queue.isEmpty else { return }
        configureRemoteCommandsIfNeeded()
        AudioPlayer.shared.keepSessionActiveInBackground = true
        isPaused = false
        isPlaying = true
        startLoopFromCurrentIndex()
    }

    func nextCard() {
        guard !queue.isEmpty else { return }
        Haptics.selection()
        loopTask?.cancel()
        loopTask = nil
        AudioPlayer.shared.stop()
        advanceIndexOrReshuffle()
        if isPlaying || isPaused {
            isPaused = false
            isPlaying = true
            startLoopFromCurrentIndex()
        }
    }

    func previousCard() {
        guard !queue.isEmpty else { return }
        Haptics.selection()
        loopTask?.cancel()
        loopTask = nil
        AudioPlayer.shared.stop()
        if currentIndex > 0 {
            currentIndex -= 1
        } else {
            currentIndex = max(0, queue.count - 1)
        }
        if isPlaying || isPaused {
            isPaused = false
            isPlaying = true
            startLoopFromCurrentIndex()
        }
    }

    func shuffleQueue() {
        guard queue.count > 1 else { return }
        Haptics.impact(.light)
        let currentID = currentCard?.id
        var shuffled = queue.shuffled()
        if let currentID, shuffled.first?.id == currentID, shuffled.count > 1 {
            shuffled.swapAt(0, Int.random(in: 1..<shuffled.count))
        }
        queue = shuffled
        currentIndex = 0
        if isPlaying {
            loopTask?.cancel()
            loopTask = nil
            AudioPlayer.shared.stop()
            startLoopFromCurrentIndex()
        } else {
            updateNowPlayingInfo()
        }
    }

    func stop(clearQueue: Bool = true) {
        loopTask?.cancel()
        loopTask = nil
        prefetchTask?.cancel()
        prefetchTask = nil
        isPlaying = false
        isPaused = false
        step = .idle
        AudioPlayer.shared.keepSessionActiveInBackground = false
        AudioPlayer.shared.stop()
        if clearQueue {
            queue = []
            currentIndex = 0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        } else {
            updateNowPlayingInfo()
        }
    }

    // MARK: - Sequential Playback Engine

    private func startLoopFromCurrentIndex() {
        loopTask?.cancel()
        loopTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.isPlaying && !self.queue.isEmpty {
                if self.shouldStopForSleepTimer() {
                    self.pause()
                    break
                }

                guard let card = self.currentCard else { break }
                self.prefetchUpcomingCards()

                // 1. Speak Headword (1..wordRepeatCount times)
                let repeats = max(1, min(3, self.wordRepeatCount))
                var aborted = false
                for attempt in 1...repeats {
                    guard !Task.isCancelled && self.isPlaying else { aborted = true; break }
                    self.step = .word(attempt: attempt, total: repeats)
                    self.updateNowPlayingInfo()

                    let ok = (try? await self.tts.speakAndWait(card.word, language: card.cardLanguage)) ?? false
                    guard !Task.isCancelled && self.isPlaying && ok else { aborted = true; break }

                    if attempt < repeats {
                        let gap = await AudioPlayer.shared.playSilenceAndWait(duration: 0.75)
                        if gap != .completed || Task.isCancelled || !self.isPlaying {
                            aborted = true
                            break
                        }
                    }
                }
                if aborted || Task.isCancelled || !self.isPlaying { break }

                // 2. Thinking Pause (Active Recall)
                self.step = .thinkingPause
                self.updateNowPlayingInfo()
                let pauseOutcome = await AudioPlayer.shared.playSilenceAndWait(duration: self.thinkingDelaySeconds)
                guard pauseOutcome == .completed, !Task.isCancelled, self.isPlaying else { break }

                // 3. Speak Vietnamese Meaning (if enabled)
                if self.speakMeaningVi,
                   let meaning = Self.cleanMeaning(for: card),
                   !meaning.isEmpty {
                    self.step = .meaningVi
                    self.updateNowPlayingInfo()

                    let langCode = (card.meaningVi?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                        ? "vi-VN"
                        : "en-US"
                    let meaningResult = await AudioPlayer.shared.speakSystemAndWait(meaning, languageCode: langCode)
                    guard meaningResult == .completed, !Task.isCancelled, self.isPlaying else { break }
                }

                // 4. Speak Example Sentence (if enabled)
                if self.speakExample,
                   let exampleText = Self.firstSpokenExample(for: card),
                   !exampleText.isEmpty {
                    let preExampleGap = await AudioPlayer.shared.playSilenceAndWait(duration: 0.45)
                    guard preExampleGap == .completed, !Task.isCancelled, self.isPlaying else { break }

                    self.step = .example
                    self.updateNowPlayingInfo()

                    let exOk = (try? await self.tts.speakAndWait(exampleText, language: card.cardLanguage)) ?? false
                    guard exOk, !Task.isCancelled, self.isPlaying else { break }
                }

                // 5. Transition Pause before next card
                self.step = .transition
                self.updateNowPlayingInfo()
                self.playedCardsCount += 1

                if self.shouldStopForSleepTimer() {
                    self.pause()
                    break
                }

                let transitionGap = await AudioPlayer.shared.playSilenceAndWait(duration: 1.15)
                guard transitionGap == .completed, !Task.isCancelled, self.isPlaying else { break }

                self.advanceIndexOrReshuffle()
            }
        }
    }

    private func advanceIndexOrReshuffle() {
        guard !queue.isEmpty else { return }
        if currentIndex + 1 < queue.count {
            currentIndex += 1
        } else if queue.count > 1 {
            let lastID = queue[currentIndex].id
            var reshuffled = queue.shuffled()
            if reshuffled.first?.id == lastID {
                reshuffled.swapAt(0, Int.random(in: 1..<reshuffled.count))
            }
            queue = reshuffled
            currentIndex = 0
        } else {
            currentIndex = 0
        }
    }

    private func prefetchUpcomingCards() {
        prefetchTask?.cancel()
        guard !VoiceSettingsStore.shared.useDeviceSpeech, queue.count > 1 else { return }

        var upcoming: [Card] = []
        for offset in 1...2 {
            let idx = (currentIndex + offset) % queue.count
            if queue.indices.contains(idx) {
                upcoming.append(queue[idx])
            }
        }
        let includeEx = speakExample
        let service = tts

        prefetchTask = Task.detached(priority: .utility) {
            for card in upcoming {
                if Task.isCancelled { return }
                let resolvedWord = await service.resolveInput(card.word, language: card.cardLanguage)
                if !resolvedWord.text.isEmpty {
                    _ = try? await service.ensureCached(cleanText: resolvedWord.text, voiceModel: resolvedWord.voice)
                }
                if includeEx, let ex = await Self.firstSpokenExample(for: card), !ex.isEmpty {
                    let resolvedEx = await service.resolveInput(ex, language: card.cardLanguage)
                    if !resolvedEx.text.isEmpty {
                        _ = try? await service.ensureCached(cleanText: resolvedEx.text, voiceModel: resolvedEx.voice)
                    }
                }
            }
        }
    }

    // MARK: - Sleep Timer

    private func resetSleepTimerBounds() {
        switch sleepTimer {
        case .off:
            sleepTimerDeadline = nil
            sleepTimerMaxCards = nil
        case .cards10:
            sleepTimerDeadline = nil
            sleepTimerMaxCards = playedCardsCount + 10
        case .cards20:
            sleepTimerDeadline = nil
            sleepTimerMaxCards = playedCardsCount + 20
        case .cards50:
            sleepTimerDeadline = nil
            sleepTimerMaxCards = playedCardsCount + 50
        case .minutes15:
            sleepTimerMaxCards = nil
            sleepTimerDeadline = Date().addingTimeInterval(15 * 60)
        case .minutes30:
            sleepTimerMaxCards = nil
            sleepTimerDeadline = Date().addingTimeInterval(30 * 60)
        case .minutes45:
            sleepTimerMaxCards = nil
            sleepTimerDeadline = Date().addingTimeInterval(45 * 60)
        }
    }

    private func shouldStopForSleepTimer() -> Bool {
        if let maxCards = sleepTimerMaxCards, playedCardsCount >= maxCards {
            sleepTimer = .off
            return true
        }
        if let deadline = sleepTimerDeadline, Date() >= deadline {
            sleepTimer = .off
            return true
        }
        return false
    }

    // MARK: - Lock Screen / Control Center / AirPods Integration

    private func configureRemoteCommandsIfNeeded() {
        guard !remoteCommandsConfigured else { return }
        remoteCommandsConfigured = true

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.resume() }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.pause() }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.togglePlayPause() }
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.nextCard() }
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.previousCard() }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let card = currentCard else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        let title: String
        if let phonetic = card.phonetic, !phonetic.isEmpty {
            title = "\(card.word) · \(phonetic)"
        } else {
            title = card.word
        }

        let meaningText = Self.cleanMeaning(for: card) ?? ""
        let subtitle: String
        if shouldShowMeaningNow && !meaningText.isEmpty {
            subtitle = meaningText
        } else {
            subtitle = "🎧 \(step.title)"
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: subtitle,
            MPMediaItemPropertyAlbumTitle: "\(deckTitle) (\(currentIndex + 1)/\(queue.count))",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(currentIndex),
            MPMediaItemPropertyPlaybackDuration: Double(max(queue.count, 1)),
        ]

        if let artwork = Self.renderArtwork(for: card, showMeaning: shouldShowMeaningNow, stepTitle: step.title) {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private static func renderArtwork(for card: Card, showMeaning: Bool, stepTitle: String) -> MPMediaItemArtwork? {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)

            // Dark editorial emerald background
            UIColor(red: 0.06, green: 0.11, blue: 0.10, alpha: 1.0).setFill()
            ctx.fill(rect)

            let cardRect = rect.insetBy(dx: 28, dy: 28)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 36)
            UIColor(red: 0.10, green: 0.16, blue: 0.15, alpha: 1.0).setFill()
            cardPath.fill()

            UIColor(red: 0.086, green: 0.639, blue: 0.463, alpha: 0.45).setStroke()
            cardPath.lineWidth = 3
            cardPath.stroke()

            let green = UIColor(red: 0.12, green: 0.78, blue: 0.56, alpha: 1.0)
            let secondary = UIColor(white: 0.72, alpha: 1.0)

            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: green,
            ]
            NSString(string: "VOCA RADIO · \(stepTitle.uppercased())").draw(
                in: CGRect(x: 56, y: 56, width: 400, height: 32),
                withAttributes: headerAttrs
            )

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let wordFontSize: CGFloat = card.isChinese ? 92 : 60
            let wordAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: wordFontSize, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
            ]
            NSString(string: card.word).draw(
                in: CGRect(x: 48, y: 150, width: 416, height: 120),
                withAttributes: wordAttrs
            )

            if let phonetic = card.phonetic, !phonetic.isEmpty {
                let phoneticAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 28, weight: .semibold),
                    .foregroundColor: green,
                    .paragraphStyle: paragraph,
                ]
                NSString(string: phonetic).draw(
                    in: CGRect(x: 48, y: 278, width: 416, height: 42),
                    withAttributes: phoneticAttrs
                )
            }

            let footerText = showMeaning
                ? (cleanMeaning(for: card) ?? "")
                : "🤔 Tự nhẩm nghĩa trong đầu…"
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .semibold),
                .foregroundColor: showMeaning ? UIColor.white : secondary,
                .paragraphStyle: paragraph,
            ]
            NSString(string: footerText).draw(
                in: CGRect(x: 54, y: 352, width: 404, height: 100),
                withAttributes: footerAttrs
            )
        }

        return MPMediaItemArtwork(boundsSize: size) { _ in image }
    }

    private func observeAudioSessionEvents() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

            Task { @MainActor [weak self] in
                guard let self else { return }
                switch type {
                case .began:
                    if self.isPlaying {
                        self.wasPlayingBeforeInterruption = true
                        self.pause()
                    }
                case .ended:
                    if self.wasPlayingBeforeInterruption && options.contains(.shouldResume) {
                        self.wasPlayingBeforeInterruption = false
                        self.resume()
                    }
                @unknown default:
                    break
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
                  reason == .oldDeviceUnavailable
            else { return }
            Task { @MainActor [weak self] in
                self?.pause()
            }
        }
    }

    // MARK: - Card Text Helpers

    static func cleanMeaning(for card: Card) -> String? {
        for candidate in [card.meaningVi, card.meaningEn, card.answer] {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    static func firstSpokenExample(for card: Card) -> String? {
        guard let raw = card.examples?.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return nil
        }
        if card.isChinese {
            let parsed = ChineseExample(raw).hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
            return parsed.isEmpty ? nil : parsed
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func firstExampleDisplay(for card: Card) -> (primary: String, secondary: String?)? {
        guard let raw = card.examples?.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return nil
        }
        if card.isChinese {
            let parsed = ChineseExample(raw)
            let sub = [parsed.pinyin, parsed.meaningVi].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            return (parsed.hanzi, sub.isEmpty ? nil : sub)
        }
        return (raw, nil)
    }
}
