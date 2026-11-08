import Foundation

public struct TemplatePart: Equatable, Sendable {
    public var text: String
    public var isPlaceholder: Bool
}
public enum TemplateText {
    /// Keep Character Card variables byte-for-byte intact during translation.
    public static func parts(_ text: String) -> [TemplatePart] {
        guard let regex = try? NSRegularExpression(pattern: "\\{\\{[^}]+\\}\\}") else { return [.init(text: text, isPlaceholder: false)] }
        var result: [TemplatePart] = []; var start = text.startIndex
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            if start < range.lowerBound { result += chunks(String(text[start..<range.lowerBound])) }
            result.append(.init(text: String(text[range]), isPlaceholder: true)); start = range.upperBound
        }
        if start < text.endIndex { result += chunks(String(text[start...])) }
        return result
    }
    private static func chunks(_ text: String) -> [TemplatePart] {
        var remaining = text; var result: [TemplatePart] = []
        while remaining.count > 1600 {
            let upper = remaining.index(remaining.startIndex, offsetBy: 1600)
            let lower = remaining.index(remaining.startIndex, offsetBy: 800)
            let split = remaining.rangeOfCharacter(from: .whitespacesAndNewlines, options: .backwards, range: lower..<upper)?.upperBound ?? upper
            result.append(.init(text: String(remaining[..<split]), isPlaceholder: false)); remaining = String(remaining[split...])
        }
        if !remaining.isEmpty { result.append(.init(text: remaining, isPlaceholder: false)) }
        return result
    }
}
