import Foundation
import Observation

@MainActor
@Observable
final class MacSessionStore {
    enum Phase: Equatable, Sendable {
        case loading
        case signedOut
        case signedIn(Account)
    }

    struct Account: Equatable, Sendable {
        let id: String
        let displayName: String
        let email: String

        static let preview = Account(
            id: "preview-account",
            displayName: "Voca Learner",
            email: "learner@example.com"
        )
    }

    struct SavedCredentials: Equatable, Sendable {
        let email: String
        let password: String
        let rememberCredentials: Bool
    }

    enum SignInError: LocalizedError, Equatable {
        case missingEmail
        case invalidEmail
        case missingPassword
        case invalidCredentials
        case serverMessage(String)

        var errorDescription: String? {
            switch self {
            case .missingEmail:
                "Vui lòng nhập địa chỉ email."
            case .invalidEmail:
                "Địa chỉ email không hợp lệ."
            case .missingPassword:
                "Vui lòng nhập mật khẩu."
            case .invalidCredentials:
                "Email hoặc mật khẩu không chính xác."
            case let .serverMessage(message):
                message
            }
        }
    }

    private(set) var phase: Phase = .loading
    private(set) var isSigningIn = false
    private(set) var signInError: SignInError?
    private(set) var savedCredentials: SavedCredentials?

    private let persistence: MacSessionPersistence
    private let authentication: MacAuthenticationService

    init(
        persistence: MacSessionPersistence,
        authentication: MacAuthenticationService
    ) {
        self.persistence = persistence
        self.authentication = authentication
        self.savedCredentials = persistence.loadSavedCredentials()

        ApiClient.shared.onSessionExpired = { [weak self] in
            Task { @MainActor in
                self?.handleExpiredSession()
            }
        }
    }

    convenience init() {
        self.init(
            persistence: UserDefaultsMacSessionPersistence(),
            authentication: SharedMacAuthenticationService()
        )
    }

    var account: Account? {
        guard case let .signedIn(account) = phase else {
            return nil
        }

        return account
    }

    var isSignedIn: Bool {
        account != nil
    }

    func bootstrap() async {
        guard phase == .loading else {
            return
        }

        let cachedAccount = persistence.loadAccount()

        do {
            if let account = try await authentication.restoreSession() {
                persistence.saveAccount(account)
                phase = .signedIn(account)
                return
            }
        } catch {
            // A cached profile may paint the first authenticated frame while
            // the server is temporarily unavailable. Token expiry is still
            // handled by the shared ApiClient session-expiration callback.
            if let cachedAccount {
                phase = .signedIn(cachedAccount)
                return
            }
        }

        if let cachedAccount {
            phase = .signedIn(cachedAccount)
        } else {
            phase = .signedOut
        }
    }

    func signIn(
        email: String,
        password: String,
        rememberCredentials: Bool = true
    ) async {
        guard !isSigningIn else {
            return
        }

        signInError = nil

        let normalizedEmail = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalizedEmail.isEmpty else {
            signInError = .missingEmail
            return
        }

        guard normalizedEmail.contains("@"),
              normalizedEmail.contains(".")
        else {
            signInError = .invalidEmail
            return
        }

        guard !password.isEmpty else {
            signInError = .missingPassword
            return
        }

        isSigningIn = true
        defer {
            isSigningIn = false
        }

        do {
            let account = try await authentication.signIn(
                email: normalizedEmail,
                password: password
            )

            persistence.saveAccount(account)
            if rememberCredentials {
                let credentials = SavedCredentials(
                    email: normalizedEmail,
                    password: password,
                    rememberCredentials: true
                )
                persistence.saveCredentials(credentials)
                savedCredentials = credentials
            } else {
                persistence.clearSavedCredentials()
                savedCredentials = nil
            }
            phase = .signedIn(account)
        } catch let apiError as ApiError {
            signInError = .serverMessage(apiError.message)
        } catch {
            signInError = .invalidCredentials
        }
    }

    func register(
        email: String,
        password: String,
        displayName: String,
        rememberCredentials: Bool = true
    ) async throws {
        let normalizedEmail = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let account = try await authentication.register(
            email: normalizedEmail,
            password: password,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        persistence.saveAccount(account)
        if rememberCredentials {
            let credentials = SavedCredentials(
                email: normalizedEmail,
                password: password,
                rememberCredentials: true
            )
            persistence.saveCredentials(credentials)
            savedCredentials = credentials
        }
        phase = .signedIn(account)
    }

    func clearSavedCredentials() {
        persistence.clearSavedCredentials()
        savedCredentials = nil
    }

    func usePreviewAccount() {
        signInError = nil
        persistence.saveAccount(.preview)
        phase = .signedIn(.preview)
    }

    func signOut() {
        persistence.clear()
        signInError = nil
        phase = .signedOut
        MacSystemIntegrations.clearSpotlightIndex()
        MacSystemIntegrations.clearNotifications()

        Task {
            await authentication.signOut()
        }
    }

    func dismissSignInError() {
        signInError = nil
    }

    private func handleExpiredSession() {
        persistence.clear()
        signInError = nil
        phase = .signedOut
        MacSystemIntegrations.clearSpotlightIndex()
        MacSystemIntegrations.clearNotifications()
    }

    private func displayName(from email: String) -> String {
        let localPart = email
            .split(separator: "@", maxSplits: 1)
            .first
            .map(String.init) ?? email

        let words = localPart
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }

        return words.isEmpty
            ? "Voca Learner"
            : words.joined(separator: " ")
    }
}

protocol MacAuthenticationService: Sendable {
    func restoreSession() async throws -> MacSessionStore.Account?
    func signIn(
        email: String,
        password: String
    ) async throws -> MacSessionStore.Account
    func register(
        email: String,
        password: String,
        displayName: String
    ) async throws -> MacSessionStore.Account
    func signOut() async
}

extension MacAuthenticationService {
    func register(
        email: String,
        password: String,
        displayName: String
    ) async throws -> MacSessionStore.Account {
        try await signIn(email: email, password: password)
    }
}

struct SharedMacAuthenticationService: MacAuthenticationService {
    func restoreSession() async throws -> MacSessionStore.Account? {
        guard await ApiClient.shared.hasStoredSession() else {
            return nil
        }

        let user: User = try await ApiClient.shared.get("/api/auth/me")
        AppCache.saveUser(user)
        return account(from: user)
    }

    func signIn(
        email: String,
        password: String
    ) async throws -> MacSessionStore.Account {
        let response: AuthResponse = try await ApiClient.shared.post(
            "/api/auth/login",
            body: [
                "email": email,
                "password": password
            ],
            authorized: false
        )

        await ApiClient.shared.storeTokens(
            access: response.accessToken,
            refresh: response.refreshToken
        )
        AppCache.saveUser(response.user)

        return account(from: response.user)
    }

    func register(
        email: String,
        password: String,
        displayName: String
    ) async throws -> MacSessionStore.Account {
        var body: [String: String] = [
            "email": email,
            "password": password
        ]
        if !displayName.isEmpty {
            body["displayName"] = displayName
        }

        let response: AuthResponse = try await ApiClient.shared.post(
            "/api/auth/register",
            body: body,
            authorized: false
        )

        await ApiClient.shared.storeTokens(
            access: response.accessToken,
            refresh: response.refreshToken
        )
        AppCache.saveUser(response.user)

        return account(from: response.user)
    }

    func signOut() async {
        await ApiClient.shared.logout()
        AppCache.clearAll()
    }

    private func account(
        from user: User
    ) -> MacSessionStore.Account {
        MacSessionStore.Account(
            id: String(user.id),
            displayName: normalizedDisplayName(
                user.displayName,
                email: user.email
            ),
            email: user.email
        )
    }

    private func normalizedDisplayName(
        _ displayName: String?,
        email: String
    ) -> String {
        if let displayName {
            let trimmed = displayName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return email
            .split(separator: "@", maxSplits: 1)
            .first
            .map(String.init) ?? email
    }
}

struct PreviewMacAuthenticationService: MacAuthenticationService {
    func restoreSession() async throws -> MacSessionStore.Account? {
        nil
    }

    func signIn(
        email: String,
        password: String
    ) async throws -> MacSessionStore.Account {
        let localPart = email
            .split(separator: "@", maxSplits: 1)
            .first
            .map(String.init) ?? email

        let displayName = localPart
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")

        return MacSessionStore.Account(
            id: email,
            displayName: displayName.isEmpty
                ? "Voca Learner"
                : displayName,
            email: email
        )
    }

    func signOut() async {}
}

@MainActor
protocol MacSessionPersistence {
    func loadAccount() -> MacSessionStore.Account?
    func saveAccount(_ account: MacSessionStore.Account)
    func clear()
    func loadSavedCredentials() -> MacSessionStore.SavedCredentials?
    func saveCredentials(_ credentials: MacSessionStore.SavedCredentials)
    func clearSavedCredentials()
}

extension MacSessionPersistence {
    func loadSavedCredentials() -> MacSessionStore.SavedCredentials? { nil }
    func saveCredentials(_ credentials: MacSessionStore.SavedCredentials) {}
    func clearSavedCredentials() {}
}

@MainActor
struct UserDefaultsMacSessionPersistence: MacSessionPersistence {
    private enum Key {
        static let accountID = "mac.session.account.id"
        static let displayName = "mac.session.account.displayName"
        static let email = "mac.session.account.email"
        static let rememberCredentials = "mac.session.credentials.remember"
        static let savedEmail = "mac.session.credentials.email"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadAccount() -> MacSessionStore.Account? {
        guard let id = defaults.string(forKey: Key.accountID),
              let displayName = defaults.string(forKey: Key.displayName),
              let email = defaults.string(forKey: Key.email),
              !id.isEmpty,
              !email.isEmpty
        else {
            return nil
        }

        return MacSessionStore.Account(
            id: id,
            displayName: displayName,
            email: email
        )
    }

    func saveAccount(_ account: MacSessionStore.Account) {
        defaults.set(account.id, forKey: Key.accountID)
        defaults.set(account.displayName, forKey: Key.displayName)
        defaults.set(account.email, forKey: Key.email)
    }

    func clear() {
        defaults.removeObject(forKey: Key.accountID)
        defaults.removeObject(forKey: Key.displayName)
        defaults.removeObject(forKey: Key.email)
    }

    func loadSavedCredentials() -> MacSessionStore.SavedCredentials? {
        let remember = defaults.object(forKey: Key.rememberCredentials) as? Bool ?? true
        guard remember else {
            return nil
        }
        let email = defaults.string(forKey: Key.savedEmail)
            ?? KeychainStore.get(KeychainStore.savedEmailKey)
            ?? ""
        let password = KeychainStore.get(KeychainStore.savedPasswordKey) ?? ""
        guard !email.isEmpty else {
            return nil
        }
        return MacSessionStore.SavedCredentials(
            email: email,
            password: password,
            rememberCredentials: true
        )
    }

    func saveCredentials(_ credentials: MacSessionStore.SavedCredentials) {
        defaults.set(credentials.rememberCredentials, forKey: Key.rememberCredentials)
        defaults.set(credentials.email, forKey: Key.savedEmail)
        KeychainStore.set(credentials.email, for: KeychainStore.savedEmailKey)
        KeychainStore.set(credentials.password, for: KeychainStore.savedPasswordKey)
    }

    func clearSavedCredentials() {
        defaults.set(false, forKey: Key.rememberCredentials)
        defaults.removeObject(forKey: Key.savedEmail)
        KeychainStore.set(nil, for: KeychainStore.savedEmailKey)
        KeychainStore.set(nil, for: KeychainStore.savedPasswordKey)
    }
}

@MainActor
final class InMemoryMacSessionPersistence: MacSessionPersistence {
    private var account: MacSessionStore.Account?
    private var credentials: MacSessionStore.SavedCredentials?

    init(account: MacSessionStore.Account? = nil) {
        self.account = account
    }

    func loadAccount() -> MacSessionStore.Account? {
        account
    }

    func saveAccount(_ account: MacSessionStore.Account) {
        self.account = account
    }

    func clear() {
        account = nil
    }

    func loadSavedCredentials() -> MacSessionStore.SavedCredentials? {
        credentials
    }

    func saveCredentials(_ credentials: MacSessionStore.SavedCredentials) {
        self.credentials = credentials
    }

    func clearSavedCredentials() {
        credentials = nil
    }
}
