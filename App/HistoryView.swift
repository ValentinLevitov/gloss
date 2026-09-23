import SwiftUI

struct HistoryView: View {
    let onSelect: (HistoryEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var entries = HistoryStore.load()
    @State private var query = ""

    private var filtered: [HistoryEntry] {
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.source.localizedCaseInsensitiveContains(query) || $0.translation.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { entry in
                    Button {
                        onSelect(entry)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.source)
                                .font(.body.weight(.medium))
                                .lineLimit(2)
                            Text(MarkdownText.plain(entry.translation))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .tint(.primary)
                }
                .onDelete { offsets in
                    let ids = offsets.map { filtered[$0].id }
                    entries.removeAll { ids.contains($0.id) }
                    HistoryStore.save(entries)
                }
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView("Nothing yet", systemImage: "clock",
                                           description: Text("Translations from the app and the system menu will show up here."))
                }
            }
            .searchable(text: $query)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
