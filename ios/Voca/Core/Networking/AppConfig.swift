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
           let url = URL(string: raw) {
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
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            if trimmed.lowercased().hasPrefix("localhost")
                || trimmed.contains("127.0.0.1")
                || trimmed.contains("192.168.")
                || trimmed.contains("10.") {
                trimmed = "http://" + trimmed
            } else {
                trimmed = "https://" + trimmed
            }
        }
        // Remove trailing "/api" if entered accidentally
        if trimmed.hasSuffix("/api") {
            trimmed.removeLast(4)
        }
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            throw ConfigurationError.invalidURL
        }
        return url
    }

    /// Validates, stores the new custom base URL, and purges previous cached session data.
    @discardableResult
    static func setCustomURL(_ urlString: String) throws -> URL {
        let validURL = try normalizeAndValidate(url: urlString)
        UserDefaults.standard.set(validURL.absoluteString, forKey: customServerURLKey)
        KeychainStore.set(nil, for: KeychainStore.accessTokenKey)
        KeychainStore.set(nil, for: KeychainStore.refreshTokenKey)
        AppCache.clearAll()
        return validURL
    }

    /// Resets the server base URL to default and purges cached session data.
    static func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: customServerURLKey)
        KeychainStore.set(nil, for: KeychainStore.accessTokenKey)
        KeychainStore.set(nil, for: KeychainStore.refreshTokenKey)
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

