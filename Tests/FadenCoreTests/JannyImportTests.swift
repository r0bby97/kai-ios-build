import XCTest
@testable import FadenCore

final class JannyImportTests: XCTestCase {
    func testCanonicalCardURLAndRedirectHostsKeepExactSourceIdentity() throws {
        let id = "00000000-0000-4000-8000-000000000001"
        let url = try XCTUnwrap(JannyWebsite.cardURL(id: id, name: "Mara & Élias"))
        XCTAssertEqual(url.absoluteString, "https://jannyai.com/characters/" + id + "_character-mara-elias")
        XCTAssertEqual(JannyWebsite.cardID(in: url), id)
        XCTAssertEqual(JannyWebsite.cardID(in: URL(string: "https://www.jannyai.com/characters/" + id + "_character-mara")!), id)
        XCTAssertNil(JannyWebsite.cardID(in: URL(string: "https://other.example/characters/" + id)!))
        XCTAssertNil(JannyWebsite.cardID(in: URL(string: "https://jannyai.com/search/" + id)!))
        XCTAssertNil(JannyWebsite.cardID(in: URL(string: "https://jannyai.com/characters/" + id + "-wrong")!))
    }
    func testBrowserAndAPIImportsKeepPreviewFieldsWithoutReplacingRealDefinition() {
        let id = "00000000-0000-4000-8000-000000000001"
        var preview = CharacterCard(id: "janny/" + id, name: "Mara", tagline: "Ein öffentlicher Kurztext", creatorNotes: "Originale Notizen", tags: ["BDSM", "Mystery", "AnyPOV"], avatarURL: "https://image.jannyai.com/original.png", isAdult: true)
        preview.castOverride = .init(isEnsemble: true, names: ["Mara", "Elias"])
        let downloaded = CharacterCard(name: "Mara", description: "Die echte Persönlichkeit", firstMessage: "Hallo {{user}}", tags: ["mystery"])
        let card = JannyWebsite.merging(downloaded, with: preview)
        XCTAssertEqual(card.id, preview.id)
        XCTAssertEqual(card.description, downloaded.description)
        XCTAssertEqual(card.firstMessage, downloaded.firstMessage)
        XCTAssertEqual(card.tagline, preview.tagline)
        XCTAssertEqual(card.creatorNotes, preview.creatorNotes)
        XCTAssertEqual(card.tags, ["mystery", "BDSM", "AnyPOV"])
        XCTAssertEqual(card.avatarURL, preview.avatarURL)
        XCTAssertEqual(card.castOverride, preview.castOverride)
        XCTAssertTrue(card.isAdult)
        XCTAssertEqual(card.sourceURL, JannyWebsite.cardURL(id: id, name: card.name)?.absoluteString)
        preview.sourceURL = "https://www.jannyai.com/characters/" + id + "_character-original-name"
        preview.name = "Geänderter deutscher Anzeigename"
        XCTAssertEqual(JannyWebsite.merging(downloaded, with: preview).sourceURL, preview.sourceURL)
        XCTAssertEqual(JannyWebsite.sourceURL(for: preview)?.absoluteString, preview.sourceURL)
    }
}
