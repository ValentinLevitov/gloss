import XCTest

/// Walks the app on a device with real data and saves one screenshot attachment per screen.
final class StoreShots: XCTestCase {
    private func shot(_ name: String) {
        sleep(2)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Scrolls the thread a few pages up to find a passage with highlighted phrase cards.
    func testThreadPages() {
        let app = XCUIApplication()
        app.launch()
        sleep(3)
        for i in 1...6 {
            app.swipeDown()
            shot("thread-page-\(i)")
        }
    }

    /// Books step: the phrase is selected by hand beforehand; this taps Translate and shoots the sheet.
    func testBooksSheet() {
        let books = XCUIApplication(bundleIdentifier: "com.apple.iBooks")
        books.activate()
        sleep(3)
        func item(_ label: String) -> XCUIElement {
            let inBooks = books.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
            if inBooks.exists { return inBooks }
            return XCUIApplication(bundleIdentifier: "com.apple.springboard").descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", label)).firstMatch
        }
        var translate = item("Translate")
        if !translate.waitForExistence(timeout: 3) {
            let more = books.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'more' OR label == 'Forward'")).firstMatch
            if more.waitForExistence(timeout: 2) { more.tap(); sleep(1) }
            translate = item("Translate")
        }
        XCTAssertTrue(translate.waitForExistence(timeout: 3), "Translate not found")
        translate.tap()
        sleep(14)
        shot("8-sheet")
    }
}
