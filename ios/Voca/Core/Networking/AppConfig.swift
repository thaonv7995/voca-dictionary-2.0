import Foundation

/// App-wide configuration. The base URL points at the Voca Spring Boot backend.
///
/// In development the backend runs on `http://localhost:22052`; the iOS Simulator shares
/// `localhost` with the host machine, so no extra setup is needed. Override at launch with the
/// `VOCA_BASE_URL` environment variable (Scheme → Run → Arguments) to hit a staging/prod server.
enum AppConfig {
    /// Production server (used by device builds by default).
    static let productionURL = URL(string: "https://voca.thaonv.online")!

    static let baseURL: URL = {
        // Explicit override always wins (Scheme → Run → Arguments → Environment Variables).
        if let raw = ProcessInfo.processInfo.environment["VOCA_BASE_URL"],
           let url = URL(string: raw) {
            return url
        }
        #if targetEnvironment(simulator)
        // Dev on the Simulator talks to a local backend on the host machine.
        return URL(string: "http://localhost:22052")!
        #else
        // On a real device localhost is the phone itself — default to the live server.
        return productionURL
        #endif
    }()
}
