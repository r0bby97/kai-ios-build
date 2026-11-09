import XCTest
@testable import FadenCore

final class CatalogueSearchTests: XCTestCase {
    func testFastSourcePublishesBeforeSlowSourceAndFailuresDoNotHideCards() async throws {
        let gate = SearchGate()
        let received = SearchUpdates()
        let fast = expectation(description: "Cardex results publish before slow Chub returns")
        let task = Task {
            try await CatalogueSearch.run(source: .all, fetch: { source, _ in
                switch source {
                case .cardex: return .init(cards: [self.card("cardex/a"), self.card("cardex/b")], hasMore: false)
                case .chub: await gate.wait(); return .init(cards: [self.card("chub/a")], hasMore: false)
                case .janny: throw SearchError.offline
                case .all: XCTFail("All is a selection, never a remote database"); return .init(cards: [], hasMore: false)
                }
            }, updated: { page in
                await received.append(page)
                if page.cards.contains(where: { $0.id == "cardex/a" }) && !page.cards.contains(where: { $0.id == "chub/a" }) { fast.fulfill() }
            })
        }
        fast.assertForOverFulfill = false
        await fulfillment(of: [fast], timeout: 2)
        await gate.open()
        let result = try await task.value
        XCTAssertEqual(result.cards.map(\.id), ["cardex/a", "chub/a", "cardex/b"])
        XCTAssertEqual(result.notices.map(\.source), [.janny])
        XCTAssertEqual(result.continuations, [.janny: .init(page: 1)])
        XCTAssertNil(result.totalCount)
    }
    func testIndependentPaginationRetriesFailedPageAndDoesNotRestartExhaustedSource() async throws {
        let requests = SearchRequests()
        let first = try await CatalogueSearch.run(source: .all, fetch: { source, position in
            if source == .janny { throw SearchError.offline }
            return .init(cards: [self.card(source.rawValue + "/1")], hasMore: source == .cardex, nextCursor: source == .cardex ? "cursor-2" : nil)
        })
        let second = try await CatalogueSearch.run(source: .all, positions: first.continuations, fetch: { source, position in
            await requests.append(source, position)
            return .init(cards: [self.card(source.rawValue + "/2")], hasMore: false)
        })
        let values = await requests.values
        XCTAssertEqual(values[.cardex], .init(page: 2, cursor: "cursor-2"))
        XCTAssertEqual(values[.janny], .init(page: 1))
        XCTAssertNil(values[.chub])
        XCTAssertFalse(second.hasMore)
        XCTAssertTrue(second.notices.isEmpty)
    }
    func testDuplicateIDsAreNotRepeatedAndUnknownTotalsAreNotInvented() async throws {
        let result = try await CatalogueSearch.run(source: .all, fetch: { source, _ in
            .init(cards: [self.card("same"), self.card(source.rawValue)], hasMore: false, totalCount: 5)
        })
        XCTAssertEqual(result.cards.map(\.id), ["same", "cardex", "chub", "janny"])
        XCTAssertEqual(result.totalCount, 15)
    }
    func testAllFailuresRemainAnErrorWithNamesOfFailedSources() async {
        do {
            _ = try await CatalogueSearch.run(source: .all, fetch: { _, _ in throw SearchError.offline })
            XCTFail("An outage must not masquerade as an empty successful search")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Cardex"))
            XCTAssertTrue(error.localizedDescription.contains("Chub"))
            XCTAssertTrue(error.localizedDescription.contains("JannyAI"))
        }
    }
    func testCancellationStopsAllSourceWork() async throws {
        let started = expectation(description: "Search started")
        let task = Task {
            try await CatalogueSearch.run(source: .cardex, fetch: { _, _ in
                started.fulfill(); try await Task.sleep(for: .seconds(30))
                return .init(cards: [], hasMore: false)
            })
        }
        await fulfillment(of: [started], timeout: 2); task.cancel()
        do { _ = try await task.value; XCTFail("Cancellation must propagate") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
    }
    private func card(_ id: String) -> CharacterCard { .init(id: id, name: id) }
    private enum SearchError: Error { case offline }
    private actor SearchUpdates {
        var values: [CataloguePage] = []
        func append(_ page: CataloguePage) { values.append(page) }
    }
    private actor SearchRequests {
        var values: [CatalogueSource: CataloguePosition] = [:]
        func append(_ source: CatalogueSource, _ position: CataloguePosition) { values[source] = position }
    }
    private actor SearchGate {
        var opened = false
        var waiting: CheckedContinuation<Void, Never>?
        func wait() async { if !opened { await withCheckedContinuation { waiting = $0 } } }
        func open() { opened = true; waiting?.resume(); waiting = nil }
    }
}
