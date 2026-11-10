import Foundation
import CoreFoundation

public struct CardPropertyRow: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String?
    public var text: String
    public var depth: Int
    public var isHeading: Bool
}

/// Reads data, never evaluates JavaScript. Unrecognized or excessive input stays
/// ordinary text rather than losing a fragment of the character definition.
public struct CardStructuredText: Sendable {
    private let value: Value
    public let rows: [CardPropertyRow]
    public var plainText: String { rows.map { [$0.title, $0.text].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ": ") }.joined(separator: "\n") }

    public static func parse(_ text: String) -> CardStructuredText? {
        guard text.utf8.count <= 256 * 1024 else { return nil }
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```"), clean.hasSuffix("```"), let line = clean.firstIndex(of: "\n") {
            clean = String(clean[clean.index(after: line)..<clean.index(clean.endIndex, offsetBy: -3)]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard clean.first == "{" || clean.first == "[", let data = clean.data(using: .utf8) else { return nil }
        var options: JSONSerialization.ReadingOptions = []
        #if canImport(Darwin)
        options.insert(.json5Allowed)
        #endif
        let root: Value?
        if let object = try? JSONSerialization.jsonObject(with: data, options: options) {
            root = try? Value.read(object, depth: 0)
        } else { root = wpp(clean) }
        guard let root else { return nil }
        var rows: [CardPropertyRow] = []
        guard (try? root.appendRows(to: &rows, path: "", title: nil, depth: 0)) != nil, !rows.isEmpty else { return nil }
        return .init(value: root, rows: rows)
    }

    /// Only text values are translated. Keys, numbers, booleans, proper names
    /// and the surrounding data structure remain intact.
    public var translationFields: [String: String] {
        var fields: [String: String] = [:]
        _ = value.mapStrings(path: "", key: nil) { path, key, text in
            if !Self.isName(key) { fields[path] = text }
            return text
        }
        return fields
    }
    public func restoring(_ fields: [String: String]) -> String {
        value.mapStrings(path: "", key: nil) { path, key, text in
            Self.isName(key) ? text : fields[path] ?? text
        }.json
    }
    public func emphasizedFields(_ keys: Set<String>) -> String {
        var sections: [String] = []
        value.collectFields(keys, owner: nil, into: &sections)
        return sections.joined(separator: "\n")
    }

    private static func isName(_ key: String?) -> Bool {
        guard let key else { return false }
        return ["name", "fullname", "character", "charactername", "char", "charakter", "charaktername"].contains(key.lowercased().filter(\.isLetter))
    }
    private static func title(_ key: String) -> String {
        let names = ["name":"Name", "character":"Charakter", "age":"Alter", "gender":"Geschlecht", "sex":"Geschlecht", "species":"Spezies", "personality":"Persönlichkeit", "traits":"Eigenschaften", "appearance":"Aussehen", "height":"Größe", "occupation":"Beruf", "backstory":"Vergangenheit", "background":"Hintergrund", "scenario":"Ausgangsszene", "likes":"Vorlieben", "dislikes":"Abneigungen", "relationships":"Beziehungen", "speakingstyle":"Sprechweise", "speech":"Sprechweise", "habits":"Gewohnheiten", "goals":"Ziele", "abilities":"Fähigkeiten", "description":"Beschreibung"]
        if let known = names[key.lowercased().filter(\.isLetter)] { return known }
        return key.replacingOccurrences(of: #"([a-z])([A-Z])"#, with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
    }
    private enum Invalid: Error { case data }
    private indirect enum Value: Sendable {
        case object([String: Value]), array([Value]), text(String), number(String), boolean(Bool), null
        static func read(_ input: Any, depth: Int) throws -> Value {
            guard depth <= 12 else { throw Invalid.data }
            if let object = input as? [String: Any] { return .object(try object.mapValues { try read($0, depth: depth + 1) }) }
            if let array = input as? [Any] { return .array(try array.map { try read($0, depth: depth + 1) }) }
            if let text = input as? String { return .text(text) }
            if let number = input as? NSNumber {
                if CFGetTypeID(number) == CFBooleanGetTypeID() { return .boolean(number.boolValue) }
                guard number.doubleValue.isFinite else { throw Invalid.data }
                return .number(number.stringValue)
            }
            if input is NSNull { return .null }
            throw Invalid.data
        }
        private static func segment(_ key: String) -> String { key.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1") }
        func mapStrings(path: String, key: String?, transform: (String, String?, String) -> String) -> Value {
            switch self {
            case .text(let text): return .text(transform(path, key, text))
            case .object(let values): return .object(Dictionary(uniqueKeysWithValues: values.map { k, v in (k, v.mapStrings(path: path + "/" + Self.segment(k), key: k, transform: transform)) }))
            case .array(let values): return .array(values.enumerated().map { $0.element.mapStrings(path: path + "/\($0.offset)", key: key, transform: transform) })
            default: return self
            }
        }
        var scalar: String? {
            switch self { case .text(let value), .number(let value): value; case .boolean(let value): value ? "Ja" : "Nein"; case .null: "Keine Angabe"; default: nil }
        }
        func collectFields(_ keys: Set<String>, owner: String?, into result: inout [String]) {
            switch self {
            case .object(let values):
                let name = values["name"]?.scalar ?? values["Character"]?.scalar ?? owner
                for key in values.keys.sorted() {
                    let normalized = key.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE")).filter(\.isLetter)
                    if keys.contains(normalized), let value = values[key] {
                        var rows: [CardPropertyRow] = []
                        if (try? value.appendRows(to: &rows, path: "", title: nil, depth: 0)) != nil {
                            let text = rows.map { [$0.title, $0.text].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ": ") }.joined(separator: "\n")
                            result.append((name.map { $0 + " · " } ?? "") + CardStructuredText.title(key) + ": " + text)
                        }
                    } else { values[key]?.collectFields(keys, owner: name, into: &result) }
                }
            case .array(let values): for value in values { value.collectFields(keys, owner: owner, into: &result) }
            default: break
            }
        }
        func appendRows(to rows: inout [CardPropertyRow], path: String, title: String?, depth: Int) throws {
            guard rows.count < 256 else { throw Invalid.data }
            if let scalar {
                if !scalar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rows.append(.init(id: path, title: title, text: scalar, depth: min(depth, 2), isHeading: false))
                }
                return
            }
            if case .array(let values) = self, values.allSatisfy({ $0.scalar != nil }) {
                rows.append(.init(id: path, title: title, text: values.compactMap(\.scalar).map { "• " + $0 }.joined(separator: "\n"), depth: min(depth, 2), isHeading: false))
                return
            }
            if let title { rows.append(.init(id: path + ":heading", title: title, text: "", depth: min(depth, 2), isHeading: true)) }
            switch self {
            case .object(let values):
                for key in values.keys.sorted() {
                    try values[key]!.appendRows(to: &rows, path: path + "/" + Self.segment(key), title: CardStructuredText.title(key), depth: depth + (title == nil ? 0 : 1))
                }
            case .array(let values):
                for (index, value) in values.enumerated() {
                    let name: String
                    if case .object(let fields) = value, case .text(let text) = fields["name"] { name = text }
                    else { name = "Abschnitt \(index + 1)" }
                    try value.appendRows(to: &rows, path: path + "/\(index)", title: name, depth: depth + (title == nil ? 0 : 1))
                }
            default: break
            }
        }
        var json: String {
            switch self {
            case .text(let value): return String(decoding: (try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])) ?? Data("\"\"".utf8), as: UTF8.self)
            case .number(let value): return value
            case .boolean(let value): return value ? "true" : "false"
            case .null: return "null"
            case .array(let values): return "[" + values.map(\.json).joined(separator: ",") + "]"
            case .object(let values): return "{" + values.keys.sorted().map { Value.text($0).json + ":" + values[$0]!.json }.joined(separator: ",") + "}"
            }
        }
    }

    /// The common W++ attribute form, e.g. [Character("Mara"){Age("28")...}].
    /// Require complete coverage by data fields and wrappers; prose is left alone.
    private static func wpp(_ text: String) -> Value? {
        let quoted = #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#
        guard let attributes = try? NSRegularExpression(pattern: #"([\p{L}_][\p{L}\p{N}_-]*)\s*\(((?:"# + quoted + #"|[^()"'])*)\)"#),
              let strings = try? NSRegularExpression(pattern: quoted) else { return nil }
        let matches = attributes.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard matches.count >= 2, matches.count <= 128 else { return nil }
        var remainder = text
        for match in matches.reversed() { if let range = Range(match.range, in: remainder) { remainder.removeSubrange(range) } }
        guard remainder.allSatisfy({ $0.isWhitespace || "[]{}:;,".contains($0) }) else { return nil }
        var fields: [String: Value] = [:]
        for match in matches {
            guard let keyRange = Range(match.range(at: 1), in: text), let bodyRange = Range(match.range(at: 2), in: text) else { return nil }
            let key = String(text[keyRange]), body = String(text[bodyRange])
            let literals = strings.matches(in: body, range: NSRange(body.startIndex..., in: body))
            var rest = body
            for literal in literals.reversed() { if let range = Range(literal.range, in: rest) { rest.removeSubrange(range) } }
            let value: Value
            if !literals.isEmpty {
                guard rest.allSatisfy({ $0.isWhitespace || "+,".contains($0) }) else { return nil }
                let parts = literals.compactMap { literal -> Value? in
                    guard let range = Range(literal.range, in: body), let decoded = decodeQuoted(String(body[range])) else { return nil }
                    return .text(decoded)
                }
                guard parts.count == literals.count else { return nil }
                value = parts.count == 1 ? parts[0] : .array(parts)
            } else {
                guard let data = body.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]), let scalar = try? Value.read(object, depth: 0), scalar.scalar != nil else { return nil }
                value = scalar
            }
            if let previous = fields[key] { fields[key] = .array([previous, value]) }
            else { fields[key] = value }
        }
        return .object(fields)
    }
    private static func decodeQuoted(_ text: String) -> String? {
        if text.first == "\"", let data = text.data(using: .utf8) { return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) as? String }
        guard text.first == "'", text.last == "'" else { return nil }
        var result = "", escaped = false
        for character in text.dropFirst().dropLast() {
            if escaped {
                switch character { case "n": result += "\n"; case "r": result += "\r"; case "t": result += "\t"; case "'", "\"", "\\": result.append(character); default: return nil }
                escaped = false
            } else if character == "\\" { escaped = true } else { result.append(character) }
        }
        return escaped ? nil : result
    }
}
