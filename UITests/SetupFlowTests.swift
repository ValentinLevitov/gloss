import XCTest

/// Fresh install: paste a (fake) key into Setup and check that Next unlocks without pressing Return.
final class SetupFlowTests: XCTestCase {
    func testSetupNextUnlocksAfterPaste() {
        let app = XCUIApplication()
        app.launchEnvironment["GLOSS_RESET"] = "1"
        app.launch()
        let field = app.secureTextFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("sk-ant-fake-key-for-ui-test")
        sleep(4)   // auto-verify fires (fails offline/invalid), key is saved anyway
        XCTAssertTrue(app.buttons["Next"].firstMatch.isEnabled, "Next should unlock once a key is saved")
        sleep(2)
    }
}
