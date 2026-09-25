import SwiftUI
import UIKit

/// The input bar: translations and questions in the app, questions only in the extensions.
struct ComposerView: View {
    @Bindable var session: ConversationSession
    var allowsTranslate = true
    var focused: FocusState<Bool>.Binding
    /// Photo translation lives in the app only; extensions have no camera or library access.
    var onPhoto: ((PhotoSource) -> Void)?
    /// Dictation; the app supplies it, extensions cannot use the microphone.
    var dictation: DictationControl?
    /// Liquid Glass chrome when the host is glassy (the system translation sheet); a plain bar in the app.
    var glass = false

    enum PhotoSource { case camera, library }

    struct DictationControl {
        let isRecording: Bool
        let start: (Language) -> Void
        let stop: () -> Void
    }

    private var hasDraft: Bool {
        !session.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isRecording: Bool { dictation?.isRecording == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let quote = session.quote {
                HStack(alignment: .top) {
                    QuoteLabel(text: quote)
                    Spacer()
                    Button { session.quote = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                // The same controls in every state: camera and mic on the left, question and translate on the right.
                if let onPhoto { photoMenu(onPhoto) }
                if let dictation { micMenu(dictation) }

                if isRecording {
                    // While dictating the field is not focused (no keyboard), so show the transcript in a view that
                    // keeps its tail visible instead of a text field stuck at its first lines.
                    ScrollView {
                        Text(session.draft.isEmpty ? String(localized: "Listening…") : session.draft)
                            .foregroundStyle(session.draft.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .defaultScrollAnchor(.bottom)
                    .frame(maxHeight: 132)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .modifier(FieldChrome())
                } else {
                    TextField(placeholder, text: $session.draft, axis: .vertical)
                        .lineLimit(1...6)
                        .focused(focused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .modifier(FieldChrome())
                }

                buttons
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .modifier(BarChrome(glass: glass))
    }

    private var placeholder: LocalizedStringKey {
        if isRecording { return "Listening…" }
        if session.quote != nil { return "Question about the fragment (optional)" }
        return allowsTranslate ? "Text to translate or a question" : "Ask about the translation…"
    }

    private func photoMenu(_ onPhoto: @escaping (PhotoSource) -> Void) -> some View {
        Menu {
            Button { onPhoto(.camera) } label: { Label("Take Photo", systemImage: "camera") }
            Button { onPhoto(.library) } label: { Label("Choose Photo", systemImage: "photo.on.rectangle") }
        } label: {
            Image(systemName: "camera").font(.title3)
        }
        .padding(.bottom, 8)
        .disabled(session.isLoading || dictation?.isRecording == true)
    }

    private func micMenu(_ dictation: DictationControl) -> some View {
        let languages = LanguageSettings.current
        return Group {
            if dictation.isRecording {
                Button { dictation.stop() } label: {
                    Image(systemName: "stop.circle.fill").font(.title3).foregroundStyle(.red)
                }
            } else {
                Menu {
                    Button { dictation.start(languages.foreign) } label: { Label(languages.foreign.name, systemImage: "mic") }
                    Button { dictation.start(languages.native) } label: { Label(languages.native.name, systemImage: "mic") }
                } label: {
                    Image(systemName: "mic").font(.title3)
                }
            }
        }
        .padding(.bottom, 8)
        .disabled(session.isLoading)
    }

    @ViewBuilder
    private var buttons: some View {
        if session.isRecognizing {
            ProgressView().padding(.bottom, 8).padding(.trailing, 6)
        } else if session.isLoading {
            Button { session.cancel() } label: { Image(systemName: "stop.circle.fill").font(.title) }
        } else if session.quote == nil, !hasDraft, allowsTranslate {
            // System paste button: iOS does not prompt, the tap itself is the permission.
            PasteButton(payloadType: String.self) { strings in
                if let pasted = strings.first { session.translate(pasted) }
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.circle)
            .padding(.bottom, 2)
        } else {
            // One send button. With a fragment attached (or in the sheet) it asks; otherwise it translates.
            // Long-press offers the other action for the rare free-standing question.
            let asks = session.quote != nil || !allowsTranslate
            Menu {
                if asks, allowsTranslate {
                    Button { send { session.translate($0) } } label: { Label("Translate instead", systemImage: "character.book.closed") }
                } else if allowsTranslate {
                    Button { sendQuestion() } label: { Label("Ask a question instead", systemImage: "bubble.left") }
                }
            } label: {
                Image(systemName: asks ? "arrow.up.circle.fill" : "arrow.up.circle.fill").font(.title)
            } primaryAction: {
                if asks { sendQuestion() } else { send { session.translate($0) } }
            }
            .disabled(session.quote == nil && !hasDraft)
        }
    }

    private func sendQuestion() {
        let quote = session.quote
        session.quote = nil
        send { session.ask($0, quote: quote) }
    }

    private func send(_ action: (String) -> Void) {
        let text = session.draft
        session.draft = ""
        action(text)
    }
}

private struct FieldChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 18))
        } else {
            content.background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

private struct BarChrome: ViewModifier {
    let glass: Bool

    func body(content: Content) -> some View {
        if glass {
            content.background(.clear)
        } else {
            content.background(.bar)
        }
    }
}
