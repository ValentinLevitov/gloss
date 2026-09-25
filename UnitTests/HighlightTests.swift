import XCTest
@testable import Translator

final class HighlightTests: XCTestCase {
    private func matches(_ phrase: String, in text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: SelectableText.phrasePattern(phrase), options: .caseInsensitive)
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }

    func testWholePhraseOnly() {
        XCTAssertEqual(matches("once in a blue moon", in: "It happens once in a blue moon, not once a week."), ["once in a blue moon"])
        XCTAssertTrue(matches("blue moon", in: "bluemoon").isEmpty)
    }

    func testSlotAllowsObjectInTheMiddle() {
        XCTAssertEqual(matches("pick something up", in: "Could you pick the kids up at five?"), ["pick the kids up"])
        XCTAssertEqual(matches("give someone the cold shoulder", in: "She gave him the cold shoulder."), [])   // form "gave" is a separate entry
        XCTAssertEqual(matches("give someone the cold shoulder", in: "They give Tom the cold shoulder."), ["give Tom the cold shoulder"])
    }

    func testTwoWordPhrasalVerbSplits() {
        XCTAssertEqual(matches("pick up", in: "Pick it up. Then pick up the rest."), ["Pick it up", "pick up"])
        XCTAssertTrue(matches("pick up", in: "pick a very long list of things up").isEmpty, "gap is capped at three words")
    }
}
