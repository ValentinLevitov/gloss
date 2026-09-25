import XCTest

/// End-to-end demo for App Review: recorded on a physical device via the test plan's screen recording.
final class DemoFlow: XCTestCase {
    func testDemo() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(3)

        // 0. Start from an empty thread.
        let newThread = app.buttons["square.and.pencil"].firstMatch
        if newThread.exists, newThread.isEnabled { newThread.tap(); sleep(2) }

        // 1. Translate a paragraph.
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("It was the best of times, it was the worst of times, it was the age of wisdom, it was the age of foolishness.")
        sleep(1)
        app.buttons["arrow.up.circle.fill"].firstMatch.tap()
        sleep(14)

        // 2. Explain a selected word in the translation, then add it to cards.
        let translation = app.textViews.element(boundBy: 1)
        if translation.waitForExistence(timeout: 5) {
            translation.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).press(forDuration: 1.0)
            sleep(2)
            if app.menuItems["Explain"].waitForExistence(timeout: 3) { app.menuItems["Explain"].tap() }
            sleep(14)
            let original = app.textViews.element(boundBy: 0)
            original.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.3)).press(forDuration: 1.0)
            sleep(2)
            if app.menuItems["Add to cards"].waitForExistence(timeout: 3) { app.menuItems["Add to cards"].tap() }
            sleep(12)
        }

        // 3. Cards and study mode.
        app.buttons["rectangle.stack"].firstMatch.tap()
        sleep(4)
        if app.buttons["Study"].firstMatch.waitForExistence(timeout: 3) {
            app.buttons["Study"].firstMatch.tap()
            sleep(3)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()   // flip
            sleep(3)
            app.buttons["Remember"].firstMatch.tap()
            sleep(3)
            app.buttons["Forgot"].firstMatch.tap()
            sleep(3)
            app.buttons["Close"].firstMatch.tap()
            sleep(2)
        }
        app.buttons["Close"].firstMatch.tap()
        sleep(2)

        // 4. Show where Gloss is set as the system translation app.
        SettingsStep.run()

        // 5. System Translate sheet from Apple Books (the book must be open on a page).
        BooksStep.run()
    }
}

/// Settings > Apps > Default Apps > Translation, showing Gloss selected.
enum SettingsStep {
    static func run() {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        sleep(2)
        for label in ["Apps", "Default Apps", "Translation"] {
            let row = settings.staticTexts[label].firstMatch
            for _ in 0..<8 where !(row.exists && row.isHittable) { settings.swipeUp() }
            if row.waitForExistence(timeout: 5) { row.tap() }
            sleep(2)
        }
        sleep(3)
    }
}

/// Opens the book and leaves 45 seconds for the phrase to be selected and translated by hand.
enum BooksStep {
    static func run() {
        let books = XCUIApplication(bundleIdentifier: "com.apple.iBooks")
        books.activate()
        sleep(45)
    }
}

/// Books step alone: the phrase is already selected by hand; find Translate in the selection menu.
final class BooksOnly: XCTestCase {
    func testBooks() {
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
        // Keep the recorder busy while the translation streams in.
        for _ in 0..<6 { sleep(5); _ = books.exists }
    }
}

/// Not recorded: leaves the app on an empty thread so the demo starts clean.
final class DemoPrep: XCTestCase {
    func testStartNewThread() {
        let app = XCUIApplication()
        app.launch()
        sleep(2)
        let newThread = app.buttons["square.and.pencil"].firstMatch
        if newThread.exists, newThread.isEnabled { newThread.tap(); sleep(1) }
    }
}
