import Foundation

/// Text-to-speech via `POST /api/tts` (server holds the TTS key). Returns `audio/mpeg` bytes.
struct TTSService {
    private let api = ApiClient.shared

    private struct TTSBody: Encodable { let text: String; let voiceModel: String? }

    /// Synthesises `text` and plays it. Throws `ApiError` (e.g. 503 if TTS isn't configured server-side).
    func speak(_ text: String, voiceModel: String? = nil) async throws {
        let data = try await api.rawData(method: "POST", path: "/api/tts",
                                         body: TTSBody(text: text, voiceModel: voiceModel))
        await AudioPlayer.shared.play(data)
    }
}
