import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HordeModel: Sendable, Equatable {
    public var id: String
    public var contextTokens: Int
    public var outputTokens: Int
}
public struct HordeWorker: Sendable {
    public var id: String
    public var model: HordeModel
}
public enum HordeProgress: Sendable {
    case waiting, generating, outputLimit(Int)
    public var message: String {
        switch self {
        case .waiting: "AI Horde · wartet auf einen freien Rechner"
        case .generating: "AI Horde · Antwort wird erzeugt"
        case .outputLimit(let tokens): "AI Horde · Gratis-Ausgabe derzeit auf \(tokens) Tokens begrenzt"
        }
    }
}
public struct HordeFailure: LocalizedError, Sendable {
    public var message: String
    public var code: String
    public var httpStatus: Int?
    public var blocksConnection: Bool
    public var retryable: Bool
    public var freeOutputAllowance: Int?
    public var diagnostic: InferenceDiagnostic?
    public var errorDescription: String? { message }
    public init(_ message: String, code: String, httpStatus: Int? = nil, blocksConnection: Bool = false,
                retryable: Bool = true, freeOutputAllowance: Int? = nil) {
        self.message = message; self.code = code; self.httpStatus = httpStatus
        self.blocksConnection = blocksConnection; self.retryable = retryable; self.freeOutputAllowance = freeOutputAllowance
    }
}

public enum HordeCodec {
    public static let automaticModel = "horde/roleplay-auto"
    public static func isRoleplayModel(_ name: String) -> Bool { rank(name) < 10 }
    public static func workers(_ data: Data) throws -> [HordeWorker] {
        guard data.count <= 4 * 1024 * 1024, let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw HordeFailure("AI Horde liefert keine lesbare Rechnerliste.", code: "invalid_workers")
        }
        return rows.compactMap { row in
            guard row["nsfw"] as? Bool == true, row["trusted"] as? Bool == true,
                  row["maintenance_mode"] as? Bool != true, let id = row["id"] as? String, UUID(uuidString: id) != nil,
                  let chat = row["chat"] as? [String: Any], let model = chat["model_id"] as? String, !model.isEmpty,
                  (chat["features"] as? [String] ?? []).contains("prompt_overflow_refused"),
                  let limits = chat["limits"] as? [String: Any], let context = limits["max_context_length"] as? Int,
                  let output = limits["max_length"] as? Int, context >= 80, output >= 16 else { return nil }
            return .init(id: id, model: .init(id: model, contextTokens: context, outputTokens: output))
        }
    }
    public static func models(_ workers: [HordeWorker]) -> [HordeModel] {
        Dictionary(grouping: workers, by: { $0.model.id }).values.compactMap { group in
            guard let first = group.first else { return nil }
            return HordeModel(id: first.model.id, contextTokens: group.map { $0.model.contextTokens }.max()!, outputTokens: group.map { $0.model.outputTokens }.max()!)
        }.sorted { rank($0.id) == rank($1.id) ? $0.id < $1.id : rank($0.id) < rank($1.id) }
    }
    public static func selection(_ workers: [HordeWorker], model: String, contextTokens: Int, outputTokens: Int) throws -> [HordeWorker] {
        let eligible = workers.filter {
            (model == automaticModel ? rank($0.model.id) < 10 : $0.model.id == model) &&
            $0.model.contextTokens >= contextTokens && $0.model.outputTokens >= outputTokens
        }.sorted { rank($0.model.id) == rank($1.model.id) ? $0.model.contextTokens > $1.model.contextTokens : rank($0.model.id) < rank($1.model.id) }
        guard !eligible.isEmpty else {
            throw HordeFailure("AI Horde: Kein geeigneter freier Chat-Rechner bietet gerade \(contextTokens) Kontext- und \(outputTokens) Ausgabe-Tokens. Die Charakterregeln werden dafür nicht abgeschnitten.", code: "no_eligible_worker")
        }
        return Array(eligible.prefix(5))
    }
    public static func payload(prompt: BuiltPrompt, workers: [HordeWorker], contextTokens: Int, maxTokens: Int, operationID: UUID) throws -> Data {
        var seen = Set<String>()
        let models = workers.map { $0.model.id }.filter { seen.insert($0).inserted }
        guard !models.isEmpty else { throw HordeFailure("AI Horde: Es ist kein Chat-Modell ausgewählt.", code: "no_model") }
        let messages = [["role": "system", "content": prompt.system]] + prompt.messages.map { ["role": $0.role, "content": $0.content] }
        // Native chat workers apply their own tokenizer/template. They must refuse overflow;
        // dropping the front of a raw completion could erase the personality and viewpoint rules.
        let body: [String: Any] = ["models": models, "messages": messages, "max_tokens": maxTokens, "stream": false,
            "horde": ["only": workers.map(\.id), "trusted_workers": true, "slow_workers": true,
                      "max_context_length": contextTokens, "context_fit": "reject", "conformance": "strict",
                      "include_reasoning": false, "operation_key": operationID.uuidString.lowercased()]]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }
    public static func failure(status: Int, data: Data) -> HordeFailure {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let code = metadataCode(object["rc"], fallback: "http_\(status)")
        let suffix = " (HTTP \(status), \(String(code.prefix(80))))"
        if code == "KudosUpfront" {
            let message = object["message"] as? String ?? ""
            let allowance = message.range(of: #"(?i)up to [0-9]+ tokens"#, options: .regularExpression).flatMap { range in
                Int(message[range].filter(\.isNumber))
            }
            return .init("AI Horde verlangt für diese Antwort mehr Kudos. Ein regulärer kostenloser Horde-Zugang kann helfen; die Priorität hängt vom Guthaben und freien Rechnern ab." + suffix,
                         code: code, httpStatus: status, blocksConnection: true, freeOutputAllowance: allowance)
        }
        switch status {
        case 401, 403: return .init("AI Horde akzeptiert den Schlüssel oder diese Anfrage nicht." + suffix, code: code, httpStatus: status, blocksConnection: true)
        case 429: return .init("Das Nutzungslimit dieses Horde-Zugangs ist erreicht. Kai wechselt zur nächsten eingerichteten Verbindung." + suffix, code: code, httpStatus: status, blocksConnection: true)
        case 400, 404, 413, 422: return .init("AI Horde kann Modell, Nachrichten oder Kontext in dieser Anfrage nicht verarbeiten." + suffix, code: code, httpStatus: status)
        default: return .init("AI Horde ist derzeit nicht erreichbar oder hat keine passende Kapazität." + suffix, code: code, httpStatus: status)
        }
    }
    private static func rank(_ name: String) -> Int {
        let name = name.lowercased()
        if name.contains("mini-magnum") { return 0 }
        if name.contains("magnum") { return 1 }
        if name.contains("behemoth") { return 2 }
        if name.contains("stheno") { return 3 }
        if name.contains("cydonia") { return 4 }
        return 10
    }
    static func metadataCode(_ value: Any?, fallback: String) -> String {
        guard let text = value as? String, text.range(of: #"^[A-Za-z0-9_-]{1,80}$"#, options: .regularExpression) != nil else { return fallback }
        return text
    }
}

public struct AIHordeClient: Sendable {
    public static let baseURL = "https://aihorde.net/api/v2"
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12; config.timeoutIntervalForResource = 20
        config.httpCookieStorage = nil; config.urlCache = nil
        return URLSession(configuration: config, delegate: HordeNoRedirects(), delegateQueue: nil)
    }()
    private let session: URLSession
    private let pollInterval: TimeInterval
    public init(session: URLSession? = nil, pollInterval: TimeInterval = 2) {
        self.session = session ?? Self.session; self.pollInterval = max(0.001, pollInterval)
    }
    public func models() async throws -> [HordeModel] {
        let response = try await exchange(path: "workers?type=text")
        guard response.status == 200 else { throw HordeCodec.failure(status: response.status, data: response.data) }
        return try HordeCodec.models(HordeCodec.workers(response.data))
    }
    public func generate(model: String, key: String, prompt: BuiltPrompt, maxTokens: Int, contextTokens: Int,
                         timeoutSeconds: TimeInterval = 90, providerName: String = "AI Horde",
                         progress: @escaping @Sendable (HordeProgress) async -> Void = { _ in }) async throws -> InferenceResult {
        var report = InferenceDiagnostic(provider: providerName, model: model, host: "aihorde.net")
        var job: String?
        let credential = key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "0000000000" : key.trimmingCharacters(in: .whitespacesAndNewlines)
        let wait = max(0.01, min(300, timeoutSeconds.isFinite ? timeoutSeconds : 90))
        let clock = ContinuousClock(); let deadline = clock.now.advanced(by: .seconds(wait))
        do {
            let available = try await exchange(path: "workers?type=text")
            guard available.status == 200 else { throw HordeCodec.failure(status: available.status, data: available.data) }
            let workers = try HordeCodec.workers(available.data)
            let requestedOutput = min(16_384, max(16, maxTokens))
            let reservedContext = prompt.estimatedTokens + 192
            guard contextTokens >= reservedContext + 16 else {
                throw HordeFailure("AI Horde: Der vorbereitete Kontext passt nicht in das eingestellte Fenster. Er wurde nicht still gekürzt.", code: "context_overflow", retryable: false)
            }
            let capacities = workers.filter { model == HordeCodec.automaticModel ? HordeCodec.isRoleplayModel($0.model.id) : $0.model.id == model }
                .map { min($0.model.outputTokens, $0.model.contextTokens - reservedContext) }
            var output = min(requestedOutput, contextTokens - reservedContext, capacities.max() ?? 0)
            guard output >= 16 else { throw HordeFailure("AI Horde: Kein geeigneter Chat-Rechner kann den vollständigen Charakterkontext gerade verarbeiten.", code: "no_eligible_worker") }
            if output < requestedOutput { await progress(.outputLimit(output)) }
            let requiredContext = max(256, reservedContext + output)
            let selected = try HordeCodec.selection(workers, model: model, contextTokens: requiredContext, outputTokens: output)
            var payload = try HordeCodec.payload(prompt: prompt, workers: selected, contextTokens: requiredContext, maxTokens: output, operationID: UUID())
            try Task.checkCancellation()
            var submitted = try await submit(payload: payload, key: credential)
            if !(200..<300).contains(submitted.status) {
                let failure = HordeCodec.failure(status: submitted.status, data: submitted.data)
                // Respect the advertised free allowance; never shorten character/context data.
                if credential == "0000000000", let allowance = failure.freeOutputAllowance, allowance >= 16, allowance < output {
                    try Task.checkCancellation()
                    output = allowance
                    await progress(.outputLimit(allowance))
                    payload = try HordeCodec.payload(prompt: prompt, workers: selected, contextTokens: requiredContext, maxTokens: allowance, operationID: UUID())
                    submitted = try await submit(payload: payload, key: credential)
                }
            }
            report.httpStatus = submitted.status; report.bytes += submitted.data.count
            guard [200, 202].contains(submitted.status) else { throw HordeCodec.failure(status: submitted.status, data: submitted.data) }
            let receipt = try object(submitted.data)
            guard let id = receipt["id"] as? String, UUID(uuidString: id) != nil else {
                throw HordeFailure("AI Horde hat keine gültige Auftragsnummer geliefert.", code: "invalid_job")
            }
            job = id
            var transientErrors = 0
            while true {
                try Task.checkCancellation()
                guard clock.now < deadline else { throw HordeFailure("AI Horde hat innerhalb der eingestellten Wartezeit keine Antwort fertiggestellt. Der Auftrag wird abgebrochen und die nächste Verbindung kann übernehmen.", code: "queue_timeout") }
                let status = try await exchange(path: "generate/chat/status/" + id, key: credential)
                report.httpStatus = status.status; report.bytes += status.data.count; report.events += 1
                if (500...599).contains(status.status), transientErrors < 2 {
                    transientErrors += 1; try await Task.sleep(for: .seconds(pollInterval)); continue
                }
                guard status.status == 200 else { throw HordeCodec.failure(status: status.status, data: status.data) }
                let object = try object(status.data)
                if object["faulted"] as? Bool == true {
                    throw HordeFailure("Der Horde-Rechner konnte die Antwort nicht fertigstellen.", code: HordeCodec.metadataCode(object["fault_rc"], fallback: "worker_fault"))
                }
                if object["is_possible"] as? Bool == false {
                    throw HordeFailure("Kein passender Horde-Rechner kann den Auftrag gerade bearbeiten.", code: "no_capacity")
                }
                if object["done"] as? Bool == true {
                    if (object["context_adjustments"] as? [[String: Any]] ?? []).contains(where: { $0["reason"] as? String == "truncate_oldest" }) {
                        throw HordeFailure("AI Horde hat trotz der Vorgabe Nachrichten abgeschnitten. Diese Antwort wird nicht übernommen.", code: "context_truncated", retryable: false)
                    }
                    guard let generation = (object["generations"] as? [[String: Any]])?.first else {
                        throw HordeFailure("AI Horde hat den Auftrag ohne Antwort abgeschlossen.", code: "missing_generation")
                    }
                    let state = generation["state"] as? String ?? "ok"
                    let finish = generation["finish_reason"] as? String ?? "stop"
                    guard state == "ok", finish != "content_filter" else {
                        throw HordeFailure("Der Horde-Rechner hat die Antwort aufgrund seiner Inhaltsregeln beendet.", code: "content_filter", retryable: false)
                    }
                    let message = generation["message"] as? [String: Any] ?? [:]
                    // Hidden reasoning is never fictional character text.
                    let text = message["content"] as? String ?? ""
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw HordeFailure("Der Horde-Rechner lieferte keine sichtbare Antwort; Abschluss: \(String(finish.prefix(60))).", code: "empty_output")
                    }
                    if let actual = generation["model"] as? String {
                        guard selected.contains(where: { $0.model.id == actual }) else {
                            throw HordeFailure("AI Horde hat ein anderes als die ausgewählten Modelle gemeldet.", code: "model_mismatch", retryable: false)
                        }
                        report.model = actual
                    }
                    report.contentType = "application/json"; report.finishReason = finish
                    report.outputTokens = generation["completion_tokens"] as? Int; report.reasoningTokens = generation["reasoning_tokens"] as? Int
                    report.textEvents = 1; report.textCharacters = text.count; report.outcome = "Antwort empfangen"
                    job = nil
                    return .init(text: text, diagnostic: report)
                }
                await progress((object["processing"] as? Int ?? 0) > 0 ? .generating : .waiting)
                try await Task.sleep(for: .seconds(pollInterval))
            }
        } catch {
            if let job { await cancel(job: job, key: credential) }
            if Task.isCancelled || error is CancellationError { throw CancellationError() }
            var failure = error as? HordeFailure ?? .init("AI Horde: Verbindungsfehler. Details stehen im Fehlerbericht.", code: "transport_error")
            report.outcome = "Fehlgeschlagen"; report.errorCode = failure.code
            report.httpStatus = failure.httpStatus ?? report.httpStatus; report.networkCode = (error as? URLError)?.code.rawValue
            failure.diagnostic = report
            throw failure
        }
    }
    private struct Exchange: Sendable { var data: Data; var status: Int }
    private func submit(payload: Data, key: String) async throws -> Exchange {
        // Receive the receipt even if the caller cancels during submission, so it can
        // DELETE the accepted job. A lost receipt is recovered with the same operation key.
        try await Task.detached {
            do { return try await exchange(path: "generate/chat/async", method: "POST", key: key, body: payload) }
            catch { return try await exchange(path: "generate/chat/async", method: "POST", key: key, body: payload) }
        }.value
    }
    private func exchange(path: String, method: String = "GET", key: String? = nil, body: Data? = nil) async throws -> Exchange {
        var request = URLRequest(url: URL(string: Self.baseURL + "/" + path)!)
        request.httpMethod = method; request.httpBody = body
        request.setValue("Kai/1.6", forHTTPHeaderField: "User-Agent")
        request.setValue("Kai:1.6:https://github.com/r0bby97/kai-ios-build", forHTTPHeaderField: "Client-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let key { request.setValue(key, forHTTPHeaderField: "apikey") }
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard data.count <= 4 * 1024 * 1024 else { throw HordeFailure("Die Horde-Antwort ist zu groß.", code: "response_too_large") }
        return .init(data: data, status: (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
    private func object(_ data: Data) throws -> [String: Any] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HordeFailure("AI Horde hat keine lesbare JSON-Antwort geliefert.", code: "invalid_json")
        }
        return object
    }
    private func cancel(job: String, key: String) async {
        let session = session
        // A cancelled parent task must still send DELETE; cancellation cannot suppress cleanup.
        await Task.detached(priority: .utility) {
            var request = URLRequest(url: URL(string: Self.baseURL + "/generate/chat/status/" + job)!)
            request.httpMethod = "DELETE"; request.timeoutInterval = 3
            request.setValue(key, forHTTPHeaderField: "apikey")
            request.setValue("Kai/1.6", forHTTPHeaderField: "User-Agent")
            _ = try? await session.data(for: request)
        }.value
    }
}
private final class HordeNoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
