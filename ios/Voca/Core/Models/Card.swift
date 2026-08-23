import Foundation

/// A vocabulary card. Mirrors the backend `CardDto`. Identified by `slug` (unique per user).
struct Card: Codable, Identifiable, Hashable {
    var id: String { slug }

    let numericId: Int?
    let slug: String
    let word: String
    let ipa: String?
    let pronunciation: String?
    let frequency: String?
    let meaningEn: String?
    let meaningVi: String?
    let useCases: [String]?
    let examples: [String]?
    let memoryTip: String?
    let toeicTrap: String?
    let partOfSpeech: String?
    let topic: String?
    let tags: [String]?
    let keyword: String?
    let practicePrompt: String?
    let answer: String?
    let level: String?
    let audioUrl: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case numericId = "id"
        case slug, word, ipa, pronunciation, frequency, meaningEn, meaningVi
        case useCases, examples, memoryTip, toeicTrap, partOfSpeech, topic, tags
        case keyword, practicePrompt, answer, level, audioUrl, createdAt
    }
}

/// Learning level of a card. Backend stores these as lowercase strings.
enum CardLevel: String, CaseIterable, Identifiable {
    case new, learning, known, mastered

    var id: String { rawValue }

    var label: String {
        switch self {
        case .new: return "Mới"
        case .learning: return "Đang học"
        case .known: return "Đã biết"
        case .mastered: return "Thành thạo"
        }
    }

    init?(_ raw: String?) {
        guard let raw, let level = CardLevel(rawValue: raw.lowercased()) else { return nil }
        self = level
    }
}
