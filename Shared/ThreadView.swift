import SwiftUI
import UIKit

/// The conversation feed: translations, questions and answers. Shared by the app and the extensions.
struct ThreadView: View {
    let session: ConversationSession
    /// Extensions show only what appeared after they opened; the rest of the thread is context for the model.
    var fromIndex = 0
    /// Called when a fragment is picked via "Discuss", so the host can focus the question field.
    var onDiscuss: () -> Void = {}

    private var visible: ArraySlice<ThreadMessage> {
        session.messages.dropFirst(min(fromIndex, session.messages.count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(visible) { message in
                row(for: message)
            }

            if let word = session.buildingCardFor {
                Label { Text("Building a card for “\(word)”…") } icon: { ProgressView().controlSize(.small) }
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let card = session.lastAddedCard {
                Label("Added to cards: \(card.headword)", systemImage: "checkmark.rectangle.stack")
                    .font(.callout)
                    .foregroundStyle(.green)
                    .task {
                        try? await Task.sleep(for: .seconds(4))
                        if session.lastAddedCard?.id == card.id { session.lastAddedCard = nil }
                    }
            }
            if let error = session.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func row(for message: ThreadMessage) -> some View {
        switch (message.role, message.kind) {
        case (.user, .translation):
            VStack(alignment: .leading, spacing: 10) {
                if message.id != visible.first?.id { Divider() }
                selectable(message.text, style: .callout, color: .secondaryLabel)
            }
        case (.user, .question):
            VStack(alignment: .leading, spacing: 6) {
                if let quote = message.quote, !quote.isEmpty {
                    QuoteLabel(text: quote)
                }
                Text(message.text.isEmpty ? String(localized: "Explain") : message.text)
                    .font(.callout)
            }
            .padding(10)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: .infinity, alignment: .trailing)
        case (.assistant, _):
            if message.text.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    selectable(message.text, style: .body, color: .label)
                    if !(session.isLoading && message.id == session.messages.last?.id) {
                        Button {
                            UIPasteboard.general.string = MarkdownText.plain(message.text)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.footnote)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func selectable(_ markdown: String, style: UIFont.TextStyle, color: UIColor) -> some View {
        SelectableText(markdown: markdown, textStyle: style, color: color,
                       onExplain: { session.ask("", quote: $0) },
                       onDiscuss: {
                           session.quote = $0
                           onDiscuss()
                       },
                       onAddCard: { session.addCard(word: $0, context: MarkdownText.plain(markdown)) },
                       cardsVersion: CardStore.shared.version)
    }
}

struct QuoteLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .padding(.leading, 8)
            .overlay(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.6)).frame(width: 2.5)
            }
    }
}
