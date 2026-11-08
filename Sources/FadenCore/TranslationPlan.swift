import Foundation

public struct TranslationPlan: Sendable {
    public let chunks: [String]
    private let variables: [String]
    public init(_ original: String) {
        let regex = try! NSRegularExpression(pattern: "\\{\\{[^}]+\\}\\}")
        let matches = regex.matches(in: original, range: NSRange(original.startIndex..., in: original))
        variables = matches.compactMap { Range($0.range, in: original).map { String(original[$0]) } }
        var protected = original
        for (index, match) in matches.enumerated().reversed() {
            if let range = Range(match.range, in: protected) { protected.replaceSubrange(range, with: "ZXQKAIVAR\(index)QXZ") }
        }
        chunks = TemplateText.parts(protected).map(\.text)
    }
    public func restore(_ translated: [String]) throws -> String {
        guard translated.count == chunks.count else { throw FadenError.invalidData("Übersetzung unvollständig.") }
        var text = zip(chunks, translated).map { original, value -> String in
            let leading = String(original.prefix(while: \.isWhitespace))
            let trailing = String(original.reversed().prefix(while: \.isWhitespace).reversed())
            return leading + value.trimmingCharacters(in: .whitespacesAndNewlines) + trailing
        }.joined()
        for (index, variable) in variables.enumerated() {
            let marker = "ZXQKAIVAR\(index)QXZ"
            guard text.contains(marker) else { throw FadenError.invalidData("Die Übersetzung hat eine Kartenvariable verändert.") }
            text = text.replacingOccurrences(of: marker, with: variable)
        }
        return text
    }
}
