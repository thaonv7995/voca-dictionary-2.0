import Foundation
import AVFoundation

/// Plays MP3 data returned by the TTS endpoints with `AVSpeechSynthesizer` fallback.
/// One shared player; a new clip replaces the previous.
@MainActor
final class AudioPlayer: NSObject {
    static let shared = AudioPlayer()

    private var player: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private var finishContinuation: CheckedContinuation<Bool, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Fire-and-forget playback (single word / one line). Returns false if audio bytes are invalid.
    @discardableResult
    func play(_ data: Data) -> Bool {
        prepareSession()
        stop()
        guard !data.isEmpty, let p = try? AVAudioPlayer(data: data) else { return false }
        player = p
        p.prepareToPlay()
        return p.play()
    }

    /// Plays and suspends until playback finishes (or fails) — used for sequential "play all".
    @discardableResult
    func playAndWait(_ data: Data) async -> Bool {
        prepareSession()
        stop()
        guard !data.isEmpty else { return false }
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            do {
                let p = try AVAudioPlayer(data: data)
                p.delegate = self
                player = p
                finishContinuation = cont
                p.prepareToPlay()
                if !p.play() {
                    resumeFinish(success: false)
                }
            } catch {
                cont.resume(returning: false)
            }
        }
    }

    /// Fallback fire-and-forget system speech (`zh-CN` / `en-US`) when `/api/tts` is unavailable.
    func speakSystem(_ text: String, languageCode: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        prepareSession()
        stop()
        let utterance = makeUtterance(trimmed, languageCode: languageCode)
        synthesizer.speak(utterance)
    }

    /// Fallback system speech suspending until playback finishes.
    func speakSystemAndWait(_ text: String, languageCode: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        prepareSession()
        stop()
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            finishContinuation = cont
            let utterance = makeUtterance(trimmed, languageCode: languageCode)
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        player?.stop()
        player = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        resumeFinish(success: true)
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
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
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

    private func resumeFinish(success: Bool) {
        finishContinuation?.resume(returning: success)
        finishContinuation = nil
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.resumeFinish(success: flag) }
    }
}

extension AudioPlayer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.resumeFinish(success: true) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.resumeFinish(success: false) }
    }
}
