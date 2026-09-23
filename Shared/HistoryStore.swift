import Foundation

struct HistoryEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    let source: String
    let translation: String
    let date: Date
}

/// History as a JSON file in the App Group container, shared by the app and the extensions.
enum HistoryStore {
    private static let limit = 300

    private static var fileURL: URL {
        let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("history.json")
    }

    static func load() -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([HistoryEntry].self, from: data)) ?? []
    }

    static func save(_ entries: [HistoryEntry]) {
        guard let data = try? JSONEncoder().encode(Array(entries.prefix(limit))) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func add(source: String, translation: String) {
        var entries = load()
        entries.removeAll { $0.source == source }
        entries.insert(HistoryEntry(source: source, translation: translation, date: Date()), at: 0)
        save(entries)
    }
}
