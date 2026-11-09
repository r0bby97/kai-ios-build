import Foundation

public struct CataloguePosition: Equatable, Sendable {
    public var page: Int
    public var cursor: String?
    public init(page: Int = 1, cursor: String? = nil) { self.page = max(1, page); self.cursor = cursor }
}

public struct CatalogueNotice: Equatable, Sendable {
    public var source: CatalogueSource
    public var message: String
    public init(source: CatalogueSource, message: String) { self.source = source; self.message = message }
}

public struct CataloguePage: Sendable {
    public var cards: [CharacterCard]
    public var hasMore: Bool
    public var totalCount: Int?
    public var nextCursor: String?
    public var continuations: [CatalogueSource: CataloguePosition]
    public var notices: [CatalogueNotice]
    public init(cards: [CharacterCard], hasMore: Bool, totalCount: Int? = nil, nextCursor: String? = nil,
                continuations: [CatalogueSource: CataloguePosition] = [:], notices: [CatalogueNotice] = []) {
        self.cards = cards; self.hasMore = hasMore; self.totalCount = totalCount; self.nextCursor = nextCursor
        self.continuations = continuations; self.notices = notices
    }
}

/// Searches sources independently, keeping their pagination and failures separate.
public enum CatalogueSearch {
    public static func run(source: CatalogueSource, positions: [CatalogueSource: CataloguePosition]? = nil,
                           fetch: @escaping @Sendable (CatalogueSource, CataloguePosition) async throws -> CataloguePage,
                           updated: @escaping @Sendable (CataloguePage) async -> Void = { _ in }) async throws -> CataloguePage {
        let requested = positions ?? Dictionary(uniqueKeysWithValues: source.sources.map { ($0, CataloguePosition()) })
        let sources = source.sources.filter { requested[$0] != nil }
        guard !sources.isEmpty else { return .init(cards: [], hasMore: false) }
        return try await withThrowingTaskGroup(of: Outcome.self) { group in
            for current in sources {
                let position = requested[current]!
                group.addTask {
                    do { return .success(current, try await fetch(current, position)) }
                    catch {
                        if Task.isCancelled || error is CancellationError { throw CancellationError() }
                        return .failure(current, error.localizedDescription)
                    }
                }
            }
            var pages: [CatalogueSource: CataloguePage] = [:]
            var failures: [CatalogueSource: String] = [:]
            var next = requested
            for try await outcome in group {
                try Task.checkCancellation()
                switch outcome {
                case .success(let current, let page):
                    pages[current] = page
                    next[current] = page.hasMore ? CataloguePosition(page: requested[current]!.page + 1, cursor: page.nextCursor) : nil
                case .failure(let current, let message): failures[current] = message
                }
                let partial = merged(sources: sources, pages: pages, failures: failures, next: next)
                await updated(partial)
            }
            try Task.checkCancellation()
            guard !pages.isEmpty else {
                let messages = sources.compactMap { current in failures[current].map { current.title + ": " + $0 } }
                throw FadenError.network(messages.joined(separator: "\n"))
            }
            return merged(sources: sources, pages: pages, failures: failures, next: next)
        }
    }
    private enum Outcome: Sendable {
        case success(CatalogueSource, CataloguePage)
        case failure(CatalogueSource, String)
    }
    private static func merged(sources: [CatalogueSource], pages: [CatalogueSource: CataloguePage],
                               failures: [CatalogueSource: String], next: [CatalogueSource: CataloguePosition]) -> CataloguePage {
        // Round-robin preserves each source's ranking without comparing unrelated scores.
        var cards: [CharacterCard] = []; var seen = Set<String>()
        let longest = pages.values.map { $0.cards.count }.max() ?? 0
        for index in 0..<longest {
            for source in sources {
                if let list = pages[source]?.cards, index < list.count, seen.insert(list[index].id).inserted { cards.append(list[index]) }
            }
        }
        let counts = sources.compactMap { pages[$0]?.totalCount }
        let total = counts.count == sources.count ? counts.reduce(0, +) : nil
        let notices = sources.compactMap { source in failures[source].map { CatalogueNotice(source: source, message: $0) } }
        return .init(cards: cards, hasMore: !next.isEmpty, totalCount: total, continuations: next, notices: notices)
    }
}
