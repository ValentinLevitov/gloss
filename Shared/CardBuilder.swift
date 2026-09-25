import Foundation

/// Asks the model for a dictionary card and parses its JSON reply.
enum CardBuilder {
    enum BuildError: LocalizedError {
        case badReply

        var errorDescription: String? { String(localized: "Couldn't build a card from the model's reply.") }
    }

    static func build(word: String, context: String, model: ModelOption) async throws -> FlashCard {
        let languages = LanguageSettings.current
        let prompt = """
        You are a lexicographer. Make a flashcard for the word or short phrase marked below, as it is used in the context.

        WORD: \(word)
        CONTEXT: \(context.prefix(600))

        Rules:
        - "headword" is the dictionary form: singular for nouns, infinitive for verbs (without "to"), base form for adjectives. Keep multi-word phrases as phrases.
        - For separable phrasal verbs and idioms with an object slot, write the slot as "someone" or "something" in the headword and forms: "pick something up", "give someone the cold shoulder", "take something for granted".
        - "language" is the ISO 639-1 code of the word's language.
        - Write "translations", "note" and example translations in \(languages.native.englishName); \
        if the word itself is in \(languages.native.englishName), translate into \(languages.foreign.englishName).
        - "transcription" is IPA of the headword; empty string if not applicable.
        - "forms": for verbs give all principal forms (e.g. base, 3rd person, past, past participle, present participle, or the equivalents in the word's language); \
        for nouns the plural; for adjectives comparative/superlative when irregular. Each item has a short "label" and the "value". Empty array if nothing useful.
        - "examples": 2 short sentences using the headword, each with a translation. Reuse the context if it is a good example.
        - "note": one line on nuance (register, false friend, idiom) or empty string.
        - "level": CEFR level at which learners typically meet this word: A1, A2, B1, B2, C1 or C2.

        Reply with ONLY a JSON object, no markdown, no prose:
        {"headword":"","language":"","partOfSpeech":"","transcription":"","translations":[""],"forms":[{"label":"","value":""}],"examples":[{"text":"","translation":""}],"note":"","level":""}
        """

        var reply = ""
        for try await chunk in Providers.make(for: model).stream([ChatMessage(role: "user", content: prompt)], model: model) {
            reply += chunk
        }
        return try parse(reply, sourceWord: word)
    }

    static func parse(_ reply: String, sourceWord: String) throws -> FlashCard {
        guard let start = reply.firstIndex(of: "{"), let end = reply.lastIndex(of: "}") else { throw BuildError.badReply }
        let json = Data(reply[start...end].utf8)
        guard let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let headword = object["headword"] as? String, !headword.isEmpty else { throw BuildError.badReply }

        let forms = (object["forms"] as? [[String: Any]] ?? []).compactMap { item -> FlashCard.Form? in
            guard let label = item["label"] as? String, let value = item["value"] as? String, !value.isEmpty else { return nil }
            return FlashCard.Form(label: label, value: value)
        }
        let examples = (object["examples"] as? [[String: Any]] ?? []).compactMap { item -> FlashCard.Example? in
            guard let text = item["text"] as? String, !text.isEmpty else { return nil }
            return FlashCard.Example(text: text, translation: item["translation"] as? String ?? "")
        }
        var card = FlashCard(
            headword: headword,
            language: (object["language"] as? String ?? "").lowercased(),
            partOfSpeech: object["partOfSpeech"] as? String ?? "",
            transcription: object["transcription"] as? String ?? "",
            translations: (object["translations"] as? [String] ?? []).filter { !$0.isEmpty },
            forms: forms,
            examples: examples,
            note: object["note"] as? String ?? "",
            sourceWord: sourceWord.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        card.level = (object["level"] as? String ?? "").uppercased().trimmingCharacters(in: .whitespaces)
        return card
    }
}
