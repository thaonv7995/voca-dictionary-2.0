import Foundation

/// Text-to-speech via `POST /api/tts` (server holds the TTS key) with system speech fallback.
struct TTSService {
    private let api = ApiClient.shared

    private struct TTSBody: Encodable { let text: String; let voiceModel: String? }

    /// Synthesises `text` and plays it. Uses on-device speech immediately when enabled in Settings,
    /// otherwise calls `POST /api/tts` with optional `AVSpeechSynthesizer` fallback.
    func speak(_ text: String,
               language: CardLanguage? = nil,
               voiceModel: String? = nil,
               fallbackToSystem: Bool = true,
               forceSystem: Bool? = nil) async throws {
        try await performSpeech(
            text,
            language: language,
            voiceModel: voiceModel,
            fallbackToSystem: fallbackToSystem,
            forceSystem: forceSystem,
            waitForCompletion: false
        )
    }

    /// Synthesises `text` and suspends until playback finishes — for sequential "play all".
    func speakAndWait(_ text: String,
                      language: CardLanguage? = nil,
                      voiceModel: String? = nil,
                      fallbackToSystem: Bool = true,
                      forceSystem: Bool? = nil) async throws {
        try await performSpeech(
            text,
            language: language,
            voiceModel: voiceModel,
            fallbackToSystem: fallbackToSystem,
            forceSystem: forceSystem,
            waitForCompletion: true
        )
    }

    private func performSpeech(_ text: String,
                               language: CardLanguage?,
                               voiceModel: String?,
                               fallbackToSystem: Bool,
                               forceSystem: Bool?,
                               waitForCompletion: Bool) async throws {
        let useDevice = await resolveUseDevice(forceSystem: forceSystem)
        if !useDevice {
            await VoiceSettingsStore.shared.refreshIfNeeded()
        }

        let (cleanText, effectiveVoice, speechLang) = await resolveInput(
            text,
            language: language,
            voiceModel: voiceModel
        )
        guard !cleanText.isEmpty else { return }

        if useDevice {
            if waitForCompletion {
                await AudioPlayer.shared.speakSystemAndWait(cleanText, languageCode: speechLang)
            } else {
                await AudioPlayer.shared.speakSystem(cleanText, languageCode: speechLang)
            }
            return
        }

        do {
            let data = try await api.rawData(method: "POST", path: "/api/tts",
                                             body: TTSBody(text: cleanText, voiceModel: effectiveVoice))
            let played: Bool
            if waitForCompletion {
                played = await AudioPlayer.shared.playAndWait(data)
            } else {
                played = await AudioPlayer.shared.play(data)
            }
            if !played {
                throw ApiError(status: 0, code: "AUDIO_PLAYBACK_FAILED", message: "Không phát được tệp âm thanh từ máy chủ.")
            }
        } catch {
            if fallbackToSystem {
                if waitForCompletion {
                    await AudioPlayer.shared.speakSystemAndWait(cleanText, languageCode: speechLang)
                } else {
                    await AudioPlayer.shared.speakSystem(cleanText, languageCode: speechLang)
                }
            } else {
                throw error
            }
        }
    }

    @MainActor
    private func resolveUseDevice(forceSystem: Bool?) -> Bool {
        forceSystem ?? VoiceSettingsStore.shared.useDeviceSpeech
    }

    private func resolveInput(_ text: String,
                              language: CardLanguage?,
                              voiceModel: String?) async -> (text: String, voice: String, speechLanguage: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isChinese = trimmed.hasChineseCharacters || language == .chinese
        let clean: String
        if isChinese {
            let spoken = trimmed.spokenChineseText
            clean = spoken.isEmpty ? trimmed : spoken
        } else {
            clean = trimmed
        }
        let resolvedVoice = await VoiceSettingsStore.shared.resolvedVoice(
            forText: clean,
            language: isChinese ? .chinese : .english,
            explicitVoice: voiceModel
        )
        return (clean, resolvedVoice, isChinese ? "zh-CN" : "en-US")
    }
}
