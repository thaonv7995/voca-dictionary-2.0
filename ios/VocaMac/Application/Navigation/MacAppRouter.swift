import Foundation
import Observation

enum MacAppRoute: Hashable, Sendable {
    case destination(MacDestination)
    case vocabularyWord(id: String)
    case quickLookup(query: String?)
    case settings
}

enum MacRouteError: LocalizedError, Equatable {
    case unsupportedScheme
    case unsupportedRoute
    case invalidIdentifier
    case queryTooLong

    var errorDescription: String? {
        switch self {
        case .unsupportedScheme:
            "This link does not use the Voca URL scheme."
        case .unsupportedRoute:
            "This Voca link is not supported."
        case .invalidIdentifier:
            "This Voca link contains an invalid identifier."
        case .queryTooLong:
            "The Quick Lookup query is too long."
        }
    }
}

struct MacRouteParser: Sendable {
    private let maximumLookupQueryLength = 120

    func parse(_ url: URL) throws -> MacAppRoute {
        guard url.scheme?.lowercased() == "voca" else {
            throw MacRouteError.unsupportedScheme
        }

        let host = url.host?.lowercased()
        let pathComponents = url.pathComponents
            .filter { $0 != "/" }
            .map { $0.removingPercentEncoding ?? $0 }

        switch host {
        case "today":
            return .destination(.today)

        case "vocabulary":
            return try parseVocabulary(pathComponents)

        case "review":
            return .destination(.review)

        case "practice":
            return .destination(.practice)

        case "assistant":
            return .destination(.assistant)

        case "insights":
            return .destination(.insights)

        case "quick-lookup":
            return try parseQuickLookup(url)

        case "settings":
            return .settings

        default:
            throw MacRouteError.unsupportedRoute
        }
    }

    private func parseVocabulary(
        _ pathComponents: [String]
    ) throws -> MacAppRoute {
        guard !pathComponents.isEmpty else {
            return .destination(.vocabulary)
        }

        guard pathComponents.count == 2,
              pathComponents[0].lowercased() == "word"
        else {
            throw MacRouteError.unsupportedRoute
        }

        let identifier = pathComponents[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !identifier.isEmpty,
              identifier.count <= 128,
              identifier.unicodeScalars.allSatisfy({
                  CharacterSet.alphanumerics
                      .union(CharacterSet(charactersIn: "-_"))
                      .contains($0)
              })
        else {
            throw MacRouteError.invalidIdentifier
        }

        return .vocabularyWord(id: identifier)
    }

    private func parseQuickLookup(_ url: URL) throws -> MacAppRoute {
        let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )

        let query = components?
            .queryItems?
            .first(where: { $0.name == "query" })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let query, !query.isEmpty else {
            return .quickLookup(query: nil)
        }

        guard query.count <= maximumLookupQueryLength else {
            throw MacRouteError.queryTooLong
        }

        return .quickLookup(query: query)
    }
}

@MainActor
@Observable
final class MacAppRouter {
    private(set) var selectedDestination: MacDestination = .today
    private(set) var selectedVocabularyWordID: String?
    private(set) var quickLookupQuery: String?
    private(set) var isQuickLookupPresented = false
    private(set) var isAddWordPresented = false
    private(set) var addWordInitialTerm: String?
    private(set) var isImportExportPresented = false
    private(set) var importExportInitialMode: MacImportExportSheet.Mode = .importWords
    private(set) var importExportInitialText: String?
    private(set) var isSettingsRequested = false
    private(set) var routeError: MacRouteError?

    private let parser: MacRouteParser

    init(parser: MacRouteParser = MacRouteParser()) {
        self.parser = parser
    }

    func select(_ destination: MacDestination) {
        selectedDestination = destination

        if destination != .vocabulary {
            selectedVocabularyWordID = nil
        }
    }

    func open(_ url: URL) {
        do {
            routeError = nil
            open(try parser.parse(url))
        } catch let error as MacRouteError {
            routeError = error
        } catch {
            routeError = .unsupportedRoute
        }
    }

    func open(_ route: MacAppRoute) {
        routeError = nil

        switch route {
        case let .destination(destination):
            select(destination)

        case let .vocabularyWord(id):
            selectedDestination = .vocabulary
            selectedVocabularyWordID = id

        case let .quickLookup(query):
            quickLookupQuery = query
            isQuickLookupPresented = true

        case .settings:
            isSettingsRequested = true
        }
    }

    func dismissQuickLookup() {
        isQuickLookupPresented = false
        quickLookupQuery = nil
    }

    func requestAddWord(initialTerm: String? = nil) {
        addWordInitialTerm = initialTerm
        isAddWordPresented = true
    }

    func dismissAddWord() {
        isAddWordPresented = false
        addWordInitialTerm = nil
    }

    func requestImportExport(
        mode: MacImportExportSheet.Mode = .importWords,
        initialText: String? = nil
    ) {
        importExportInitialMode = mode
        importExportInitialText = initialText
        isImportExportPresented = true
    }

    func dismissImportExport() {
        isImportExportPresented = false
        importExportInitialText = nil
    }

    func consumeSettingsRequest() {
        isSettingsRequested = false
    }

    func dismissRouteError() {
        routeError = nil
    }
}
