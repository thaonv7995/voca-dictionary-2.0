import Foundation

enum MacDestination: String, CaseIterable, Identifiable, Codable, Sendable {
    case today
    case vocabulary
    case review
    case practice
    case assistant
    case insights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            "Hôm nay"
        case .vocabulary:
            "Từ vựng"
        case .review:
            "Ôn tập"
        case .practice:
            "Luyện tập"
        case .assistant:
            "Trợ lý AI"
        case .insights:
            "Thống kê"
        }
    }

    var systemImage: String {
        switch self {
        case .today:
            "sun.max"
        case .vocabulary:
            "books.vertical"
        case .review:
            "rectangle.on.rectangle.angled"
        case .practice:
            "sparkles"
        case .assistant:
            "bubble.left.and.bubble.right"
        case .insights:
            "chart.xyaxis.line"
        }
    }
}
