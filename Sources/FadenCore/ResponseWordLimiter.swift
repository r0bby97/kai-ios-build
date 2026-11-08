import Foundation

public struct WordLimitedText: Sendable {
    public var text: String
    public var reachedLimit: Bool
}

/// Counts whitespace-separated words containing a letter or number, preserving complete words
/// across arbitrary stream chunks. A word is cut only when a subsequent word actually begins.
public struct ResponseWordLimiter: Sendable {
    public let maximumWords: Int
    private var buffer = ""
    private var stopped = false
    public init(maximumWords: Int) { self.maximumWords = max(1, maximumWords) }
    public mutating func append(_ delta: String) -> WordLimitedText {
        guard !stopped else { return .init(text: buffer, reachedLimit: true) }
        buffer += delta
        var count = 0
        for word in buffer.split(whereSeparator: \.isWhitespace) where word.contains(where: { $0.isLetter || $0.isNumber }) {
            count += 1
            if count > maximumWords {
                buffer = String(buffer[..<word.startIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                stopped = true; break
            }
        }
        return .init(text: buffer, reachedLimit: stopped)
    }
}
