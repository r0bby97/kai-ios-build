import Foundation

/// The exact requests/restoration used by Apple's batch translation. Variables never leave the app.
public struct CardTranslationBatch: Sendable {
    public struct Request: Sendable {
        public var id: String
        public var text: String
    }
    public let requests: [Request]
    private struct Entry: Sendable {
        var field: String
        var path: String?
        var parts: [TemplatePart]
        var prefix: String
    }
    private let entries: [Entry]
    private let structures: [String: CardStructuredText]
    public init(fields: [String: String]) {
        var requests: [Request] = [], entries: [Entry] = []
        var structures: [String: CardStructuredText] = [:]
        func add(_ text: String, field: String, path: String?) {
            let parts = TemplateText.parts(CardMarkup.plain(text)).flatMap { part in
                part.isPlaceholder ? [part] : Self.segments(part.text).map { TemplatePart(text: $0, isPlaceholder: false) }
            }
            let prefix = String(entries.count)
            entries.append(.init(field: field, path: path, parts: parts, prefix: prefix))
            for (i, part) in parts.enumerated() where !part.isPlaceholder && part.text.contains(where: \.isLetter) {
                requests.append(.init(id: "\(prefix):\(i)", text: part.text))
            }
        }
        for (key, value) in fields.sorted(by: { $0.key < $1.key }) {
            if let structure = CardStructuredText.parse(value) {
                structures[key] = structure
                for (path, text) in structure.translationFields.sorted(by: { $0.key < $1.key }) { add(text, field: key, path: path) }
            } else { add(value, field: key, path: nil) }
        }
        self.requests = requests; self.entries = entries; self.structures = structures
    }
    public func restore(_ translations: [String: String]) throws -> [String: String] {
        var result: [String: String] = [:]
        var structuredValues: [String: [String: String]] = [:]
        for entry in entries {
            var text = ""
            for (i, part) in entry.parts.enumerated() {
                if part.isPlaceholder || !part.text.contains(where: \.isLetter) { text += part.text; continue }
                guard let translated = translations["\(entry.prefix):\(i)"], !translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw FadenError.invalidData("Die Übersetzung wurde nicht vollständig geliefert.")
                }
                let leading = String(part.text.prefix(while: \.isWhitespace))
                let trailing = String(part.text.reversed().prefix(while: \.isWhitespace).reversed())
                text += leading + translated.trimmingCharacters(in: .whitespacesAndNewlines) + trailing
            }
            if let path = entry.path { structuredValues[entry.field, default: [:]][path] = text }
            else { result[entry.field] = text }
        }
        for (key, structure) in structures { result[key] = structure.restoring(structuredValues[key] ?? [:]) }
        return result
    }
    /// Preserve line endings and split changes of writing system so a Korean
    /// paragraph is never sent as part of an English-only translation request.
    private static func segments(_ text: String) -> [String] {
        var result: [String] = [], current = "", script: Int?
        for character in text {
            let next = writingSystem(character)
            if let next, let script, next != script, !current.isEmpty { result.append(current); current = "" }
            if let next { script = next }
            current.append(character)
            if character == "\n" || character == "\r" || character == "\r\n" {
                result.append(current); current = ""; script = nil
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
    private static func writingSystem(_ character: Character) -> Int? {
        guard character.isLetter, let scalar = character.unicodeScalars.first else { return nil }
        switch scalar.value {
        case 0x0041...0x024f: return 0
        case 0x0400...0x052f: return 1
        case 0x1100...0x11ff, 0x3130...0x318f, 0xac00...0xd7af: return 2
        case 0x3040...0x30ff, 0x3400...0x9fff: return 3
        case 0x0590...0x05ff: return 4
        case 0x0600...0x08ff: return 5
        case 0x0900...0x097f: return 6
        case 0x0e00...0x0e7f: return 7
        default: return 8
        }
    }
}
