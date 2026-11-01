import XCTest
@testable import VocaMac

final class MacRouteParserTests: XCTestCase {
    private let parser = MacRouteParser()

    func testParsesPrimaryDestinations() throws {
        XCTAssertEqual(
            try parser.parse(try url("voca://today")),
            .destination(.today)
        )
        XCTAssertEqual(
            try parser.parse(try url("voca://vocabulary")),
            .destination(.vocabulary)
        )
        XCTAssertEqual(
            try parser.parse(try url("voca://review")),
            .destination(.review)
        )
        XCTAssertEqual(
            try parser.parse(try url("voca://practice")),
            .destination(.practice)
        )
        XCTAssertEqual(
            try parser.parse(try url("voca://assistant")),
            .destination(.assistant)
        )
        XCTAssertEqual(
            try parser.parse(try url("voca://insights")),
            .destination(.insights)
        )
    }

    func testParsesVocabularyWordRoute() throws {
        let route = try parser.parse(
            try url("voca://vocabulary/word/card_123-abc")
        )

        XCTAssertEqual(
            route,
            .vocabularyWord(id: "card_123-abc")
        )
    }

    func testRejectsInvalidVocabularyIdentifier() throws {
        XCTAssertThrowsError(
            try parser.parse(
                try url("voca://vocabulary/word/invalid%20identifier")
            )
        ) { error in
            XCTAssertEqual(
                error as? MacRouteError,
                .invalidIdentifier
            )
        }
    }

    func testParsesQuickLookupWithoutQuery() throws {
        XCTAssertEqual(
            try parser.parse(try url("voca://quick-lookup")),
            .quickLookup(query: nil)
        )
    }

    func testParsesQuickLookupQuery() throws {
        XCTAssertEqual(
            try parser.parse(
                try url("voca://quick-lookup?query=concise")
            ),
            .quickLookup(query: "concise")
        )
    }

    func testRejectsOversizedQuickLookupQuery() throws {
        let query = String(repeating: "a", count: 121)

        XCTAssertThrowsError(
            try parser.parse(
                try url("voca://quick-lookup?query=\(query)")
            )
        ) { error in
            XCTAssertEqual(
                error as? MacRouteError,
                .queryTooLong
            )
        }
    }

    func testRejectsUnsupportedScheme() throws {
        XCTAssertThrowsError(
            try parser.parse(try url("https://example.com"))
        ) { error in
            XCTAssertEqual(
                error as? MacRouteError,
                .unsupportedScheme
            )
        }
    }

    func testRejectsUnsupportedRoute() throws {
        XCTAssertThrowsError(
            try parser.parse(try url("voca://unknown"))
        ) { error in
            XCTAssertEqual(
                error as? MacRouteError,
                .unsupportedRoute
            )
        }
    }

    @MainActor
    func testRouterSelectsDestination() {
        let router = MacAppRouter()

        router.select(.review)

        XCTAssertEqual(router.selectedDestination, .review)
        XCTAssertNil(router.selectedVocabularyWordID)
    }

    @MainActor
    func testRouterOpensVocabularyWord() {
        let router = MacAppRouter()

        router.open(.vocabularyWord(id: "card-123"))

        XCTAssertEqual(router.selectedDestination, .vocabulary)
        XCTAssertEqual(router.selectedVocabularyWordID, "card-123")
    }

    @MainActor
    func testRouterPresentsQuickLookup() {
        let router = MacAppRouter()

        router.open(.quickLookup(query: "简洁"))

        XCTAssertTrue(router.isQuickLookupPresented)
        XCTAssertEqual(router.quickLookupQuery, "简洁")

        router.dismissQuickLookup()

        XCTAssertFalse(router.isQuickLookupPresented)
        XCTAssertNil(router.quickLookupQuery)
    }

    private func url(
        _ value: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> URL {
        try XCTUnwrap(URL(string: value), file: file, line: line)
    }
}
