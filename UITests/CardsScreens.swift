import XCTest

/// Long-presses the app icon on the home screen to show the quick action.
final class CardsScreens: XCTestCase {
    func testQuickAction() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCUIDevice.shared.press(.home)
        sleep(2)
        let icon = springboard.icons["Gloss"].firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 5))
        icon.press(forDuration: 1.5)
        sleep(4)
        let item = springboard.buttons["Study words"].firstMatch
        if item.waitForExistence(timeout: 3) { item.tap() }
        sleep(5)
    }
}
