import Foundation

/// Owns the JWT access/refresh tokens and serialises refresh so that many concurrent 401s trigger
/// exactly one refresh round-trip (token rotation). Backed by the Keychain.
///
/// `refreshCall` performs the raw `POST /api/auth/refresh` (it must NOT go through the authorised
/// request path, or a failing refresh would recurse).
actor TokenManager {
    private(set) var accessToken: String?
    private(set) var refreshToken: String?

    private var inFlightRefresh: Task<Bool, Never>?
    private let refreshCall: (String) async -> AuthResponse?

    init(refreshCall: @escaping (String) async -> AuthResponse?) {
        self.refreshCall = refreshCall
        self.accessToken = KeychainStore.get(KeychainStore.accessTokenKey)
        self.refreshToken = KeychainStore.get(KeychainStore.refreshTokenKey)
    }

    var hasSession: Bool { refreshToken != nil }

    func store(access: String, refresh: String) {
        accessToken = access
        refreshToken = refresh
        KeychainStore.set(access, for: KeychainStore.accessTokenKey)
        KeychainStore.set(refresh, for: KeychainStore.refreshTokenKey)
    }

    func clear() {
        accessToken = nil
        refreshToken = nil
        KeychainStore.set(nil, for: KeychainStore.accessTokenKey)
        KeychainStore.set(nil, for: KeychainStore.refreshTokenKey)
    }

    /// Refreshes the access token. Concurrent callers await the same in-flight task.
    func refresh() async -> Bool {
        if let existing = inFlightRefresh { return await existing.value }
        guard let refresh = refreshToken else { return false }

        let task = Task { () -> Bool in
            guard let result = await refreshCall(refresh) else { return false }
            store(access: result.accessToken, refresh: result.refreshToken)
            return true
        }
        inFlightRefresh = task
        let ok = await task.value
        inFlightRefresh = nil
        return ok
    }
}
