import XCTest
@testable import FadenCore

final class APIProviderTests: XCTestCase {
    private let prompt = BuiltPrompt(system: "FIGURENSTIMME bleibt erhalten. Private Nutzergedanken bleiben privat.",
        messages: [.init(role: "assistant", content: "Ein gespeicherter Anfang."), .init(role: "user", content: "„Guten Abend.“")], retrievedCount: 0, truncated: false)

    func testPresetsUseOfficialEndpointsRequireKeysAndStartDisabled() throws {
        XCTAssertEqual(APIProviderPreset.allCases.count, 8)
        for preset in APIProviderPreset.allCases {
            var connection = preset.connection()
            XCTAssertTrue(preset.matches(connection))
            XCTAssertEqual(URL(string: connection.baseURL)?.scheme, "https")
            XCTAssertEqual(preset.keyURL.scheme, "https")
            XCTAssertTrue(connection.requiresAPIKey); XCTAssertFalse(connection.enabled)
            connection.enabled = true; connection.allowsCosts = false; connection.models = ["configured-model"]
            connection.freeTierConfirmed = false
            XCTAssertTrue(connection.permittedModels(freeOnly: true).isEmpty, "An unverified API tier must not be assumed free")
            XCTAssertEqual(connection.permittedModels(freeOnly: false), ["configured-model"])
            connection.baseURL = "https://example.invalid/v1"
            XCTAssertFalse(preset.matches(connection))
        }
        XCTAssertEqual(APIProviderPreset.claude.kind, .anthropic)
        XCTAssertEqual(APIProviderPreset.openAI.kind, .openAI)
        XCTAssertEqual(APIProviderPreset.gemini.baseURL, "https://generativelanguage.googleapis.com/v1beta/openai")
    }
    func testClaudeUsesNativeMessagesAndAvoidsUnsupportedSamplingFields() throws {
        let body = try object(.anthropic)
        XCTAssertEqual(body["system"] as? String, prompt.system)
        XCTAssertEqual(body["max_tokens"] as? Int, 1200)
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertNil(body["temperature"]); XCTAssertNil(body["top_p"])
        let turns = try XCTUnwrap(body["messages"] as? [[String: String]])
        XCTAssertEqual(turns.first?["role"], "user")
        XCTAssertTrue(turns.contains { $0["content"] == "Ein gespeicherter Anfang." })
        XCTAssertEqual(turns.last?["content"], "„Guten Abend.“")
        XCTAssertFalse(turns.contains { $0["role"] == "system" })
    }
    func testVeniceKeepsCardSystemPromptWithoutVendorPersonaOrVisibleReasoning() throws {
        let data = try InferencePayload.encode(kind: .compatible, model: "text-model", prompt: prompt, maxTokens: 64, preset: .venice)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let options = try XCTUnwrap(body["venice_parameters"] as? [String: Bool])
        XCTAssertEqual(options["include_venice_system_prompt"], false)
        XCTAssertEqual(options["disable_thinking"], true)
        XCTAssertEqual(options["strip_thinking_response"], true)
        XCTAssertEqual((body["messages"] as? [[String: String]])?.first?["content"], prompt.system)
    }
    func testClaudeContinuationDoesNotSendAnAssistantPrefill() throws {
        var continuing = prompt
        continuing.messages = [.init(role: "assistant", content: "Eine abgeschlossene Antwort.")]
        let data = try InferencePayload.encode(kind: .anthropic, model: "api-model", prompt: continuing, maxTokens: 1200)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let turns = try XCTUnwrap(body["messages"] as? [[String: String]])
        XCTAssertEqual(turns.last?["role"], "user")
        XCTAssertTrue(turns.last?["content"]?.contains("keine Beiträge der Nutzerfigur erfinden") == true)
    }
    func testOpenAIAPIKeepsSeparateOutputBudgetFromChatGPTPlanSharing() throws {
        let api = try object(.openAI), plan = try object(.chatGPT)
        XCTAssertEqual(api["max_output_tokens"] as? Int, 1200)
        XCTAssertNil(plan["max_output_tokens"])
        for body in [api, plan] {
            XCTAssertEqual(body["instructions"] as? String, prompt.system)
            XCTAssertEqual(body["store"] as? Bool, false)
            XCTAssertNil(body["temperature"])
        }
        XCTAssertEqual((try object(.compatible))["messages"] as? [[String: String]], [["role": "system", "content": prompt.system]] + prompt.messages.map { ["role": $0.role, "content": $0.content] })
    }
    func testClaudeStreamDoesNotExposeReasoningAsCharacterThoughts() {
        func event(_ json: String) -> ClaudeStreamEvent { .decode(.init(name: "message", data: json)) }
        XCTAssertEqual(event(#"{"type":"content_block_delta","delta":{"type":"text_delta","text":"Hallo"}}"#), .text("Hallo"))
        XCTAssertEqual(event(#"{"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"internal reasoning"}}"#), .ignored)
        XCTAssertEqual(event(#"{"type":"message_delta","delta":{"stop_reason":"end_turn"}}"#), .ignored)
        XCTAssertEqual(event(#"{"type":"message_stop"}"#), .completed)
        XCTAssertEqual(event(#"{"type":"error","error":{"type":"rate_limit_error"}}"#), .failure(blocksConnection: true))
        XCTAssertEqual(event(#"{"type":"error","error":{"type":"overloaded_error"}}"#), .failure(blocksConnection: false))
        XCTAssertEqual(event("malformed"), .ignored)
    }
    func testPresetAndWorkspaceSurviveBackupWithoutCredentials() throws {
        var connection = APIProviderPreset.claude.connection(); connection.workspaceID = "workspace-test"
        let data = try JSONEncoder().encode(Archive(connections: [connection]))
        let restored = try JSONDecoder().decode(Archive.self, from: data)
        XCTAssertEqual(restored.connections.first?.apiPreset, .claude)
        XCTAssertEqual(restored.connections.first?.workspaceID, "workspace-test")
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("apiKey"))
    }
    private func object(_ kind: ProviderKind) throws -> [String: Any] {
        let data = try InferencePayload.encode(kind: kind, model: "api-model", prompt: prompt, maxTokens: 1200)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
