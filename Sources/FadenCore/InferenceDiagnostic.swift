import Foundation

/// Metadata only. Never store prompts, response text, access tokens or upstream error bodies.
public struct InferenceDiagnostic: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var date = Date()
    public var appVersion = ""
    public var provider: String
    public var model: String
    public var host: String?
    public var httpStatus: Int?
    public var contentType: String?
    public var bytes = 0
    public var events = 0
    public var textEvents = 0
    public var textCharacters = 0
    public var finishReason: String?
    public var outputTokens: Int?
    public var reasoningTokens: Int?
    public var networkCode: Int?
    public var errorCode: String?
    public var outcome = "gestartet"
    public init(provider: String, model: String, host: String? = nil) {
        self.provider = provider; self.model = model; self.host = host
    }
    public var readable: String {
        var lines = ["Kai \(appVersion)", "Zeit: \(date.ISO8601Format())", "Anbieter: \(provider)", "Modell: \(model)", "Ergebnis: \(outcome)"]
        if let host { lines.append("Server: \(host)") }
        if let httpStatus { lines.append("HTTP: \(httpStatus)") }
        if let contentType { lines.append("Antwortformat: \(contentType)") }
        lines += ["Empfangen: \(bytes) Bytes · \(events) Ereignisse", "Text: \(textEvents) Ereignisse · \(textCharacters) Zeichen"]
        if let finishReason { lines.append("Abschluss/Stopp: \(finishReason)") }
        if let outputTokens { lines.append("Ausgabe-Tokens: \(outputTokens)") }
        if let reasoningTokens { lines.append("Berechnungs-Tokens: \(reasoningTokens)") }
        if let networkCode { lines.append("Netzwerkcode: \(networkCode)") }
        if let errorCode { lines.append("Fehlercode: \(errorCode)") }
        return lines.joined(separator: "\n")
    }
}

public struct InferenceResult: Sendable {
    public var text: String
    public var diagnostic: InferenceDiagnostic
    public init(text: String, diagnostic: InferenceDiagnostic) { self.text = text; self.diagnostic = diagnostic }
}

public enum ResponseText {
    public static func finalText(_ object: [String: Any]) -> String {
        if let response = object["response"] as? [String: Any] { return finalText(response) }
        if let output = object["output_text"] as? String { return output }
        if object["type"] as? String == "message" { return content(object["content"]) }
        if let output = object["output"] as? [[String: Any]] {
            return output.filter { $0["type"] as? String == "message" }.map { content($0["content"]) }.joined()
        }
        if let choices = object["choices"] as? [[String: Any]], let first = choices.first {
            let message = first["message"] as? [String: Any] ?? [:]
            return content(message["content"]) + (message["refusal"] as? String ?? "")
        }
        return ""
    }
    private static func content(_ value: Any?) -> String {
        if let text = value as? String { return text }
        guard let parts = value as? [[String: Any]] else { return "" }
        return parts.compactMap { part in
            switch part["type"] as? String {
            case "text", "output_text": part["text"] as? String
            case "refusal": part["refusal"] as? String
            default: nil
            }
        }.joined()
    }
}
