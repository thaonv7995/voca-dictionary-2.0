import Foundation

/// Text-to-speech via `POST /api/tts` (server holds the TTS key). Returns `audio/mpeg` bytes.
struct TTSService {
    private let api = ApiClient.shared

    private struct TTSBody: Encodable { let text: String; let voiceModel: String? }

    /// Synthesises `text` and plays it. Throws `ApiError` (e.g. 503 if TTS isn't configured server-side).
    func speak(_ text: String, voiceModel: String? = nil) async throws {
        let (cleanText, effectiveVoice) = resolveInput(text, voiceModel: voiceModel)
        let data = try await api.rawData(method: "POST", path: "/api/tts",
                                         body: TTSBody(text: cleanText, voiceModel: effectiveVoice))
        await AudioPlayer.shared.play(data)
    }

    /// Synthesises `text` and suspends until playback finishes — for sequential "play all".
    func speakAndWait(_ text: String, voiceModel: String? = nil) async throws {
        let (cleanText, effectiveVoice) = resolveInput(text, voiceModel: voiceModel)
        let data = try await api.rawData(method: "POST", path: "/api/tts",
                                         body: TTSBody(text: cleanText, voiceModel: effectiveVoice))
        await AudioPlayer.shared.playAndWait(data)
    }

    private func resolveInput(_ text: String, voiceModel: String?) -> (String, String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasChineseCharacters {
            let spoken = trimmed.spokenChineseText
            let clean = spoken.isEmpty ? trimmed : spoken
            // Prevent English voice models from being used for Chinese text
            let voice: String
            if let vm = voiceModel, vm.contains("/zh-") {
                voice = vm
            } else {
                voice = "edge-tts/zh-CN-XiaoxiaoNeural"
            }
            return (clean, voice)
        }
        return (trimmed, voiceModel)
    }
}
