import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    var pendingCardSlug: String?

    func open(_ url: URL) {
        guard url.scheme == "voca" else { return }
        let slug = url.pathComponents.dropFirst().joined(separator: "/")
            .removingPercentEncoding ?? ""
        if !slug.isEmpty { pendingCardSlug = slug }

        guard url.host == "speak",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let text = components.queryItems?.first(where: { $0.name == "text" })?.value,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        let rawLang = components.queryItems?.first(where: { $0.name == "language" })?.value
        let resolvedLang: CardLanguage = rawLang == CardLanguage.chinese.rawValue || text.hasChineseCharacters
            ? .chinese
            : .english
        Task {
            try? await TTSService().speak(text, language: resolvedLang)
        }
    }

    func openPendingWidgetCard() {
        guard let slug = WidgetSharedStore.takePendingCardSlug() else { return }
        pendingCardSlug = slug
    }
}
