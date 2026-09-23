import SwiftUI

/// All flashcards: the ones being learned first, then the learned ones.
struct CardsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var showStudy = false
    private var store: CardStore { CardStore.shared }

    private func filtered(_ learned: Bool) -> [FlashCard] {
        store.cards.filter { $0.isLearned == learned }.filter {
            query.isEmpty || $0.headword.localizedCaseInsensitiveContains(query)
                || $0.translations.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                section("Learning", cards: filtered(false))
                section("Learned", cards: filtered(true))
            }
            .overlay {
                if store.cards.isEmpty {
                    ContentUnavailableView("No cards yet", systemImage: "rectangle.stack",
                                           description: Text("Select a word in any translation and choose “Add to cards”."))
                }
            }
            .searchable(text: $query)
            .navigationTitle("Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showStudy = true } label: { Label("Study", systemImage: "play.fill") }
                        .disabled(!store.cards.contains { !$0.isLearned })
                }
            }
            .fullScreenCover(isPresented: $showStudy) { StudyView() }
        }
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, cards: [FlashCard]) -> some View {
        if !cards.isEmpty {
            Section {
                ForEach(cards) { card in
                    NavigationLink { CardDetailView(cardID: card.id) } label: { CardRow(card: card) }
                        .swipeActions(edge: .leading) {
                            Button {
                                store.setLearned(card, !card.isLearned)
                            } label: {
                                Label(card.isLearned ? "Learning" : "Learned",
                                      systemImage: card.isLearned ? "arrow.uturn.backward" : "checkmark")
                            }
                            .tint(card.isLearned ? .orange : .green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { store.delete(card) } label: { Label("Delete", systemImage: "trash") }
                        }
                }
            } header: {
                Text(title) + Text(" · \(cards.count)")
            }
        }
    }
}

private struct CardRow: View {
    let card: FlashCard

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(card.isLearned ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(card.headword).font(.body.weight(.semibold))
                    if !card.transcription.isEmpty {
                        Text(card.transcription).font(.footnote).foregroundStyle(.secondary)
                    }
                    if !card.level.isEmpty { LevelBadge(level: card.level) }
                }
                Text(card.translations.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct CardDetailView: View {
    let cardID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    private var store: CardStore { CardStore.shared }

    var body: some View {
        if let card = store.cards.first(where: { $0.id == cardID }) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(card.headword).font(.title.weight(.bold))
                        HStack(spacing: 8) {
                            if !card.transcription.isEmpty { Text(card.transcription) }
                            if !card.partOfSpeech.isEmpty {
                                Text(card.partOfSpeech).italic()
                            }
                            if !card.level.isEmpty { LevelBadge(level: card.level) }
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        Text(card.translations.joined(separator: ", "))
                            .font(.title3)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }

                if !card.forms.isEmpty {
                    Section("Forms") {
                        ForEach(card.forms, id: \.self) { form in
                            LabeledContent(form.label, value: form.value)
                        }
                    }
                }

                if !card.examples.isEmpty {
                    Section("Examples") {
                        ForEach(card.examples, id: \.self) { example in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(example.text)
                                Text(example.translation).foregroundStyle(.secondary)
                            }
                            .font(.callout)
                        }
                    }
                }

                if !card.note.isEmpty {
                    Section("Note") { Text(card.note).font(.callout) }
                }

                Section {
                    Button {
                        store.setLearned(card, !card.isLearned)
                    } label: {
                        Label(card.isLearned ? "Mark as learning" : "Mark as learned",
                              systemImage: card.isLearned ? "arrow.uturn.backward" : "checkmark.circle")
                    }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Delete card", systemImage: "trash")
                    }
                } footer: {
                    if let learnedAt = card.learnedAt {
                        Text("Learned \(learnedAt.formatted(date: .abbreviated, time: .omitted)) · added \(card.addedAt.formatted(date: .abbreviated, time: .omitted))")
                    } else {
                        Text("Added \(card.addedAt.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
            }
            .navigationTitle(card.headword)
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Delete this card?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.delete(card)
                    dismiss()
                }
            }
        } else {
            ContentUnavailableView("Card deleted", systemImage: "rectangle.stack")
        }
    }
}

/// CEFR level chip: A1–A2 green, B1–B2 blue, C1–C2 purple.
struct LevelBadge: View {
    let level: String

    private var tint: Color {
        switch level.prefix(1) {
        case "A": return .green
        case "B": return .blue
        default: return .purple
        }
    }

    var body: some View {
        Text(level)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}
