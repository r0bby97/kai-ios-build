import Foundation

public enum APIProviderPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI, claude, gemini, grok, deepSeek
    public var id: String { rawValue }
    public var title: String {
        switch self { case .openAI: "OpenAI API"; case .claude: "Claude API"; case .gemini: "Gemini API"; case .grok: "Grok API"; case .deepSeek: "DeepSeek API" }
    }
    public var kind: ProviderKind {
        switch self { case .openAI: .openAI; case .claude: .anthropic; default: .compatible }
    }
    public var baseURL: String {
        switch self {
        case .openAI: "https://api.openai.com/v1"
        case .claude: "https://api.anthropic.com/v1"
        case .gemini: "https://generativelanguage.googleapis.com/v1beta/openai"
        case .grok: "https://api.x.ai/v1"
        case .deepSeek: "https://api.deepseek.com/v1"
        }
    }
    public var keyURL: URL {
        let address: String
        switch self {
        case .openAI: address = "https://platform.openai.com/api-keys"
        case .claude: address = "https://platform.claude.com/settings/keys"
        case .gemini: address = "https://aistudio.google.com/api-keys"
        case .grok: address = "https://console.x.ai"
        case .deepSeek: address = "https://platform.deepseek.com/api_keys"
        }
        return URL(string: address)!
    }
    public var accountNote: String {
        switch self {
        case .openAI: "API-Schlüssel und API-Abrechnung sind von ChatGPT-Abos getrennt. Für dein ChatGPT-Kontingent wähle stattdessen ChatGPT-Konto."
        case .claude: "Claude wird über einen Console-API-Schlüssel verbunden. Pro enthält keine API-Nutzung; bestimmte Max-, Ultra- und Team-Tarife können verknüpfbare API-Credits enthalten."
        case .gemini: "Verwendet einen Gemini-API-Schlüssel aus Google AI Studio. Free Tier und Kosten hängen vom Modell, Projekt und dessen Abrechnung ab; ein Google-AI-Abo ist keine pauschale API-Flatrate."
        case .grok: "Verwendet einen xAI-API-Schlüssel. API-Nutzung wird separat zu den Modellpreisen abgerechnet und nicht aus dem Grok-Abo-Kontingent bezahlt."
        case .deepSeek: "Verwendet einen DeepSeek-API-Schlüssel und das API-Guthaben dieses Kontos. Ein Chat-Zugang ersetzt keinen API-Schlüssel."
        }
    }
    public func connection() -> Connection {
        var connection = Connection(name: title, kind: kind, baseURL: baseURL, enabled: false, allowsCosts: true)
        connection.apiPreset = self
        return connection
    }
    public func matches(_ connection: Connection) -> Bool {
        connection.kind == kind && connection.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == baseURL
    }
}

public enum ClaudeStreamEvent: Equatable, Sendable {
    case text(String), completed, ignored, failure(blocksConnection: Bool)
    public static func decode(_ event: SSEEvent) -> ClaudeStreamEvent {
        guard let data = event.data.data(using: .utf8), let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .ignored }
        let type = body["type"] as? String ?? event.name
        if type == "message_stop" { return .completed }
        if type == "error" {
            let error = body["error"] as? [String: Any] ?? [:]
            let code = error["type"] as? String ?? ""
            return .failure(blocksConnection: ["rate_limit_error", "authentication_error", "permission_error", "billing_error"].contains(code))
        }
        if type == "content_block_delta", let delta = body["delta"] as? [String: Any],
           delta["type"] as? String == "text_delta", let text = delta["text"] as? String { return .text(text) }
        if type == "content_block_start", let block = body["content_block"] as? [String: Any],
           block["type"] as? String == "text", let text = block["text"] as? String, !text.isEmpty { return .text(text) }
        // Model reasoning/signatures are never presented as fictional character thoughts.
        return .ignored
    }
}
