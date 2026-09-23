import Foundation

struct GeminiProvider: TranslationProvider {
    private static let base = URL(string: "https://generativelanguage.googleapis.com/v1beta")!

    private func request(_ path: String, query: [URLQueryItem] = [], method: String = "GET") throws -> URLRequest {
        guard let apiKey = KeychainStore.apiKey(for: .gemini), !apiKey.isEmpty else {
            throw TranslationError.missingAPIKey(.gemini)
        }
        var components = URLComponents(url: Self.base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.timeoutInterval = 120
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func stream(_ messages: [ChatMessage], model: ModelOption) -> AsyncThrowingStream<String, Error> {
        ProviderHTTP.stream { continuation in
            let body: [String: Any] = [
                "system_instruction": ["parts": [["text": Prompt.system(LanguageSettings.current)]]],
                "contents": messages.map {
                    ["role": $0.role == "assistant" ? "model" : "user", "parts": [["text": $0.content]]]
                },
                "generationConfig": ["maxOutputTokens": model.maxTokens],
            ]
            var request = try request("models/\(model.id):streamGenerateContent",
                                      query: [URLQueryItem(name: "alt", value: "sse")], method: "POST")
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
                guard let event = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any]
                else { continue }
                if let error = event["error"] as? [String: Any] {
                    throw TranslationError.api(status: status, message: error["message"] as? String ?? payload)
                }
                guard let candidate = (event["candidates"] as? [[String: Any]])?.first else {
                    if (event["promptFeedback"] as? [String: Any])?["blockReason"] != nil { throw TranslationError.refused }
                    continue
                }
                let parts = (candidate["content"] as? [String: Any])?["parts"] as? [[String: Any]] ?? []
                for part in parts where part["thought"] as? Bool != true {
                    if let text = part["text"] as? String, !text.isEmpty { continuation.yield(text) }
                }
                switch candidate["finishReason"] as? String {
                case "MAX_TOKENS": throw TranslationError.truncated
                case "SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST": throw TranslationError.refused
                default: break
                }
            }
        }
    }

    func listModels() async throws -> [ModelOption] {
        var models: [ModelOption] = []
        var pageToken: String?
        repeat {
            var query = [URLQueryItem(name: "pageSize", value: "1000")]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let (data, response) = try await URLSession.shared.data(for: request("models", query: query))
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                throw TranslationError.api(status: status, message: ProviderHTTP.errorMessage(from: data))
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { break }
            for item in json["models"] as? [[String: Any]] ?? [] {
                guard let name = item["name"] as? String,
                      let methods = item["supportedGenerationMethods"] as? [String],
                      methods.contains("generateContent") else { continue }
                let id = name.replacingOccurrences(of: "models/", with: "")
                guard isChatModel(id) else { continue }
                let limit = item["outputTokenLimit"] as? Int ?? 8192
                models.append(ModelOption(id: id, title: item["displayName"] as? String ?? id, provider: .gemini,
                                          maxTokens: min(limit, 32000), createdAt: .distantPast,
                                          supportsAdaptiveThinking: false, supportsEffort: false))
            }
            pageToken = json["nextPageToken"] as? String
        } while pageToken != nil
        // No creation dates in this API; newer versions sort higher by id.
        return models.sorted { (a: ModelOption, b: ModelOption) in
            a.id.compare(b.id, options: .numeric) == .orderedDescending
        }
    }

    private func isChatModel(_ id: String) -> Bool {
        let excluded = ["embedding", "image", "tts", "audio", "live", "vision", "aqa", "learnlm", "imagen", "veo",
                        "robotics", "computer-use", "exp", "preview-0", "-001", "-002", "gemma", "deep-research"]
        return id.hasPrefix("gemini") && !excluded.contains { id.contains($0) }
    }
}
