import Foundation

public enum CardCodec {
    public static let maximumBytes = 24 * 1024 * 1024
    public static func decode(_ data: Data, filename: String = "") throws -> CharacterCard {
        guard data.count <= maximumBytes else { throw FadenError.invalidData("Die Charakterkarte ist zu groß (maximal 24 MB).") }
        let pngSignature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]
        if Array(data.prefix(8)) == pngSignature { return try decodePNG(data) }
        return try decodeJSON(data)
    }
    public static func decodeJSON(_ data: Data) throws -> CharacterCard {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FadenError.invalidData("Keine gültige Charakterkarte.")
        }
        if root["firstMessage"] != nil {
            return try JSONDecoder().decode(CharacterCard.self, from: data)
        }
        let card = root["data"] as? [String: Any] ?? root
        func string(_ key: String) -> String { card[key] as? String ?? "" }
        let name = string("name").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw FadenError.invalidData("Der Charakter hat keinen Namen.") }
        let book = card["character_book"] as? [String: Any] ?? [:]
        let lore = (book["entries"] as? [[String: Any]] ?? []).compactMap { entry -> LoreEntry? in
            guard entry["enabled"] as? Bool != false, let text = entry["content"] as? String else { return nil }
            return LoreEntry(keys: entry["keys"] as? [String] ?? [], content: text, alwaysOn: entry["constant"] as? Bool ?? false)
        }
        var result = CharacterCard(name: name, tagline: string("tagline"), description: string("description"),
            personality: string("personality"), scenario: string("scenario"), firstMessage: string("first_mes"),
            exampleDialogue: string("mes_example"), systemPrompt: string("system_prompt"),
            creatorNotes: string("creator_notes"), tags: card["tags"] as? [String] ?? [],
            alternateGreetings: card["alternate_greetings"] as? [String] ?? [], lore: lore,
            creator: string("creator").isEmpty ? "Importiert" : string("creator"))
        if let extensions = card["extensions"] as? [String: Any], let faden = extensions["faden"] as? [String: Any],
           let group = faden["is_ensemble"] as? Bool {
            result.castOverride = .init(isEnsemble: group, names: faden["cast_names"] as? [String] ?? [])
        }
        return result
    }
    private static func decodePNG(_ data: Data) throws -> CharacterCard {
        let bytes = [UInt8](data); var offset = 8; var fallback: Data?
        while offset + 12 <= bytes.count {
            let length = bytes[offset..<offset+4].reduce(0) { ($0 << 8) | Int($1) }
            guard length <= maximumBytes, offset + 12 + length <= bytes.count else {
                throw FadenError.invalidData("Die PNG-Karte ist beschädigt.")
            }
            let type = String(bytes: bytes[offset+4..<offset+8], encoding: .ascii) ?? ""
            let payload = Array(bytes[offset+8..<offset+8+length])
            if type == "tEXt" || type == "iTXt", let zero = payload.firstIndex(of: 0) {
                let keyword = String(bytes: payload[..<zero], encoding: .utf8) ?? ""
                if keyword == "chara" || keyword == "ccv3" {
                    var start = zero + 1
                    if type == "iTXt" {
                        guard start + 2 <= payload.count, payload[start] == 0 else {
                            throw FadenError.invalidData("Komprimierte PNG-Metadaten werden nicht unterstützt. Bitte die JSON-Karte importieren.")
                        }
                        start += 2
                        for _ in 0..<2 {
                            guard start <= payload.count, let end = payload[start...].firstIndex(of: 0) else {
                                throw FadenError.invalidData("Ungültige PNG-Metadaten.")
                            }
                            start = end + 1
                        }
                    }
                    guard start <= payload.count else { throw FadenError.invalidData("Ungültige PNG-Karte.") }
                    let raw = Data(payload[start...])
                    let decoded = Data(base64Encoded: raw, options: .ignoreUnknownCharacters) ?? raw
                    if keyword == "ccv3" { return try decodeJSON(decoded) }
                    fallback = decoded
                }
            }
            offset += length + 12
            if type == "IEND" { break }
        }
        guard let fallback else { throw FadenError.invalidData("In diesem Bild wurde keine Charakterkarte gefunden.") }
        return try decodeJSON(fallback)
    }
    public static func encode(_ card: CharacterCard) throws -> Data {
        let entries: [[String: Any]] = card.lore.map { ["keys": $0.keys, "content": $0.content, "constant": $0.alwaysOn, "enabled": true] }
        var data: [String: Any] = ["name": card.name, "description": card.description,
            "personality": card.personality, "scenario": card.scenario, "first_mes": card.firstMessage,
            "mes_example": card.exampleDialogue, "system_prompt": card.systemPrompt,
            "creator_notes": card.creatorNotes, "creator": card.creator, "tags": card.tags,
            "alternate_greetings": card.alternateGreetings, "character_book": ["entries": entries]]
        if let cast = card.castOverride {
            data["extensions"] = ["faden": ["is_ensemble": cast.isEnsemble, "cast_names": cast.names]]
        }
        return try JSONSerialization.data(withJSONObject: ["spec": "chara_card_v2", "spec_version": "2.0", "data": data], options: [.prettyPrinted, .sortedKeys])
    }
}

public struct SSEEvent: Equatable, Sendable {
    public var name: String
    public var data: String
}
public struct SSEParser {
    private var name = "message"
    private var lines: [String] = []
    public init() {}
    public mutating func consume(_ line: String) -> SSEEvent? {
        let line = line.hasSuffix("\r") ? String(line.dropLast()) : line
        if line.isEmpty {
            defer { name = "message"; lines = [] }
            return lines.isEmpty ? nil : SSEEvent(name: name, data: lines.joined(separator: "\n"))
        }
        if line.hasPrefix(":") { return nil }
        let pieces = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let key = String(pieces[0]); var value = pieces.count > 1 ? String(pieces[1]) : ""
        if value.hasPrefix(" ") { value.removeFirst() }
        if key == "event" { name = value }
        if key == "data" { lines.append(value) }
        return nil
    }
    public mutating func finish() -> SSEEvent? { consume("") }
}
