import Foundation
import Observation

@MainActor
@Observable
final class ConversationSession {
    static let modelDefaultsKey = "selectedModel"
    static let providerDefaultsKey = "selectedProvider"

    private(set) var messages: [ThreadMessage]
    var draft = ""
    /// Fragment picked via "Discuss"; attached to the next question.
    var quote: String?
    private(set) var isLoading = false
    var errorMessage: String?
    /// True while a photo is being recognized, before the translation request starts.
    var isRecognizing = false
    /// Word whose card is being built right now.
    private(set) var buildingCardFor: String?
    /// Headword of the card that was just added; cleared by the UI after showing it.
    var lastAddedCard: FlashCard?

    private var task: Task<Void, Never>?

    init() {
        messages = ConversationStore.loadCurrent()
    }

    static var selectedModel: ModelOption {
        let defaults = AppGroup.defaults
        let provider = ProviderKind(rawValue: defaults.string(forKey: providerDefaultsKey) ?? "")
        return ModelOption.find(provider: provider, id: defaults.string(forKey: modelDefaultsKey))
            ?? ModelCatalog.models(for: provider ?? .anthropic).first
            ?? .default
    }

    static func select(_ model: ModelOption) {
        AppGroup.defaults.set(model.provider.rawValue, forKey: providerDefaultsKey)
        AppGroup.defaults.set(model.id, forKey: modelDefaultsKey)
    }

    /// Pick up the thread that another process (app ↔ extension) may have continued.
    func reload() {
        guard !isLoading else { return }
        messages = ConversationStore.loadCurrent()
    }

    func translate(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        send(ThreadMessage(role: .user, kind: .translation, text: text))
    }

    /// An empty question with a quote means "explain this fragment".
    func ask(_ rawQuestion: String, quote: String? = nil) {
        let question = rawQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        let quote = quote?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty || !(quote ?? "").isEmpty else { return }
        send(ThreadMessage(role: .user, kind: .question, text: question, quote: quote))
    }

    func startNewThread() {
        cancel()
        messages = []
        draft = ""
        quote = nil
        errorMessage = nil
        ConversationStore.save(messages)
    }

    func startThread(from entry: HistoryEntry) {
        startNewThread()
        messages = [
            ThreadMessage(role: .user, kind: .translation, text: entry.source),
            ThreadMessage(role: .assistant, kind: .translation, text: entry.translation),
        ]
        ConversationStore.save(messages)
    }

    func cancel() {
        guard isLoading else { return }
        task?.cancel()
        task = nil
        isLoading = false
        dropUnansweredTail()
        ConversationStore.save(messages)
    }

    private func send(_ userMessage: ThreadMessage) {
        guard !isLoading else { return }
        errorMessage = nil
        isLoading = true

        messages.append(userMessage)
        let payload = ConversationStore.payload(from: messages)
        let reply = ThreadMessage(role: .assistant, kind: userMessage.kind, text: "")
        messages.append(reply)

        let model = Self.selectedModel
        task = Task {
            do {
                for try await chunk in Providers.make(for: model).stream(payload, model: model) {
                    guard !Task.isCancelled, let index = messages.lastIndex(where: { $0.id == reply.id }) else { return }
                    messages[index].text += chunk
                }
                guard !Task.isCancelled else { return }
                isLoading = false
                dropUnansweredTail()
                ConversationStore.save(messages)
                if userMessage.kind == .translation, let done = messages.last(where: { $0.id == reply.id }) {
                    HistoryStore.add(source: userMessage.text, translation: done.text)
                }
            } catch {
                guard !Task.isCancelled else { return }
                isLoading = false
                errorMessage = error.localizedDescription
                if dropUnansweredTail(), userMessage.kind == .question {
                    draft = userMessage.text
                    quote = userMessage.quote
                }
                ConversationStore.save(messages)
            }
        }
    }

    /// Builds a flashcard for `word` (as selected in `context`) with the current model and stores it.
    func addCard(word: String, context: String) {
        let word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty, buildingCardFor == nil else { return }
        buildingCardFor = word
        errorMessage = nil
        let model = Self.selectedModel
        Task {
            defer { buildingCardFor = nil }
            do {
                let card = try await CardBuilder.build(word: word, context: context, model: model)
                CardStore.shared.add(card)
                lastAddedCard = card
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Drops an empty reply together with its question so no unanswered exchange stays in history.
    @discardableResult
    private func dropUnansweredTail() -> Bool {
        guard let last = messages.last, last.role == .assistant, last.text.isEmpty else { return false }
        messages.removeLast()
        if messages.last?.role == .user { messages.removeLast() }
        return true
    }
}
