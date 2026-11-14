import Foundation

/// Curated Edge TTS voice presets shown in Settings and passed to Conversation prompts.
enum VoicePreset {
    static let chinese: [(id: String, label: String)] = [
        ("edge-tts/zh-CN-XiaoxiaoNeural", "Xiaoxiao (Chinese Mainland · F)"),
        ("edge-tts/zh-CN-YunxiNeural", "Yunxi (Chinese Mainland · M)"),
        ("edge-tts/zh-CN-XiaoyiNeural", "Xiaoyi (Chinese Mainland · F)"),
        ("edge-tts/zh-CN-YunjianNeural", "Yunjian (Chinese Mainland · M)"),
        ("edge-tts/zh-CN-YunxiaNeural", "Yunxia (Chinese Mainland · M)"),
        ("edge-tts/zh-CN-YunyangNeural", "Yunyang (Chinese Mainland · M)"),
        ("edge-tts/zh-CN-liaoning-XiaobeiNeural", "Xiaobei (Chinese NE · F)"),
        ("edge-tts/zh-TW-HsiaoChenNeural", "HsiaoChen (Chinese TW · F)"),
        ("edge-tts/zh-TW-YunJheNeural", "YunJhe (Chinese TW · M)"),
        ("edge-tts/zh-TW-HsiaoYuNeural", "HsiaoYu (Chinese TW · F)"),
        ("edge-tts/zh-HK-HiuGaaiNeural", "HiuGaai (Cantonese · F)"),
        ("edge-tts/zh-HK-HiuMaanNeural", "HiuMaan (HK · F)"),
        ("edge-tts/zh-HK-WanLungNeural", "WanLung (HK · M)"),
        ("edge-tts/zh-CN-shaanxi-XiaoniNeural", "Xiaoni (Shaanxi · F)"),
    ]

    static let english: [(id: String, label: String)] = [
        ("edge-tts/en-US-SteffanNeural", "Steffan (US · M)"),
        ("edge-tts/en-US-AvaNeural", "Ava (US · F)"),
        ("edge-tts/en-US-AndrewNeural", "Andrew (US · M)"),
        ("edge-tts/en-US-EmmaNeural", "Emma (US · F)"),
        ("edge-tts/en-US-BrianNeural", "Brian (US · M)"),
    ]
}

/// Voice preferences stored inside `user_settings.voices` on the server (shared schema with the web app).
struct UserVoices: Codable, Equatable {
    var a: String?
    var b: String?
    var c: String?
    var chineseModel: String?
    var chineseA: String?
    var chineseB: String?
    var chineseC: String?
    var autoSelect: Bool?

    static let defaultEnglishModel = "edge-tts/en-US-AndrewNeural"
    static let defaultChineseModel = "edge-tts/zh-CN-XiaoxiaoNeural"
    static let defaultEnglishSpeakers = [
        "edge-tts/en-US-SteffanNeural",
        "edge-tts/en-US-AvaNeural",
        "edge-tts/en-US-AndrewNeural",
    ]
    static let defaultChineseSpeakers = [
        "edge-tts/zh-CN-XiaoxiaoNeural",
        "edge-tts/zh-CN-YunxiNeural",
        "edge-tts/zh-CN-XiaoyiNeural",
    ]
}

/// `GET /api/user/settings` (safe DTO — secrets are never returned, only `hasLlmKey`/`hasTtsKey`).
struct UserSettings: Decodable {
    let llmBaseUrl: String?
    let llmModel: String?
    let hasLlmKey: Bool
    let ttsBaseUrl: String?
    let ttsModel: String?
    let hasTtsKey: Bool
    let voices: UserVoices?
}

/// `PUT /api/user/settings` body. Nil fields are omitted (server treats blank as "leave unchanged").
struct UpdateSettingsBody: Encodable {
    var llmBaseUrl: String?
    var llmApiKey: String?
    var llmModel: String?
    var ttsBaseUrl: String?
    var ttsApiKey: String?
    var ttsModel: String?
    var voices: UserVoices?
}

/// Local cache + runtime resolver for English/Chinese voice models synced with `/api/user/settings`.
@MainActor
final class VoiceSettingsStore {
    static let shared = VoiceSettingsStore()

    private struct Snapshot: Codable {
        var ttsModel: String?
        var voices: UserVoices?
    }

    static let useDeviceSpeechDefaultsKey = "voca.audio.useDeviceSpeech"

    private let defaultsKey = "voca.voice.settings.v1"
    private(set) var ttsModel: String?
    private(set) var voices: UserVoices = UserVoices()
    private var refreshTask: Task<Void, Never>?
    private var hasRefreshed = false

    /// When true, `TTSService` speaks via on-device `AVSpeechSynthesizer` without calling the backend.
    var useDeviceSpeech: Bool {
        UserDefaults.standard.bool(forKey: Self.useDeviceSpeechDefaultsKey)
    }

    func setUseDeviceSpeech(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.useDeviceSpeechDefaultsKey)
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            ttsModel = snapshot.ttsModel
            voices = snapshot.voices ?? UserVoices()
        }
    }

    func apply(_ settings: UserSettings) {
        ttsModel = Self.clean(settings.ttsModel)
        if let incoming = settings.voices {
            voices = incoming
        }
        hasRefreshed = true
        persist()
    }

    func refreshIfNeeded() async {
        guard !hasRefreshed else { return }
        if let existing = refreshTask {
            await existing.value
            return
        }
        let task = Task {
            if let settings = try? await SettingsService().get() {
                apply(settings)
            } else {
                hasRefreshed = true
            }
            refreshTask = nil
        }
        refreshTask = task
        await task.value
    }

    static func isEnglishVoice(_ id: String) -> Bool {
        let lower = id.lowercased()
        return lower.contains("/en-") || lower.hasPrefix("en-")
    }

    static func isChineseVoice(_ id: String) -> Bool {
        let lower = id.lowercased()
        return lower.contains("/zh-") || lower.hasPrefix("zh-") || lower.contains("chinese")
    }

    func resolvedVoice(forText text: String, language: CardLanguage? = nil, explicitVoice: String? = nil) -> String {
        let isChinese = text.hasChineseCharacters || language == .chinese
        let cleanedExplicit = Self.clean(explicitVoice)

        if isChinese {
            if let explicit = cleanedExplicit, !Self.isEnglishVoice(explicit) {
                return explicit
            }
            if let chineseModel = Self.clean(voices.chineseModel), !Self.isEnglishVoice(chineseModel) {
                return chineseModel
            }
            if let ttsModel, Self.isChineseVoice(ttsModel) {
                return ttsModel
            }
            return UserVoices.defaultChineseModel
        }

        if let explicit = cleanedExplicit, !Self.isChineseVoice(explicit) {
            return explicit
        }
        if let ttsModel, !Self.isChineseVoice(ttsModel) {
            return ttsModel
        }
        return UserVoices.defaultEnglishModel
    }

    func speakerVoices(for language: CardLanguage) -> [String] {
        switch language {
        case .chinese:
            let configured = [voices.chineseA, voices.chineseB, voices.chineseC]
            return zip(configured, UserVoices.defaultChineseSpeakers).map { custom, fallback in
                if let val = Self.clean(custom), !Self.isEnglishVoice(val) { return val }
                return fallback
            }
        case .english:
            let configured = [voices.a, voices.b, voices.c]
            return zip(configured, UserVoices.defaultEnglishSpeakers).map { custom, fallback in
                if let val = Self.clean(custom), !Self.isChineseVoice(val) { return val }
                return fallback
            }
        }
    }

    var autoSelectConversationVoices: Bool {
        voices.autoSelect ?? true
    }

    func availableVoiceOptions(for language: CardLanguage) -> [(id: String, label: String)] {
        let base = language == .chinese ? VoicePreset.chinese : VoicePreset.english
        var result = base
        var seen = Set(base.map(\.id))
        let extras: [String?] = language == .chinese
            ? [voices.chineseModel, voices.chineseA, voices.chineseB, voices.chineseC]
            : [ttsModel, voices.a, voices.b, voices.c]
        for case let id? in extras.map(Self.clean) where !seen.contains(id) {
            seen.insert(id)
            result.append((id: id, label: id))
        }
        return result
    }

    private func persist() {
        let snapshot = Snapshot(ttsModel: ttsModel, voices: voices)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private static func clean(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

// MARK: - Self-service API keys

/// `GET /api/user/api-keys` → `{ keys, scopes }`.
struct ApiKeysResponse: Decodable {
    let keys: [ApiKeyInfo]
    let scopes: [OfferedScope]
}

struct ApiKeyInfo: Decodable, Identifiable {
    let id: Int
    let name: String
    let prefix: String?
    let scopes: [String]?
    let status: String?
    let lastUsedAt: String?
    let createdAt: String?
}

struct OfferedScope: Decodable, Identifiable {
    let value: String
    let label: String
    let endpoints: String
    var id: String { value }
}

/// `POST /api/user/api-keys` response — includes the plaintext `key`, shown exactly once.
struct CreatedKey: Decodable {
    let id: Int
    let name: String
    let key: String
    let prefix: String?
    let scopes: [String]?
}

struct CreateKeyBody: Encodable {
    let name: String
    let scopes: [String]?
}
