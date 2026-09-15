import Foundation

/// Stateless wrapper over the SRS endpoints (`/api/review`, `/api/study/*`).
struct StudyService {
    private let api = ApiClient.shared

    private struct ReviewBody: Encodable { let slug: String; let grade: Int }

    func due() async throws -> DueResponse {
        let value: DueResponse = try await api.get("/api/study/due")
        AppCache.saveDue(value)
        return value
    }

    func stats() async throws -> StudyStats {
        let value: StudyStats = try await api.get("/api/study/stats")
        AppCache.saveStudyStats(value)
        return value
    }

    func cachedDue() -> DueResponse? { AppCache.loadDue() }
    func cachedStats() -> StudyStats? { AppCache.loadStudyStats() }

    @discardableResult
    func review(slug: String, grade: ReviewGrade) async throws -> ReviewResult {
        try await api.post("/api/review", body: ReviewBody(slug: slug, grade: grade.rawValue))
    }
}
