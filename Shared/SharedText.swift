import Foundation

enum SharedText {
    /// Books wraps the selection in quotes and appends "Excerpt From <book> <author> This material may be
    /// protected by copyright." — not something to translate.
    static func clean(_ raw: String) -> String {
        var text = raw
        for marker in ["\n\nExcerpt From"] {
            if let range = text.range(of: marker, options: .backwards) {
                text = String(text[..<range.lowerBound])
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.hasPrefix("“"), text.hasSuffix("”"), text.count > 1 {
                    text = String(text.dropFirst().dropLast())
                }
                break
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
