import XCTest
import FadenCore
@testable import Faden

@MainActor final class CloudEngineTests: XCTestCase {
    private func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StreamFixture.self]
        return URLSession(configuration: config)
    }
    func testOfficialChatGPTResponseWithoutHeaderTraversesActualByteStream() async throws {
        let connection = Connection(name: "ChatGPT", kind: .chatGPT, baseURL: "https://api.openai.com/v1")
        var output = ""
        let result = try await CloudEngine.generate(connection: connection, model: "headerless", key: "test-not-a-real-key", prompt: prompt, maxTokens: 64, session: session()) { output += $0; return false }
        XCTAssertEqual(output, "Guten Abend.")
        XCTAssertEqual(result.text, output)
        XCTAssertEqual(result.diagnostic.httpStatus, 200)
        XCTAssertGreaterThan(result.diagnostic.events, 0)
        XCTAssertEqual(result.diagnostic.textCharacters, output.count)
    }
    func testOpenRouterTextStreamAndRequestBody() async throws {
        let connection = Connection(name: "Free", kind: .openRouter, baseURL: "https://openrouter.ai/api/v1")
        var output = ""
        try await CloudEngine.generate(connection: connection, model: "free-fixture", key: "test-not-a-real-key", prompt: prompt, maxTokens: 64, session: session()) { output += $0; return false }
        XCTAssertEqual(output, "Guten Abend.")
    }
    func testAccountLimitAndReasoningOnlyResponseAreFailures() async throws {
        let connection = Connection(name: "Free", kind: .openRouter, baseURL: "https://openrouter.ai/api/v1")
        for model in ["blocked", "reasoning-only", "truncated", "html"] {
            do {
                try await CloudEngine.generate(connection: connection, model: model, key: "test-not-a-real-key", prompt: prompt, maxTokens: 64, session: session()) { _ in XCTFail("No character text expected"); return false }
                XCTFail("A failed or empty stream must not be reported as success: \(model)")
            } catch let error as ProviderFailure {
                if model == "blocked" { XCTAssertTrue(error.blocksConnection) }
                if model == "truncated" { XCTAssertTrue(error.text.contains("Ausgabelimit")) }
            }
        }
    }
    func testFinalSnapshotAndJSONResponseAreNotLost() async throws {
        let connection = Connection(name: "ChatGPT", kind: .chatGPT, baseURL: "https://api.openai.com/v1")
        for model in ["snapshot-only", "json-response"] {
            var output = ""
            let result = try await CloudEngine.generate(connection: connection, model: model, key: "test-not-a-real-key", prompt: prompt, maxTokens: 64, session: session()) { output += $0; return false }
            XCTAssertEqual(output, "Guten Abend."); XCTAssertEqual(result.text, output)
        }
    }
    func testFailureHasActionableMetadataWithoutPromptOrKey() async throws {
        let connection = Connection(name: "Free", kind: .openRouter, baseURL: "https://openrouter.ai/api/v1")
        do {
            _ = try await CloudEngine.generate(connection: connection, model: "blocked", key: "test-not-a-real-key", prompt: prompt, maxTokens: 64, session: session()) { _ in false }
            XCTFail("Must fail")
        } catch let failure as ProviderFailure {
            let report = try XCTUnwrap(failure.diagnostic)
            XCTAssertEqual(report.httpStatus, 429); XCTAssertEqual(report.errorCode, "http_429")
            XCTAssertTrue(report.readable.contains("HTTP: 429"))
            XCTAssertFalse(report.readable.contains("test-not-a-real-key")); XCTAssertFalse(report.readable.contains("Hallo"))
        }
    }
    func testLiveDedicatedGoogleTranslationPreservesVariablesAndGreeting() async throws {
        let previous = UserDefaults.standard.string(forKey: "translationEngine")
        UserDefaults.standard.set("google", forKey: "translationEngine")
        defer { if let previous { UserDefaults.standard.set(previous, forKey: "translationEngine") } else { UserDefaults.standard.removeObject(forKey: "translationEngine") } }
        let original = CharacterCard(name: "Translation acceptance", description: "The detective waits at the railway station. It is raining outside.", firstMessage: "Good evening, {{user}}. Come in.")
        let translated = try await GermanTranslator().germanize(original, scope: "acceptance-test")
        XCTAssertEqual(translated.languageCode, "de")
        XCTAssertTrue(translated.firstMessage.contains("{{user}}"))
        XCTAssertTrue(translated.firstMessage.localizedCaseInsensitiveContains("Guten Abend"))
        XCTAssertNotEqual(translated.description, original.description)
    }
    private var prompt: BuiltPrompt { .init(system: "Deutsch", messages: [.init(role: "user", content: "Hallo")], retrievedCount: 0, truncated: false) }
}

final class StreamFixture: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var data = request.httpBody
        if data == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096); var body = Data()
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; body.append(contentsOf: buffer.prefix(n)) }
            data = body
        }
        let object = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any] ?? [:]
        let model = object["model"] as? String ?? ""
        let status = model == "blocked" ? 429 : 200
        var headers = ["Content-Type": "text/event-stream"]
        let text: String
        switch model {
        case "headerless":
            headers = [:]
            text = "event: response.output_text.delta\r\ndata: {\"type\":\"response.output_text.delta\",\"delta\":\"Guten Abend.\"}\r\n\r\ndata: {\"type\":\"response.completed\"}\r\n\r\n"
        case "snapshot-only":
            text = "data: {\"type\":\"response.completed\",\"response\":{\"status\":\"completed\",\"output\":[{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"Guten Abend.\"}]}]}}\n\n"
        case "json-response":
            headers = ["Content-Type": "application/json"]
            text = "{\"status\":\"completed\",\"error\":null,\"output\":[{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"Guten Abend.\"}]}]}"
        case "blocked": text = "{\"error\":{\"code\":429}}"
        case "html": headers = ["Content-Type": "text/html"]; text = "<html>Unexpected response</html>"
        case "reasoning-only", "truncated":
            let reason = model == "truncated" ? "length" : "stop"
            text = "data: {\"choices\":[{\"delta\":{\"reasoning\":\"internal\",\"content\":null}}]}\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"\(reason)\"}]}\n\ndata: [DONE]\n\n"
        default:
            if request.url?.host == "openrouter.ai" {
                XCTAssertEqual(object["reasoning"] as? [String: Bool], ["enabled": false, "exclude": true])
            }
            text = "data: {\"choices\":[{\"delta\":{\"content\":\"Guten \"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"Abend.\"}}]}\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n"
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        // Fragment across UTF-8/SSE boundaries to exercise the real byte reader.
        let bytes = Array(text.utf8)
        for offset in stride(from: 0, to: bytes.count, by: 7) { client?.urlProtocol(self, didLoad: Data(bytes[offset..<min(offset + 7, bytes.count)])) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
