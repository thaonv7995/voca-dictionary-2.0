import Foundation
import WidgetKit

/// Publishes the user's cards to the App Group so the home-screen widget can show them,
/// then asks WidgetKit to refresh. Call after loading cards or changing active language.
enum WidgetSync {
    @MainActor private static var lastSyncedLanguage: String?
    @MainActor private static var languageReloadTask: Task<Void, Never>?

    static func publish(_ cards: [Card]) {
        let widgetCards = cards.prefix(200).map {
            WidgetCard(slug: $0.slug, word: $0.word, ipa: $0.ipa, pronunciation: $0.pronunciation,
                       language: $0.language?.rawValue, meaningVi: $0.meaningVi,
                       partOfSpeech: $0.partOfSpeech)
        }
        WidgetSharedStore.save(Array(widgetCards))
        WidgetCenter.shared.reloadAllTimelines()
    }

    @MainActor
    static func setSelectedLanguage(_ value: String) {
        guard lastSyncedLanguage != value else { return }
        lastSyncedLanguage = value
        languageReloadTask?.cancel()
        languageReloadTask = Task {
            // Defer App Group IPC & WidgetKit XPC until after the switcher spring finishes.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            WidgetSharedStore.setSelectedLanguage(value)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
