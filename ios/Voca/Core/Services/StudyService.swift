import Foundation

/// Stateless wrapper over the SRS endpoints (`/api/review`, `/api/study/*`).
struct StudyService {
    private let api = ApiClient.shared

    private struct ReviewBody: Encodable { let slug: String; let grade: Int }

    func due() async throws -> DueResponse {
        try await api.get("/api/study/due")
    }

    func stats() async throws -> StudyStats {
        try await api.get("/api/study/stats")
    }

    @discardableResult
    func review(slug: String, grade: ReviewGrade) async throws -> ReviewResult {
        try await api.post("/api/review", body: ReviewBody(slug: slug, grade: grade.rawValue))
    }
}
