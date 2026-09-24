import XCTest
@testable import Translator

/// Streaming parsers against canned SSE bodies; no network, no keys beyond a throwaway one in the test Keychain.
final class ProviderStreamTests: XCTestCase {
    private let model = ModelOption(id: "test-model", title: "t", provider: .anthropic, maxTokens: 100,
                                    createdAt: .distantPast, supportsAdaptiveThinking: true, supportsEffort: true)

    override func setUp() {
        super.setUp()
        ProviderHTTP.session = StubURLProtocol.session()
        for provider in ProviderKind.allCases { KeychainStore.setAPIKey("test-key", for: provider) }
    }

    override func tearDown() {
        ProviderHTTP.session = .shared
        StubURLProtocol.handler = nil
        for provider in ProviderKind.allCases { KeychainStore.setAPIKey("", for: provider) }
        super.tearDown()
    }

    private func collect(_ stream: AsyncThrowingStream<String, Error>) async throws -> String {
        var out = ""
        for try await chunk in stream { out += chunk }
        return out
    }

    func testAnthropicStreamConcatenatesTextDeltas() async throws {
        StubURLProtocol.handler = { request in
            let body = String(data: request.httpBody ?? request.httpBodyStream.map { Self.read($0) } ?? Data(), encoding: .utf8) ?? ""
            XCTAssertTrue(body.contains("\"stream\":true"))
            XCTAssertTrue(body.contains("\"thinking\""))
            return (200, Data("""
            event: message_start
            data: {"type":"message_start"}

            data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Зовите "}}

            data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"меня"}}

            data: {"type":"message_delta","delta":{"stop_reason":"end_turn"}}

            data: {"type":"message_stop"}
            """.utf8))
        }
        let text = try await collect(AnthropicProvider().stream([ChatMessage(role: "user", content: "x")], model: model))
        XCTAssertEqual(text, "Зовите меня")
    }

    func testAnthropicRefusalSurfacesAsError() async {
        StubURLProtocol.handler = { _ in
            (200, Data("data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"refusal\"}}\n".utf8))
        }
        do {
            _ = try await collect(AnthropicProvider().stream([ChatMessage(role: "user", content: "x")], model: model))
            XCTFail("expected refusal")
        } catch TranslationError.refused {
        } catch { XCTFail("unexpected \(error)") }
    }

    func testHTTPErrorCarriesServerMessage() async {
        StubURLProtocol.handler = { _ in (401, Data(#"{"error":{"message":"invalid x-api-key"}}"#.utf8)) }
        do {
            _ = try await collect(AnthropicProvider().stream([ChatMessage(role: "user", content: "x")], model: model))
            XCTFail("expected error")
        } catch TranslationError.api(let status, let message) {
            XCTAssertEqual(status, 401)
            XCTAssertEqual(message, "invalid x-api-key")
        } catch { XCTFail("unexpected \(error)") }
    }

    func testOpenAIStreamStopsAtDone() async throws {
        StubURLProtocol.handler = { _ in
            (200, Data("""
            data: {"choices":[{"delta":{"content":"Hel"}}]}

            data: {"choices":[{"delta":{"content":"lo"},"finish_reason":"stop"}]}

            data: [DONE]

            data: {"choices":[{"delta":{"content":"IGNORED"}}]}
            """.utf8))
        }
        let openai = ModelOption(id: "gpt-5", title: "gpt-5", provider: .openai, maxTokens: 100, createdAt: .distantPast,
                                 supportsAdaptiveThinking: false, supportsEffort: true)
        let text = try await collect(OpenAICompatibleProvider(kind: .openai).stream([ChatMessage(role: "user", content: "x")], model: openai))
        XCTAssertEqual(text, "Hello")
    }

    func testGeminiStreamSkipsThoughtParts() async throws {
        StubURLProtocol.handler = { _ in
            (200, Data("""
            data: {"candidates":[{"content":{"parts":[{"text":"hidden","thought":true},{"text":"Привет"}]}}]}

            data: {"candidates":[{"content":{"parts":[{"text":"!"}]},"finishReason":"STOP"}]}
            """.utf8))
        }
        let gemini = ModelOption(id: "gemini-2.5-flash", title: "g", provider: .gemini, maxTokens: 100, createdAt: .distantPast,
                                 supportsAdaptiveThinking: false, supportsEffort: false)
        let text = try await collect(GeminiProvider().stream([ChatMessage(role: "user", content: "x")], model: gemini))
        XCTAssertEqual(text, "Привет!")
    }

    func testOpenAIModelListFiltersNonChatModels() async throws {
        StubURLProtocol.handler = { _ in
            (200, Data(#"{"data":[{"id":"gpt-5","created":1700000000},{"id":"whisper-1","created":1600000000},{"id":"gpt-4o-2024-08-06","created":1650000000},{"id":"gpt-4o","created":1650000000},{"id":"text-embedding-3-small","created":1}]}"#.utf8))
        }
        let ids = try await OpenAICompatibleProvider(kind: .openai).listModels().map(\.id)
        XCTAssertEqual(ids, ["gpt-5", "gpt-4o"])
    }

    private static func read(_ stream: InputStream) -> Data {
        stream.open(); defer { stream.close() }
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: buffer.count)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }
}
