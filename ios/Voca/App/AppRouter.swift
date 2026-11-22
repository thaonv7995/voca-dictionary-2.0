import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    var pendingCardSlug: String?
    @ObservationIgnored private var speakTask: Task<Void, Never>?

    func open(_ url: URL) {
        guard url.scheme?.lowercased() == "voca" else { return }

        switch url.host?.lowercased() {
        case "card":
            // `url.pathComponents` is already percent-decoded by Foundation.
            let slug = url.pathComponents.dropFirst().joined(separator: "/")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !slug.isEmpty {
                pendingCardSlug = slug
            }

        case "speak":
            guard AppCache.loadUser() != nil,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let rawText = components.queryItems?.first(where: { $0.name == "text" })?.value
            else { return }
            let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let boundedText = String(trimmed.prefix(300))
            let rawLang = components.queryItems?.first(where: { $0.name == "language" })?.value
            let resolvedLang: CardLanguage = rawLang == CardLanguage.chinese.rawValue || boundedText.hasChineseCharacters
                ? .chinese
                : .english
            speakTask?.cancel()
            speakTask = Task {
                try? await TTSService().speak(boundedText, language: resolvedLang)
            }

        case "today":
            pendingCardSlug = nil

        default:
            break
        }
    }

    func clearPending() {
        pendingCardSlug = nil
        speakTask?.cancel()
        speakTask = nil
    }
}
