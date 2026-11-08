import Foundation

public enum MenuTheme: String, Codable, CaseIterable, Sendable {
    case dark, light
    public var title: String { self == .dark ? "Dunkel" : "Hell" }
}

public enum RoleplayKind: String, Codable, Sendable {
    case thought = "gedanke_privat"
    case speech = "laut_gesagt"
    case context = "erzaehlkontext_nicht_gesprochen"
}

public struct RoleplayPart: Equatable, Sendable {
    public var kind: RoleplayKind
    /// Original delimiters are retained for faithful display, editing and exports.
    public var text: String
}

public enum RoleplayText {
    /// Only balanced quotes outside thought spans count as audible speech.
    /// An unfinished thought remains private through the end of the message.
    public static func parts(_ text: String) -> [RoleplayPart] {
        let chars = Array(text)
        var result: [RoleplayPart] = []
        var pending = ""; var index = 0
        func flush() {
            if !pending.isEmpty { result.append(.init(kind: .context, text: pending)); pending = "" }
        }
        func escaped(_ position: Int) -> Bool {
            var cursor = position; var slashes = 0
            while cursor > 0, chars[cursor - 1] == "\\" { slashes += 1; cursor -= 1 }
            return slashes % 2 != 0
        }
        func thoughtUpper(_ start: Int) -> Int {
            let width = start + 1 < chars.count && chars[start + 1] == "*" ? 2 : 1
            var end = start + width
            while end < chars.count {
                if chars[end] == "*", !escaped(end),
                   width == 1 || (end + 1 < chars.count && chars[end + 1] == "*") { break }
                end += 1
            }
            return min(chars.count, end + (end < chars.count ? width : 0))
        }
        let quotes: [Character: Character] = ["\"": "\"", "„": "“", "“": "”", "«": "»", "»": "«"]
        while index < chars.count {
            let character = chars[index]
            if !escaped(index), character == "*" {
                flush()
                let upper = thoughtUpper(index)
                result.append(.init(kind: .thought, text: String(chars[index..<upper])))
                index = upper
            } else if !escaped(index), let closing = quotes[character] {
                var end = index + 1
                while end < chars.count {
                    if chars[end] == "*", !escaped(end) { end = thoughtUpper(end) }
                    else if chars[end] == closing, !escaped(end) { break }
                    else { end += 1 }
                }
                if end < chars.count {
                    flush()
                    var cursor = index; var spokenStart = index
                    while cursor <= end {
                        if chars[cursor] == "*", !escaped(cursor) {
                            if cursor > spokenStart { result.append(.init(kind: .speech, text: String(chars[spokenStart..<cursor]))) }
                            let upper = thoughtUpper(cursor)
                            result.append(.init(kind: .thought, text: String(chars[cursor..<upper])))
                            cursor = upper; spokenStart = upper
                        } else { cursor += 1 }
                    }
                    if spokenStart <= end { result.append(.init(kind: .speech, text: String(chars[spokenStart...end]))) }
                    index = end + 1
                } else { pending.append(character); index += 1 }
            } else { pending.append(character); index += 1 }
        }
        flush()
        return result
    }

    /// JSON keeps literal user text separate from the app's segment labels.
    public static func promptContent(_ text: String) -> String {
        let values = parts(text).filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { ["art": $0.kind.rawValue, "text": $0.text] }
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys, .withoutEscapingSlashes]),
              let encoded = String(data: data, encoding: .utf8) else { return text }
        return "Nutzernachricht in getrennten Erzählabschnitten:\n" + encoded
    }

    public static let instructions = """
    Getrenntes Erzähl- und Figurenwissen:
    gedanke_privat (*Sternchen*): für JEDE Figur unhörbar und unbekannt, auch Zitate darin. Nur Erzählregie; nie als Figur beantworten, zitieren oder daraus Wissen ableiten.
    laut_gesagt: nur geschlossene Anführungszeichen außerhalb von Gedanken, etwa "Hallo" oder „Hallo“, sind ausdrücklich Rede zum Gegenüber.
    erzaehlkontext_nicht_gesprochen: Text ohne Anführungszeichen, möglicherweise Selbstgespräch, ist NICHT automatisch hörbar. Nur ausdrücklich sichtbare Handlungen sind wahrnehmbar.
    Diese Trennung gilt auch in Erinnerungen und älteren Auszügen. Reine Gedanken erlauben eine sichtbare Szenenfortsetzung, keine Kenntnis des Geheimnisses. Keine Entscheidungen oder Gedanken für den Nutzer schreiben.
    """
}
