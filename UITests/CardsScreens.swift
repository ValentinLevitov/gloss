import XCTest

/// Opens study mode from the main-screen banner so screenshots can be taken from outside.
final class CardsScreens: XCTestCase {
    func testStudyFromBanner() {
        let app = XCUIApplication()
        app.launchEnvironment["GLOSS_SEED_ANTHROPIC_KEY"] = "placeholder"
        app.launch()
        sleep(5)
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'words to learn'")).firstMatch.tap()
        sleep(5)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).tap()
        sleep(5)
    }
}
