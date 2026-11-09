import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import FadenCore

final class CardexCatalogueTests: XCTestCase {
    private let slug = "mara-am-bahnhof-1234abcd"
    private var preview: CharacterCard {
        CharacterCard(id: "cardex/" + slug, name: "Mara", tagline: "Ein ruhiger Abend", tags: ["Guideverse"],
                      avatarURL: "https://cardex.zip/i/original.webp", sourceURL: "https://cardex.zip/c/" + slug, creator: "Kartenautorin", isAdult: true)
    }
    private func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [CardexFixture.self]
        return URLSession(configuration: config)
    }
    func testDirectImportUsesCompleteExportAndKeepsOriginalImageAndMetadata() async throws {
        let client = CardexCatalogueClient(session: session())
        let page = try await client.search(query: "Mara", includeAdult: true, genre: .guideverse)
        XCTAssertEqual(page.cards.count, 1)
        XCTAssertFalse(page.cards[0].hasDefinition, "Search text must never be treated as the character definition")
        XCTAssertEqual(page.cards[0].avatarURL, "https://cardex.zip/i/original.webp")
        XCTAssertEqual(CatalogueSource.source(for: page.cards[0].id), .cardex)
        let card = try await client.detail(page.cards[0])
        XCTAssertTrue(card.hasDefinition)
        XCTAssertEqual(card.id, page.cards[0].id)
        XCTAssertEqual(card.description, "Mara ist eine ruhige, genaue Ermittlerin.")
        XCTAssertEqual(card.firstMessage, "Guten Abend, {{user}}.")
        XCTAssertEqual(card.scenario, "Am Bahnhof")
        XCTAssertEqual(card.avatarURL, "https://cardex.zip/i/original.webp")
        XCTAssertEqual(card.tagline, "Ein ruhiger Abend")
        XCTAssertEqual(card.creator, "Kartenautorin")
        XCTAssertEqual(card.sourceURL, "https://cardex.zip/c/" + slug)
        XCTAssertTrue(card.isAdult)
        XCTAssertEqual(card.tags, ["Mystery", "Guideverse"])
        XCTAssertEqual(card.lore.first?.content, "Der Bahnhof schließt um Mitternacht.")
    }
    func testCursorAndGenreSurvivePagingAndQueryIsNotInterpretedAsURLParameters() throws {
        let position = CataloguePosition(page: 2, cursor: "opaque+/token=123")
        let url = CardexCatalogueCodec.searchURL(query: "A/B/O & source=other", position: position, includeAdult: false, genre: .omegaverse)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(values["q"], "omegaverse & source=other")
        XCTAssertNil(values["source"])
        XCTAssertEqual(values["tags"], "omegaverse")
        XCTAssertEqual(values["cursor"], position.cursor)
        XCTAssertNil(values["page"], "Cardex rejects a cursor together with a page beyond 1")
        XCTAssertEqual(values["mode"], "fts")
        XCTAssertEqual(values["nsfw"], "exclude")
        XCTAssertEqual(values["sort"], "relevance", "Cardex full-text search fails when combined with popularity ordering")
        let browse = CardexCatalogueCodec.searchURL(query: "", position: .init(), includeAdult: true, genre: .omegaverse)
        XCTAssertEqual(URLComponents(url: browse, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "sort" }?.value, "popular")
    }
    func testSearchDoesNotTurnArchiveTagCountsIntoFilteredTotals() throws {
        let page = try CardexCatalogueCodec.decodeSearch(CardexFixture.search())
        XCTAssertNil(page.totalCount)
        XCTAssertEqual(page.nextCursor, "next-token")
        XCTAssertTrue(page.hasMore)
        let data = try JSONSerialization.data(withJSONObject: ["items": [], "has_more": false, "total": 0])
        XCTAssertEqual(try CardexCatalogueCodec.decodeSearch(data).totalCount, 0)
        XCTAssertThrowsError(try CardexCatalogueCodec.decodeSearch(Data("{}".utf8)))
        XCTAssertThrowsError(try CardexCatalogueCodec.decodeSearch(Data("<html>temporarily unavailable</html>".utf8)))
    }
    func testAdultFilterIsAppliedToLoadedCardsToo() async throws {
        let page = try await CardexCatalogueClient(session: session()).search(query: "Mara", includeAdult: false)
        XCTAssertTrue(page.cards.isEmpty)
    }
    func testUnavailableExportReportsHTTPStatusInsteadOfImportingPreview() async throws {
        var missing = preview; missing.id = "cardex/unavailable-1234abcd"
        do {
            _ = try await CardexCatalogueClient(session: session()).detail(missing)
            XCTFail("An unavailable card must not become a usable character")
        } catch { XCTAssertTrue(error.localizedDescription.contains("503")) }
    }
    func testHiddenFilesAndForeignDownloadsAndWrongCardAreRejected() throws {
        let hash = String(repeating: "a", count: 64)
        for path in ["https://other.example/api/v1/download/\(hash)?mode=json", "https://cardex.zip@other.example/api/v1/download/\(hash)?mode=json", "/api/v1/download/../private?mode=json", "/api/v1/download/\(hash)?mode=original"] {
            XCTAssertThrowsError(try CardexCatalogueCodec.decodeExport(CardexFixture.metadata(download: path), preview: preview))
        }
        XCTAssertThrowsError(try CardexCatalogueCodec.decodeExport(CardexFixture.metadata(hidden: true), preview: preview))
        var other = preview; other.id = "cardex/different-1234abcd"
        XCTAssertThrowsError(try CardexCatalogueCodec.decodeExport(CardexFixture.metadata(), preview: other))
        XCTAssertThrowsError(try CardexCatalogueCodec.merging(CharacterCard(name: "Vorschau"), with: preview))
    }
    func testUnsafeSourceAndImageURLsAreNotAccepted() throws {
        XCTAssertNil(CatalogueSource.source(for: "cardex/../../private"))
        XCTAssertNil(CatalogueSource.source(for: "cardex/%2fprivate"))
        let item: [String: Any] = ["slug": slug, "name": "Mara", "image_url": "https://other.example/image.png", "kind": "character"]
        let data = try JSONSerialization.data(withJSONObject: ["items": [item], "has_more": false])
        let card = try XCTUnwrap(CardexCatalogueCodec.decodeSearch(data).cards.first)
        XCTAssertNil(card.avatarURL)
        XCTAssertEqual(card.sourceURL, preview.sourceURL)
    }
}

private final class CardexFixture: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        do {
            XCTAssertEqual(request.url?.host, "cardex.zip")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let path = request.url!.path
            var status = 200
            let data: Data
            if path == "/api/v1/search" { data = try Self.search() }
            else if path == "/api/v1/cards/mara-am-bahnhof-1234abcd" { data = try Self.metadata() }
            else if path == "/api/v1/cards/unavailable-1234abcd" { status = 503; data = Data("Service unavailable".utf8) }
            else if path == "/api/v1/download/" + String(repeating: "a", count: 64) {
                XCTAssertEqual(request.url?.query, "mode=json")
                var card = CharacterCard(name: "Mara", description: "Mara ist eine ruhige, genaue Ermittlerin.", scenario: "Am Bahnhof", firstMessage: "Guten Abend, {{user}}.", tags: ["Mystery"], creator: "")
                card.lore = [.init(keys: ["Bahnhof"], content: "Der Bahnhof schließt um Mitternacht.")]
                data = try CardCodec.encode(card)
            } else { XCTFail("Unexpected Cardex request: \(path)"); status = 404; data = Data() }
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    static func search() throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "items": [["slug": "mara-am-bahnhof-1234abcd", "name": "Mara", "tagline": "Ein ruhiger Abend", "kind": "character",
                       "image_url": "/i/original.webp", "creator": ["name": "Kartenautorin"], "tags": ["Guideverse"], "nsfw": true]],
            "total": NSNull(), "tags": [["slug": "guideverse", "card_count": 115]], "has_more": true, "next_cursor": "next-token"
        ])
    }
    static func metadata(download: String? = nil, hidden: Bool = false) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "card": ["slug": "mara-am-bahnhof-1234abcd", "hidden": false, "nsfw": true],
            "top": ["name": ["value": "Mara"], "tagline": ["value": "Ein ruhiger Abend"], "creator": ["value": "Kartenautorin"],
                    "cover": ["image": ["url": "/i/original.webp"]], "tags": [["label": "Guideverse"]]],
            "files": [["hidden": hidden, "current": true, "downloads": ["json": download ?? "/api/v1/download/\(String(repeating: "a", count: 64))?mode=json"]]]
        ])
    }
}
