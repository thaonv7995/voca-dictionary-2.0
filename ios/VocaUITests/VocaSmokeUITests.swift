import XCTest

/// End-to-end smoke test: logs in against a live server and walks every tab, capturing a screenshot
/// of each. Base URL + credentials come from the test process environment (see the xcodebuild call),
/// falling back to the dev defaults.
final class VocaSmokeUITests: XCTestCase {

    private var baseURL: String { env("VOCA_BASE_URL", "https://voca.thaonv.online") }
    private var email: String { env("VOCA_TEST_EMAIL", "iostest-1787480229@voca.local") }
    private var password: String { env("VOCA_TEST_PASSWORD", "Test1234!") }

    private func env(_ key: String, _ fallback: String) -> String {
        let v = ProcessInfo.processInfo.environment[key]
        return (v?.isEmpty == false) ? v! : fallback
    }

    func testLoginAndWalkTabs() throws {
        let app = XCUIApplication()
        app.launchEnvironment["VOCA_BASE_URL"] = baseURL
        app.launch()

        // --- Login screen ---
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 15), "Login screen (Email field) did not appear")
        snapshot(app, "00-login")

        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["Mật khẩu"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText(password)

        app.buttons["Đăng nhập"].tap()

        // --- Signed in: the tab bar appears ---
        let dictionaryTab = app.tabBars.buttons["Kho từ"]
        XCTAssertTrue(dictionaryTab.waitForExistence(timeout: 25), "Did not reach the signed-in tab bar (login failed?)")

        // Default tab is now "Hôm nay" — give the network a moment to load stats/cards.
        Thread.sleep(forTimeInterval: 3)
        snapshot(app, "01-today")

        tapTabAndSnapshot(app, tab: "Kho từ", name: "02-dictionary")
        tapTabAndSnapshot(app, tab: "Học", name: "03-study")
        // Enter the swipe-flashcard deck if there are due cards.
        let startReview = app.buttons["Bắt đầu ôn tập"]
        if startReview.waitForExistence(timeout: 5), startReview.isEnabled {
            startReview.tap()
            Thread.sleep(forTimeInterval: 2)
            snapshot(app, "03b-study-deck")
            let close = app.buttons["Đóng"].firstMatch
            if close.waitForExistence(timeout: 3) { close.tap(); Thread.sleep(forTimeInterval: 1) }
        }
        tapTabAndSnapshot(app, tab: "Trợ lý", name: "04-assistant")
        tapTabAndSnapshot(app, tab: "Hồ sơ", name: "05-profile")
    }

    /// Full AI-mode walkthrough against a LOCAL backend + mock LLM. Skipped unless VOCA_E2E=1.
    /// Generates real streamed content in every Assistant mode and captures screenshots so
    /// rendering/width issues are visible. Run with:
    ///   TEST_RUNNER_VOCA_E2E=1 TEST_RUNNER_VOCA_BASE_URL=http://localhost:22052 \
    ///   TEST_RUNNER_VOCA_TEST_EMAIL=e2e@voca.local TEST_RUNNER_VOCA_TEST_PASSWORD='E2e12345!' \
    ///   xcodebuild test … -only-testing:VocaUITests/VocaSmokeUITests/testAIModesE2E
    func testAIModesE2E() throws {
        try XCTSkipUnless(env("VOCA_E2E", "") == "1", "E2E AI walk only runs when VOCA_E2E=1")

        let app = XCUIApplication()
        app.launchEnvironment["VOCA_BASE_URL"] = baseURL
        app.launch()

        // Login (fresh install state) or already signed in.
        let emailField = app.textFields["Email"]
        if emailField.waitForExistence(timeout: 8) {
            emailField.tap(); emailField.typeText(email)
            let pass = app.secureTextFields["Mật khẩu"]
            XCTAssertTrue(pass.waitForExistence(timeout: 5)); pass.tap(); pass.typeText(password)
            app.buttons["Đăng nhập"].tap()
        }
        XCTAssertTrue(app.tabBars.buttons["Trợ lý"].waitForExistence(timeout: 25))
        app.tabBars.buttons["Trợ lý"].tap()
        Thread.sleep(forTimeInterval: 1)

        // 1. Chat
        sendChatMessage(app, "So sánh diligent và hard-working giúp tôi")
        Thread.sleep(forTimeInterval: 6)
        snapshot(app, "e2e-01-chat")

        // 2. Drills
        selectMode(app, "Trắc nghiệm")
        tapIfExists(app.buttons["Tạo 5 câu hỏi"], in: app)
        Thread.sleep(forTimeInterval: 6)
        snapshot(app, "e2e-02-drills")
        // Answer the first drill (any visible choice button with a letter prefix).
        let choice = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'A.'")).firstMatch
        if choice.waitForExistence(timeout: 3), choice.isHittable {
            choice.tap()
            Thread.sleep(forTimeInterval: 1.5)
            snapshot(app, "e2e-03-drill-answered")
        }

        // 3. Reading
        selectMode(app, "Đọc hiểu")
        tapIfExists(app.buttons["Tạo bài đọc"], in: app)
        Thread.sleep(forTimeInterval: 6)
        snapshot(app, "e2e-04-reading")

        // 4. Article
        selectMode(app, "Bài báo")
        tapIfExists(app.buttons["Tạo bài báo"], in: app)
        Thread.sleep(forTimeInterval: 6)
        snapshot(app, "e2e-05-article")

        // 5. Conversation
        selectMode(app, "Hội thoại")
        tapIfExists(app.buttons["Tạo hội thoại"], in: app)
        Thread.sleep(forTimeInterval: 7)
        snapshot(app, "e2e-06-conversation")
    }

    /// Types into the chat composer (a multiline field — may surface as textField or textView).
    private func sendChatMessage(_ app: XCUIApplication, _ message: String) {
        let byPlaceholder = NSPredicate(format: "placeholderValue == %@", "Nhập tin nhắn…")
        let field = app.textFields.matching(byPlaceholder).firstMatch
        let view = app.textViews.matching(byPlaceholder).firstMatch
        let target = field.waitForExistence(timeout: 4) ? field
                   : (view.waitForExistence(timeout: 2) ? view : app.textViews.firstMatch)
        guard target.exists else { return }
        target.tap()
        target.typeText(message)
        let send = app.buttons["Gửi"]
        if send.waitForExistence(timeout: 3) { send.tap() }
    }

    /// Taps a mode pill, horizontally dragging the pill row if the pill is off-screen.
    /// NOTE: never query `isHittable` on an off-screen SwiftUI button — it throws
    /// ("Activation point invalid"). Use frame containment instead.
    private func selectMode(_ app: XCUIApplication, _ name: String) {
        let pill = app.buttons[name]
        guard pill.waitForExistence(timeout: 5) else { return }
        let window = app.windows.firstMatch.frame

        // Vertical position of the pill row (normalized), taken from an always-present pill.
        let rowAnchor = app.buttons["Trò chuyện"].exists ? app.buttons["Trò chuyện"] : pill
        let yNorm = max(0.02, min(0.98, rowAnchor.frame.midY / max(window.height, 1)))

        var attempts = 0
        while attempts < 4, !window.insetBy(dx: 10, dy: 0).contains(
            CGPoint(x: pill.frame.midX, y: pill.frame.midY)) {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: yNorm))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: yNorm))
            start.press(forDuration: 0.05, thenDragTo: end)
            Thread.sleep(forTimeInterval: 0.6)
            attempts += 1
        }
        pill.tap()
        Thread.sleep(forTimeInterval: 1)
    }

    private func tapIfExists(_ element: XCUIElement, in app: XCUIApplication) {
        if element.waitForExistence(timeout: 5), element.isHittable { element.tap() }
    }

    private func tapTabAndSnapshot(_ app: XCUIApplication, tab: String, name: String) {
        let button = app.tabBars.buttons[tab]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Tab '\(tab)' not found")
        button.tap()
        Thread.sleep(forTimeInterval: 2)
        snapshot(app, name)
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
