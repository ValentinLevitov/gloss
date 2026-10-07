import XCTest

/// Opens study mode from the banner so the seeded phrase card can be captured.
final class CardsScreens: XCTestCase {
    func testStudyFromBanner() {
        let app = XCUIApplication()
        app.launchEnvironment["GLOSS_SEED_ANTHROPIC_KEY"] = "placeholder"
        app.launch()
        sleep(4)
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'words to learn'")).firstMatch.tap()
        sleep(6)
    }
}
