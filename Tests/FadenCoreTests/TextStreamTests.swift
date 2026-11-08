import XCTest
@testable import FadenCore

final class TextStreamTests: XCTestCase {
    func testOfficialChatGPTStreamMayOmitContentTypeButMustNotBeHTML() {
        XCTAssertTrue(TextStreamPolicy.accepts(contentType: nil, kind: .chatGPT))
        XCTAssertTrue(TextStreamPolicy.accepts(contentType: "", kind: .chatGPT))
        XCTAssertTrue(TextStreamPolicy.accepts(contentType: "Text/Event-Stream; charset=utf-8", kind: .chatGPT))
        XCTAssertFalse(TextStreamPolicy.accepts(contentType: "text/html", kind: .chatGPT))
        XCTAssertFalse(TextStreamPolicy.accepts(contentType: nil, kind: .openRouter))
    }
    func testHeaderlessResponsesStreamRequiresARealCompletionEvent() {
        var parser = SSEParser(); var events: [TextStreamEvent] = []
        let stream = "event: response.output_text.delta\r\ndata: {\"type\":\"response.output_text.delta\",\"delta\":\"Guten Abend.\"}\r\n\r\ndata: {\"type\":\"response.completed\"}\r\n\r\n"
        for bytes in stream.utf8.split(separator: 10, omittingEmptySubsequences: false) {
            let line = String(decoding: bytes, as: UTF8.self)
            if let event = parser.consume(line) { events.append(.decode(event, responses: true)) }
        }
        XCTAssertEqual(events, [.text("Guten Abend."), .completed])
        XCTAssertEqual(TextStreamEvent.decode(.init(name: "message", data: "[DONE]"), responses: true), .ignored)
    }
    func testFreeModelReasoningCannotMasqueradeAsACharacterAnswer() {
        func decode(_ json: String) -> TextStreamEvent { .decode(.init(name: "message", data: json), responses: false) }
        XCTAssertEqual(decode(#"{"choices":[{"delta":{"reasoning":"private computation","content":null},"finish_reason":null}]}"#), .ignored)
        XCTAssertEqual(decode(#"{"choices":[{"delta":{},"finish_reason":"length"}]}"#), .failure(code: "length"))
        XCTAssertEqual(decode(#"{"choices":[{"delta":{"content":"Hallo"},"finish_reason":null}]}"#), .text("Hallo"))
        XCTAssertEqual(decode(#"{"choices":[{"delta":{},"finish_reason":"stop"}]}"#), .completed)
        XCTAssertEqual(decode(#"{"choices":[{"delta":{},"finish_reason":"content_filter"}]}"#), .failure(code: "content_filter"))
        XCTAssertEqual(decode(#"{"error":{"code":429,"message":"sensitive upstream text"}}"#), .failure(code: "429"))
    }
    func testStructuredTextPartsAndUnknownErrorsDoNotExposePrivateFields() {
        let event = SSEEvent(name: "message", data: #"{"choices":[{"delta":{"content":[{"type":"text","text":"Guten "},{"type":"thinking","text":"private"},{"type":"output_text","text":"Abend"}]}}]}"#)
        XCTAssertEqual(TextStreamEvent.decode(event, responses: false), .text("Guten Abend"))
        XCTAssertEqual(TextStreamEvent.decode(.init(name: "error", data: #"{"type":"error","code":"unexpected submitted story text"}"#), responses: true), .failure(code: "error"))
    }
    func testCompletedResponseSnapshotExtractsOnlyVisibleText() {
        let data = Data(#"{"response":{"output":[{"type":"reasoning","summary":[{"text":"private"}]},{"type":"message","content":[{"type":"output_text","text":"Guten Abend."}]}]}}"#.utf8)
        let object = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(ResponseText.finalText(object), "Guten Abend.")
    }
    func testTranslatedChunksKeepTheirOriginalWordBoundaries() throws {
        let text = String(repeating: "A sentence at the station. ", count: 160)
        let plan = CardTranslationBatch(fields: ["body": text])
        XCTAssertGreaterThan(plan.requests.count, 1)
        let translated = Dictionary(uniqueKeysWithValues: plan.requests.map { ($0.id, $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) })
        XCTAssertEqual(try plan.restore(translated)["body"], text)
        let object: [String: Any] = ["type": "message", "content": [["type": "thinking", "thinking": "private"], ["type": "text", "text": "Hallo"]]]
        XCTAssertEqual(ResponseText.finalText(object), "Hallo")
    }
    func testTranslationVariablesAndGuideverseAliases() throws {
        let plan = CardTranslationBatch(fields: ["greeting": "Hello {{user}}. Welcome, {{char}}."])
        let values = Dictionary(uniqueKeysWithValues: plan.requests.map { ($0.id, $0.text.replacingOccurrences(of: "Hello", with: "Hallo").replacingOccurrences(of: "Welcome", with: "Willkommen").trimmingCharacters(in: .whitespacesAndNewlines)) })
        XCTAssertEqual(try plan.restore(values)["greeting"], "Hallo {{user}}. Willkommen, {{char}}.")
        XCTAssertFalse(plan.requests.contains { $0.text.contains("{{") })
        XCTAssertThrowsError(try plan.restore([:]))
        XCTAssertTrue(CharacterGenre.guideverse.matches(.init(name: "Rollen", tags: ["Guideverse"])))
        XCTAssertTrue(CharacterGenre.guideverse.matches(.init(name: "Esper and Guide")))
        XCTAssertFalse(CharacterGenre.guideverse.matches(.init(name: "Travel Guide")))
        XCTAssertEqual(JannyCatalogueCodec.query("", genre: .guideverse), "Guideverse")
    }
    func testOpenRouterAsksToDisableReasoningWithoutChangingOtherAPIs() throws {
        let prompt = BuiltPrompt(system: "Deutsch", messages: [.init(role: "user", content: "Hallo")], retrievedCount: 0, truncated: false)
        for kind in [ProviderKind.openRouter, .compatible] {
            let data = try InferencePayload.encode(kind: kind, model: "openrouter/free", prompt: prompt, maxTokens: 1200)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let reasoning = object["reasoning"] as? [String: Bool]
            if kind == .openRouter { XCTAssertEqual(reasoning, ["enabled": false, "exclude": true]) }
            else { XCTAssertNil(reasoning) }
        }
    }
}
