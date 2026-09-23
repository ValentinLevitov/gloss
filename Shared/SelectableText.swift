import SwiftUI
import UIKit

/// Selectable text whose edit menu has "Explain" and "Discuss".
/// SwiftUI `Text` does not expose the selection, hence a UITextView underneath.
struct SelectableText: UIViewRepresentable {
    let markdown: String
    var textStyle: UIFont.TextStyle = .body
    var color: UIColor = .label
    let onExplain: (String) -> Void
    let onDiscuss: (String) -> Void
    var onAddCard: ((String) -> Void)?
    /// Bumped by the card store; part of the render key so highlights refresh.
    var cardsVersion = 0

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.delegate = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        let key = "\(dynamicTypeSize)|\(cardsVersion)|\(markdown)"
        guard context.coordinator.renderedKey != key else { return }
        context.coordinator.renderedKey = key
        view.attributedText = Self.attributed(markdown, textStyle: textStyle, color: color,
                                              sizeCategory: dynamicTypeSize.contentSizeCategory)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let height = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return CGSize(width: width, height: height)
    }

    static func attributed(_ markdown: String, textStyle: UIFont.TextStyle, color: UIColor,
                           sizeCategory: UIContentSizeCategory) -> NSAttributedString {
        let traits = UITraitCollection(preferredContentSizeCategory: sizeCategory)
        let base = UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traits)
        let result = NSMutableAttributedString()
        let rendered = MarkdownText.render(markdown)
        for run in rendered.runs {
            var traits: UIFontDescriptor.SymbolicTraits = []
            if run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true { traits.insert(.traitBold) }
            if run.inlinePresentationIntent?.contains(.emphasized) == true { traits.insert(.traitItalic) }
            let font = base.fontDescriptor.withSymbolicTraits(traits).map { UIFont(descriptor: $0, size: 0) } ?? base
            let text = String(rendered[run.range].characters)
            result.append(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color]))
        }
        highlightCards(in: result)
        return result
    }

    /// Marks words that have flashcards: orange while learning, green once learned.
    private static func highlightCards(in text: NSMutableAttributedString) {
        let index = CardStore.shared.index
        guard !index.isEmpty else { return }
        let string = text.string as NSString
        let words = try! NSRegularExpression(pattern: "\\p{L}[\\p{L}'’\\-]*")
        for match in words.matches(in: text.string, range: NSRange(location: 0, length: string.length)) {
            let word = string.substring(with: match.range).lowercased()
            guard let card = index[word] else { continue }
            let tint: UIColor = card.isLearned ? .systemGreen : .systemOrange
            text.addAttributes([.backgroundColor: tint.withAlphaComponent(0.22)], range: match.range)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableText
        var renderedKey: String?

        init(_ parent: SelectableText) { self.parent = parent }

        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange,
                      suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard range.length > 0, let text = textView.text else { return nil }
            let selected = (text as NSString).substring(with: range)

            let explain = UIAction(title: String(localized: "Explain"), image: UIImage(systemName: "lightbulb")) { [weak self] _ in
                textView.selectedTextRange = nil
                self?.parent.onExplain(selected)
            }
            let discuss = UIAction(title: String(localized: "Discuss"), image: UIImage(systemName: "bubble.left")) { [weak self] _ in
                textView.selectedTextRange = nil
                self?.parent.onDiscuss(selected)
            }
            var actions: [UIMenuElement] = [explain, discuss]
            if let onAddCard = parent.onAddCard, selected.split(separator: " ").count <= 3 {
                let title = CardStore.shared.card(for: selected) == nil ? "Add to cards" : "Update card"
                actions.append(UIAction(title: String(localized: String.LocalizationValue(title)),
                                        image: UIImage(systemName: "rectangle.stack.badge.plus")) { _ in
                    textView.selectedTextRange = nil
                    onAddCard(selected)
                })
            }
            return UIMenu(children: actions + suggestedActions)
        }
    }
}

enum MarkdownText {
    static func render(_ markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }

    static func plain(_ markdown: String) -> String {
        String(render(markdown).characters)
    }
}
