import Foundation

/// Text-to-speech with persistent disk caching (`AudioCacheStore`) over `POST /api/tts`,
/// plus on-device `AVSpeechSynthesizer` mode/fallback.
struct TTSService: Sendable {
    private struct TTSBody: Encodable, Sendable { let text: String; let voiceModel: String? }

    /// Synthesises `text` and plays it. Uses on-device speech when enabled in Settings,
    /// otherwise hits `AudioCacheStore` first and only calls `POST /api/tts` on cache miss.
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

    /// Resolves canonical spoken text + effective voice model matching `speak(...)` cache keys.
    func resolveInput(_ text: String,
                      language: CardLanguage?,
                      voiceModel: String? = nil) async -> (text: String, voice: String, speechLanguage: String) {
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

    /// Ensures audio for `(cleanText, effectiveVoice)` is cached on disk without playing it.
    /// Used by `AudioPrefetchManager` to batch-download vocabulary audio over multiple concurrent workers.
    func ensureCached(cleanText: String, voiceModel: String) async throws -> (fromCache: Bool, byteCount: Int) {
        let result = try await AudioCacheStore.shared.getOrFetchAudio(
            text: cleanText,
            voiceModel: voiceModel
        ) {
            try await ApiClient.shared.rawData(
                method: "POST",
                path: "/api/tts",
                body: TTSBody(text: cleanText, voiceModel: voiceModel)
            )
        }
        return (result.fromCache, result.data.count)
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
            let (data, _) = try await AudioCacheStore.shared.getOrFetchAudio(
                text: cleanText,
                voiceModel: effectiveVoice
            ) {
                try await ApiClient.shared.rawData(
                    method: "POST",
                    path: "/api/tts",
                    body: TTSBody(text: cleanText, voiceModel: effectiveVoice)
                )
            }
            let played: Bool
            if waitForCompletion {
                played = await AudioPlayer.shared.playAndWait(data)
            } else {
                played = await AudioPlayer.shared.play(data)
            }
            if !played {
                throw ApiError(status: 0, code: "AUDIO_PLAYBACK_FAILED", message: "Không phát được tệp âm thanh.")
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
}
