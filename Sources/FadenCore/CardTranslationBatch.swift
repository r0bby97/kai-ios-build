import Foundation

/// The exact requests/restoration used by Apple's batch translation. Variables never leave the app.
public struct CardTranslationBatch: Sendable {
    public struct Request: Sendable {
        public var id: String
        public var text: String
    }
    public let requests: [Request]
    private let plans: [String: [TemplatePart]]
    public init(fields: [String: String]) {
        var requests: [Request] = []; var plans: [String: [TemplatePart]] = [:]
        for (key, value) in fields.sorted(by: { $0.key < $1.key }) {
            let parts = TemplateText.parts(value); plans[key] = parts
            for (i, part) in parts.enumerated() where !part.isPlaceholder && part.text.contains(where: \.isLetter) {
                requests.append(.init(id: "\(key):\(i)", text: part.text))
            }
        }
        self.requests = requests; self.plans = plans
    }
    public func restore(_ translations: [String: String]) throws -> [String: String] {
        var result: [String: String] = [:]
        for (key, parts) in plans {
            var text = ""
            for (i, part) in parts.enumerated() {
                if part.isPlaceholder || !part.text.contains(where: \.isLetter) { text += part.text; continue }
                guard let translated = translations["\(key):\(i)"], !translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw FadenError.invalidData("Die Übersetzung wurde nicht vollständig geliefert.")
                }
                let leading = String(part.text.prefix(while: \.isWhitespace))
                let trailing = String(part.text.reversed().prefix(while: \.isWhitespace).reversed())
                text += leading + translated.trimmingCharacters(in: .whitespacesAndNewlines) + trailing
            }
            result[key] = text
        }
        return result
    }
}
