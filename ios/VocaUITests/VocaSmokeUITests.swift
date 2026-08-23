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
        // Send a long message to inspect the AI response bubble width/wrapping.
        let msgField = app.textFields["Nhập tin nhắn…"]
        if msgField.waitForExistence(timeout: 5) {
            msgField.tap()
            msgField.typeText("Giải thích chi tiết sự khác nhau giữa các từ đồng nghĩa và cho nhiều ví dụ thật dài để kiểm tra chiều rộng của bong bóng trả lời trên màn hình.")
            let send = app.buttons["Gửi"]
            if send.waitForExistence(timeout: 3) { send.tap() }
            Thread.sleep(forTimeInterval: 5)
            snapshot(app, "04b-ai-response")
        }

        tapTabAndSnapshot(app, tab: "Hồ sơ", name: "05-profile")
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
