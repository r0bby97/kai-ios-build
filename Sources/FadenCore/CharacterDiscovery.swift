import Foundation

public enum CharacterGenre: String, CaseIterable, Sendable {
    case all, omegaverse, fantasy, everyday, noir, scienceFiction, mystery, adventure, romance, horror, guideverse
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
        }
    }
    public func matches(_ card: CharacterCard) -> Bool {
        if self == .all { return true }
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
    case chub, janny
    public var title: String { self == .chub ? "Chub" : "JannyAI" }
    public static func source(for id: String) -> CatalogueSource? {
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
