import Foundation
import Observation
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
@Observable
final class MacVocabularyStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var items: [MacVocabularyItem] = []
    private(set) var loadState: LoadState = .idle
    private(set) var mutatingItemIDs: Set<MacVocabularyItem.ID> = []

    private let repository: MacVocabularyRepository
    private let ledger: MacActivityLedger
    private let sqlite: MacSQLiteVocabularyDatabase

    init(
        repository: MacVocabularyRepository,
        ledger: MacActivityLedger,
        sqlite: MacSQLiteVocabularyDatabase = MacSQLiteVocabularyDatabase()
    ) {
        self.repository = repository
        self.ledger = ledger
        self.sqlite = sqlite
        let sqlCached = sqlite.fetchAllItems()
        let rawCached = sqlCached.isEmpty ? repository.cachedItems() : sqlCached
        items = enrich(rawCached)
        if !items.isEmpty {
            sqlite.upsertItems(items)
            syncToWidget(items)
        }
    }

    convenience init(
        repository: MacVocabularyRepository =
            SharedMacVocabularyRepository()
    ) {
        self.init(
            repository: repository,
            ledger: MacActivityLedger(),
            sqlite: MacSQLiteVocabularyDatabase(inMemory: true)
        )
    }

    convenience init(ledger: MacActivityLedger) {
        self.init(
            repository: SharedMacVocabularyRepository(),
            ledger: ledger,
            sqlite: MacSQLiteVocabularyDatabase()
        )
    }

    var isLoading: Bool {
        loadState == .loading
    }

    var errorMessage: String? {
        guard case let .failed(message) = loadState else {
            return nil
        }

        return message
    }

    var pendingMutationCount: Int {
        ledger.pendingMutations.count
    }

    func load() async {
        guard !isLoading else {
            return
        }

        if items.isEmpty {
            items = enrich(repository.cachedItems())
        }

        loadState = .loading

        await ledger.flushPendingMutations()

        do {
            let fetched = try await repository.fetchItems()
            items = enrich(fetched)
            sqlite.upsertItems(items)
            MacSystemIntegrations.indexVocabularyInSpotlight(items)
            syncToWidget(items)
            loadState = .loaded
        } catch {
            if items.isEmpty {
                loadState = .failed(error.localizedDescription)
            } else {
                // Keep cached vocabulary usable while making the failed
                // refresh visible to the user.
                items = enrich(items)
                loadState = .failed(
                    "Showing cached vocabulary. "
                    + error.localizedDescription
                )
            }
        }
    }

    func retry() async {
        await load()
    }

    func create(
        word: String,
        language: MacVocabularyItem.Language
    ) async throws -> MacVocabularyItem {
        let normalizedWord = word.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !normalizedWord.isEmpty else {
            throw MacVocabularyRepositoryError.emptyWord
        }

        do {
            let created = try await repository.createItem(
                word: normalizedWord,
                language: language
            )

            let enriched = enrichItem(created)
            upsert(enriched)
            sqlite.upsertItems([enriched])
            syncToWidget(items)
            loadState = .loaded
            return enriched
        } catch {
            // Queue offline creation when remote request fails
            let fallbackID = normalizedWord
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
            let localItem = MacVocabularyItem(
                id: fallbackID,
                term: normalizedWord,
                pronunciation: nil,
                meaning: "Pending AI enrichment (saved offline).",
                language: language,
                level: "new",
                tags: ["offline"],
                isFavorite: false,
                isDue: true,
                examples: [],
                personalNote: ""
            )

            ledger.enqueueMutation(
                MacActivityLedger.PendingMutation(
                    kind: .createCard,
                    targetID: fallbackID,
                    payload: [
                        "word": normalizedWord,
                        "language": language.cardLanguage.rawValue
                    ]
                )
            )

            upsert(localItem)
            sqlite.upsertItems([localItem])
            return localItem
        }
    }

    func delete(_ identifier: MacVocabularyItem.ID) async {
        guard !mutatingItemIDs.contains(identifier) else {
            return
        }

        mutatingItemIDs.insert(identifier)
        defer {
            mutatingItemIDs.remove(identifier)
        }

        items.removeAll(where: { $0.id == identifier })
        sqlite.deleteItem(id: identifier)
        syncToWidget(items)

        do {
            try await repository.deleteItem(identifier: identifier)
        } catch {
            ledger.enqueueMutation(
                MacActivityLedger.PendingMutation(
                    kind: .deleteCard,
                    targetID: identifier
                )
            )
            loadState = .failed(
                "Deletion queued for sync when online. "
                + error.localizedDescription
            )
        }
    }

    func toggleFavorite(_ identifier: MacVocabularyItem.ID) {
        guard let index = items.firstIndex(where: {
            $0.id == identifier
        }) else {
            return
        }

        let isNowFavorite = ledger.toggleFavorite(identifier)
        items[index].isFavorite = isNowFavorite
        sqlite.upsertItems([items[index]])
    }

    func setPersonalNote(
        _ note: String,
        for identifier: MacVocabularyItem.ID
    ) {
        ledger.setPersonalNote(note, for: identifier)
        guard let index = items.firstIndex(where: {
            $0.id == identifier
        }) else {
            return
        }
        items[index].personalNote = ledger.personalNote(for: identifier)
        sqlite.upsertItems([items[index]])
    }

    func updateTags(
        _ tags: [String],
        for identifier: MacVocabularyItem.ID
    ) {
        ledger.setCustomTags(tags, for: identifier)
        guard let index = items.firstIndex(where: {
            $0.id == identifier
        }) else {
            return
        }
        items[index].tags = ledger.customTags(for: identifier)
        sqlite.upsertItems([items[index]])
    }

    func searchFTS(query: String) -> [MacVocabularyItem] {
        sqlite.searchItems(query: query)
    }

    func updateLevel(
        _ level: String,
        for identifier: MacVocabularyItem.ID
    ) async {
        guard let index = items.firstIndex(where: {
            $0.id == identifier
        }) else {
            return
        }

        items[index].level = level

        do {
            let updated = try await repository.updateLevel(
                identifier: identifier,
                level: level
            )
            items[index] = enrichItem(updated)
        } catch {
            ledger.enqueueMutation(
                MacActivityLedger.PendingMutation(
                    kind: .updateLevel,
                    targetID: identifier,
                    payload: ["level": level]
                )
            )
        }
    }

    func markReviewed(cardID: MacVocabularyItem.ID) {
        guard let index = items.firstIndex(where: {
            $0.id == cardID
        }) else {
            return
        }
        items[index].isDue = false
    }

    func replaceItemsForTesting(_ items: [MacVocabularyItem]) {
        self.items = items
        loadState = .loaded
    }

    func resetForSignOut() {
        items = []
        mutatingItemIDs = []
        loadState = .idle
        WidgetSharedStore.clear()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func upsert(_ item: MacVocabularyItem) {
        if let index = items.firstIndex(where: {
            $0.id == item.id
        }) {
            items[index] = item
        } else {
            items.insert(item, at: 0)
        }
    }

    private func enrich(_ rawItems: [MacVocabularyItem]) -> [MacVocabularyItem] {
        let richLookup = Dictionary(
            uniqueKeysWithValues: repository.cachedItems().map { ($0.id, $0) }
        )
        return rawItems.map { item in
            var merged = item
            if let rich = richLookup[item.id] {
                if merged.meaningVi == nil { merged.meaningVi = rich.meaningVi }
                if merged.meaningEn == nil { merged.meaningEn = rich.meaningEn }
                if merged.partOfSpeech == nil { merged.partOfSpeech = rich.partOfSpeech }
                if merged.topic == nil { merged.topic = rich.topic }
                if merged.useCases.isEmpty { merged.useCases = rich.useCases }
                if merged.memoryTip == nil { merged.memoryTip = rich.memoryTip }
                if merged.toeicTrap == nil { merged.toeicTrap = rich.toeicTrap }
                if merged.createdAt == nil { merged.createdAt = rich.createdAt }
            }
            return enrichItem(merged)
        }
    }

    private func enrichItem(_ item: MacVocabularyItem) -> MacVocabularyItem {
        var copy = item
        if ledger.isFavorite(item.id) {
            copy.isFavorite = true
        }
        let note = ledger.personalNote(for: item.id)
        if !note.isEmpty {
            copy.personalNote = note
        }
        let customTags = ledger.customTags(for: item.id)
        if !customTags.isEmpty {
            let merged = Array(
                NSOrderedSet(array: copy.tags + customTags)
            ) as? [String] ?? copy.tags
            copy.tags = merged
        }
        return copy
    }

    private func syncToWidget(_ items: [MacVocabularyItem]) {
        let widgetCards = items.prefix(250).map { item in
            WidgetCard(
                slug: item.id,
                word: item.term,
                ipa: item.pronunciation,
                pronunciation: item.pronunciation,
                language: item.language == .chinese ? "zh-CN" : "en",
                meaningVi: item.displayMeaningVi,
                partOfSpeech: item.partOfSpeech
            )
        }
        WidgetSharedStore.save(Array(widgetCards))
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

protocol MacVocabularyRepository: Sendable {
    @MainActor
    func cachedItems() -> [MacVocabularyItem]

    func fetchItems() async throws -> [MacVocabularyItem]

    func createItem(
        word: String,
        language: MacVocabularyItem.Language
    ) async throws -> MacVocabularyItem

    func updateLevel(
        identifier: String,
        level: String
    ) async throws -> MacVocabularyItem

    func deleteItem(identifier: String) async throws
}

extension MacVocabularyRepository {
    func updateLevel(
        identifier: String,
        level: String
    ) async throws -> MacVocabularyItem {
        let items = try await fetchItems()
        guard var matching = items.first(where: { $0.id == identifier }) else {
            throw MacVocabularyRepositoryError.emptyWord
        }
        matching.level = level
        return matching
    }
}

enum MacVocabularyRepositoryError: LocalizedError {
    case emptyWord

    var errorDescription: String? {
        switch self {
        case .emptyWord:
            "Enter a word or short phrase."
        }
    }
}

struct SharedMacVocabularyRepository: MacVocabularyRepository {
    private let service = CardsService()
    private let studyService = StudyService()

    @MainActor
    func cachedItems() -> [MacVocabularyItem] {
        let dueSlugs = Set(
            studyService.cachedDue()?.cards.map(\.card.slug) ?? []
        )
        return service.cachedList().map { card in
            MacVocabularyItem(
                card: card,
                isDue: dueSlugs.contains(card.slug)
            )
        }
    }

    func fetchItems() async throws -> [MacVocabularyItem] {
        async let cardsRequest = service.list()
        async let dueRequest = try? studyService.due()

        let cards = try await cardsRequest
        let dueResponse = await dueRequest
        let dueSlugs = Set(
            dueResponse?.cards.map(\.card.slug) ?? []
        )

        return cards.map { card in
            MacVocabularyItem(
                card: card,
                isDue: dueSlugs.contains(card.slug)
            )
        }
    }

    func createItem(
        word: String,
        language: MacVocabularyItem.Language
    ) async throws -> MacVocabularyItem {
        let card = try await service.createWithAI(
            word: word,
            language: language.cardLanguage
        )

        return MacVocabularyItem(card: card, isDue: true)
    }

    func updateLevel(
        identifier: String,
        level: String
    ) async throws -> MacVocabularyItem {
        let card = try await service.setLevel(
            slug: identifier,
            level: level
        )
        let dueSlugs = Set(
            studyService.cachedDue()?.cards.map(\.card.slug) ?? []
        )
        return MacVocabularyItem(
            card: card,
            isDue: dueSlugs.contains(card.slug)
        )
    }

    func deleteItem(identifier: String) async throws {
        try await service.delete(slug: identifier)
    }
}

extension MacVocabularyItem {
    init(card: Card, isDue: Bool = false) {
        id = card.slug
        term = card.word
        pronunciation = card.phonetic
        meaning = Self.preferredMeaning(from: card)
        language = Language(cardLanguage: card.cardLanguage)
        level = card.level
        tags = card.tags ?? []
        isFavorite = false
        self.isDue = isDue
        examples = card.examples ?? []
        personalNote = ""
        meaningVi = Self.trimmedNonEmpty(card.meaningVi)
        meaningEn = Self.trimmedNonEmpty(card.meaningEn)
        partOfSpeech = Self.trimmedNonEmpty(card.partOfSpeech)
        topic = Self.trimmedNonEmpty(card.topic)
        useCases = card.useCases ?? []
        memoryTip = Self.trimmedNonEmpty(card.memoryTip)
        toeicTrap = Self.trimmedNonEmpty(card.toeicTrap)
        createdAt = Self.trimmedNonEmpty(card.createdAt)
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func preferredMeaning(from card: Card) -> String {
        let candidates = [
            card.meaningVi,
            card.meaningEn,
            card.answer
        ]

        return candidates.compactMap { value in
            guard let value else {
                return nil
            }

            let trimmed = value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            return trimmed.isEmpty ? nil : trimmed
        }.first ?? "No meaning available."
    }
}

extension MacVocabularyItem.Language {
    init(cardLanguage: CardLanguage) {
        switch cardLanguage {
        case .english:
            self = .english
        case .chinese:
            self = .chinese
        }
    }

    var cardLanguage: CardLanguage {
        switch self {
        case .english:
            .english
        case .chinese:
            .chinese
        }
    }
}

struct PreviewMacVocabularyRepository: MacVocabularyRepository {
    var items: [MacVocabularyItem] = MacVocabularyItem.previewItems

    @MainActor
    func cachedItems() -> [MacVocabularyItem] {
        items
    }

    func fetchItems() async throws -> [MacVocabularyItem] {
        items
    }

    func createItem(
        word: String,
        language: MacVocabularyItem.Language
    ) async throws -> MacVocabularyItem {
        MacVocabularyItem(
            id: word.lowercased(),
            term: word,
            pronunciation: nil,
            meaning: "Generated preview vocabulary.",
            language: language,
            level: "new",
            tags: [],
            isFavorite: false,
            isDue: false
        )
    }

    func deleteItem(identifier: String) async throws {}
}
