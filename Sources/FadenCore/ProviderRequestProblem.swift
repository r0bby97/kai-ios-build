import Foundation

/// Classifies known error categories without exposing a provider's raw message,
/// which can contain submitted conversation text or credentials.
public enum ProviderRequestProblem {
    public static func describe(_ data: Data) -> String {
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let error = root["error"] as? [String: Any] ?? root
        let metadata = error["metadata"] as? [String: Any] ?? [:]
        let text = ((error["code"] as? String ?? "") + " " + (error["message"] as? String ?? "") + " " + (metadata["raw"] as? String ?? "")).lowercased()
        if text.contains("context") && ["length", "window", "exceed", "maximum", "limit"].contains(where: text.contains) {
            return "Der Verlauf oder die gewünschte Antwort überschreitet das Kontextfenster dieses Modells"
        }
        if ["must start with", "first message must", "alternate", "consecutive"].contains(where: text.contains) {
            return "Der Modellanbieter akzeptiert die Reihenfolge der übermittelten Gesprächsrollen nicht"
        }
        if text.contains("reasoning") && ["missing", "required", "signature"].contains(where: text.contains) {
            return "Dieses Modell verlangt zusätzliche Verlaufsdaten früherer Antworten, die hier nicht verfügbar sind"
        }
        if text.contains("no endpoints") || text.contains("data policy") {
            return "Für dieses Modell ist mit den aktuellen Zugangs- oder Datenschutzeinstellungen kein passender Endpunkt verfügbar"
        }
        if text.contains("unsupported") && ["parameter", "max_tokens", "response_format"].contains(where: text.contains) {
            return "Dieses Modell unterstützt einen der angefragten Ausgabeparameter nicht"
        }
        return "Der Modellanbieter unterstützt dieses Modell oder diese Anfrage derzeit nicht"
    }
}
