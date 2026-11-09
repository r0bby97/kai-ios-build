import Foundation

public enum CharacterGenre: String, CaseIterable, Sendable {
    case all, omegaverse, fantasy, everyday, noir, scienceFiction, mystery, adventure, romance, horror, guideverse, bdsm
    public var title: String {
        switch self {
        case .all: "Alle"
        case .omegaverse: "Omegaverse"
        case .fantasy: "Fantasy"
        case .everyday: "Alltag"
        case .noir: "Noir"
        case .scienceFiction: "Science-Fiction"
        case .mystery: "Mystery"
        case .adventure: "Abenteuer"
        case .romance: "Romantik"
        case .horror: "Horror"
        case .guideverse: "Guideverse"
        case .bdsm: "BDSM"
        }
    }
    public var catalogueTopic: String? {
        switch self {
        case .all: nil
        case .omegaverse: "Omegaverse"
        case .fantasy: "Fantasy"
        case .everyday: "Slice of Life"
        case .noir: "Noir"
        case .scienceFiction: "Sci-Fi"
        case .mystery: "Mystery"
        case .adventure: "Adventure"
        case .romance: "Romance"
        case .horror: "Horror"
        case .guideverse: "Guideverse"
        case .bdsm: "BDSM"
        }
    }
    public func matches(_ card: CharacterCard) -> Bool {
        if self == .all { return true }
        if self == .bdsm {
            let text = ([card.name, card.tagline, card.description, card.personality, card.scenario, card.creatorNotes] + card.tags).joined(separator: " ")
            return text.range(of: #"(?i)\bbdsm\b"#, options: .regularExpression) != nil
        }
        if self == .guideverse {
            let text = ([card.name, card.tagline, card.description, card.personality, card.scenario, card.creatorNotes] + card.tags).joined(separator: " ")
            return text.range(of: #"(?i)\b(?:guide[\s-]*verse|esper[\s-]*verse|esper\s*(?:&|and|und|/|\+)\s*guide)\b"#, options: .regularExpression) != nil
        }
        if self == .omegaverse {
            let text = ([card.name, card.tagline, card.description, card.personality, card.scenario, card.creatorNotes] + card.tags).joined(separator: " ")
            return OmegaverseSearch.containsGenre(text)
        }
        let aliases = [title.lowercased(), catalogueTopic?.lowercased() ?? "", self == .scienceFiction ? "science fiction" : ""]
        return card.tags.contains { aliases.contains($0.lowercased()) }
    }
}

public enum OmegaverseSearch {
    public static func containsGenre(_ text: String) -> Bool {
        text.range(of: #"(?i)\b(?:omega[\s-]*verse|a\s*/\s*b\s*/\s*o|abo)\b"#, options: .regularExpression) != nil
    }
    public static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: #"(?i)\b(?:omega[\s-]+verse|a\s*/\s*b\s*/\s*o|abo)\b"#, with: "omegaverse", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum CatalogueSource: String, CaseIterable, Sendable {
    case all, cardex, chub, janny
    public var title: String {
        switch self { case .all: "Alle"; case .cardex: "Cardex"; case .chub: "Chub"; case .janny: "JannyAI" }
    }
    public var sources: [CatalogueSource] { self == .all ? [.cardex, .chub, .janny] : [self] }
    public func sortDescription(query: String) -> String {
        switch self {
        case .all: "Gemischte Quellen · Rangfolge je Quelle"
        case .cardex: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nach Beliebtheit" : "Nach Suchrelevanz"
        case .chub: "Nach Beliebtheit"
        case .janny: "Nach Suchrelevanz"
        }
    }
    public var discoveryNote: String {
        switch self {
        case .all: "Karten aus Cardex, Chub und JannyAI. Treffer erscheinen, sobald eine Quelle antwortet. Eine ausgefallene Quelle hält die anderen nicht auf. Beliebtheitszahlen verschiedener Quellen sind nicht direkt vergleichbar."
        case .cardex: "Archivierte Originalkarten mit direktem Import von Definition und Kartenbild. Ältere Archivbilder können verkleinert sein. Nicht jede Karte ist vollständig erhalten."
        case .chub: "Genres werden direkt im Katalog gesucht. Weitere Treffer lassen sich nachladen."
        case .janny: "JannyAI liefert Suchvorschauen. Der direkte Kartendownload kann an Website-Prüfungen scheitern; Cardex und Chub bieten weitere Karten zum direkten Import."
        }
    }
    public static func source(for id: String) -> CatalogueSource? {
        if id.hasPrefix("cardex/"), CardexCatalogueCodec.validSlug(String(id.dropFirst(7))) { return .cardex }
        if id.hasPrefix("chub/") { return .chub }
        if id.hasPrefix("janny/"), UUID(uuidString: String(id.dropFirst(6))) != nil { return .janny }
        return nil
    }
}

public enum CharacterKindFilter: String, CaseIterable, Sendable {
    case all, single, ensemble
    public var title: String {
        switch self { case .all: "Alle Karten"; case .single: "Einzelne Figuren"; case .ensemble: "Gruppenkarten" }
    }
    public func matches(_ card: CharacterCard) -> Bool {
        self == .all || (self == .ensemble ? card.cast.isEnsemble : !card.cast.isEnsemble)
    }
}
