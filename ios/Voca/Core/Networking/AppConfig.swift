import Foundation

/// App-wide configuration. The base URL points at the Voca Spring Boot backend.
///
/// In development the backend runs on `http://localhost:22052`; the iOS Simulator shares
/// `localhost` with the host machine, so no extra setup is needed. Override at launch with the
/// `VOCA_BASE_URL` environment variable (Scheme → Run → Arguments) to hit a staging/prod server,
/// or dynamically configure via UI at runtime (persisted in UserDefaults).
enum AppConfig {
    /// Production server (used by device builds by default).
    static let productionURL = URL(string: "https://voca.thaonv.online")!

    /// Local simulator backend URL.
    static let simulatorURL = URL(string: "http://localhost:22052")!

    /// UserDefaults key for storing user-configured server URL.
    static let customServerURLKey = "voca.server.custom_base_url"

    /// The default base URL based on environment variable or build target.
    static var defaultBaseURL: URL {
        if let raw = ProcessInfo.processInfo.environment["VOCA_BASE_URL"],
           let url = try? normalizeAndValidate(url: raw) {
            return url
        }
        #if targetEnvironment(simulator)
        return simulatorURL
        #else
        return productionURL
        #endif
    }

    /// Dynamic base URL: reads from UserDefaults if configured, otherwise falls back to `defaultBaseURL`.
    static var baseURL: URL {
        get {
            if let custom = UserDefaults.standard.string(forKey: customServerURLKey),
               let url = URL(string: custom) {
                return url
            }
            return defaultBaseURL
        }
        set {
            UserDefaults.standard.set(newValue.absoluteString, forKey: customServerURLKey)
        }
    }

    /// Whether a custom server URL is currently active.
    static var isCustomBaseURL: Bool {
        UserDefaults.standard.string(forKey: customServerURLKey) != nil
    }

    /// Normalizes and validates a server URL input string.
    static func normalizeAndValidate(url string: String) throws -> URL {
        var trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ConfigurationError.emptyURL
        }
        let lower = trimmed.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            if lower.hasPrefix("localhost")
                || lower.hasPrefix("127.0.0.1")
                || lower.hasPrefix("192.168.")
                || lower.hasPrefix("10.") {
                trimmed = "http://" + trimmed
            } else {
                trimmed = "https://" + trimmed
            }
        }
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        // Remove trailing "/api" (case-insensitive) if entered accidentally, then strip any remaining "/"
        if trimmed.lowercased().hasSuffix("/api") {
            trimmed.removeLast(4)
            while trimmed.hasSuffix("/") {
                trimmed.removeLast()
            }
        }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = url.host, !host.isEmpty else {
            throw ConfigurationError.invalidURL
        }
        return url
    }

    /// Validates and persists the new custom base URL without mutating session/auth state directly.
    @discardableResult
    static func persistCustomURL(_ urlString: String) throws -> URL {
        let validURL = try normalizeAndValidate(url: urlString)
        if validURL == defaultBaseURL {
            UserDefaults.standard.removeObject(forKey: customServerURLKey)
        } else {
            UserDefaults.standard.set(validURL.absoluteString, forKey: customServerURLKey)
        }
        return validURL
    }

    /// Removes any custom server override so `baseURL` returns `defaultBaseURL`.
    static func clearCustomURL() {
        UserDefaults.standard.removeObject(forKey: customServerURLKey)
    }

    /// Validates, stores the new custom base URL, and purges previous cached session data.
    /// Prefer `AuthStore.switchServerURL(_:)` in UI flows so in-memory tokens and auth phase stay in sync.
    @discardableResult
    static func setCustomURL(_ urlString: String) throws -> URL {
        let validURL = try persistCustomURL(urlString)
        KeychainStore.set(nil, for: KeychainStore.accessTokenKey)
        KeychainStore.set(nil, for: KeychainStore.refreshTokenKey)
        Task { await ApiClient.shared.clearTokens() }
        AppCache.clearAll()
        return validURL
    }

    /// Resets the server base URL to default and purges cached session data.
    static func resetToDefault() {
        clearCustomURL()
        KeychainStore.set(nil, for: KeychainStore.accessTokenKey)
        KeychainStore.set(nil, for: KeychainStore.refreshTokenKey)
        Task { await ApiClient.shared.clearTokens() }
        AppCache.clearAll()
    }

    enum ConfigurationError: LocalizedError {
        case emptyURL
        case invalidURL

        var errorDescription: String? {
            switch self {
            case .emptyURL:
                return "Địa chỉ máy chủ không được để trống."
            case .invalidURL:
                return "Địa chỉ máy chủ không hợp lệ. Vui lòng nhập URL dạng http:// hoặc https:// (ví dụ: https://voca.thaonv.online hoặc http://localhost:22052)."
            }
        }
    }
}

