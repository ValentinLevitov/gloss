import SwiftUI

/// Lets the user rewrite the system prompt template; saves on leaving the screen.
struct PromptEditorView: View {
    @State private var text = Prompt.customTemplate ?? Prompt.defaultTemplate
    @State private var confirmReset = false

    private var isDefault: Bool { text == Prompt.defaultTemplate }

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.callout)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 4) {
                Text("Placeholders: \(Prompt.placeholders.joined(separator: ", ")) are filled from the language settings.")
                Text("The app relies on <text> tags marking text to translate and on the “Fragment:” prefix for selected fragments — keep those rules.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.bar)
        }
        .navigationTitle("Prompt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") { confirmReset = true }
                    .disabled(isDefault)
            }
        }
        .confirmationDialog("Restore the built-in prompt?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset to default", role: .destructive) { text = Prompt.defaultTemplate }
        }
        .onDisappear {
            Prompt.customTemplate = isDefault ? nil : text
        }
    }
}
