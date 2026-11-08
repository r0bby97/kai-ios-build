import Foundation

public struct CardCast: Codable, Hashable, Sendable {
    public var isEnsemble: Bool
    public var names: [String]
    public init(isEnsemble: Bool, names: [String] = []) { self.isEnsemble = isEnsemble; self.names = names }
}

/// Conservative, offline detection; users can correct the classification in the card editor.
/// A scene mentioning a friend is not sufficient evidence of a shared multi-character card.
public enum CardCastDetector {
    public static func detect(_ card: CharacterCard) -> CardCast {
        func normalized(_ text: String) -> String {
            text.lowercased().replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
                .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        let groupTags: Set<String> = ["multiple characters", "multi character", "multi characters", "multichar", "multicharacter", "multiple", "group chat", "groupchat", "ensemble", "mehrere figuren", "mehrere charaktere", "gruppenkarte", "gruppenchat"]
        let tagged = card.tags.contains { groupTags.contains(normalized($0)) }
        let titleNames = namesInTitle(card.name)
        let definition = [card.description, card.personality, card.systemPrompt].joined(separator: "\n")
        let labeled = captures(#"(?im)^\s*(?:[-*#]+\s*)?(?:name|character name|charaktername|figur)\s*[:=]\s*["']?([^\n\r;"'\[\]{}]{2,50})"#, in: definition)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var seen = Set<String>()
        let names = (titleNames + labeled).filter { !$0.contains("{{") && seen.insert($0.lowercased()).inserted }.prefix(12)
        let explicit = !captures(#"(?i)(?:\bthis (?:card|bot)|\{\{char\}\}|\bdiese (?:karte|ki))\s+(?:plays|portrays|represents|contains|consists of|verkörpert|spielt|enthält|besteht aus)\s+(?:multiple|several|two|three|both|mehrere|zwei|drei|beide)\b"#, in: definition).isEmpty
        return CardCast(isEnsemble: tagged || titleNames.count > 1 || labeled.count > 1 || explicit, names: Array(names))
    }

    private static func namesInTitle(_ title: String) -> [String] {
        let pieces = title.components(separatedBy: try! NSRegularExpression(pattern: #"\s*(?:&|\+|\bund\b|\band\b|\bet\b|\by\b|\bи\b|、|と)\s*"#))
        guard (2...6).contains(pieces.count) else { return [] }
        let names = pieces.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard names.allSatisfy({ name in
            !name.isEmpty && name.count <= 32 && name.split(separator: " ").count <= 3 &&
            name.first?.isUppercase == true && name.allSatisfy { $0.isLetter || $0.isWhitespace || $0 == "-" || $0 == "'" }
        }) else { return [] }
        return names
    }
    private static func captures(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            let index = match.numberOfRanges > 1 ? 1 : 0
            return Range(match.range(at: index), in: text).map { String(text[$0]) }
        }
    }
}

private extension String {
    func components(separatedBy regex: NSRegularExpression) -> [String] {
        var result: [String] = []; var start = startIndex
        for match in regex.matches(in: self, range: NSRange(startIndex..., in: self)) {
            guard let range = Range(match.range, in: self) else { continue }
            result.append(String(self[start..<range.lowerBound])); start = range.upperBound
        }
        result.append(String(self[start...])); return result
    }
}
