import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = ConversationSession.selectedModel
    @State private var languages = LanguageSettings.current
    @AppStorage(TextSize.key, store: AppGroup.defaults) private var textSize = TextSize.system.rawValue
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ModelPickerView(selected: $model)
                    } label: {
                        HStack {
                            Text("Model")
                            Spacer()
                            if model.provider.hasKey {
                                Text(model.title).foregroundStyle(.secondary)
                            } else {
                                Text("Add an API key").foregroundStyle(.red)
                            }
                        }
                    }
                    NavigationLink {
                        PromptEditorView()
                    } label: {
                        HStack {
                            Text("Prompt")
                            Spacer()
                            Text(Prompt.customTemplate == nil ? "Default" : "Custom").foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Keys are stored only in this device's Keychain. Requests go directly to the provider.")
                }

                Section {
                    Picker("My language", selection: $languages.native) {
                        ForEach(Language.all) { Text($0.name).tag($0) }
                    }
                    Picker("Foreign language", selection: $languages.foreign) {
                        ForEach(Language.all) { Text($0.name).tag($0) }
                    }
                } header: {
                    Text("Languages")
                } footer: {
                    Text("Foreign or any other text is translated into my language; my language is translated into the foreign one. Explanations are written in my language.")
                }

                Section {
                    Picker("Text size", selection: $textSize) {
                        ForEach(TextSize.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                } header: {
                    Text("Appearance")
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openDefaultApplicationsSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Default Apps settings", systemImage: "gear")
                    }
                    Button {
                        showOnboarding = true
                    } label: {
                        Label("Setup guide", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("System translator")
                } footer: {
                    Text("Choose Translation → Gloss there, and “Translate” in the text selection menu will open this app.")
                }
            }
            .sheet(isPresented: $showOnboarding) { OnboardingView() }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        ConversationSession.select(model)
                        languages.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
