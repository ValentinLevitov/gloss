import Foundation

enum ProviderKind: String, Codable, CaseIterable, Identifiable {
    case anthropic, openai, gemini, deepseek, xai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        case .deepseek: return "DeepSeek"
        case .xai: return "xAI"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .anthropic: return "sk-ant-…"
        case .openai: return "sk-…"
        case .gemini: return "AIza…"
        case .deepseek: return "sk-…"
        case .xai: return "xai-…"
        }
    }

    /// Where to get a key.
    var consoleURL: URL {
        switch self {
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")!
        case .openai: return URL(string: "https://platform.openai.com/api-keys")!
        case .gemini: return URL(string: "https://aistudio.google.com/apikey")!
        case .deepseek: return URL(string: "https://platform.deepseek.com/api_keys")!
        case .xai: return URL(string: "https://console.x.ai")!
        }
    }

    var hasKey: Bool {
        !(KeychainStore.apiKey(for: self) ?? "").isEmpty
    }
}

struct ModelOption: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let provider: ProviderKind
    let maxTokens: Int
    let createdAt: Date
    /// The model accepts `thinking: adaptive` (Anthropic only).
    let supportsAdaptiveThinking: Bool
    /// The model accepts an effort / reasoning-effort setting.
    let supportsEffort: Bool

    /// Anthropic models with safety classifiers may return `stop_reason: refusal`; enable the server-side fallback.
    /// Not exposed by the Models API, so derived from the id.
    var usesFallbacks: Bool {
        provider == .anthropic && ["claude-fable", "claude-mythos", "claude-opus-5"].contains { id.hasPrefix($0) }
    }

    /// Fallback lists used until a provider's models have been fetched at least once.
    static func builtIn(for provider: ProviderKind) -> [ModelOption] {
        func make(_ id: String, _ title: String, effort: Bool = true, thinking: Bool = false) -> ModelOption {
            ModelOption(id: id, title: title, provider: provider, maxTokens: 32000, createdAt: .distantPast,
                        supportsAdaptiveThinking: thinking, supportsEffort: effort)
        }
        switch provider {
        case .anthropic:
            return [make("claude-opus-5", "Claude Opus 5", thinking: true),
                    make("claude-sonnet-5", "Claude Sonnet 5", thinking: true),
                    make("claude-haiku-4-5", "Claude Haiku 4.5", effort: false)]
        case .openai:
            return [make("gpt-5", "gpt-5"), make("gpt-5-mini", "gpt-5-mini")]
        case .gemini:
            return [make("gemini-2.5-pro", "Gemini 2.5 Pro", effort: false),
                    make("gemini-2.5-flash", "Gemini 2.5 Flash", effort: false)]
        case .deepseek:
            return [make("deepseek-flash", "deepseek-flash"), make("deepseek-v4-pro", "deepseek-v4-pro")]
        case .xai:
            return [make("grok-4", "grok-4")]
        }
    }

    static let `default` = builtIn(for: .anthropic)[0]

    static func find(provider: ProviderKind?, id: String?) -> ModelOption? {
        guard let provider else { return nil }
        let available = ModelCatalog.cached(for: provider) ?? builtIn(for: provider)
        return available.first { $0.id == id }
    }
}

enum TranslationError: LocalizedError {
    case missingAPIKey(ProviderKind)
    case api(status: Int, message: String)
    case refused
    case truncated

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return String(localized: "No \(provider.title) API key. Open Settings → Model.")
        case .api(let status, let message):
            return String(localized: "API error (\(status)): \(message)")
        case .refused:
            return String(localized: "The model declined this request. Try another model in Settings.")
        case .truncated:
            return String(localized: "The reply hit the token limit — the text is too long, split it up.")
        }
    }
}

protocol TranslationProvider {
    /// Streams the reply to the last message of the thread in text chunks as it is generated.
    func stream(_ messages: [ChatMessage], model: ModelOption) -> AsyncThrowingStream<String, Error>
    /// Models the key can use, newest first.
    func listModels() async throws -> [ModelOption]
}

enum Providers {
    static func make(for provider: ProviderKind) -> TranslationProvider {
        switch provider {
        case .anthropic: return AnthropicProvider()
        case .gemini: return GeminiProvider()
        case .openai, .deepseek, .xai: return OpenAICompatibleProvider(kind: provider)
        }
    }

    static func make(for model: ModelOption) -> TranslationProvider {
        make(for: model.provider)
    }
}

/// Helpers shared by the HTTP providers.
enum ProviderHTTP {
    static func errorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any], let message = error["message"] as? String { return message }
            if let message = json["message"] as? String { return message }
            if let error = json["error"] as? String { return error }
        }
        return String(data: data, encoding: .utf8) ?? String(localized: "unknown error")
    }

    /// Runs `body` as an `AsyncThrowingStream`, cancelling the task when the consumer stops listening.
    static func stream(_ body: @escaping (AsyncThrowingStream<String, Error>.Continuation) async throws -> Void)
        -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await body(continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Drops dated snapshots (`…-2025-08-07`, `…-20251001`) when an undated alias of the same model is present.
    static func collapseSnapshots(_ models: [ModelOption]) -> [ModelOption] {
        let ids = Set(models.map(\.id))
        let dateSuffix = try! NSRegularExpression(pattern: "-(\\d{4}-\\d{2}-\\d{2}|\\d{8}|\\d{4})$")
        return models.filter { model in
            let range = NSRange(model.id.startIndex..., in: model.id)
            guard let match = dateSuffix.firstMatch(in: model.id, range: range),
                  let cut = Range(match.range, in: model.id) else { return true }
            return !ids.contains(String(model.id[..<cut.lowerBound]))
        }
    }
}
