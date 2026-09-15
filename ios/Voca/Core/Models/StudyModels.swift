import Foundation

/// `GET /api/study/due` → `{ count, cards: [{ card, review }] }`.
struct DueResponse: Codable {
    let count: Int
    let cards: [DueItem]
}

struct DueItem: Codable, Identifiable {
    let card: Card
    let review: ReviewInfo
    var id: String { card.slug }
}

struct ReviewInfo: Codable {
    let level: String?
    let due: String?
    let reps: Int?
    let lapses: Int?
    let isNew: Bool?
}

/// `POST /api/review` result.
struct ReviewResult: Decodable {
    let slug: String
    let grade: Int
    let level: String?
    let due: String?
    let intervalDays: Double?
    let stability: Double?
    let difficulty: Double?
    let reps: Int?
    let lapses: Int?
    let state: Int?
}

/// `GET /api/study/stats`.
struct StudyStats: Codable {
    let totalCards: Int
    let totalReviews: Int
    let dueNow: Int
    let byLevel: [String: Int]
}

/// FSRS grade 1..4 (Again / Hard / Good / Easy).
enum ReviewGrade: Int, CaseIterable, Identifiable {
    case again = 1, hard = 2, good = 3, easy = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .again: return "Lại"
        case .hard: return "Khó"
        case .good: return "Tốt"
        case .easy: return "Dễ"
        }
    }
}
