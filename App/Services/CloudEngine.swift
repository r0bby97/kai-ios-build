import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import FadenCore

struct ProviderFailure: LocalizedError {
    var text: String
    var blocksConnection = false
    var retryable = true
    var diagnostic: InferenceDiagnostic?
    var errorDescription: String? { text }
}
struct RemoteModel: Identifiable, Sendable {
    var id: String
    var name: String
    var isFree: Bool
    var supportsText = true
    var reasoning = false
    var context = 0
}

enum CloudEngine {
    @MainActor private static var modelCache: [String: (date: Date, models: [RemoteModel])] = [:]
    @MainActor static func contextWindow(connection: Connection, model: String) -> Int {
        let configured = connection.kind == .local ? min(connection.contextTokens, 8192) : connection.contextTokens
        let base = connection.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let cached = modelCache[base], Date().timeIntervalSince(cached.date) < 3600,
           let actual = cached.models.first(where: { $0.id == model && $0.context > 0 })?.context {
            return min(configured, actual)
        }
        return configured
    }
    static func models(connection: Connection, key: String, session: URLSession = HTTP.session) async throws -> [RemoteModel] {
        if connection.kind == .aiHorde {
            _ = try validatedBase(connection)
            let models = try await AIHordeClient(session: session === HTTP.session ? nil : session).models()
            return [.init(id: HordeCodec.automaticModel, name: "Automatische Rollenspielauswahl", isFree: true, context: models.map(\.contextTokens).max() ?? 0)] +
                models.map { .init(id: $0.id, name: $0.id, isFree: true, context: $0.contextTokens) }
        }
        let base = try validatedBase(connection)
        var request = URLRequest(url: base.appendingPathComponent("models"))
        if connection.apiPreset == .venice {
            var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            components.queryItems = [.init(name: "type", value: "text")]; request.url = components.url
        }
        authenticate(&request, connection: connection, key: key)
        let (data, response) = try await session.data(for: request)
        try checkStatus(response, data: data)
        let object = try HTTP.object(data)
        let models = object["models"] as? [[String: Any]] ?? object["data"] as? [[String: Any]] ?? []
        let result = models.compactMap { item -> RemoteModel? in
            guard let id = item["slug"] as? String ?? item["id"] as? String else { return nil }
            if let visibility = item["visibility"] as? String, visibility != "list" { return nil }
            let pricing = item["pricing"] as? [String: Any] ?? [:]
            let free = (pricing["prompt"] as? String == "0" && pricing["completion"] as? String == "0") || id.hasSuffix(":free") || id == "openrouter/free"
            let architecture = item["architecture"] as? [String: Any] ?? [:]
            let outputs = architecture["output_modalities"] as? [String] ?? []
            let text = connection.kind != .openRouter || outputs.contains("text")
            let reasoning = (item["supported_parameters"] as? [String] ?? []).contains("reasoning")
            return RemoteModel(id: id, name: item["display_name"] as? String ?? item["name"] as? String ?? id, isFree: free, supportsText: text, reasoning: reasoning, context: item["context_length"] as? Int ?? 0)
        }
        await MainActor.run { modelCache[base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))] = (Date(), result) }
        return result
    }

    @MainActor private static var freeCache: (date: Date, models: [RemoteModel])?
    @MainActor static func freeFallbackModels(connection: Connection, key: String, excluding: [String]) async throws -> [String] {
        let available: [RemoteModel]
        if let cached = freeCache, Date().timeIntervalSince(cached.date) < 3600 { available = cached.models }
        else { available = try await models(connection: connection, key: key); freeCache = (Date(), available) }
        return Array(available.filter { $0.isFree && $0.supportsText && $0.id.hasSuffix(":free") && !excluding.contains($0.id) }
            .sorted { if $0.reasoning != $1.reasoning { return !$0.reasoning }; return $0.context > $1.context }.prefix(3).map(\.id))
    }

    @MainActor static func generate(connection: Connection, model: String, key: String,
        prompt: BuiltPrompt, maxTokens: Int, session: URLSession = HTTP.session,
        onStatus: @escaping @MainActor (String) -> Void = { _ in }, onDelta: @escaping @MainActor (String) -> Bool) async throws -> InferenceResult {
        if connection.kind == .aiHorde {
            do {
                _ = try validatedBase(connection)
                var result = try await AIHordeClient(session: session === HTTP.session ? nil : session).generate(model: model, key: key, prompt: prompt, maxTokens: maxTokens,
                    contextTokens: connection.contextTokens, timeoutSeconds: Double(connection.hordeWaitSeconds ?? 90), providerName: connection.name,
                    progress: { update in await MainActor.run { onStatus(update.message) } })
                if onDelta(result.text) { result.diagnostic.outcome = "Wortgrenze erreicht" }
                return result
            } catch let failure as HordeFailure {
                throw ProviderFailure(text: failure.message, blocksConnection: failure.blocksConnection, retryable: failure.retryable, diagnostic: failure.diagnostic)
            }
        }
        var report = InferenceDiagnostic(provider: connection.name, model: model, host: URL(string: connection.baseURL)?.host)
        do {
            let base = try validatedBase(connection)
            let responses = connection.kind == .chatGPT || connection.kind == .openAI
            let claude = connection.kind == .anthropic
            var request = URLRequest(url: base.appendingPathComponent(responses ? "responses" : claude ? "messages" : "chat/completions"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            authenticate(&request, connection: connection, key: key)
            if connection.kind == .openRouter { request.setValue("Kai", forHTTPHeaderField: "X-Title") }
            request.httpBody = try InferencePayload.encode(kind: connection.kind, model: model, prompt: prompt, maxTokens: maxTokens, preset: connection.apiPreset)
            let (bytes, response) = try await session.bytes(for: request)
            defer { bytes.task.cancel() }
            guard let response = response as? HTTPURLResponse else { throw ProviderFailure(text: "Keine HTTP-Serverantwort empfangen.") }
            report.httpStatus = response.statusCode
            report.contentType = response.value(forHTTPHeaderField: "Content-Type")?.components(separatedBy: ";").first.map { String($0.prefix(80)) }
            if !(200..<300).contains(response.statusCode) {
                var errorData = Data()
                for try await byte in bytes { errorData.append(byte); if errorData.count >= 8192 { break } }
                report.bytes = errorData.count; report.errorCode = "http_\(response.statusCode)"
                if response.statusCode == 401, connection.kind == .openRouter,
                   base.host == "openrouter.ai", try await openRouterKeyIsValid(base: base, key: key, session: session) {
                    report.errorCode = "model_access_denied_key_valid"
                    throw ProviderFailure(text: "OpenRouter bestätigt den API-Schlüssel, aber dieses Gratis-Modell verweigert den Zugriff (HTTP 401). Kai kann ein anderes freigegebenes Modell versuchen.")
                }
                try checkStatus(response, data: errorData)
            }
            var text = ""; var completed = false; var stopped = false; var finalCandidate = ""
            func publish(_ delta: String) {
                guard !delta.isEmpty else { return }
                text += delta; report.textEvents += 1; report.textCharacters = text.count
                stopped = onDelta(delta)
            }
            func inspect(_ object: [String: Any]) {
                let response = object["response"] as? [String: Any] ?? object
                if let usage = response["usage"] as? [String: Any] {
                    report.outputTokens = usage["output_tokens"] as? Int ?? usage["completion_tokens"] as? Int
                    let details = usage["output_tokens_details"] as? [String: Any] ?? usage["completion_tokens_details"] as? [String: Any]
                    report.reasoningTokens = details?["reasoning_tokens"] as? Int
                }
                if let choices = object["choices"] as? [[String: Any]], let reason = choices.first?["finish_reason"] as? String { report.finishReason = String(reason.prefix(60)) }
                if let status = response["status"] as? String, ["completed", "incomplete", "failed", "cancelled"].contains(status) { report.finishReason = status }
            }
            let mime = report.contentType?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if mime == "application/json" {
                var data = Data()
                for try await byte in bytes { try Task.checkCancellation(); data.append(byte); if data.count > 2 * 1024 * 1024 { throw ProviderFailure(text: "Die Serverantwort ist zu groß.") } }
                report.bytes = data.count
                let object = try HTTP.object(data); inspect(object)
                if let error = object["error"], !(error is NSNull) { throw ProviderFailure(text: "Der Anbieter meldet einen Fehler in seiner JSON-Antwort.") }
                publish(ResponseText.finalText(object)); completed = true; report.finishReason = report.finishReason ?? "json_response"
            } else {
                guard TextStreamPolicy.accepts(contentType: report.contentType, kind: connection.kind) else {
                    report.errorCode = "unexpected_content_type"
                    throw ProviderFailure(text: "Der Server liefert kein unterstütztes Textformat (HTTP \(response.statusCode), \(report.contentType ?? "ohne Formatangabe")).", retryable: false)
                }
                var parser = SSEParser(); var lineBytes = Data()
                func handle(_ event: SSEEvent) throws {
                    report.events += 1
                    let object = event.data.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any] ?? [:]
                    inspect(object)
                    if object["type"] as? String == "response.output_text.done", let value = object["text"] as? String { finalCandidate = value }
                    if claude {
                        switch ClaudeStreamEvent.decode(event) {
                        case .text(let delta): publish(delta)
                        case .completed: completed = true; report.finishReason = "message_stop"
                        case .failure(let blocks): throw ProviderFailure(text: "Claude hat die Antwort abgebrochen.", blocksConnection: blocks)
                        case .ignored: break
                        }
                        return
                    }
                    switch TextStreamEvent.decode(event, responses: responses) {
                    case .text(let delta): publish(delta)
                    case .completed:
                        // Some gateways only include text in the final response snapshot.
                        // Read that SAME response; never submit a duplicate paid request.
                        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let snapshot = ResponseText.finalText(object)
                            publish(snapshot.isEmpty ? finalCandidate : snapshot)
                        }
                        completed = true; report.finishReason = report.finishReason ?? (responses ? "response.completed" : "done")
                    case .ignored: break
                    case .failure(let code):
                        report.errorCode = code
                        let message: String
                        switch code {
                        case "length": message = "Das Ausgabelimit wurde erreicht (HTTP \(response.statusCode)). Es kann vollständig für Modellberechnungen verbraucht worden sein."
                        case "content_filter": message = "Der Anbieter hat die Antwort aufgrund seiner Inhaltsregeln beendet."
                        case "401", "403", "invalid_api_key": message = "Der Anbieter akzeptiert die Anmeldung oder den API-Schlüssel nicht."
                        case "402", "insufficient_quota": message = "Guthaben oder Kontingent des Anbieters reicht nicht aus."
                        case "429", "rate_limit_exceeded", "usage_limit_reached", "sharing_limit_exceeded": message = "Das Nutzungslimit dieses Kontos ist erreicht."
                        default: message = "Der Anbieter hat den Textstream abgebrochen (\(code))."
                        }
                        throw ProviderFailure(text: message, blocksConnection: ["401", "402", "403", "429", "invalid_api_key", "insufficient_quota", "rate_limit_exceeded", "usage_limit_reached", "sharing_limit_exceeded"].contains(code))
                    }
                }
                for try await byte in bytes {
                    try Task.checkCancellation(); report.bytes += 1
                    if byte == 10 {
                        let line = String(decoding: lineBytes, as: UTF8.self); lineBytes.removeAll(keepingCapacity: true)
                        if let event = parser.consume(line) { try handle(event); if completed || stopped { break } }
                    } else {
                        lineBytes.append(byte)
                        if lineBytes.count > 2 * 1024 * 1024 { throw ProviderFailure(text: "Ein Stream-Ereignis ist zu groß.") }
                    }
                }
                if !completed && !stopped {
                    if !lineBytes.isEmpty, let event = parser.consume(String(decoding: lineBytes, as: UTF8.self)) { try handle(event) }
                    if let event = parser.finish() { try handle(event) }
                }
            }
            guard completed || stopped else {
                report.errorCode = "stream_interrupted"
                throw ProviderFailure(text: "Textstream vorzeitig beendet: HTTP \(report.httpStatus ?? 0), \(report.events) Ereignisse, \(report.textCharacters) Textzeichen. Ein Abschlussereignis fehlt.")
            }
            guard text.contains(where: { !$0.isWhitespace }) else {
                report.errorCode = "empty_output"
                throw ProviderFailure(text: "Leere Serverantwort: HTTP \(report.httpStatus ?? 0), \(report.events) Ereignisse, \(report.outputTokens.map { "\($0) Ausgabe-Tokens" } ?? "keine Tokenangabe"), Abschluss: \(report.finishReason ?? "unbekannt"). Details unter Fehlerberichte.")
            }
            report.outcome = stopped ? "Wortgrenze erreicht" : "Antwort empfangen"
            return .init(text: text, diagnostic: report)
        } catch is CancellationError { throw CancellationError() }
        catch var failure as ProviderFailure {
            report.outcome = "Fehlgeschlagen"; failure.diagnostic = report; throw failure
        } catch {
            report.outcome = "Fehlgeschlagen"; report.networkCode = (error as? URLError)?.code.rawValue
            report.errorCode = report.errorCode ?? "transport_error"
            throw ProviderFailure(text: "Verbindungsfehler bei \(report.host ?? connection.name) (\(report.networkCode.map(String.init) ?? "Antwortformat nicht lesbar")). Details unter Fehlerberichte.", diagnostic: report)
        }
    }

    private static func validatedBase(_ connection: Connection) throws -> URL {
        let base = try HTTP.requireHTTPS(connection.baseURL)
        if connection.kind == .aiHorde && base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) != AIHordeClient.baseURL {
            throw FadenError.invalidData("Horde-Schlüssel dürfen nur an die offizielle AI-Horde-API gesendet werden.")
        }
        if connection.kind == .chatGPT && base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) != "https://api.openai.com/v1" {
            throw FadenError.invalidData("ChatGPT-Anmeldedaten dürfen nur an die offizielle API gesendet werden.")
        }
        if let preset = connection.apiPreset, !preset.matches(connection) {
            throw FadenError.invalidData("Die API-Adresse passt nicht zum ausgewählten Anbieter. Lege für andere Adressen eine eigene Verbindung an.")
        }
        return base
    }
    private static func authenticate(_ request: inout URLRequest, connection: Connection, key: String) {
        if connection.kind == .anthropic {
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            if let workspace = connection.workspaceID?.trimmingCharacters(in: .whitespacesAndNewlines), !workspace.isEmpty {
                request.setValue(workspace, forHTTPHeaderField: "anthropic-workspace-id")
            }
        } else if !key.isEmpty { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
    }

    private static func checkStatus(_ response: URLResponse, data: Data) throws {
        guard let status = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(status) else { return }
        switch status {
        case 401, 403: throw ProviderFailure(text: "Der Anbieter verweigert den Zugriff (HTTP \(status)). Anmeldung, API-Schlüssel oder Modellberechtigung prüfen.", blocksConnection: true)
        case 402: throw ProviderFailure(text: "Das Guthaben oder Kontingent dieses Kontos reicht nicht aus.", blocksConnection: true)
        case 429:
            // Free-tier daily limits span the account, not an individual model.
            throw ProviderFailure(text: "Der Anbieter hat sein Nutzungslimit erreicht. Bitte bis zur Freigabe warten.", blocksConnection: true)
        case 400, 404, 422:
            let reason = ProviderRequestProblem.describe(data)
            throw ProviderFailure(text: "\(reason) (HTTP \(status)).")
        case 500...599: throw ProviderFailure(text: "Der Anbieter ist vorübergehend nicht verfügbar (\(status)).")
        default: throw ProviderFailure(text: "Der Anbieter antwortet mit HTTP \(status).", retryable: false)
        }
    }
    private static func openRouterKeyIsValid(base: URL, key: String, session: URLSession) async throws -> Bool {
        var request = URLRequest(url: base.appendingPathComponent("key"))
        request.timeoutInterval = 10
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await session.data(for: request)
            try Task.checkCancellation()
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            if Task.isCancelled { throw CancellationError() }
            // An unavailable validation endpoint cannot prove model-only denial.
            // Preserve the original HTTP 401 instead of replacing it with a probe error.
            return false
        }
    }
}
