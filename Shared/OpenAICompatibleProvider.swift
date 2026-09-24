import Foundation

/// Chat Completions as OpenAI, DeepSeek and xAI serve it: same wire format, different base URLs.
struct OpenAICompatibleProvider: TranslationProvider {
    let kind: ProviderKind

    private var baseURL: URL {
        switch kind {
        case .openai: return URL(string: "https://api.openai.com/v1")!
        case .deepseek: return URL(string: "https://api.deepseek.com")!
        case .xai: return URL(string: "https://api.x.ai/v1")!
        default: preconditionFailure("\(kind) is not OpenAI-compatible")
        }
    }

    private func request(_ path: String, method: String = "GET") throws -> URLRequest {
        guard let apiKey = KeychainStore.apiKey(for: kind), !apiKey.isEmpty else {
            throw TranslationError.missingAPIKey(kind)
        }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func stream(_ messages: [ChatMessage], model: ModelOption) -> AsyncThrowingStream<String, Error> {
        ProviderHTTP.stream { continuation in
            var body: [String: Any] = [
                "model": model.id,
                "stream": true,
                "messages": [["role": "system", "content": Prompt.system(LanguageSettings.current)]]
                    + messages.map { ["role": $0.role, "content": $0.content] },
            ]
            // DeepSeek still takes the classic name; OpenAI reasoning models reject it.
            body[kind == .deepseek ? "max_tokens" : "max_completion_tokens"] = model.maxTokens
            if model.supportsEffort {
                // Translation does not need long reasoning: low effort gives the lowest latency.
                body["reasoning_effort"] = "low"
            }

            do {
                try await run(body, into: continuation)
            } catch TranslationError.api(400, let message) where body["reasoning_effort"] != nil
                && message.localizedCaseInsensitiveContains("reasoning") {
                // Not every model on the list accepts the parameter; retry once without it.
                body["reasoning_effort"] = nil
                try await run(body, into: continuation)
            }
        }
    }

    private func run(_ body: [String: Any],
                     into continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        var request = try request("chat/completions", method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await ProviderHTTP.session.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            var data = Data()
            for try await byte in bytes { data.append(byte) }
            throw TranslationError.api(status: status, message: ProviderHTTP.errorMessage(from: data))
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let event = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any] else {
                continue
            }
            if let error = event["error"] as? [String: Any] {
                throw TranslationError.api(status: status, message: error["message"] as? String ?? payload)
            }
            guard let choice = (event["choices"] as? [[String: Any]])?.first else { continue }
            if let delta = choice["delta"] as? [String: Any], let text = delta["content"] as? String, !text.isEmpty {
                continuation.yield(text)
            }
            switch choice["finish_reason"] as? String {
            case "length": throw TranslationError.truncated
            case "content_filter": throw TranslationError.refused
            default: break
            }
        }
    }

    func listModels() async throws -> [ModelOption] {
        let path = kind == .xai ? "language-models" : "models"
        let (data, response) = try await ProviderHTTP.session.data(for: request(path))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw TranslationError.api(status: status, message: ProviderHTTP.errorMessage(from: data))
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = (json["data"] ?? json["models"]) as? [[String: Any]] else { return [] }

        var models: [ModelOption] = []
        for item in items {
            guard let id = item["id"] as? String, isChatModel(id) else { continue }
            let created = (item["created"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? .distantPast
            // xAI lists one entry per model with its aliases ("grok-4-latest", …); the canonical id is enough.
            models.append(ModelOption(id: id, title: id, provider: kind, maxTokens: 32000, createdAt: created,
                                      supportsAdaptiveThinking: false, supportsEffort: isReasoningModel(id)))
        }
        let sorted = models.sorted { (a: ModelOption, b: ModelOption) in
            a.createdAt != b.createdAt ? a.createdAt > b.createdAt : a.id > b.id
        }
        return ProviderHTTP.collapseSnapshots(sorted)
    }

    /// OpenAI's list mixes in audio, image, embedding and moderation models; keep the chat ones.
    private func isChatModel(_ id: String) -> Bool {
        let excluded = ["embedding", "tts", "whisper", "transcribe", "audio", "realtime", "image", "dall-e",
                        "moderation", "search", "instruct", "davinci", "babbage", "computer-use", "codex",
                        "vision", "sora", "aqa", "chat-latest"]
        if excluded.contains(where: { id.contains($0) }) { return false }
        switch kind {
        case .openai: return id.hasPrefix("gpt-") || id.hasPrefix("o1") || id.hasPrefix("o3") || id.hasPrefix("o4")
        default: return true
        }
    }

    private func isReasoningModel(_ id: String) -> Bool {
        switch kind {
        case .openai: return id.hasPrefix("gpt-5") || id.hasPrefix("o1") || id.hasPrefix("o3") || id.hasPrefix("o4")
        case .deepseek: return id.contains("reason") || id.contains("v4") || id.contains("flash")
        case .xai: return id.contains("grok-4") || id.contains("reasoning") || id.contains("grok-3-mini")
        default: return false
        }
    }
}
