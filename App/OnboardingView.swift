import SwiftUI
import UIKit

/// First-run setup: a key, the system translator switch, and how to use the app.
struct OnboardingView: View {
    static let completedKey = "onboardingCompleted"

    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var provider: ProviderKind = .anthropic
    @State private var hasKey = ProviderKind.allCases.contains { $0.hasKey }

    var body: some View {
        NavigationStack {
            TabView(selection: $step) {
                keyStep.tag(0)
                defaultAppStep.tag(1)
                usageStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if step < 2 {
                        Button("Next") { withAnimation { step += 1 } }
                            .disabled(step == 0 && !hasKey)
                    } else {
                        Button("Done") { finish() }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if hasKey { Button("Skip") { finish() } }
                }
            }
        }
        .interactiveDismissDisabled(!hasKey)
    }

    private var keyStep: some View {
        Form {
            Section {
                Text("Gloss sends text to an AI model using your own API key. Pick a provider and add a key; the key stays in this device's Keychain.")
                    .font(.callout)
            }
            Section {
                Picker("Provider", selection: $provider) {
                    ForEach(ProviderKind.allCases) { Text($0.title).tag($0) }
                }
                APIKeyField(provider: provider) { ok in
                    hasKey = ok || ProviderKind.allCases.contains { $0.hasKey }
                    if ok, let first = ModelCatalog.models(for: provider).first { ConversationSession.select(first) }
                }
                .id(provider)
            } header: {
                Text("1 · API key")
            } footer: {
                Text("Anthropic (Claude) is the default. More providers can be added later in Settings → Model.")
            }
        }
    }

    private var defaultAppStep: some View {
        Form {
            Section {
                Text("Make Gloss the system translation app. Then “Translate” in the text selection menu of Books, Safari and other apps opens Gloss instead of Apple Translate.")
                    .font(.callout)
                Button {
                    if let url = URL(string: UIApplication.openDefaultApplicationsSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Default Apps settings", systemImage: "gear")
                }
            } header: {
                Text("2 · System translator")
            } footer: {
                Text("In Settings choose Translation → Gloss. Come back here when done.")
            }
        }
    }

    private var usageStep: some View {
        Form {
            Section("3 · How to use") {
                Label("In any app: select text → Translate. The translation streams in a sheet.", systemImage: "text.cursor")
                Label("Select a word in the original or the translation → Explain, or Discuss to ask your own question.", systemImage: "bubble.left.and.text.bubble.right")
                Label("Everything goes into one thread, so the model keeps the context of what you are reading. Open the app to see it all or start a new thread.", systemImage: "list.bullet.rectangle")
                Label("In the app: type or paste text, or point the camera at a page.", systemImage: "camera")
            }
            .font(.callout)
        }
    }

    private func finish() {
        AppGroup.defaults.set(true, forKey: Self.completedKey)
        dismiss()
    }
}
