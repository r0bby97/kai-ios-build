import Foundation

public enum CatalogueLibrary {
    /// Publish previews immediately, without replacing cached definitions or user edits.
    public static func merging(_ previews: [CharacterCard], into existing: [CharacterCard], order: [String]) -> [CharacterCard] {
        var cards = existing
        for var card in previews where !cards.contains(where: { $0.id == card.id }) {
            if card.languageCode != "de" { card.languageCode = "pending" }
            cards.append(card)
        }
        let ranks = Dictionary(order.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        return cards.enumerated().sorted {
            let left = ranks[$0.element.id] ?? Int.max, right = ranks[$1.element.id] ?? Int.max
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
    }
}

public struct CataloguePreparationResult: Sendable {
    public var id: String
    public var card: CharacterCard?
}

public enum CataloguePreparation {
    /// Rolling concurrency: a slow card must not hold back completed cards in its batch.
    public static func run(cards: [CharacterCard], concurrency: Int = 3,
                           fetch: @escaping @Sendable (CharacterCard) async throws -> CharacterCard,
                           finished: @escaping @Sendable (CataloguePreparationResult) async -> Void) async throws {
        try await withThrowingTaskGroup(of: CataloguePreparationResult.self) { group in
            var next = 0
            func enqueue(_ card: CharacterCard) {
                group.addTask {
                    do { return .init(id: card.id, card: try await fetch(card)) }
                    catch is CancellationError { throw CancellationError() }
                    catch { return .init(id: card.id, card: nil) }
                }
            }
            for _ in 0..<min(max(1, concurrency), cards.count) { enqueue(cards[next]); next += 1 }
            for try await result in group {
                try Task.checkCancellation()
                await finished(result)
                if next < cards.count { enqueue(cards[next]); next += 1 }
            }
        }
    }
}
