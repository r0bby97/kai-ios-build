import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import FadenCore

final class AIHordeTests: XCTestCase {
    private let prompt = BuiltPrompt(system: "PRIVATE-PROMPT-MARKER: Mara bleibt eine ruhige Ermittlerin. Keine Nutzerbeiträge erfinden.", messages: [.init(role: "user", content: "Guten Abend.")], retrievedCount: 0, truncated: false)
    private func client(_ mode: HordeFixture.Mode = .success) -> AIHordeClient {
        HordeFixture.reset(mode)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [HordeFixture.self]
        return .init(session: URLSession(configuration: config), pollInterval: 0.002)
    }
    func testNativeChatTransportPreservesSystemAndReturnsOnlyVisibleReply() async throws {
        let result = try await client().generate(model: HordeCodec.automaticModel, key: "", prompt: prompt, maxTokens: 64, contextTokens: 4096)
        XCTAssertEqual(result.text, "Guten Abend, ich bin Mara.")
        XCTAssertEqual(result.diagnostic.model, HordeFixture.model)
        XCTAssertEqual(result.diagnostic.outputTokens, 12)
        XCTAssertFalse(result.diagnostic.readable.contains("PRIVATE-PROMPT"))
        XCTAssertFalse(result.diagnostic.readable.contains("Geheime Berechnung"))
        XCTAssertFalse(result.diagnostic.readable.contains("Guten Abend, ich bin Mara."))
        let posts = HordeFixture.posts
        XCTAssertEqual(posts.count, 1)
        let body = try object(posts[0])
        XCTAssertEqual((body["messages"] as? [[String: String]])?.first, ["role": "system", "content": prompt.system])
        let options = try XCTUnwrap(body["horde"] as? [String: Any])
        XCTAssertEqual(options["context_fit"] as? String, "reject")
        XCTAssertEqual(options["conformance"] as? String, "strict")
        XCTAssertEqual(options["include_reasoning"] as? Bool, false)
        XCTAssertEqual(HordeFixture.keys, ["0000000000"])
    }
    func testCancellationDeletesQueuedJobWithoutAnotherGeneration() async throws {
        let service = client(.waiting)
        let queued = expectation(description: "Horde job was queued")
        let task = Task { try await service.generate(model: HordeCodec.automaticModel, key: "test-horde-key", prompt: prompt, maxTokens: 64, contextTokens: 4096, progress: { _ in queued.fulfill() }) }
        queued.assertForOverFulfill = false
        await fulfillment(of: [queued], timeout: 2); task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled job must not return a reply") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        XCTAssertEqual(HordeFixture.deleteCount, 1)
        XCTAssertEqual(HordeFixture.posts.count, 1)
    }
    func testTimeoutDeletesJobAndAllowsNextProvider() async throws {
        do {
            _ = try await client(.waiting).generate(model: HordeCodec.automaticModel, key: "", prompt: prompt, maxTokens: 64, contextTokens: 4096, timeoutSeconds: 0.03)
            XCTFail("Waiting must be bounded")
        } catch let error as HordeFailure {
            XCTAssertEqual(error.code, "queue_timeout"); XCTAssertFalse(error.blocksConnection)
        }
        XCTAssertEqual(HordeFixture.deleteCount, 1)
    }
    func testLostReceiptRetriesIdenticalOperationInsteadOfDuplicatingJob() async throws {
        let result = try await client(.lostReceipt).generate(model: HordeCodec.automaticModel, key: "", prompt: prompt, maxTokens: 64, contextTokens: 4096)
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertEqual(HordeFixture.posts.count, 2)
        XCTAssertEqual(HordeFixture.posts[0], HordeFixture.posts[1])
    }
    func testExplicitFreeAllowanceOnlyReducesOutputAndKeepsContextUnchanged() async throws {
        _ = try await client(.allowance).generate(model: HordeCodec.automaticModel, key: "", prompt: prompt, maxTokens: 64, contextTokens: 4096)
        let first = try object(HordeFixture.posts[0]), second = try object(HordeFixture.posts[1])
        XCTAssertEqual(first["max_tokens"] as? Int, 64)
        XCTAssertEqual(second["max_tokens"] as? Int, 32)
        XCTAssertEqual(first["messages"] as? [[String: String]], second["messages"] as? [[String: String]])
        let firstContext = try XCTUnwrap((first["horde"] as? [String: Any])?["max_context_length"] as? Int)
        let secondContext = try XCTUnwrap((second["horde"] as? [String: Any])?["max_context_length"] as? Int)
        XCTAssertEqual(secondContext, max(256, prompt.estimatedTokens + 192 + 32))
        XCTAssertLessThanOrEqual(secondContext, firstContext, "Worker budget follows the shorter output while all messages stay identical")
    }
    func testSmallerWorkerCanGiveAShorterReplyWithoutDroppingThePersona() async throws {
        _ = try await client(.smallOutput).generate(model: HordeCodec.automaticModel, key: "", prompt: prompt, maxTokens: 64, contextTokens: 4096)
        let body = try object(HordeFixture.posts[0])
        XCTAssertEqual(body["max_tokens"] as? Int, 32)
        XCTAssertEqual((body["messages"] as? [[String: String]])?.first?["content"], prompt.system)
        XCTAssertEqual(HordeFixture.posts.count, 1)
    }
    func testAccountLimitDoesNotTryAnotherHordeModelOrSubmitAnotherJob() async throws {
        do {
            _ = try await client(.rateLimit).generate(model: HordeCodec.automaticModel, key: "test-horde-key", prompt: prompt, maxTokens: 64, contextTokens: 4096)
            XCTFail("429 must stay a limit")
        } catch let error as HordeFailure {
            XCTAssertTrue(error.blocksConnection)
            XCTAssertEqual(error.httpStatus, 429)
            XCTAssertFalse(error.diagnostic?.readable.contains("test-horde-key") ?? true)
        }
        XCTAssertEqual(HordeFixture.posts.count, 1)
        XCTAssertEqual(HordeFixture.deleteCount, 0)
    }
    func testNoCapacityDoesNotDropCharacterContextToForceAnAnswer() async throws {
        do {
            _ = try await client(.smallWorker).generate(model: HordeCodec.automaticModel, key: "", prompt: prompt, maxTokens: 64, contextTokens: 4096)
            XCTFail("A too-small worker must be skipped")
        } catch let error as HordeFailure { XCTAssertEqual(error.code, "no_eligible_worker") }
        XCTAssertTrue(HordeFixture.posts.isEmpty)
    }
    func testFilteredEmptyWrongModelAndSilentlyTruncatedRepliesAreRejected() async throws {
        for (mode, code) in [(HordeFixture.Mode.filtered, "content_filter"), (.empty, "empty_output"), (.wrongModel, "model_mismatch"), (.truncated, "context_truncated")] {
            do {
                _ = try await client(mode).generate(model: HordeCodec.automaticModel, key: "", prompt: prompt, maxTokens: 64, contextTokens: 4096)
                XCTFail("\(code) must not publish character text")
            } catch let error as HordeFailure { XCTAssertEqual(error.code, code) }
            XCTAssertEqual(HordeFixture.deleteCount, 1)
        }
    }
    func testTemporaryStatusFailureDoesNotResubmitGeneration() async throws {
        let result = try await client(.temporaryStatusFailure).generate(model: HordeCodec.automaticModel, key: "", prompt: prompt, maxTokens: 64, contextTokens: 4096)
        XCTAssertFalse(result.text.isEmpty); XCTAssertEqual(HordeFixture.posts.count, 1)
    }
    func testOnlyNsfwTrustedChatWorkersWithOverflowRefusalAreListed() throws {
        var rows = try XCTUnwrap(JSONSerialization.jsonObject(with: HordeFixture.workerData()) as? [[String: Any]])
        let original = rows[0]
        var sfw = original; sfw["nsfw"] = false; rows.append(sfw)
        var untrusted = original; untrusted["trusted"] = false; rows.append(untrusted)
        var raw = original; raw.removeValue(forKey: "chat"); rows.append(raw)
        var unsupported = original; unsupported["chat"] = ["model_id": "other", "features": [], "limits": ["max_context_length": 8192, "max_length": 2048]]; rows.append(unsupported)
        let workers = try HordeCodec.workers(JSONSerialization.data(withJSONObject: rows))
        XCTAssertEqual(workers.count, 1)
    }
    func testNoEligibleWorkerIsCapacityAndNotAnInvalidKey() {
        let failure = HordeCodec.failure(status: 403, data: Data(#"{"rc":"NoEligibleWorker","message":"private upstream text"}"#.utf8))
        XCTAssertFalse(failure.blocksConnection)
        XCTAssertTrue(failure.retryable)
        XCTAssertTrue(failure.message.contains("keinen passenden Chat-Rechner"))
        XCTAssertFalse(failure.message.contains("private upstream text"))
        let denied = HordeCodec.failure(status: 403, data: Data(#"{"rc":"InvalidAPIKey"}"#.utf8))
        XCTAssertTrue(denied.blocksConnection)
    }
    func testStaleCapacityIsRefreshedOnceWithoutDroppingAnyMessages() async throws {
        _ = try await client(.staleCapacity).generate(model: HordeCodec.automaticModel, key: "", prompt: prompt, maxTokens: 64, contextTokens: 4096)
        XCTAssertEqual(HordeFixture.posts.count, 2)
        let first = try object(HordeFixture.posts[0]), second = try object(HordeFixture.posts[1])
        XCTAssertEqual(first["messages"] as? [[String: String]], second["messages"] as? [[String: String]])
        XCTAssertEqual(first["max_tokens"] as? Int, second["max_tokens"] as? Int)
        XCTAssertNotEqual((first["horde"] as? [String: Any])?["operation_key"] as? String, (second["horde"] as? [String: Any])?["operation_key"] as? String)
    }
    func testPersistentCapacityFailureIsBoundedAndStillAllowsOtherProviders() async throws {
        do {
            _ = try await client(.noEligible).generate(model: HordeCodec.automaticModel, key: "", prompt: prompt, maxTokens: 64, contextTokens: 4096)
            XCTFail("Unavailable capacity must not become a fake success")
        } catch let failure as HordeFailure {
            XCTAssertEqual(failure.code, "NoEligibleWorker")
            XCTAssertEqual(failure.httpStatus, 403)
            XCTAssertFalse(failure.blocksConnection)
        }
        XCTAssertEqual(HordeFixture.posts.count, 2)
        XCTAssertEqual(HordeFixture.deleteCount, 0, "No job was accepted")
    }
    private func object(_ data: Data) throws -> [String: Any] { try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]) }
}

private final class HordeFixture: URLProtocol {
    enum Mode { case success, waiting, lostReceipt, allowance, rateLimit, smallWorker, smallOutput, filtered, empty, wrongModel, truncated, temporaryStatusFailure, staleCapacity, noEligible }
    static let model = "koboldcpp/mini-magnum-12b-v1.1"
    private static let lock = NSLock()
    private static var mode = Mode.success
    private static var capturedPosts: [Data] = []
    private static var capturedKeys: [String] = []
    private static var deletes = 0
    private static var statuses = 0
    static var posts: [Data] { lock.lock(); defer { lock.unlock() }; return capturedPosts }
    static var keys: [String] { lock.lock(); defer { lock.unlock() }; return capturedKeys }
    static var deleteCount: Int { lock.lock(); defer { lock.unlock() }; return deletes }
    static func reset(_ value: Mode) { lock.lock(); defer { lock.unlock() }; mode = value; capturedPosts = []; capturedKeys = []; deletes = 0; statuses = 0 }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        do {
            XCTAssertEqual(request.url?.host, "aihorde.net")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            Self.lock.lock(); let mode = Self.mode; Self.lock.unlock()
            let path = request.url!.path
            var status = 200; let data: Data
            if path == "/api/v2/workers" {
                XCTAssertNil(request.value(forHTTPHeaderField: "apikey"))
                data = try Self.workerData(context: mode == .smallWorker ? 256 : 8192, output: mode == .smallOutput ? 32 : 2048)
            } else if request.httpMethod == "DELETE" {
                Self.lock.lock(); Self.deletes += 1; Self.lock.unlock()
                data = Data(#"{"done":true}"#.utf8)
            } else if path == "/api/v2/generate/chat/async" {
                let body = try readBody(request)
                Self.lock.lock(); Self.capturedPosts.append(body); Self.capturedKeys.append(request.value(forHTTPHeaderField: "apikey") ?? ""); let count = Self.capturedPosts.count; Self.lock.unlock()
                if mode == .lostReceipt && count == 1 { client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost)); return }
                if mode == .noEligible || mode == .staleCapacity && count == 1 { status = 403; data = Data(#"{"rc":"NoEligibleWorker"}"#.utf8) }
                else if mode == .rateLimit { status = 429; data = Data(#"{"rc":"TooManyParallelRequests","message":"limited"}"#.utf8) }
                else if mode == .allowance && count == 1 {
                    status = 400; data = Data(#"{"rc":"KudosUpfront","message":"The workers currently serve up to 32 tokens without kudos held upfront."}"#.utf8)
                } else { status = 202; data = Data(#"{"id":"00000000-0000-4000-8000-000000000002"}"#.utf8) }
            } else if path == "/api/v2/generate/chat/status/00000000-0000-4000-8000-000000000002" {
                Self.lock.lock(); Self.statuses += 1; let count = Self.statuses; Self.lock.unlock()
                if mode == .waiting || count == 1 && mode != .temporaryStatusFailure { data = Data(#"{"done":false,"is_possible":true,"processing":0,"waiting":1}"#.utf8) }
                else if mode == .temporaryStatusFailure && count == 1 { status = 503; data = Data(#"{"message":"temporarily unavailable"}"#.utf8) }
                else {
                    let generation: [String: Any] = ["model": mode == .wrongModel ? "unselected-model" : Self.model,
                        "state": mode == .filtered ? "censored" : "ok", "finish_reason": mode == .filtered ? "content_filter" : "stop", "completion_tokens": 12,
                        "message": ["role": "assistant", "content": mode == .empty ? "" : "Guten Abend, ich bin Mara.", "reasoning_content": "Geheime Berechnung"]]
                    var object: [String: Any] = ["done": true, "is_possible": true, "generations": [generation]]
                    if mode == .truncated { object["context_adjustments"] = [["reason": "truncate_oldest", "dropped_messages": 2]] }
                    data = try JSONSerialization.data(withJSONObject: object)
                }
            } else { XCTFail("Unexpected request: \(path)"); status = 404; data = Data() }
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    static func workerData(context: Int = 8192, output: Int = 2048) throws -> Data {
        try JSONSerialization.data(withJSONObject: [["id": "00000000-0000-4000-8000-000000000001", "trusted": true, "nsfw": true,
            "chat": ["model_id": model, "features": ["prompt_overflow_refused"], "limits": ["max_context_length": context, "max_length": output]]]])
    }
    private func readBody(_ request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }; var result = Data(); var bytes = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable { let count = stream.read(&bytes, maxLength: bytes.count); if count <= 0 { break }; result.append(contentsOf: bytes.prefix(count)) }
        return result
    }
}
