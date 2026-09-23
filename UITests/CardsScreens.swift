import XCTest

/// Opens the Cards list and Study mode in the app so screenshots can be taken from outside.
final class CardsScreens: XCTestCase {
    func testCardsAndStudy() {
        let app = XCUIApplication()
        app.launch()
        sleep(4)
        app.buttons["rectangle.stack"].firstMatch.tap()
        sleep(9)
        app.buttons["Study"].firstMatch.tap()
        sleep(9)
    }
}
