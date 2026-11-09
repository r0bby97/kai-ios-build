import Foundation

public enum InferencePayload {
    public static func encode(kind: ProviderKind, model: String, prompt: BuiltPrompt, maxTokens: Int, preset: APIProviderPreset? = nil) throws -> Data {
        let messages = prompt.messages.map { ["role": $0.role, "content": $0.content] }
        let body: [String: Any]
        if kind == .anthropic {
            var turns = messages.filter { ["user", "assistant"].contains($0["role"] ?? "") }
            if turns.first?["role"] == "assistant" {
                turns.insert(["role": "user", "content": "Die folgende Begrüßung und der Verlauf sind bereits geschehen."], at: 0)
            }
            if turns.isEmpty || turns.last?["role"] == "assistant" {
                turns.append(["role": "user", "content": "Erzähle als zugewiesene Figur weiter; keine Beiträge der Nutzerfigur erfinden."])
            }
            body = ["model": model, "system": prompt.system, "messages": turns, "max_tokens": maxTokens, "stream": true]
        } else if kind == .chatGPT || kind == .openAI {
            // SIWC plan sharing rejects max_output_tokens. Kai enforces its word cap while streaming.
            var responseBody: [String: Any] = ["model": model, "instructions": prompt.system, "input": messages, "store": false, "stream": true]
            if kind == .openAI { responseBody["max_output_tokens"] = maxTokens }
            body = responseBody
        } else {
            var chatBody: [String: Any] = ["model": model, "messages": [["role": "system", "content": prompt.system]] + messages,
                    "stream": true, "max_tokens": maxTokens]
            if kind == .openRouter { chatBody["reasoning"] = ["enabled": false, "exclude": true] }
            if preset == .venice {
                chatBody["venice_parameters"] = ["include_venice_system_prompt": false, "disable_thinking": true, "strip_thinking_response": true]
            }
            body = chatBody
        }
        return try JSONSerialization.data(withJSONObject: body)
    }
}
