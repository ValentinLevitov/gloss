import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Share sheet → Gloss: a fallback for apps without the system Translate item.
final class ShareViewController: UIViewController {
    /// What the host app passed when no text was found among it; for diagnostics.
    private var receivedTypes: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        Task { @MainActor in
            let text = SharedText.clean(await loadSharedText())
            show(ShareRootView(text: text, receivedTypes: receivedTypes) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            })
        }
    }

    private func show(_ root: some View) {
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    private func loadSharedText() async -> String {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }

        for type in [UTType.plainText, .text, .rtf, .html] {
            for provider in providers where provider.hasItemConformingToTypeIdentifier(type.identifier) {
                let item = try? await provider.loadItem(forTypeIdentifier: type.identifier)
                if let text = Self.string(from: item, type: type), !text.isEmpty { return text }
            }
        }
        // Some apps put the selected text into the item itself rather than an attachment.
        if let text = items.compactMap({ $0.attributedContentText?.string }).first(where: { !$0.isEmpty }) {
            return text
        }
        receivedTypes = providers.flatMap(\.registeredTypeIdentifiers)
        return ""
    }

    private static func string(from item: NSSecureCoding?, type: UTType) -> String? {
        if let string = item as? String { return string }
        if let attributed = item as? NSAttributedString { return attributed.string }
        guard let data = item as? Data else { return nil }
        let documentType: NSAttributedString.DocumentType? = type == .rtf ? .rtf : type == .html ? .html : nil
        if let documentType,
           let attributed = try? NSAttributedString(data: data, options: [.documentType: documentType],
                                                    documentAttributes: nil) {
            return attributed.string
        }
        return String(data: data, encoding: .utf8)
    }
}

private struct ShareRootView: View {
    let text: String
    let receivedTypes: [String]
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if text.isEmpty {
                    ContentUnavailableView("No text", systemImage: "text.badge.xmark",
                                           description: Text("The app did not pass the selected text.\nReceived: "
                                                             + (receivedTypes.isEmpty ? String(localized: "nothing") : receivedTypes.joined(separator: ", "))))
                } else {
                    QuickTranslationView(sourceText: text)
                }
            }
            .appTextSize(TextSize.current)
            .navigationTitle("Gloss")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }
}
