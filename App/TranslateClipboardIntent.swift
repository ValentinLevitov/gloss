import AppIntents
import UIKit

/// Shortcuts / Action Button: open Gloss and translate the clipboard.
struct TranslateClipboardIntent: AppIntent {
    static let title: LocalizedStringResource = "Translate Clipboard"
    static let description = IntentDescription("Opens Gloss and translates the text on the clipboard.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickActions.shared.pendingClipboard = true
        return .result()
    }
}

struct GlossShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TranslateClipboardIntent(),
                    phrases: ["Translate clipboard in \(.applicationName)"],
                    shortTitle: "Translate Clipboard",
                    systemImageName: "doc.on.clipboard")
    }
}
