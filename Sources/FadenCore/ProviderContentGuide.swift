import Foundation

public enum ContentFreedom: String, Sendable, Equatable {
    case wide, limited, modelDependent, unverified
    public var title: String {
        switch self { case .wide: "viel Freiraum"; case .limited: "eingeschränkt"; case .modelDependent: "modellabhängig"; case .unverified: "ungeprüft" }
    }
}
public struct ProviderContentGuide: Sendable, Equatable {
    public var erotic: ContentFreedom
    public var violence: ContentFreedom
    public var explanation: String
    public var source: URL?
    public var summary: String { "Erotik: \(erotic.title) · Gewalt: \(violence.title)" }
    public static let reviewDate = "9. November 2026"
}
public extension Connection {
    var contentGuide: ProviderContentGuide {
        func guide(_ erotic: ContentFreedom, _ violence: ContentFreedom, _ explanation: String, _ source: String? = nil) -> ProviderContentGuide {
            .init(erotic: erotic, violence: violence, explanation: explanation, source: source.flatMap(URL.init(string:)))
        }
        if let apiPreset, !apiPreset.matches(self) {
            return guide(.unverified, .unverified, "Die Adresse stimmt nicht mit dem Anbieter überein. Dafür liegt keine geprüfte Einordnung vor.")
        }
        if kind == .aiHorde {
            guard baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == AIHordeClient.baseURL else {
                return guide(.unverified, .unverified, "Diese Adresse ist kein geprüfter AI-Horde-Zugang.")
            }
            let reviewed = !models.isEmpty && models.allSatisfy { $0 == HordeCodec.automaticModel || HordeCodec.isRoleplayModel($0) }
            return guide(reviewed ? .wide : .modelDependent, reviewed ? .wide : .modelDependent, "Die Horde erlaubt NSFW-Texte und verhängt laut FAQ keine allgemeine Textzensur. Kai wählt Rechner mit NSFW-Unterstützung. Die bekannten Rollenspielmodelle bekommen den Richtwert viel Freiraum; andere Modelle bleiben modellabhängig. Einzelne Modelle und Betreiber können Inhalte ablehnen. Freiwillige Rechnerbetreiber können die übermittelten Texte technisch mitlesen.", "https://aihorde.net/faq/")
        }
        if kind == .chatGPT || kind == .openAI || apiPreset == .openAI {
            return guide(.limited, .limited, "Für explizite Erotik keine verlässliche Wahl. Fiktive Konflikte und Kämpfe sind möglich; drastische Gore-Darstellungen sind eingeschränkt. Ein ChatGPT-Abo hebt diese Regeln nicht auf.", "https://model-spec.openai.com/")
        }
        if kind == .anthropic || apiPreset == .claude {
            return guide(.limited, .limited, "Erotische Chats und explizite Sexdarstellungen sind durch die Anbieterregeln eingeschränkt. Gewalt in Geschichten ist kein pauschaler Freibrief für jede drastische Darstellung.", "https://www.anthropic.com/legal/aup")
        }
        if apiPreset == .gemini {
            return guide(.limited, .limited, "Die Cloud-Regeln schränken pornografische Inhalte und bestimmte Gewaltdarstellungen ein. Künstlerische Ausnahmen sind keine Zusage für explizite Rollenspiele.", "https://policies.google.com/terms/generative-ai/use-policy?hl=de")
        }
        if apiPreset == .deepSeek {
            return guide(.limited, .limited, "Die DeepSeek-Cloud untersagt pornografische Inhalte; Gewaltförderung und bestimmte schädliche Inhalte sind ebenfalls eingeschränkt. Lokal ausgeführte Varianten haben andere Rahmenbedingungen.", "https://cdn.deepseek.com/policies/en-US/deepseek-open-platform-terms-of-service.html")
        }
        if apiPreset == .nanoGPT {
            let reviewed = Set(["abliteration-ai/abliterated-model-large-v2", "abliteration-ai/abliterated-model-large-flash", "z-ai/glm-5.3-uncensored", "z-ai/glm-5.3-flash-uncensored", "deepseek/deepseek-v4.1-flash-1017-uncensored"])
            let selected = !models.isEmpty && models.allSatisfy { reviewed.contains($0.lowercased()) }
            return guide(selected ? .wide : .modelDependent, selected ? .wide : .modelDependent,
                         "NanoGPT bietet ausdrücklich Modelle für erwachsene Rollenspiele und düstere Fiktion. Die Einordnung hängt von den gewählten Modellen ab; GPT- und Claude-Modelle werden dadurch nicht freier. Nutzung ist kostenpflichtig. Eine Modellbezeichnung allein ist keine Garantie für jede Szene.", "https://nano-gpt.com/use-cases/uncensored-ai")
        }
        if apiPreset == .arli {
            let roleplay = Set(["qwen3.8-27b-dark-scarlett-v2.0", "qwen3.8-27b-darker-scarlett-v0.1", "gemma-4-31b-melody1437"])
            let selected = !models.isEmpty && models.allSatisfy { roleplay.contains($0.lowercased()) }
            return guide(selected ? .wide : .modelDependent, .modelDependent, "Arli führt ausdrücklich NSFW- und Rollenspielmodelle. Das gilt nicht automatisch für jedes Modell. Für drastische Gewalt liegt keine pauschale Freigabe für alle Modelle vor. Der Gratis-Test ist klein und limitiert.", "https://www.arliai.com/terms")
        }
        if apiPreset == .venice {
            return guide(.modelDependent, .modelDependent, "Venice bietet offene Modelle sowie Modelle anderer Anbieter. Maßgeblich ist die konkrete Auswahl. Die API ist kostenpflichtig; kostenlose Nutzung in der Web-App wird nicht übernommen.", "https://venice.ai/legal/tos")
        }
        if apiPreset == .grok {
            return guide(.modelDependent, .modelDependent, "Die xAI-Regeln und das konkrete Grok-Modell sind maßgeblich. Aus der Anbieterwahl allein folgt keine Zusage für explizite Szenen.", "https://x.ai/legal/acceptable-use-policy")
        }
        if kind == .openRouter {
            return guide(.modelDependent, .modelDependent, "OpenRouter vermittelt viele Modelle und Betreiber mit unterschiedlichen Regeln. Der Free-Router kann die Modellauswahl wechseln. Er ist deshalb keine verlässlich explizite Rollenspielauswahl.", "https://openrouter.ai/terms")
        }
        if kind == .local {
            return guide(.modelDependent, .modelDependent, "Das Modell läuft auf deinem iPhone. Antwortverhalten und Lizenz hängen von den Gewichten ab; lokale Ausführung garantiert keine bestimmte Ausgabe.")
        }
        return guide(.unverified, .unverified, "Für diese eigene API-Adresse sind Inhaltsregeln und gewählte Modelle noch nicht geprüft.")
    }
}
