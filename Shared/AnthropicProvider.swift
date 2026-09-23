import Foundation

struct AnthropicProvider: TranslationProvider {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let modelsEndpoint = URL(string: "https://api.anthropic.com/v1/models")!

    func stream(_ messages: [ChatMessage], model: ModelOption) -> AsyncThrowingStream<String, Error> {
        ProviderHTTP.stream { continuation in
            try await run(messages, model: model, into: continuation)
        }
    }

    private func run(_ messages: [ChatMessage], model: ModelOption,
                     into continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        guard let apiKey = KeychainStore.apiKey(for: .anthropic), !apiKey.isEmpty else {
            throw TranslationError.missingAPIKey(.anthropic)
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var body: [String: Any] = [
            "model": model.id,
            "max_tokens": model.maxTokens,
            "stream": true,
            "system": Prompt.system(LanguageSettings.current),
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            // The thread is append-only, so automatic prefix caching makes every next request cheaper.
            "cache_control": ["type": "ephemeral"],
        ]
        if model.supportsAdaptiveThinking {
            body["thinking"] = ["type": "adaptive"]
        }
        if model.supportsEffort {
            // Translation does not need long reasoning: low effort gives the lowest latency.
            body["output_config"] = ["effort": "low"]
        }
        if model.usesFallbacks {
            request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
            body["fallbacks"] = "default"
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            var data = Data()
            for try await byte in bytes { data.append(byte) }
            throw TranslationError.api(status: status, message: ProviderHTTP.errorMessage(from: data))
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let event = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
                  let type = event["type"] as? String else { continue }

            switch type {
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let chunk = delta["text"] as? String {
                    continuation.yield(chunk)
                }
            case "message_delta":
                let stopReason = (event["delta"] as? [String: Any])?["stop_reason"] as? String
                if stopReason == "refusal" { throw TranslationError.refused }
                if stopReason == "max_tokens" { throw TranslationError.truncated }
            case "error":
                let error = event["error"] as? [String: Any]
                throw TranslationError.api(status: status, message: error?["message"] as? String ?? payload)
            default:
                break
            }
        }
    }

    func listModels() async throws -> [ModelOption] {
        guard let apiKey = KeychainStore.apiKey(for: .anthropic), !apiKey.isEmpty else {
            throw TranslationError.missingAPIKey(.anthropic)
        }

        var models: [ModelOption] = []
        var afterID: String?
        repeat {
            var components = URLComponents(url: Self.modelsEndpoint, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "limit", value: "100")]
            if let afterID { components.queryItems?.append(URLQueryItem(name: "after_id", value: afterID)) }

            var request = URLRequest(url: components.url!)
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                throw TranslationError.api(status: status, message: ProviderHTTP.errorMessage(from: data))
            }
            guard let page = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = page["data"] as? [[String: Any]] else { break }

            models += items.compactMap(Self.model(from:))
            afterID = (page["has_more"] as? Bool == true) ? page["last_id"] as? String : nil
        } while afterID != nil

        let sorted = models.sorted { (a: ModelOption, b: ModelOption) in a.createdAt > b.createdAt }
        return ProviderHTTP.collapseSnapshots(sorted)
    }

    private static func model(from item: [String: Any]) -> ModelOption? {
        guard let id = item["id"] as? String else { return nil }
        let caps = item["capabilities"] as? [String: Any] ?? [:]
        func supported(_ path: [String]) -> Bool {
            var node: Any? = caps
            for key in path { node = (node as? [String: Any])?[key] }
            return (node as? [String: Any])?["supported"] as? Bool ?? false
        }
        let createdAt = (item["created_at"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        // Streaming has no timeout concern, but a translation never needs the full 128K.
        let maxTokens = min(item["max_tokens"] as? Int ?? 32000, 64000)
        return ModelOption(
            id: id,
            title: item["display_name"] as? String ?? id,
            provider: .anthropic,
            maxTokens: maxTokens,
            createdAt: createdAt ?? .distantPast,
            supportsAdaptiveThinking: supported(["thinking", "types", "adaptive"]),
            supportsEffort: supported(["effort"])
        )
    }
}
