import Foundation

/// `POST /api/practice/conversation` → one `daily_conversation` JSON object.
struct Conversation: Decodable {
    let type: String?
    let format: String?
    let title: String?
    let context: String?
    let speakers: [String]?
    let voiceAssignments: [String: String]?
    let lines: [ConversationLine]
}

struct ConversationLine: Decodable, Identifiable {
    let id = UUID()
    let speaker: String?
    let text: String?
    let translation: String?
    let vocabulary: [String]?
    let vocabularyMeanings: [String: String]?

    enum CodingKeys: String, CodingKey {
        case speaker, text, translation, vocabulary, vocabularyMeanings
    }
}

extension PracticeParsing {
    /// Conversation is one JSON object (fence/prose tolerant).
    static func conversation(from raw: String) -> Conversation? {
        guard let json = extractJSONObject(from: raw), let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Conversation.self, from: data)
    }
}

/// Listening formats offered in the UI (mirrors the web app).
enum ConversationFormat: String, CaseIterable, Identifiable {
    case auto, conversation, radio, announcement, story

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Tự động"
        case .conversation: return "Hội thoại"
        case .radio: return "Radio"
        case .announcement: return "Thông báo"
        case .story: return "Truyện"
        }
    }
}
