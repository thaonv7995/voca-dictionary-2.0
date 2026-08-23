import Foundation

/// The authenticated user, as returned by `/api/auth/*` and `/api/auth/me`.
struct User: Codable, Identifiable, Equatable {
    let id: Int
    let email: String
    let displayName: String?
    let admin: Bool
}

/// Response body for login / register / refresh: tokens + the user profile.
struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: User
}
