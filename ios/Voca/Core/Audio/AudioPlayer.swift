import Foundation
import AVFoundation

enum AudioPlaybackResult: Sendable {
    case completed
    case interrupted
    case failed
}

/// Plays MP3 data returned by the TTS endpoints with `AVSpeechSynthesizer` fallback.
/// One shared player; a new clip replaces the previous.
@MainActor
final class AudioPlayer: NSObject {
    static let shared = AudioPlayer()

    private var player: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private var activeUtterance: AVSpeechUtterance?
    private var finishContinuation: CheckedContinuation<AudioPlaybackResult, Never>?
    private var interruptionObserver: NSObjectProtocol?

    private static var cachedSpeechVoices: [AVSpeechSynthesisVoice]?

    override init() {
        super.init()
        synthesizer.delegate = self
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue),
                  type == .began
            else { return }
            Task { @MainActor [weak self] in
                self?.stop()
            }
        }
    }

    /// Fire-and-forget playback (single word / one line). Returns false if audio bytes are invalid.
    @discardableResult
    func play(_ data: Data) -> Bool {
        stop(deactivateSession: false)
        guard !data.isEmpty, let p = try? AVAudioPlayer(data: data) else {
            deactivateSessionIfIdle()
            return false
        }
        prepareSession()
        p.delegate = self
        player = p
        p.prepareToPlay()
        if !p.play() {
            player = nil
            deactivateSessionIfIdle()
            return false
        }
        return true
    }

    /// Plays and suspends until playback finishes, is interrupted, or fails — used for sequential "play all".
    @discardableResult
    func playAndWait(_ data: Data) async -> AudioPlaybackResult {
        guard !Task.isCancelled else { return .interrupted }
        stop(deactivateSession: false)
        guard !data.isEmpty else {
            deactivateSessionIfIdle()
            return .failed
        }

        return await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<AudioPlaybackResult, Never>) in
                if Task.isCancelled {
                    deactivateSessionIfIdle()
                    cont.resume(returning: .interrupted)
                    return
                }
                do {
                    let p = try AVAudioPlayer(data: data)
                    prepareSession()
                    p.delegate = self
                    player = p
                    finishContinuation = cont
                    p.prepareToPlay()
                    if !p.play() {
                        player = nil
                        resumeFinish(result: .failed)
                    }
                } catch {
                    deactivateSessionIfIdle()
                    cont.resume(returning: .failed)
                }
            }
        } onCancel: {
            Task { @MainActor in
                AudioPlayer.shared.stop()
            }
        }
    }

    /// Fallback fire-and-forget system speech (`zh-CN` / `en-US`) when `/api/tts` is unavailable.
    func speakSystem(_ text: String, languageCode: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        stop(deactivateSession: false)
        prepareSession()
        let utterance = makeUtterance(trimmed, languageCode: languageCode)
        activeUtterance = utterance
        synthesizer.speak(utterance)
    }

    /// Fallback system speech suspending until playback finishes or is interrupted.
    @discardableResult
    func speakSystemAndWait(_ text: String, languageCode: String) async -> AudioPlaybackResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .completed }
        guard !Task.isCancelled else { return .interrupted }
        stop(deactivateSession: false)

        return await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<AudioPlaybackResult, Never>) in
                if Task.isCancelled {
                    deactivateSessionIfIdle()
                    cont.resume(returning: .interrupted)
                    return
                }
                prepareSession()
                let utterance = makeUtterance(trimmed, languageCode: languageCode)
                activeUtterance = utterance
                finishContinuation = cont
                synthesizer.speak(utterance)
            }
        } onCancel: {
            Task { @MainActor in
                AudioPlayer.shared.stop()
            }
        }
    }

    func stop() {
        stop(deactivateSession: true)
    }

    private func stop(deactivateSession: Bool) {
        if let activePlayer = player {
            activePlayer.delegate = nil
            activePlayer.stop()
            player = nil
        }
        activeUtterance = nil
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        resumeFinish(result: .interrupted, deactivateSession: deactivateSession)
    }

    private func makeUtterance(_ text: String, languageCode: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestSystemVoice(forLanguageCode: languageCode)
        utterance.rate = languageCode.hasPrefix("zh") ? 0.45 : AVSpeechUtteranceDefaultSpeechRate
        return utterance
    }

    static func preferredDeviceVoiceSummary(for language: CardLanguage) -> String {
        let code = language == .chinese ? "zh-CN" : "en-US"
        guard let voice = bestSystemVoice(forLanguageCode: code) else { return code }
        let qualityLabel: String
        switch voice.quality {
        case .premium: qualityLabel = "Premium"
        case .enhanced: qualityLabel = "Enhanced"
        default: qualityLabel = "Standard"
        }
        return "\(voice.name) (\(qualityLabel))"
    }

    private static func bestSystemVoice(forLanguageCode languageCode: String) -> AVSpeechSynthesisVoice? {
        let preferredCode = languageCode.lowercased()
        let prefix = preferredCode.hasPrefix("zh") ? "zh" : "en"
        let allVoices = cachedSpeechVoices ?? {
            let loaded = AVSpeechSynthesisVoice.speechVoices()
            cachedSpeechVoices = loaded
            return loaded
        }()
        let candidates = allVoices.filter {
            $0.language.lowercased().hasPrefix(prefix)
        }
        guard !candidates.isEmpty else {
            return AVSpeechSynthesisVoice(language: languageCode)
        }
        return candidates.max { left, right in
            let leftRank = qualityRank(left.quality)
            let rightRank = qualityRank(right.quality)
            if leftRank != rightRank { return leftRank < rightRank }
            let leftExact = left.language.lowercased() == preferredCode
            let rightExact = right.language.lowercased() == preferredCode
            if leftExact != rightExact { return !leftExact && rightExact }
            return false
        }
    }

    private static func qualityRank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium: return 3
        case .enhanced: return 2
        default: return 1
        }
    }

    private func prepareSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func deactivateSessionIfIdle() {
        guard player == nil, activeUtterance == nil, !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func resumeFinish(result: AudioPlaybackResult, deactivateSession: Bool = true) {
        if let continuation = finishContinuation {
            finishContinuation = nil
            continuation.resume(returning: result)
        }
        if deactivateSession {
            deactivateSessionIfIdle()
        }
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.player === player else { return }
            self.player = nil
            self.resumeFinish(result: flag ? .completed : .failed)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            guard self.player === player else { return }
            self.player = nil
            self.resumeFinish(result: .failed)
        }
    }
}

extension AudioPlayer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.activeUtterance === utterance else { return }
            self.activeUtterance = nil
            self.resumeFinish(result: .completed)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.activeUtterance === utterance else { return }
            self.activeUtterance = nil
            self.resumeFinish(result: .interrupted)
        }
    }
}
