import Foundation

/// Languages the user can pick. Names come from the system locale so they follow the UI language.
struct Language: Identifiable, Hashable {
    let code: String
    var id: String { code }

    var name: String {
        Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code
    }

    /// The name as the model reads it, independent of the UI locale.
    var englishName: String {
        Locale(identifier: "en").localizedString(forLanguageCode: code)?.capitalized ?? code
    }

    static let all: [Language] = [
        "ru", "en", "de", "fr", "es", "it", "pt", "uk", "pl", "nl", "tr", "zh", "ja", "ko", "ar", "he", "hi",
    ].map(Language.init)

    static func byCode(_ code: String?) -> Language? {
        all.first { $0.code == code }
    }
}

/// The user's language pair, stored in the App Group so the app and the extensions agree.
struct LanguageSettings: Equatable {
    private static let nativeKey = "targetLanguage"
    private static let foreignKey = "otherLanguage"

    /// Translations land here; explanations are written in it.
    var native: Language
    /// Where text that is already in `native` goes.
    var foreign: Language

    static var current: LanguageSettings {
        let defaults = AppGroup.defaults
        return LanguageSettings(
            native: Language.byCode(defaults.string(forKey: nativeKey)) ?? Language(code: "ru"),
            foreign: Language.byCode(defaults.string(forKey: foreignKey)) ?? Language(code: "en")
        )
    }

    func save() {
        AppGroup.defaults.set(native.code, forKey: Self.nativeKey)
        AppGroup.defaults.set(foreign.code, forKey: Self.foreignKey)
    }

    /// Short label like "EN ↔ RU".
    var label: String {
        "\(foreign.code.uppercased()) ↔ \(native.code.uppercased())"
    }
}
