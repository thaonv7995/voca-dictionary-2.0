import Foundation
import WidgetKit

/// Publishes the user's cards to the App Group so the home-screen widget can show them,
/// then asks WidgetKit to refresh. Call after loading cards.
enum WidgetSync {
    static func publish(_ cards: [Card]) {
        let widgetCards = cards.prefix(200).map {
            WidgetCard(word: $0.word, ipa: $0.ipa, meaningVi: $0.meaningVi, partOfSpeech: $0.partOfSpeech)
        }
        WidgetSharedStore.save(Array(widgetCards))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
