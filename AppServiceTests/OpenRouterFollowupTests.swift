import XCTest
import FadenCore
@testable import Faden

@MainActor final class OpenRouterFollowupTests: XCTestCase {
    private func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [FollowupFixture.self]
        return URLSession(configuration: config)
    }
    private var connection: Connection { .init(name: "OpenRouter-Test", kind: .openRouter, baseURL: "https://openrouter.ai/api/v1", models: ["second-turn:free"], contextTokens: 8192) }
    private var prompt: BuiltPrompt { .init(system: "Deutsch", messages: [.init(role: "assistant", content: "CARD_OPENING"), .init(role: "user", content: "FIRST_USER"), .init(role: "assistant", content: "FIRST_REPLY"), .init(role: "user", content: "SECOND_USER")], retrievedCount: 0, truncated: false) }
    func testActualSecondTurnTransportKeepsHistoryInAcceptedRoleOrder() async throws {
        let result = try await CloudEngine.generate(connection: connection, model: "second-turn:free", key: "synthetic-valid", prompt: prompt, maxTokens: 64, session: session()) { _ in false }
        XCTAssertEqual(result.text, "Verlauf erhalten.")
    }
    func testModelLevel401WithConfirmedValidKeyAllowsAnotherModel() async throws {
        do {
            _ = try await CloudEngine.generate(connection: connection, model: "denied:free", key: "synthetic-valid", prompt: prompt, maxTokens: 64, session: session()) { _ in false }
            XCTFail("A rejected model must not become success")
        } catch let failure as ProviderFailure {
            XCTAssertFalse(failure.blocksConnection)
            XCTAssertTrue(failure.retryable)
            XCTAssertEqual(failure.diagnostic?.errorCode, "model_access_denied_key_valid")
            XCTAssertFalse(failure.diagnostic?.readable.contains("synthetic-valid") ?? true)
        }
    }
    func testActuallyInvalidKeyStillBlocksTheConnection() async throws {
        do {
            _ = try await CloudEngine.generate(connection: connection, model: "denied:free", key: "synthetic-invalid", prompt: prompt, maxTokens: 64, session: session()) { _ in false }
            XCTFail("Invalid credentials must not be retried across models")
        } catch let failure as ProviderFailure { XCTAssertTrue(failure.blocksConnection) }
    }
    func testFallbackUsesTheKnownModelWindowAndLocalMemoryIsBounded() async throws {
        _ = try await CloudEngine.models(connection: connection, key: "synthetic-valid", session: session())
        XCTAssertEqual(CloudEngine.contextWindow(connection: connection, model: "fixture-small:free"), 2048)
        XCTAssertEqual(CloudEngine.contextWindow(connection: connection, model: "unknown:free"), 8192)
        let local = Connection(name: "Local", kind: .local, contextTokens: 65536)
        XCTAssertEqual(CloudEngine.contextWindow(connection: local, model: "local"), 8192)
    }
}

private final class FollowupFixture: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "openrouter.ai" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        let path = request.url!.path
        var data: Data, status = 200, mime = "application/json"
        if path == "/api/v1/key" {
            status = request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-invalid" ? 401 : 200
            data = Data(#"{"data":{"is_free_tier":true}}"#.utf8)
        } else if path == "/api/v1/models" {
            data = Data(#"{"data":[{"id":"fixture-small:free","context_length":2048,"architecture":{"output_modalities":["text"]}}]}"#.utf8)
        } else if path == "/api/v1/chat/completions" {
            let body = request.httpBody ?? Self.read(request.httpBodyStream)
            let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
            let model = object["model"] as? String ?? ""
            if model == "denied:free" { status = 401; data = Data(#"{"error":{"message":"Provider rejected this model"}}"#.utf8) }
            else {
                let turns = object["messages"] as? [[String: String]] ?? []
                XCTAssertEqual(turns.map { $0["role"] ?? "" }, ["system", "user", "assistant", "user"])
                XCTAssertTrue(turns.first?["content"]?.contains("CARD_OPENING") == true)
                XCTAssertEqual(turns[1]["content"], "FIRST_USER")
                XCTAssertEqual(turns[2]["content"], "FIRST_REPLY")
                XCTAssertEqual(turns[3]["content"], "SECOND_USER")
                mime = "text/event-stream"
                data = Data("data: {\"choices\":[{\"delta\":{\"content\":\"Verlauf erhalten.\"}}]}\n\ndata: [DONE]\n\n".utf8)
            }
        } else { XCTFail("Unexpected route: \(path)"); status = 404; data = Data() }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": mime])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
    }
    private static func read(_ stream: InputStream?) -> Data {
        guard let stream else { return Data() }; stream.open(); defer { stream.close() }
        var bytes = [UInt8](repeating: 0, count: 4096), result = Data()
        while stream.hasBytesAvailable { let count = stream.read(&bytes, maxLength: bytes.count); if count <= 0 { break }; result.append(contentsOf: bytes.prefix(count)) }
        return result
    }
}
