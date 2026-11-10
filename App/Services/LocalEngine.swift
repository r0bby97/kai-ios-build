import Foundation
import Observation
import FadenCore
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

@MainActor @Observable final class LocalEngine {
    var progress: Double = 0
    var loading = false
    var loadedID: String?
    var status = "Noch nicht geladen"
    private var container: ModelContainer?
    func load(id: String) async throws {
        if loadedID == id, container != nil { return }
        guard !loading else { throw FadenError.network("Das Modell wird bereits geladen.") }
        loading = true; status = "Modell wird geladen"; progress = 0
        defer { loading = false }
        container = nil; loadedID = nil
        do {
            container = try await #huggingFaceLoadModelContainer(configuration: ModelConfiguration(id: id)) { value in
                Task { @MainActor in self.progress = value.fractionCompleted }
            }
            loadedID = id; progress = 1; status = "Download fertig · Textgenerierung wird geprüft"
            let check = BuiltPrompt(system: "Antworte kurz auf Deutsch.", messages: [.init(role: "user", content: "Sag Hallo. /no_think")], retrievedCount: 0, truncated: false)
            var checkedText = ""
            _ = try await generate(id: id, prompt: check, maxTokens: 32) { text in
                checkedText += text; return !checkedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            status = "Bereit · Textgenerierung geprüft"
        } catch { status = container == nil ? "Laden fehlgeschlagen" : "Dateien vorhanden · Generierung fehlgeschlagen"; throw error }
    }
    func unload() { container = nil; loadedID = nil; status = "Aus dem Arbeitsspeicher entladen" }
    func generate(id: String, prompt: BuiltPrompt, maxTokens: Int,
                  onDelta: @escaping @MainActor (String) -> Bool) async throws -> InferenceResult {
        let prompt = prompt.chatCompatible
        // A cloud fallback must never trigger a multi-gigabyte download without consent.
        guard loadedID == id, let container else { throw FadenError.notConfigured }
        guard ProcessInfo.processInfo.thermalState != .critical else {
            throw FadenError.network("Das iPhone ist derzeit zu heiß für das lokale Modell. Lass es abkühlen oder verwende eine Cloud-Verbindung.")
        }
        // Try a fresh session once more if the model ends before any visible text.
        // Local retries use existing weights, without another download or cloud request.
        var report = InferenceDiagnostic(provider: "Auf dem iPhone", model: id)
        var tokenCount = 0
        var stopReason = "unbekannt"
        for attempt in 0..<2 {
            try Task.checkCancellation()
            let session = ChatSession(container, instructions: prompt.system,
                generateParameters: GenerateParameters(maxTokens: maxTokens, temperature: attempt == 0 ? 0.6 : 0,
                    topP: 0.95, topK: 20), additionalContext: ["enable_thinking": false])
            var turns = prompt.messages
            if turns.isEmpty || turns.last?.role != "user" {
                turns.append(.init(role: "user", content: "Setze die Szene ausschließlich als deine Figur fort. Erfinde keine Rede oder Gedanken des Nutzers."))
            }
            if id.lowercased().contains("qwen3"), let last = turns.indices.last {
                turns[last].content += "\n/no_think"
            }
            let messages: [Chat.Message] = turns.map { message in
                Chat.Message(role: message.role == "assistant" ? .assistant : .user, content: message.content)
            }
            var generated = ""
            for try await item in session.streamDetails(to: messages) {
                try Task.checkCancellation()
                if let delta = item.chunk, !delta.isEmpty {
                    generated += delta; report.textEvents += 1; report.textCharacters = generated.count
                    if onDelta(delta) {
                        report.outcome = "Ausgabe durch Client begrenzt"; report.finishReason = "client_stop"
                        return .init(text: generated, diagnostic: report)
                    }
                }
                if let info = item.info { tokenCount = info.generationTokenCount; stopReason = String(describing: info.stopReason) }
                if item.toolCall != nil { throw FadenError.network("Das lokale Modell hat einen Werkzeugaufruf statt einer Textantwort erzeugt. Wähle ein Text-Chatmodell.") }
            }
            if generated.contains(where: { !$0.isWhitespace }) {
                report.outputTokens = tokenCount; report.finishReason = stopReason; report.outcome = "Antwort empfangen"
                return .init(text: generated, diagnostic: report)
            }
        }
        report.outputTokens = tokenCount; report.finishReason = stopReason; report.errorCode = "local_empty_output"; report.outcome = "Fehlgeschlagen"
        throw ProviderFailure(text: "Lokale Generierung ohne Text: \(tokenCount) Ausgabe-Tokens, Stopp: \(stopReason), \(report.textEvents) Text-Ereignisse nach zwei Versuchen. Modelldateien geladen. Details unter Fehlerberichte.", diagnostic: report)
    }
}
