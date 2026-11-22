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
    /// Returns `true` if playback completed normally, `false` if interrupted/stopped.
    @discardableResult
    func speakAndWait(_ text: String,
                      language: CardLanguage? = nil,
                      voiceModel: String? = nil,
                      fallbackToSystem: Bool = true,
                      forceSystem: Bool? = nil) async throws -> Bool {
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

    @discardableResult
    private func performSpeech(_ text: String,
                               language: CardLanguage?,
                               voiceModel: String?,
                               fallbackToSystem: Bool,
                               forceSystem: Bool?,
                               waitForCompletion: Bool) async throws -> Bool {
        try Task.checkCancellation()
        let useDevice = await resolveUseDevice(forceSystem: forceSystem)
        if !useDevice {
            await VoiceSettingsStore.shared.refreshIfNeeded()
        }
        try Task.checkCancellation()

        let (cleanText, effectiveVoice, speechLang) = await resolveInput(
            text,
            language: language,
            voiceModel: voiceModel
        )
        guard !cleanText.isEmpty else { return true }
        try Task.checkCancellation()

        if useDevice {
            if waitForCompletion {
                let result = await AudioPlayer.shared.speakSystemAndWait(cleanText, languageCode: speechLang)
                return result == .completed
            } else {
                await AudioPlayer.shared.speakSystem(cleanText, languageCode: speechLang)
                return true
            }
        }

        do {
            let (data, fromCache) = try await AudioCacheStore.shared.getOrFetchAudio(
                text: cleanText,
                voiceModel: effectiveVoice
            ) {
                try await ApiClient.shared.rawData(
                    method: "POST",
                    path: "/api/tts",
                    body: TTSBody(text: cleanText, voiceModel: effectiveVoice)
                )
            }
            try Task.checkCancellation()

            if waitForCompletion {
                let result = await AudioPlayer.shared.playAndWait(data)
                switch result {
                case .completed:
                    return true
                case .interrupted:
                    return false
                case .failed:
                    if fromCache {
                        await AudioCacheStore.shared.remove(text: cleanText, voiceModel: effectiveVoice)
                    }
                    throw ApiError(status: 0, code: "AUDIO_PLAYBACK_FAILED", message: "Không phát được tệp âm thanh.")
                }
            } else {
                let played = await AudioPlayer.shared.play(data)
                if !played {
                    if fromCache {
                        await AudioCacheStore.shared.remove(text: cleanText, voiceModel: effectiveVoice)
                    }
                    throw ApiError(status: 0, code: "AUDIO_PLAYBACK_FAILED", message: "Không phát được tệp âm thanh.")
                }
                return true
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            if fallbackToSystem {
                if waitForCompletion {
                    let result = await AudioPlayer.shared.speakSystemAndWait(cleanText, languageCode: speechLang)
                    return result == .completed
                } else {
                    await AudioPlayer.shared.speakSystem(cleanText, languageCode: speechLang)
                    return true
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
