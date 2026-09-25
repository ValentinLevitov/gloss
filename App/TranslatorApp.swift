import SwiftUI

@main
struct TranslatorApp: App {
    init() {
        #if targetEnvironment(simulator)
        // Test hook: wipe keys and onboarding state so a UI test starts from a fresh install.
        if ProcessInfo.processInfo.environment["GLOSS_RESET"] == "1" {
            for provider in ProviderKind.allCases { KeychainStore.setAPIKey("", for: provider) }
            AppGroup.defaults.removeObject(forKey: OnboardingView.completedKey)
        }
        // Screenshot/dev convenience: seed a key and skip onboarding from the environment. Simulator only.
        if let key = ProcessInfo.processInfo.environment["GLOSS_SEED_ANTHROPIC_KEY"], !key.isEmpty {
            KeychainStore.setAPIKey(key, for: .anthropic)
            AppGroup.defaults.set(true, forKey: OnboardingView.completedKey)
        }
        #endif
    }

    @AppStorage(TextSize.key, store: AppGroup.defaults) private var textSize = TextSize.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .appTextSize(TextSize(rawValue: textSize) ?? .system)
        }
    }
}
