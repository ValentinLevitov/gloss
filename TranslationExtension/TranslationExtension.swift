import SwiftUI
import TranslationUIProvider

/// The sheet the system shows for Translate in the text selection menu.
@main
final class TranslatorUIExtension: TranslationUIProviderExtension {
    required init() {}

    var body: some TranslationUIProviderExtensionScene {
        TranslationUIProviderSelectedTextScene { context in
            SelectedTextView(context: context)
        }
    }
}

/// Reads `inputText` inside body: the context is Observable and the host may fill the text late.
private struct SelectedTextView: View {
    let context: any TranslationUIProviderContext
    @AppStorage(TextSize.key, store: AppGroup.defaults) private var textSize = TextSize.system.rawValue

    var body: some View {
        QuickTranslationView(
            sourceText: context.inputText.map { String($0.characters) } ?? "",
            onReplace: context.allowsReplacement
                ? { context.finish(translation: AttributedString($0)) }
                : nil,
            onExpand: { context.expandSheet() }
        )
        .appTextSize(TextSize(rawValue: textSize) ?? .system)
    }
}
