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

    override init() {
        super.init()
        synthesizer.delegate = self
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
        utterance.voice = AVSpeechSynthesisVoice(
            language: language.voiceLanguageCode
        )
        utterance.rate = language == .chinese
            ? 0.42
            : 0.48
        utterance.pitchMultiplier = 1

        speakingText = normalizedText
        isSpeaking = true
        synthesizer.speak(utterance)
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
            resetState()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
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
