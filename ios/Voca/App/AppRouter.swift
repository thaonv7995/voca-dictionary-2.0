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

        let language = components.queryItems?.first(where: { $0.name == "language" })?.value
        Task {
            let voice = language == CardLanguage.chinese.rawValue
                ? "edge-tts/zh-CN-XiaoxiaoNeural"
                : nil
            try? await TTSService().speak(text, voiceModel: voice)
        }
    }
}
