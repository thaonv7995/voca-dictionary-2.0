import Foundation

enum RawRefreshOutcome: Sendable {
    case success(AuthResponse)
    case invalidSession
    case transientFailure(Error)
}

enum TokenRefreshOutcome: Sendable {
    case refreshed
    case invalidSession
    case transientFailure(Error)
}

/// Owns the JWT access/refresh tokens and serialises refresh so that many concurrent 401s trigger
/// exactly one refresh round-trip (token rotation). Backed by the Keychain.
///
/// `refreshCall` performs the raw `POST /api/auth/refresh` (it must NOT go through the authorised
/// request path, or a failing refresh would recurse).
actor TokenManager {
    private struct InFlightRefresh {
        let id: UUID
        let generation: UInt64
        let task: Task<TokenRefreshOutcome, Never>
    }

    private(set) var accessToken: String?
    private(set) var refreshToken: String?

    private var generation: UInt64 = 0
    private var inFlightRefresh: InFlightRefresh?
    private let refreshCall: @Sendable (String) async -> RawRefreshOutcome

    init(refreshCall: @escaping @Sendable (String) async -> RawRefreshOutcome) {
        self.refreshCall = refreshCall
        self.accessToken = KeychainStore.get(KeychainStore.accessTokenKey)
        self.refreshToken = KeychainStore.get(KeychainStore.refreshTokenKey)
    }

    var hasSession: Bool { refreshToken != nil }

    func store(access: String, refresh: String) {
        generation &+= 1
        inFlightRefresh?.task.cancel()
        inFlightRefresh = nil
        accessToken = access
        refreshToken = refresh
        KeychainStore.set(access, for: KeychainStore.accessTokenKey)
        KeychainStore.set(refresh, for: KeychainStore.refreshTokenKey)
    }

    func clear() {
        generation &+= 1
        inFlightRefresh?.task.cancel()
        inFlightRefresh = nil
        accessToken = nil
        refreshToken = nil
        KeychainStore.set(nil, for: KeychainStore.accessTokenKey)
        KeychainStore.set(nil, for: KeychainStore.refreshTokenKey)
    }

    /// Clears tokens only if no newer login/store/clear has occurred since `expectedGeneration`.
    func clearIfGeneration(_ expectedGeneration: UInt64) {
        guard generation == expectedGeneration else { return }
        clear()
    }

    /// Refreshes the access token. Concurrent callers await the same in-flight task, and callers
    /// whose failed access token was already rotated succeed immediately without double-rotating.
    func refresh(failedAccessToken: String? = nil) async -> (outcome: TokenRefreshOutcome, generation: UInt64) {
        if let failedAccessToken,
           let current = accessToken,
           current != failedAccessToken {
            return (.refreshed, generation)
        }

        if let existing = inFlightRefresh, existing.generation == generation {
            let outcome = await existing.task.value
            return (outcome, existing.generation)
        }

        let requestGeneration = generation
        guard let refresh = refreshToken else {
            return (.invalidSession, requestGeneration)
        }

        let id = UUID()
        let call = refreshCall
        let task = Task<TokenRefreshOutcome, Never> {
            let raw = await call(refresh)
            return self.completeRefresh(id: id, generation: requestGeneration, raw: raw)
        }
        inFlightRefresh = InFlightRefresh(id: id, generation: requestGeneration, task: task)
        let outcome = await task.value
        return (outcome, requestGeneration)
    }

    private func completeRefresh(id: UUID, generation requestGeneration: UInt64, raw: RawRefreshOutcome) -> TokenRefreshOutcome {
        if inFlightRefresh?.id == id {
            inFlightRefresh = nil
        }

        switch raw {
        case .success(let auth):
            guard generation == requestGeneration else {
                // Session was cleared or replaced while refresh was in flight — do not resurrect old tokens.
                return .invalidSession
            }
            accessToken = auth.accessToken
            refreshToken = auth.refreshToken
            KeychainStore.set(auth.accessToken, for: KeychainStore.accessTokenKey)
            KeychainStore.set(auth.refreshToken, for: KeychainStore.refreshTokenKey)
            return .refreshed
        case .invalidSession:
            return .invalidSession
        case .transientFailure(let error):
            return .transientFailure(error)
        }
    }
}
