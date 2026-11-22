import AVFoundation
import Foundation
import Observation

/// Native macOS pronunciation service.
///
/// This intentionally uses `AVSpeechSynthesizer` instead of the shared
/// iOS audio player because `AVAudioSession` is unavailable on macOS.
@MainActor
@Observable
final class MacSpeechService: NSObject {
    private(set) var isSpeaking = false
    private(set) var speakingText: String?

    private let synthesizer = AVSpeechSynthesizer()
    private var cachedVoices: [MacVocabularyItem.Language: AVSpeechSynthesisVoice] = [:]
    private var activeUtterance: AVSpeechUtterance?

    override init() {
        super.init()
        synthesizer.delegate = self
        for language in MacVocabularyItem.Language.allCases {
            if let best = Self.resolveBestVoice(for: language) {
                cachedVoices[language] = best
            }
        }
    }

    func preferredVoiceSummary(
        for language: MacVocabularyItem.Language
    ) -> String {
        guard let voice = cachedVoices[language] ?? Self.resolveBestVoice(for: language) else {
            return language.voiceLanguageCode
        }
        let qualityLabel: String
        switch voice.quality {
        case .premium:
            qualityLabel = "Premium"
        case .enhanced:
            qualityLabel = "Enhanced"
        default:
            qualityLabel = "Standard"
        }
        return "\(voice.name) (\(qualityLabel))"
    }

    func speak(
        _ text: String,
        language: MacVocabularyItem.Language
    ) {
        let normalizedText = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !normalizedText.isEmpty else {
            return
        }

        stop()

        let utterance = AVSpeechUtterance(
            string: normalizedText
        )
        utterance.voice = cachedVoices[language]
            ?? Self.resolveBestVoice(for: language)
            ?? AVSpeechSynthesisVoice(language: language.voiceLanguageCode)
        utterance.rate = language == .chinese
            ? 0.43
            : 0.48
        utterance.pitchMultiplier = 1

        activeUtterance = utterance
        speakingText = normalizedText
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    private static func resolveBestVoice(
        for language: MacVocabularyItem.Language
    ) -> AVSpeechSynthesisVoice? {
        let prefix = language == .chinese ? "zh" : "en"
        let preferredCode = language.voiceLanguageCode.lowercased()

        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.lowercased().hasPrefix(prefix)
        }

        guard !candidates.isEmpty else {
            return AVSpeechSynthesisVoice(language: language.voiceLanguageCode)
        }

        return candidates.max { left, right in
            let leftRank = qualityRank(left.quality)
            let rightRank = qualityRank(right.quality)
            if leftRank != rightRank {
                return leftRank < rightRank
            }
            let leftExact = left.language.lowercased() == preferredCode
            let rightExact = right.language.lowercased() == preferredCode
            if leftExact != rightExact {
                return !leftExact && rightExact
            }
            return false
        }
    }

    private static func qualityRank(
        _ quality: AVSpeechSynthesisVoiceQuality
    ) -> Int {
        switch quality {
        case .premium:
            return 3
        case .enhanced:
            return 2
        default:
            return 1
        }
    }

    func stop() {
        guard synthesizer.isSpeaking
                || synthesizer.isPaused
        else {
            resetState()
            return
        }

        synthesizer.stopSpeaking(at: .immediate)
        resetState()
    }

    func toggle(
        _ text: String,
        language: MacVocabularyItem.Language
    ) {
        let normalizedText = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if isSpeaking,
           speakingText == normalizedText {
            stop()
        } else {
            speak(
                normalizedText,
                language: language
            )
        }
    }

    private func resetState() {
        activeUtterance = nil
        speakingText = nil
        isSpeaking = false
    }
}

extension MacSpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            guard utterance === self.activeUtterance else { return }
            resetState()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            guard utterance === self.activeUtterance else { return }
            resetState()
        }
    }
}

private extension MacVocabularyItem.Language {
    var voiceLanguageCode: String {
        switch self {
        case .english:
            "en-US"
        case .chinese:
            "zh-CN"
        }
    }
}
