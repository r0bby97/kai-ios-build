import Foundation

public enum TextStreamPolicy {
    public static func accepts(contentType: String?, kind: ProviderKind) -> Bool {
        let mime = contentType?.split(separator: ";", maxSplits: 1).first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        // The official SIWC direct route can omit this header. Events still need validation.
        return mime == "text/event-stream" || (kind == .chatGPT && mime.isEmpty)
    }
}

public enum TextStreamEvent: Equatable, Sendable {
    case text(String), completed, ignored
    case failure(code: String)

    public static func decode(_ event: SSEEvent, responses: Bool) -> Self {
        if event.data == "[DONE]" { return responses ? .ignored : .completed }
        guard let data = event.data.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return .ignored }
        if responses {
            let type = object["type"] as? String ?? event.name
            if type == "response.output_text.delta" || type == "response.refusal.delta", let text = object["delta"] as? String { return .text(text) }
            if type == "response.completed" { return .completed }
            if ["response.failed", "response.incomplete", "error"].contains(type) {
                let response = object["response"] as? [String: Any] ?? object
                let error = response["error"] as? [String: Any] ?? [:]
                return .failure(code: safeCode(error["code"] ?? object["code"]) ?? type)
            }
            return .ignored
        }
        if let error = object["error"] as? [String: Any] { return .failure(code: safeCode(error["code"]) ?? "provider_error") }
        guard let choices = object["choices"] as? [[String: Any]], let choice = choices.first else { return .ignored }
        let delta = choice["delta"] as? [String: Any] ?? choice["message"] as? [String: Any] ?? [:]
        if let text = text(delta["content"]) ?? text(delta["refusal"]), !text.isEmpty { return .text(text) }
        if let reason = choice["finish_reason"] as? String, !reason.isEmpty {
            if ["error", "content_filter", "length"].contains(reason) { return .failure(code: reason) }
            return .completed
        }
        return .ignored
    }
    private static func text(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        if let parts = value as? [[String: Any]] {
            let text = parts.filter { ["text", "output_text"].contains($0["type"] as? String ?? "") }.compactMap { $0["text"] as? String }.joined()
            return text.isEmpty ? nil : text
        }
        return nil
    }
    private static func safeCode(_ value: Any?) -> String? {
        let code = (value as? String) ?? (value as? Int).map(String.init)
        // Expose only known error categories; upstream messages can echo submitted text.
        let known = ["401", "402", "403", "429", "rate_limit_exceeded", "insufficient_quota", "model_not_found", "invalid_api_key", "content_filter", "context_length_exceeded", "usage_limit_reached", "sharing_limit_exceeded"]
        return code.flatMap { known.contains($0) ? $0 : nil }
    }
}
