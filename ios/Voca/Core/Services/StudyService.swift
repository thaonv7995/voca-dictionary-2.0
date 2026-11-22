import Foundation

/// Coalesces simultaneous study endpoint requests within the same session and
/// mutation generation so Today, Study and Stats share responses without
/// allowing stale pre-review or cross-account responses to overwrite cache.
private actor CoalescedStudyRequest<Value: Sendable> {
    private struct InFlight {
        let id: UUID
        let epoch: UInt64
        let generation: UInt64
        let task: Task<Value, Error>
    }

    private var current: InFlight?
    private var generation: UInt64 = 0

    func invalidate() {
        generation &+= 1
        current = nil
    }

    func fetch(
        epoch: UInt64,
        operation: @escaping @Sendable () async throws -> Value,
        onSuccess: @escaping @Sendable (Value) -> Void
    ) async throws -> Value {
        if let existing = current,
           existing.epoch == epoch,
           existing.generation == generation {
            return try await existing.task.value
        }

        let id = UUID()
        let requestGeneration = generation
        let task = Task<Value, Error> {
            do {
                let value = try await operation()
                self.finish(
                    id: id,
                    epoch: epoch,
                    generation: requestGeneration,
                    value: value,
                    onSuccess: onSuccess
                )
                return value
            } catch {
                self.clearIfCurrent(id: id)
                throw error
            }
        }
        current = InFlight(id: id, epoch: epoch, generation: requestGeneration, task: task)
        return try await task.value
    }

    private func finish(
        id: UUID,
        epoch: UInt64,
        generation requestGeneration: UInt64,
        value: Value,
        onSuccess: @Sendable (Value) -> Void
    ) {
        if current?.id == id {
            current = nil
        }
        guard requestGeneration == generation, AppCache.sessionEpoch == epoch else { return }
        onSuccess(value)
    }

    private func clearIfCurrent(id: UUID) {
        if current?.id == id {
            current = nil
        }
    }
}

private enum StudyRequestPool {
    static let due = CoalescedStudyRequest<DueResponse>()
    static let stats = CoalescedStudyRequest<StudyStats>()

    static func invalidateAll() async {
        await due.invalidate()
        await stats.invalidate()
    }
}

/// Stateless wrapper over the SRS endpoints (`/api/review`, `/api/study/*`).
struct StudyService {
    private let api = ApiClient.shared

    private struct ReviewBody: Encodable { let slug: String; let grade: Int }

    static func invalidatePendingRequests() async {
        await StudyRequestPool.invalidateAll()
    }

    func due() async throws -> DueResponse {
        let epoch = AppCache.sessionEpoch
        return try await StudyRequestPool.due.fetch(
            epoch: epoch,
            operation: {
                try await ApiClient.shared.get("/api/study/due")
            },
            onSuccess: { value in
                AppCache.saveDue(value)
            }
        )
    }

    func stats() async throws -> StudyStats {
        let epoch = AppCache.sessionEpoch
        return try await StudyRequestPool.stats.fetch(
            epoch: epoch,
            operation: {
                try await ApiClient.shared.get("/api/study/stats")
            },
            onSuccess: { value in
                AppCache.saveStudyStats(value)
            }
        )
    }

    func cachedDue() -> DueResponse? { AppCache.loadDue() }
    func cachedStats() -> StudyStats? { AppCache.loadStudyStats() }

    @discardableResult
    func review(slug: String, grade: ReviewGrade) async throws -> ReviewResult {
        let result: ReviewResult = try await api.post("/api/review", body: ReviewBody(slug: slug, grade: grade.rawValue))
        await StudyRequestPool.invalidateAll()
        AppCache.removeDueCard(slug: slug)
        return result
    }
}
