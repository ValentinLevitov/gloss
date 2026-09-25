import SwiftUI

/// Compact "translate the selection + discuss" screen shared by the system Translate sheet and the share sheet.
struct QuickTranslationView: View {
    let sourceText: String
    /// Set when the selection can be replaced with the translation (editable field in the system sheet).
    var onReplace: ((String) -> Void)?
    /// A discussion started; the host should give the screen more room.
    var onExpand: () -> Void = {}

    @State private var session = ConversationSession()
    /// Number of messages in the thread before opening; hidden from view but visible to the model.
    @State private var firstIndex = 0
    @State private var started = false
    @State private var waitedTooLong = false
    @FocusState private var composerFocused: Bool

    private var lastTranslation: String? {
        session.messages.last { $0.role == .assistant && $0.kind == .translation && !$0.text.isEmpty }?.text
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !started {
                    if waitedTooLong {
                        ContentUnavailableView("No text", systemImage: "text.badge.xmark",
                                               description: Text("The app did not pass the selected text."))
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }

                ThreadView(session: session, fromIndex: firstIndex) { composerFocused = true }

                if let onReplace, !session.isLoading, let translation = lastTranslation {
                    Button {
                        onReplace(MarkdownText.plain(translation))
                    } label: {
                        Label("Replace with translation", systemImage: "arrow.left.arrow.right")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
        }
        .defaultScrollAnchor(.top, for: .alignment)
        // The first translation should be read from its headword; only follow-up answers pull the view down.
        .defaultScrollAnchor(session.messages.count > firstIndex + 2 ? .bottom : .top, for: .sizeChanges)
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            ComposerView(session: session, allowsTranslate: false, focused: $composerFocused, glass: true)
        }
        .onChange(of: composerFocused) { _, focused in
            if focused { onExpand() }
        }
        .onChange(of: session.messages.count) { _, count in
            if count > firstIndex + 2 { onExpand() }
        }
        // The host (Books, Safari) may deliver the selection late; start as soon as the text arrives.
        .onChange(of: sourceText, initial: true) { _, text in
            startIfPossible(text)
        }
        .task {
            try? await Task.sleep(for: .seconds(6))
            if !started { waitedTooLong = true }
        }
        .onDisappear { session.cancel() }
    }

    private func startIfPossible(_ text: String) {
        guard !started, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        started = true
        firstIndex = session.messages.count
        session.translate(text)
    }
}
