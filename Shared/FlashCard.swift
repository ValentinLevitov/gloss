import Foundation
import Observation

struct FlashCard: Identifiable, Codable, Hashable {
    struct Form: Codable, Hashable {
        let label: String
        let value: String
    }

    struct Example: Codable, Hashable {
        let text: String
        let translation: String
    }

    var id = UUID()
    /// Dictionary form: singular noun, infinitive verb, etc.
    let headword: String
    let language: String
    let partOfSpeech: String
    let transcription: String
    let translations: [String]
    let forms: [Form]
    let examples: [Example]
    let note: String
    /// CEFR level of the word (A1…C2), empty when unknown.
    var level: String = ""
    /// The text the card was made from, as it appeared.
    let sourceWord: String
    var addedAt = Date()
    var learnedAt: Date?
    /// Consecutive "I remember" swipes in study mode; reset by "forgot".
    var knowStreak = 0
    var reviews = 0
    var lastShownAt: Date?

    var isLearned: Bool { learnedAt != nil }

    /// How many "remember" swipes in a row graduate a card.
    static let graduationStreak = 4

    /// Cards remembered often come up less often.
    var studyWeight: Double { 1.0 / Double(1 + knowStreak) }

    enum CodingKeys: String, CodingKey {
        case id, headword, language, partOfSpeech, transcription, translations, forms, examples, note, level, sourceWord
        case addedAt, learnedAt, knowStreak, reviews, lastShownAt
    }

    init(headword: String, language: String, partOfSpeech: String, transcription: String, translations: [String],
         forms: [Form], examples: [Example], note: String, sourceWord: String) {
        self.headword = headword
        self.language = language
        self.partOfSpeech = partOfSpeech
        self.transcription = transcription
        self.translations = translations
        self.forms = forms
        self.examples = examples
        self.note = note
        self.sourceWord = sourceWord
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        headword = try c.decode(String.self, forKey: .headword)
        language = try c.decode(String.self, forKey: .language)
        partOfSpeech = try c.decode(String.self, forKey: .partOfSpeech)
        transcription = try c.decode(String.self, forKey: .transcription)
        translations = try c.decode([String].self, forKey: .translations)
        forms = try c.decode([Form].self, forKey: .forms)
        examples = try c.decode([Example].self, forKey: .examples)
        note = try c.decode(String.self, forKey: .note)
        level = try c.decodeIfPresent(String.self, forKey: .level) ?? ""
        sourceWord = try c.decode(String.self, forKey: .sourceWord)
        addedAt = try c.decode(Date.self, forKey: .addedAt)
        learnedAt = try c.decodeIfPresent(Date.self, forKey: .learnedAt)
        knowStreak = try c.decodeIfPresent(Int.self, forKey: .knowStreak) ?? 0
        reviews = try c.decodeIfPresent(Int.self, forKey: .reviews) ?? 0
        lastShownAt = try c.decodeIfPresent(Date.self, forKey: .lastShownAt)
    }

    /// Every spelling that should light up in a text.
    var allForms: Set<String> {
        var set: Set<String> = [headword.lowercased(), sourceWord.lowercased()]
        for form in forms { set.insert(form.value.lowercased()) }
        return set
    }
}

/// Cards live in a JSON file in the App Group so the app and the extensions share them.
@MainActor
@Observable
final class CardStore {
    static let shared = CardStore()

    private(set) var cards: [FlashCard] = []
    /// Bumped on every change so text views know to re-highlight.
    private(set) var version = 0

    /// form (lowercased) → card
    private(set) var index: [String: FlashCard] = [:]

    private let fileURL: URL

    private static var defaultFileURL: URL {
        let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("cards.json")
    }

    private convenience init() { self.init(fileURL: Self.defaultFileURL) }

    /// Tests pass a temporary file.
    init(fileURL: URL) {
        self.fileURL = fileURL
        reload()
    }

    func reload() {
        let loaded = (try? Data(contentsOf: fileURL)).flatMap { try? JSONDecoder().decode([FlashCard].self, from: $0) } ?? []
        cards = loaded.sorted { $0.addedAt > $1.addedAt }
        rebuildIndex()
    }

    func card(for word: String) -> FlashCard? {
        index[word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }

    func add(_ card: FlashCard) {
        cards.removeAll { $0.headword.lowercased() == card.headword.lowercased() && $0.language == card.language }
        cards.insert(card, at: 0)
        save()
    }

    func setLearned(_ card: FlashCard, _ learned: Bool) {
        guard let i = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[i].learnedAt = learned ? Date() : nil
        if !learned { cards[i].knowStreak = 0 }
        save()
    }

    /// Records a study swipe; graduates the card after enough consecutive "remember" swipes.
    /// Returns true when the card just became learned.
    @discardableResult
    func record(_ card: FlashCard, known: Bool) -> Bool {
        guard let i = cards.firstIndex(where: { $0.id == card.id }) else { return false }
        cards[i].reviews += 1
        cards[i].knowStreak = known ? cards[i].knowStreak + 1 : 0
        let graduated = known && cards[i].knowStreak >= FlashCard.graduationStreak
        if graduated { cards[i].learnedAt = Date() }
        save()
        return graduated
    }

    /// Weighted random pick among cards still being learned. Recently shown cards are skipped and a card
    /// that has waited longer than three rounds is forced, so no word starves.
    func nextToStudy(excluding recent: [UUID]) -> FlashCard? {
        var pool = cards.filter { !$0.isLearned }
        guard !pool.isEmpty else { return nil }
        let roundLength = pool.count
        if pool.count > recent.count { pool.removeAll { recent.contains($0.id) } }

        let overdue = pool.filter { card in
            let shown = pool.filter { ($0.lastShownAt ?? .distantPast) > (card.lastShownAt ?? .distantPast) }.count
            return card.lastShownAt == nil ? cards.count > 1 && pool.count > 2 : shown >= 3 * roundLength
        }
        if let never = pool.first(where: { $0.lastShownAt == nil }) { return mark(never) }
        if let starving = overdue.first { return mark(starving) }

        let total = pool.reduce(0) { $0 + $1.studyWeight }
        var roll = Double.random(in: 0..<max(total, 0.0001))
        for card in pool {
            roll -= card.studyWeight
            if roll < 0 { return mark(card) }
        }
        return mark(pool.last!)
    }

    private func mark(_ card: FlashCard) -> FlashCard {
        guard let i = cards.firstIndex(where: { $0.id == card.id }) else { return card }
        cards[i].lastShownAt = Date()
        return cards[i]
    }

    func delete(_ card: FlashCard) {
        cards.removeAll { $0.id == card.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(cards) {
            try? data.write(to: fileURL, options: .atomic)
        }
        rebuildIndex()
    }

    private func rebuildIndex() {
        var map: [String: FlashCard] = [:]
        for card in cards.reversed() {
            for form in card.allForms where !form.isEmpty { map[form] = card }
        }
        index = map
        version += 1
    }
}
