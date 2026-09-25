import XCTest
@testable import Translator

final class ModelCatalogTests: XCTestCase {
    private func model(_ id: String) -> ModelOption {
        ModelOption(id: id, title: id, provider: .anthropic, maxTokens: 1, createdAt: .distantPast,
                    supportsAdaptiveThinking: false, supportsEffort: false)
    }

    func testCollapseSnapshotsKeepsAliasAndDropsDatedTwin() {
        let ids = ProviderHTTP.collapseSnapshots([
            model("claude-haiku-4-5"), model("claude-haiku-4-5-20251001"),
            model("gpt-5-2025-08-07"), model("gpt-5"), model("lonely-20240101"),
        ]).map(\.id)
        XCTAssertEqual(ids, ["claude-haiku-4-5", "gpt-5", "lonely-20240101"])
    }

    func testAnthropicModelParsingReadsCapabilities() throws {
        let item: [String: Any] = [
            "id": "claude-opus-5", "display_name": "Claude Opus 5", "created_at": "2026-04-01T00:00:00Z",
            "max_tokens": 128000,
            "capabilities": ["thinking": ["types": ["adaptive": ["supported": true]]], "effort": ["supported": true]],
        ]
        let parsed = try XCTUnwrap(AnthropicProvider.model(from: item))
        XCTAssertEqual(parsed.title, "Claude Opus 5")
        XCTAssertTrue(parsed.supportsAdaptiveThinking)
        XCTAssertTrue(parsed.supportsEffort)
        XCTAssertEqual(parsed.maxTokens, 64000, "output cap is clamped for translation")
        XCTAssertTrue(parsed.usesFallbacks)
        XCTAssertNotEqual(parsed.createdAt, .distantPast)
    }

    func testModelWithoutCapabilitiesDefaultsToOff() throws {
        let parsed = try XCTUnwrap(AnthropicProvider.model(from: ["id": "claude-haiku-4-5"]))
        XCTAssertFalse(parsed.supportsEffort)
        XCTAssertFalse(parsed.usesFallbacks)
    }

    func testErrorMessageExtraction() {
        XCTAssertEqual(ProviderHTTP.errorMessage(from: Data(#"{"error":{"message":"bad key"}}"#.utf8)), "bad key")
        XCTAssertEqual(ProviderHTTP.errorMessage(from: Data(#"{"message":"nope"}"#.utf8)), "nope")
        XCTAssertEqual(ProviderHTTP.errorMessage(from: Data("plain".utf8)), "plain")
    }
}
