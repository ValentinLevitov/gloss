import XCTest
@testable import Translator

final class HeuristicsTests: XCTestCase {
    func testSharedTextStripsBooksExcerptTrailer() {
        let raw = "“It was the best of times.”\n\nExcerpt From\nA Tale of Two Cities\nCharles Dickens\nThis material may be protected by copyright."
        XCTAssertEqual(SharedText.clean(raw), "It was the best of times.")
        XCTAssertEqual(SharedText.clean("  plain  "), "plain")
    }

    func testDictationRestartDetection() {
        XCTAssertTrue(SpeechRecorder.continues(previous: "однажды в студёную", next: "однажды в студёную зимнюю пору"))
        XCTAssertTrue(SpeechRecorder.continues(previous: "однажды в студёную", next: "Однажды в студеную зимнюю"))
        XCTAssertFalse(SpeechRecorder.continues(previous: "однажды в студёную зимнюю пору", next: "я из лесу"))
    }

    func testTargetLanguageFollowsDetectedLanguage() {
        let pair = LanguageSettings(native: Language(code: "ru"), foreign: Language(code: "en"))
        XCTAssertEqual(Prompt.targetLanguage(for: "The quick brown fox jumps over the lazy dog", pair: pair)?.code, "ru")
        XCTAssertEqual(Prompt.targetLanguage(for: "Однажды в студёную зимнюю пору я из лесу вышел", pair: pair)?.code, "en")
    }

    func testTextSizeMapping() {
        XCTAssertNil(TextSize.system.dynamicTypeSize)
        XCTAssertEqual(TextSize.xxLarge.dynamicTypeSize, .accessibility2)
    }
}
