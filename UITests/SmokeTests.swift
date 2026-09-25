import XCTest

/// Runs in CI on a simulator without any API key: the app must launch and land on the Setup screen.
final class SmokeTests: XCTestCase {
    func testFreshInstallShowsSetup() {
        let app = XCUIApplication()
        app.launchEnvironment["GLOSS_RESET"] = "1"
        app.launch()
        XCTAssertTrue(app.navigationBars["Setup"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["1 · API key"].exists)
    }
}
