import XCTest
@testable import Translator

final class ConversationTests: XCTestCase {
    private func msg(_ role: ThreadMessage.Role, _ text: String, kind: ThreadMessage.Kind = .translation,
                     quote: String? = nil) -> ThreadMessage {
        ThreadMessage(role: role, kind: kind, text: text, quote: quote)
    }

    func testPayloadAlwaysStartsWithUserMessage() {
        let messages = [msg(.assistant, "orphan reply"), msg(.user, "hello"), msg(.assistant, "hi")]
        let payload = ConversationStore.payload(from: messages)
        XCTAssertEqual(payload.first?.role, "user")
        XCTAssertEqual(payload.count, 2)
    }

    func testPayloadDropsOldestExchangesBeyondBudget() {
        let big = String(repeating: "x", count: ConversationStore.contextBudget / 2)
        let messages = [msg(.user, big), msg(.assistant, big), msg(.user, big), msg(.assistant, "recent")]
        let payload = ConversationStore.payload(from: messages)
        XCTAssertLessThanOrEqual(payload.count, 3)
        XCTAssertEqual(payload.last?.content, "recent")
        XCTAssertEqual(payload.first?.role, "user")
    }

    func testTranslationRequestIsWrappedInTextTags() {
        let content = msg(.user, "Call me Ishmael. Some years ago, having little or no money in my purse, I thought I would sail about a little.").apiContent
        XCTAssertTrue(content.hasPrefix("<text>\nCall me Ishmael. Some years ago"))
        XCTAssertTrue(content.contains("Translate into"), "explicit target language expected for a clear English text")
    }

    func testQuestionWithQuoteIsPrefixed() {
        let content = msg(.user, "why?", kind: .question, quote: "purse").apiContent
        XCTAssertEqual(content, "Fragment: «purse»\n\nwhy?")
    }

    func testEmptyQuestionFallsBackToExplain() {
        let content = msg(.user, "", kind: .question, quote: "purse").apiContent
        XCTAssertTrue(content.contains(ThreadMessage.defaultQuestion))
    }
}
