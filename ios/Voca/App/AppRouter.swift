import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    var pendingCardSlug: String?

    func open(_ url: URL) {
        guard url.scheme == "voca", url.host == "card" else { return }
        let slug = url.pathComponents.dropFirst().joined(separator: "/")
            .removingPercentEncoding ?? ""
        guard !slug.isEmpty else { return }
        pendingCardSlug = slug
    }
}
