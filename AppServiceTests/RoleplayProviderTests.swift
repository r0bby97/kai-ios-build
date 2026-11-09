import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import FadenCore
@testable import Faden

@MainActor final class RoleplayProviderTests: XCTestCase {
    private let prompt = BuiltPrompt(system: "Mara bleibt Archivarin. Keine Nutzerbeiträge erfinden.", messages: [.init(role: "user", content: "Guten Abend.")], retrievedCount: 0, truncated: false)
    private func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [RoleplayProviderFixture.self]
        return URLSession(configuration: config)
    }
    func testHordeUsesAsyncChatAndPublishesOnlyTheCompletedReply() async throws {
        var text = ""; var status = ""
        let result = try await CloudEngine.generate(connection: .horde, model: HordeCodec.automaticModel, key: "", prompt: prompt, maxTokens: 64, session: session(), onStatus: { status = $0 }) {
            text += $0; return false
        }
        XCTAssertEqual(text, "Guten Abend, ich bin Mara.")
        XCTAssertEqual(result.text, text)
        XCTAssertTrue(status.contains("Antwort wird erzeugt"))
        XCTAssertEqual(result.diagnostic.model, "koboldcpp/mini-magnum-12b-v1.1")
    }
    func testHordeLimitReachesExistingProviderFallbackContract() async throws {
        do {
            _ = try await CloudEngine.generate(connection: .horde, model: HordeCodec.automaticModel, key: "limit-fixture", prompt: prompt, maxTokens: 64, session: session()) { _ in XCTFail("No reply expected"); return false }
            XCTFail("The existing account-limit fallback must receive a failure")
        } catch let failure as ProviderFailure {
            XCTAssertTrue(failure.blocksConnection)
            XCTAssertEqual(failure.diagnostic?.httpStatus, 429)
            XCTAssertFalse(failure.diagnostic?.readable.contains("limit-fixture") ?? true)
        }
    }
    func testNamedBackupsUseTheirOfficialChatEndpointsAndBearerKeys() async throws {
        for preset in [APIProviderPreset.arli, .nanoGPT, .venice] {
            let connection = preset.connection(); var text = ""
            let result = try await CloudEngine.generate(connection: connection, model: "fixture-model", key: "api-fixture-key", prompt: prompt, maxTokens: 64, session: session()) { text += $0; return false }
            XCTAssertEqual(text, "Guten Abend."); XCTAssertEqual(result.text, text)
        }
    }
    func testHordeAndBackupsLoadModelListsUsingTheSameService() async throws {
        for preset in [APIProviderPreset.arli, .nanoGPT, .venice] {
            let list = try await CloudEngine.models(connection: preset.connection(), key: "api-fixture-key", session: session())
            XCTAssertEqual(list.first?.id, "fixture-model")
        }
        let horde = try await CloudEngine.models(connection: .horde, key: "", session: session())
        XCTAssertEqual(horde.first?.id, HordeCodec.automaticModel)
        XCTAssertTrue(horde.allSatisfy(\.isFree))
    }
    func testHordeCredentialsCannotBeRoutedToAnotherAddress() async throws {
        var connection = Connection.horde; connection.baseURL = "https://other.example/api/v2"
        do {
            _ = try await CloudEngine.generate(connection: connection, model: HordeCodec.automaticModel, key: "private-fixture", prompt: prompt, maxTokens: 64, session: session()) { _ in false }
            XCTFail("An altered base must fail before any request")
        } catch let error as FadenError { XCTAssertTrue(error.localizedDescription.contains("offizielle AI-Horde-API")) }
    }
}

private final class RoleplayProviderFixture: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        do {
            let url = request.url!; var status = 200; var object: [String: Any] = [:]; let data: Data
            if url.host == "aihorde.net" {
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                if url.path == "/api/v2/workers" {
                    XCTAssertNil(request.value(forHTTPHeaderField: "apikey"))
                    data = try JSONSerialization.data(withJSONObject: [["id": "00000000-0000-4000-8000-000000000001", "trusted": true, "nsfw": true,
                        "chat": ["model_id": "koboldcpp/mini-magnum-12b-v1.1", "features": ["prompt_overflow_refused"], "limits": ["max_context_length": 8192, "max_length": 2048]]]])
                } else {
                    let body = try readBody()
                    if url.path == "/api/v2/generate/chat/async" {
                        XCTAssertEqual((body["horde"] as? [String: Any])?["context_fit"] as? String, "reject")
                        if request.value(forHTTPHeaderField: "apikey") == "limit-fixture" { status = 429; object = ["rc": "TooManyParallelRequests"] }
                        else { object = ["id": "00000000-0000-4000-8000-000000000002"] }
                    } else if request.httpMethod == "DELETE" { object = ["done": true] }
                    else if request.url?.query == nil && request.value(forHTTPHeaderField: "apikey") == "0000000000" {
                        // Alternate queued and completed states for this fixture.
                        let key = request.url!.absoluteString
                        Self.lock.lock(); let count = Self.counts[key, default: 0]; Self.counts[key] = count + 1; Self.lock.unlock()
                        if count.isMultiple(of: 2) { object = ["done": false, "is_possible": true, "processing": 1] }
                        else { object = ["done": true, "generations": [["model": "koboldcpp/mini-magnum-12b-v1.1", "state": "ok", "message": ["role": "assistant", "content": "Guten Abend, ich bin Mara.", "reasoning_content": "nicht anzeigen"]]]] }
                    } else { XCTFail("Unexpected Horde request"); status = 404 }
                    data = try JSONSerialization.data(withJSONObject: object)
                }
            } else {
                XCTAssertTrue(["api.arliai.com", "nano-gpt.com", "api.venice.ai"].contains(url.host ?? ""))
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer api-fixture-key")
                if url.path.hasSuffix("/models") {
                    if url.host == "api.venice.ai" { XCTAssertEqual(url.query, "type=text") }
                    object = ["data": [["id": "fixture-model", "name": "RP model"]]]
                } else {
                    XCTAssertTrue(url.path.hasSuffix("/chat/completions"))
                    let body = try readBody(); XCTAssertEqual(body["model"] as? String, "fixture-model")
                    XCTAssertEqual((body["messages"] as? [[String: String]])?.first?["role"], "system")
                    if url.host == "api.venice.ai" {
                        XCTAssertEqual((body["venice_parameters"] as? [String: Bool])?["include_venice_system_prompt"], false)
                    }
                    object = ["choices": [["message": ["role": "assistant", "content": "Guten Abend."], "finish_reason": "stop"]]]
                }
                data = try JSONSerialization.data(withJSONObject: object)
            }
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    private static let lock = NSLock()
    private static var counts: [String: Int] = [:]
    private func readBody() throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }; var bytes = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&bytes, maxLength: bytes.count); if n <= 0 { break }; data.append(contentsOf: bytes.prefix(n)) }
        }
        if data.isEmpty { return [:] }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}
