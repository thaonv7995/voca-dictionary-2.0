import Foundation
import WidgetKit

/// Publishes the user's cards to the App Group so the home-screen widget can show them,
/// then asks WidgetKit to refresh. Call after loading cards or changing active language.
enum WidgetSync {
    @MainActor private static var lastSyncedLanguage: String?
    @MainActor private static var languageReloadTask: Task<Void, Never>?
    @MainActor private static var publishTask: Task<Void, Never>?

    @MainActor
    static func publish(_ cards: [Card]) {
        // Balance English and Chinese so a large deck in one language never starves the other.
        let english = cards.filter { !$0.isChinese }.prefix(120)
        let chinese = cards.filter { $0.isChinese }.prefix(120)
        let balanced = Array(english) + Array(chinese)
        let widgetCards = balanced.map {
            WidgetCard(slug: $0.slug, word: $0.word, ipa: $0.ipa, pronunciation: $0.pronunciation,
                       language: $0.language?.rawValue, meaningVi: $0.meaningVi,
                       partOfSpeech: $0.partOfSpeech)
        }
        publishTask?.cancel()
        publishTask = Task.detached(priority: .utility) {
            WidgetSharedStore.save(widgetCards)
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    @MainActor
    static func clear() {
        publishTask?.cancel()
        publishTask = nil
        languageReloadTask?.cancel()
        languageReloadTask = nil
        lastSyncedLanguage = nil
        Task.detached(priority: .utility) {
            WidgetSharedStore.clear()
            WidgetCenter.shared.reloadAllTimelines()
        }
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
            await Task.detached(priority: .utility) {
                WidgetSharedStore.setSelectedLanguage(value)
                WidgetCenter.shared.reloadAllTimelines()
            }.value
        }
    }
}
