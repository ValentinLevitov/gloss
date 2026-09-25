import XCTest
@testable import Translator

@MainActor
final class CardTests: XCTestCase {
    private var store: CardStore!

    override func setUp() {
        super.setUp()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cards-\(UUID().uuidString).json")
        store = CardStore(fileURL: url)
    }

    private func card(_ headword: String, forms: [String] = []) -> FlashCard {
        FlashCard(headword: headword, language: "en", partOfSpeech: "noun", transcription: "", translations: ["x"],
                  forms: forms.map { FlashCard.Form(label: "f", value: $0) }, examples: [], note: "",
                  sourceWord: headword)
    }

    func testParseHandlesFencedJSONAndLemma() throws {
        let reply = """
        ```json
        {"headword":"coin","language":"en","partOfSpeech":"verb","transcription":"/kɔɪn/",
         "translations":["придумать"],"forms":[{"label":"past","value":"coined"}],
         "examples":[{"text":"He coined a word.","translation":"Он придумал слово."}],"note":"","level":"b2"}
        ```
        """
        let card = try CardBuilder.parse(reply, sourceWord: "coined")
        XCTAssertEqual(card.headword, "coin")
        XCTAssertEqual(card.level, "B2")
        XCTAssertEqual(card.forms.first?.value, "coined")
        XCTAssertTrue(card.allForms.contains("coined"))
        XCTAssertTrue(card.allForms.contains("coin"))
    }

    func testParseRejectsGarbage() {
        XCTAssertThrowsError(try CardBuilder.parse("Sorry, I cannot help.", sourceWord: "x"))
        XCTAssertThrowsError(try CardBuilder.parse(#"{"headword":""}"#, sourceWord: "x"))
    }

    func testAddReplacesSameHeadwordAndIndexesForms() {
        store.add(card("go", forms: ["went", "gone"]))
        store.add(card("go", forms: ["went"]))
        XCTAssertEqual(store.cards.count, 1)
        XCTAssertNotNil(store.card(for: "WENT"))
        XCTAssertNil(store.card(for: "gone"), "re-adding replaces the old card and its forms")
    }

    func testGraduationAfterConsecutiveRemembers() {
        store.add(card("purse"))
        let c = store.cards[0]
        for _ in 0..<(FlashCard.graduationStreak - 1) { XCTAssertFalse(store.record(c, known: true)) }
        XCTAssertFalse(store.record(c, known: false), "a miss resets the streak")
        for _ in 0..<(FlashCard.graduationStreak - 1) { XCTAssertFalse(store.record(c, known: true)) }
        XCTAssertTrue(store.record(c, known: true))
        XCTAssertTrue(store.cards[0].isLearned)
        XCTAssertNil(store.nextToStudy(excluding: []), "learned cards leave the study pool")
    }

    func testStudyPickerNeverStarvesACard() {
        for word in ["a", "b", "c", "d"] { store.add(card(word)) }
        var seen: Set<String> = []
        var recent: [UUID] = []
        for _ in 0..<40 {
            let next = store.nextToStudy(excluding: recent)!
            seen.insert(next.headword)
            store.record(next, known: next.headword != "d")   // "d" is always forgotten, others remembered
            recent = Array((recent + [next.id]).suffix(2))
        }
        XCTAssertEqual(seen, ["a", "b", "c", "d"])
    }

    func testPersistsAcrossReload() {
        store.add(card("shore"))
        store.reload()
        XCTAssertEqual(store.cards.first?.headword, "shore")
    }
}
