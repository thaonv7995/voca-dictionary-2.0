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
    let pinyin: String?
    let translation: String?
    let vocabulary: [String]?
    let vocabularyMeanings: [String: String]?

    enum CodingKeys: String, CodingKey {
        case speaker, text, pinyin, translation, vocabulary, vocabularyMeanings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        speaker = try container.decodeIfPresent(String.self, forKey: .speaker)
        let rawText = try container.decodeIfPresent(String.self, forKey: .text)
        let rawPinyin = try container.decodeIfPresent(String.self, forKey: .pinyin)
        translation = try container.decodeIfPresent(String.self, forKey: .translation)
        vocabulary = try container.decodeIfPresent([String].self, forKey: .vocabulary)
        vocabularyMeanings = try container.decodeIfPresent([String: String].self, forKey: .vocabularyMeanings)

        if let raw = rawText, raw.hasChineseCharacters {
            text = raw.spokenChineseText
            let cleanPinyin = rawPinyin?.trimmingCharacters(in: .whitespacesAndNewlines)
            pinyin = (cleanPinyin != nil && !cleanPinyin!.isEmpty) ? cleanPinyin : raw.inlinePinyin
        } else {
            text = rawText
            pinyin = rawPinyin
        }
    }
}

extension String {
    var hasChineseCharacters: Bool {
        unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
        }
    }

    var spokenChineseText: String {
        let pattern = #"[\(（][a-zA-Zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜü\s,.'’\-–—0-9]+[\)）]"#
        return self.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var inlinePinyin: String? {
        let pattern = #"[\(（]([a-zA-Zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜü\s,.'’\-–—0-9]+)[\)）]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = self as NSString
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: nsString.length))
        let extracted = matches.compactMap { match -> String? in
            guard match.numberOfRanges > 1 else { return nil }
            return nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
        return extracted.isEmpty ? nil : extracted.joined(separator: " ")
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
