import XCTest

/// Drives the simulator for App Store screenshots: sets Gloss as the default translation app,
/// selects text in Safari and opens the system Translate sheet.
final class ScreenshotFlow: XCTestCase {
    private func tapRow(_ label: String, in app: XCUIApplication) {
        let row = app.staticTexts[label].firstMatch
        for _ in 0..<8 where !(row.exists && row.isHittable) { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "row \(label) not found")
        row.tap()
        sleep(1)
    }

    func testSetDefaultTranslationApp() {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        sleep(2)
        tapRow("Apps", in: settings)
        tapRow("Default Apps", in: settings)
        tapRow("Translation", in: settings)
        tapRow("Gloss", in: settings)
        sleep(1)
    }

    func testTranslateInSafari() {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.activate()
        sleep(3)
        let word = safari.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'coined by'")).firstMatch
        if word.waitForExistence(timeout: 10) {
            // Press near the start of the paragraph so a single word gets selected.
            word.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.25)).press(forDuration: 1.2)
        } else {
            safari.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.36)).press(forDuration: 1.2)
        }
        sleep(1)
        sleep(1)
        // The edit menu lives outside the Safari accessibility tree; its layout is stable for this page.
        safari.coordinate(withNormalizedOffset: CGVector(dx: 0.44, dy: 0.568)).tap()
        sleep(25)
    }
}
