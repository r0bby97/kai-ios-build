import Foundation

/// Text-only HTML interpretation. Never loads resources or executes scripts.
public enum CardMarkup {
    public static func clean(_ source: String) -> String {
        if let structure = CardStructuredText.parse(source) {
            return structure.restoring(structure.translationFields.mapValues(plain))
        }
        return plain(source)
    }
    public static func plain(_ source: String) -> String {
        guard source.contains("<") || source.contains("&") else { return source }
        guard source.utf8.count <= 2 * 1024 * 1024 else { return source }
        var text = source
        // Decode once before tokenizing, including escaped HTML commonly used in exports.
        text = entities(text)
        func replace(_ pattern: String, _ replacement: String) {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        replace(#"(?is)<!--.*?(?:-->|$)"#, "")
        replace(#"(?is)<(script|style|iframe|object|template|head|svg|canvas)\b[^>]*>.*?(?:</\1\s*>|$)"#, "")
        // Only recognize HTML names. Preserve RP control markers and comparisons.
        let tags = "a|abbr|article|aside|b|blockquote|body|br|button|caption|center|code|col|colgroup|dd|del|details|div|dl|dt|em|figcaption|figure|font|footer|form|h[1-6]|head|header|hr|html|i|img|input|label|li|link|main|mark|meta|nav|ol|p|pre|section|small|span|strong|sub|summary|sup|table|tbody|td|textarea|th|thead|title|tr|u|ul|video|source|audio"
        let pattern = #"(?is)</?(?:"# + tags + #")\b(?:[^>\"']|\"[^\"]*\"|'[^']*')*>"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return source }
        for match in expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: text) else { continue }
            let tag = String(text[range]).lowercased()
            let isTag: (String) -> Bool = { name in tag.range(of: "^</?" + name + "(?:\\s|/|>)", options: .regularExpression) != nil }
            let replacement: String
            if isTag("li") && !tag.hasPrefix("</") { replacement = "\n• " }
            else if ["br","p","div","li","tr","h[1-6]","blockquote","section","article","hr","summary","pre","ul","ol","details"].contains(where: isTag) { replacement = "\n" }
            else if isTag("td") || isTag("th") { replacement = " · " }
            else { replacement = "" }
            text.replaceSubrange(range, with: replacement)
        }
        guard text != source else { return source }
        replace(#"[ \t]+\n"#, "\n")
        replace(#"\n[ \t]+"#, "\n")
        replace(#"\n{3,}"#, "\n\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static func entities(_ text: String) -> String {
        let named = ["amp":"&", "lt":"<", "gt":">", "quot":"\"", "apos":"'", "nbsp":" ", "ndash":"–", "mdash":"—", "hellip":"…", "lsquo":"‘", "rsquo":"’", "ldquo":"“", "rdquo":"”", "bull":"•", "copy":"©", "auml":"ä", "ouml":"ö", "uuml":"ü", "szlig":"ß"]
        guard let regex = try? NSRegularExpression(pattern: #"&(#x[0-9A-Fa-f]+|#[0-9]+|[A-Za-z]+);"#) else { return text }
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: result), let nameRange = Range(match.range(at: 1), in: text) else { continue }
            let name = String(text[nameRange]); var value = named[name]
            if name.hasPrefix("#") {
                let hex = name.hasPrefix("#x")
                if let code = UInt32(name.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10), let scalar = UnicodeScalar(code), code != 0 { value = String(scalar) }
            }
            if let value { result.replaceSubrange(range, with: value) }
        }
        return result
    }
}
