import Foundation

struct ThreadMessage: Identifiable, Codable, Hashable {
    enum Role: String, Codable { case user, assistant }
    enum Kind: String, Codable { case translation, question }

    var id = UUID()
    let role: Role
    /// For an assistant reply: what it replies to.
    let kind: Kind
    var text: String
    /// The selected fragment the question is about.
    var quote: String?
    var date = Date()

    static let defaultQuestion = "Explain this fragment: what it means, its nuances, and if it is an idiom, an allusion or a cultural reference, tell me about it."

    /// The message text as it is sent to the API.
    var apiContent: String {
        switch (role, kind) {
        case (.assistant, _):
            return text
        case (.user, .translation):
            return Prompt.user(text)
        case (.user, .question):
            let question = text.isEmpty ? Self.defaultQuestion : text
            guard let quote, !quote.isEmpty else { return question }
            return "Fragment: «\(quote)»\n\n\(question)"
        }
    }
}

struct ChatMessage {
    let role: String
    let content: String
}

/// The current thread in the App Group container; both the app and the extensions continue it.
enum ConversationStore {
    /// After this much idle time the next translation starts a new thread.
    static let idleLimit: TimeInterval = 60 * 60
    /// Max characters of history sent per request (older exchanges are dropped whole).
    static let contextBudget = 30_000

    private struct Snapshot: Codable {
        let messages: [ThreadMessage]
        let updatedAt: Date
    }

    private static var fileURL: URL {
        let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("thread.json")
    }

    static func loadCurrent() -> [ThreadMessage] {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              Date().timeIntervalSince(snapshot.updatedAt) < idleLimit else { return [] }
        return snapshot.messages
    }

    static func save(_ messages: [ThreadMessage]) {
        let snapshot = Snapshot(messages: messages, updatedAt: Date())
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// History for the API: the latest exchanges within budget, always starting with a user message.
    static func payload(from messages: [ThreadMessage]) -> [ChatMessage] {
        var kept: [ThreadMessage] = []
        var used = 0
        for message in messages.reversed() where !message.apiContent.isEmpty {
            used += message.apiContent.count
            if used > contextBudget, !kept.isEmpty { break }
            kept.insert(message, at: 0)
        }
        while let first = kept.first, first.role != .user { kept.removeFirst() }
        return kept.map { ChatMessage(role: $0.role.rawValue, content: $0.apiContent) }
    }
}
