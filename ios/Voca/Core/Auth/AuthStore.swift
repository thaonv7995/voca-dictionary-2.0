import Foundation
import Observation

/// Observable auth state for the app. Drives the root route (loading / signed-out / signed-in)
/// and exposes the auth actions used by the auth screens.
@MainActor
@Observable
final class AuthStore {
    enum Phase: Equatable {
        case loading
        case signedOut
        case signedIn
    }

    private(set) var phase: Phase = .loading
    private(set) var user: User?

    private let api = ApiClient.shared

    init() {
        api.onSessionExpired = { [weak self] in
            Task { @MainActor in self?.applySignedOut() }
        }
    }

    /// Called once at launch: if a session is stored, fetch the current user; otherwise show login.
    func bootstrap() async {
        guard await api.hasStoredSession() else {
            AppCache.clearAll()
            phase = .signedOut
            return
        }
        let cachedUser = AppCache.loadUser()
        if let cachedUser {
            user = cachedUser
            phase = .signedIn
        }
        do {
            user = try await api.get("/api/auth/me")
            if let user { AppCache.saveUser(user) }
            phase = .signedIn
        } catch {
            if cachedUser == nil { applySignedOut() }
        }
    }

    func login(email: String, password: String) async throws {
        let result: AuthResponse = try await api.post(
            "/api/auth/login",
            body: ["email": email, "password": password],
            authorized: false)
        await api.storeTokens(access: result.accessToken, refresh: result.refreshToken)
        user = result.user
        AppCache.saveUser(result.user)
        phase = .signedIn
    }

    func register(email: String, password: String, displayName: String) async throws {
        var body: [String: String] = ["email": email, "password": password]
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { body["displayName"] = trimmed }

        let result: AuthResponse = try await api.post(
            "/api/auth/register", body: body, authorized: false)
        await api.storeTokens(access: result.accessToken, refresh: result.refreshToken)
        user = result.user
        AppCache.saveUser(result.user)
        phase = .signedIn
    }

    func logout() async {
        await api.logout()
        applySignedOut()
    }

    func changePassword(current: String, new: String) async throws {
        let _: OkResponse = try await api.post(
            "/api/auth/change-password",
            body: ["currentPassword": current, "newPassword": new])
    }

    func updateProfile(displayName: String) async throws {
        let updated: User = try await api.patch(
            "/api/auth/me",
            body: ["displayName": displayName.trimmingCharacters(in: .whitespacesAndNewlines)])
        user = updated
        AppCache.saveUser(updated)
    }

    private func applySignedOut() {
        AppCache.clearAll()
        user = nil
        phase = .signedOut
    }
}
