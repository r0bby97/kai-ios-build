import XCTest
@testable import FadenCore

final class CataloguePreparationTests: XCTestCase {
    func testPreviewsPublishInPopularityOrderAndPreserveTranslatedDefinitions() {
        var edited = CharacterCard(id: "chub/existing", name: "Bearbeitet", personality: "Meine deutsche Definition")
        edited.languageCode = "de"; edited.cachedAvatarURL = "file:///original.image"
        let older = CharacterCard(id: "custom", name: "Eigene Karte")
        let previews = [CharacterCard(id: "chub/new", name: "Beliebteste"), CharacterCard(id: edited.id, name: "Originalname")]
        let merged = CatalogueLibrary.merging(previews, into: [older, edited], order: previews.map(\.id))
        XCTAssertEqual(merged.map(\.id), ["chub/new", "chub/existing", "custom"])
        XCTAssertEqual(merged[0].languageCode, "pending")
        XCTAssertEqual(merged[1], edited)
        XCTAssertEqual(CatalogueLibrary.merging(previews, into: merged, order: previews.map(\.id)), merged)
    }
    func testLegacyExamplesAreRetainedForChatsButAbsentFromDiscovery() throws {
        let old = CharacterCard(id: "faden.original.2", name: "Alter Beispielcharakter")
        let own = CharacterCard(id: "my-character", name: "Eigener Charakter")
        var archive = Archive(characters: [old, own])
        archive.stories = [Story(character: old)]
        XCTAssertEqual(archive.libraryCharacters, [own])
        XCTAssertEqual(archive.characters.first?.id, archive.stories.first?.characterID)
        let restored = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(archive))
        XCTAssertEqual(restored.characters.count, 2)
        XCTAssertNil(restored.characters.first?.cachedAvatarURL)
    }
    func testFastCardsPublishBeforeSlowCardAndFailuresDoNotStopQueue() async throws {
        let gate = Gate()
        let first = expectation(description: "A slow first card must not block fast following cards")
        let cards = (0..<5).map { CharacterCard(id: "\($0)", name: "Karte \($0)") }
        let received = Results()
        let task = Task {
            try await CataloguePreparation.run(cards: cards, concurrency: 2, fetch: { card in
                if card.id == "0" { await gate.wait() }
                if card.id == "2" { throw TestError.failed }
                return card
            }, finished: { result in
                await received.append(result)
                if result.id == "4" { first.fulfill() }
            })
        }
        await fulfillment(of: [first], timeout: 3)
        let beforeRelease = await received.values
        XCTAssertFalse(beforeRelease.contains { $0.id == "0" })
        XCTAssertTrue(beforeRelease.contains { $0.id == "2" && $0.card == nil })
        await gate.open()
        try await task.value
        let all = await received.values
        XCTAssertEqual(Set(all.map(\.id)), Set(cards.map(\.id)))
    }
    func testCancellationStopsPendingWork() async throws {
        let started = expectation(description: "Fetch started")
        let task = Task {
            try await CataloguePreparation.run(cards: [CharacterCard(name: "Langsam")], fetch: { card in
                started.fulfill(); try await Task.sleep(for: .seconds(30)); return card
            }, finished: { _ in XCTFail("Cancelled work must not publish") })
        }
        await fulfillment(of: [started], timeout: 2)
        task.cancel()
        do { try await task.value; XCTFail("Cancellation must propagate") } catch is CancellationError { } catch { XCTFail("\(error)") }
    }
    private enum TestError: Error { case failed }
    private actor Results {
        var values: [CataloguePreparationResult] = []
        func append(_ value: CataloguePreparationResult) { values.append(value) }
    }
    private actor Gate {
        var isOpen = false
        var waiting: CheckedContinuation<Void, Never>?
        func wait() async { if !isOpen { await withCheckedContinuation { waiting = $0 } } }
        func open() { isOpen = true; waiting?.resume(); waiting = nil }
    }
}
