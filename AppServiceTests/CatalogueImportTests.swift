import XCTest
import WebKit
import UIKit
import ImageIO
import FadenCore
@testable import Faden

@MainActor final class CatalogueImportTests: XCTestCase {
    private func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CatalogueFixture.self]
        return URLSession(configuration: config)
    }
    private func preview(_ suffix: String = "1") -> CharacterCard {
        CharacterCard(id: "janny/00000000-0000-4000-8000-00000000000" + suffix, name: "Archiv-Test", tagline: "Eine Ermittlerin am Bahnhof", creatorNotes: "Öffentliche Beschreibung aus dem Katalog", tags: ["Detective", "Mystery"], avatarURL: "https://image.kai-test.invalid/original.png", sourceURL: "https://jannyai.com/characters/00000000-0000-4000-8000-000000000001_character-archiv-test")
    }
    func testSignedExportKeepsDefinitionAndMenuMetadataAndCachesOriginalArtwork() async throws {
        let original = preview(); let transport = session()
        let card = try await JannyCatalogue.detail(original, session: transport, downloadSession: transport)
        XCTAssertEqual(card.id, original.id)
        XCTAssertEqual(card.description, "Eine geduldige, genaue Ermittlerin.")
        XCTAssertEqual(card.firstMessage, "Guten Abend, {{user}}.")
        XCTAssertEqual(card.scenario, "Am Bahnhof")
        XCTAssertEqual(card.tagline, original.tagline)
        XCTAssertEqual(card.creatorNotes, original.creatorNotes)
        XCTAssertEqual(card.tags, ["Mystery", "Detective"])
        XCTAssertEqual(GermanLanguage.tags(["BDSM", "NOIR", "AnyPOV"]), ["BDSM", "NOIR", "AnyPOV"], "Translation must not silently delete catalogue genres or role tags")
        XCTAssertEqual(card.sourceURL, original.sourceURL)
        XCTAssertEqual(card.avatarURL, original.avatarURL)
        defer { if let url = card.cachedAvatarURL.flatMap(URL.init(string:)) { try? FileManager.default.removeItem(at: url) } }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let prepared = try await CatalogueNetwork.prepare(card, directory: folder, downloadSession: transport)
        let cached = try XCTUnwrap(prepared.cachedAvatarURL.flatMap(URL.init(string:)))
        XCTAssertTrue(cached.isFileURL)
        XCTAssertEqual(try Data(contentsOf: cached), try CatalogueFixture.pngCard())
        XCTAssertNotNil(CGImageSourceCreateWithData(try Data(contentsOf: cached) as CFData, nil))
    }
    func testBrowserFileImportKeepsPreviewLabelsAndOriginalPicture() async throws {
        let original = preview()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        try CatalogueFixture.pngCard().write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let store = AppStore()
        let done = expectation(description: "Browser file becomes a complete saved card")
        var imported: CharacterCard?
        store.importFile(file, origin: original) { card in imported = card; done.fulfill() }
        await fulfillment(of: [done], timeout: 8)
        let card = try XCTUnwrap(imported)
        XCTAssertEqual(card.id, original.id)
        XCTAssertEqual(card.tagline, original.tagline)
        XCTAssertEqual(card.creatorNotes, original.creatorNotes)
        XCTAssertEqual(card.firstMessage, "Guten Abend, {{user}}.")
        XCTAssertTrue(card.tags.contains("Mystery")); XCTAssertTrue(card.tags.contains("Detektiv"))
        XCTAssertEqual(card.avatarURL, original.avatarURL)
        let image = try XCTUnwrap(card.cachedAvatarURL.flatMap(URL.init(string:)))
        XCTAssertEqual(try Data(contentsOf: image), try CatalogueFixture.pngCard())
        try? FileManager.default.removeItem(at: image)
        store.archive.characters.removeAll { $0.id == original.id }; store.save()
    }
    func testWebsiteVerificationIsNotReportedAsAnUnavailableCreatorExport() async throws {
        let original = preview("2"); let transport = session()
        do {
            _ = try await JannyCatalogue.detail(original, session: transport, downloadSession: transport)
            XCTFail("A website challenge must not become a complete character")
        } catch CatalogueDownloadFailure.verification {
            XCTAssertFalse(original.hasDefinition)
        }
    }
    func testMissingArchiveIsDistinctFromVerification() async throws {
        let transport = session()
        do {
            _ = try await JannyCatalogue.detail(preview("3"), session: transport, downloadSession: transport)
            XCTFail("Search metadata is not a complete character definition")
        } catch CatalogueDownloadFailure.notArchived { }
    }
    func testRegularWebsitePNGDownloadIsAutomaticallyCaptured() async throws {
        let done = expectation(description: "Public export imported without a file picker")
        var file: URL?; var originatingPage: URL?
        let id = "00000000-0000-4000-8000-000000000001"
        let coordinator = CatalogueWebView.Coordinator(automaticCardID: id, onDownload: { url, page in file = url; originatingPage = page; done.fulfill() }, onError: { message in XCTFail(message); done.fulfill() })
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        web.navigationDelegate = coordinator; web.uiDelegate = coordinator
        let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }
        window?.addSubview(web)
        defer { web.removeFromSuperview(); if let file { try? FileManager.default.removeItem(at: file) } }
        let png = try CatalogueFixture.pngCard().base64EncodedString()
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width"></head><body>
        <button id="download" onclick="exportCard()">Download as PNG</button>
        <script>
        function exportCard() {
          const bytes = Uint8Array.from(atob('\(png)'), c => c.charCodeAt(0));
          const link = document.createElement('a');
          link.href = URL.createObjectURL(new Blob([bytes], {type:'image/png'}));
          link.download = 'public-character.png'; document.body.appendChild(link); link.click();
        }
        </script></body></html>
        """
        web.loadHTMLString(html, baseURL: URL(string: "https://jannyai.com/characters/" + id))
        await fulfillment(of: [done], timeout: 20)
        XCTAssertEqual(originatingPage.flatMap { JannyWebsite.cardID(in: $0) }, id, "CDN or blob downloads must retain their source card")
        let imported = try CardCodec.decode(Data(contentsOf: XCTUnwrap(file)))
        XCTAssertEqual(imported.description, "Eine geduldige, genaue Ermittlerin.")
        XCTAssertEqual(imported.firstMessage, "Guten Abend, {{user}}.")
    }
}

final class CatalogueFixture: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() { }
    override func startLoading() {
        do {
            var status = 200; var headers = ["Content-Type": "application/json"]; let data: Data
            if request.url?.host == "api.jannyai.com" {
                var body = request.httpBody
                if body == nil, let stream = request.httpBodyStream {
                    stream.open(); defer { stream.close() }
                    var bytes = [UInt8](repeating: 0, count: 4096); var collected = Data()
                    while stream.hasBytesAvailable { let n = stream.read(&bytes, maxLength: bytes.count); if n <= 0 { break }; collected.append(contentsOf: bytes.prefix(n)) }
                    body = collected
                }
                let object = try JSONSerialization.jsonObject(with: body ?? Data()) as? [String: Any]
                XCTAssertEqual(request.httpMethod, "POST")
                let id = object?["characterId"] as? String ?? ""
                if id.hasSuffix("2") {
                    status = 403; headers = ["Content-Type": "text/html", "cf-mitigated": "challenge"]
                    data = Data("<html>Website verification</html>".utf8)
                } else if id.hasSuffix("3") {
                    data = Data(#"{"status":"error","error":"Unable to find character"}"#.utf8)
                } else {
                    data = Data(#"{"status":"ok","downloadUrl":"https://cdn.kai-test.invalid/card.png?X-Amz-Signature=fixture&Expires=123"}"#.utf8)
                }
            } else {
                XCTAssertTrue(["cdn.kai-test.invalid", "image.kai-test.invalid"].contains(request.url?.host ?? ""))
                if request.url?.host == "cdn.kai-test.invalid" {
                    XCTAssertTrue(request.url?.query?.contains("X-Amz-Signature=fixture") == true, "The original signed URL must reach the download request unchanged")
                }
                headers = ["Content-Type": "image/png"]; data = try Self.pngCard()
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    static func pngCard() throws -> Data {
        let image = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNQ9sj8DwADOgHUBjy0MQAAAABJRU5ErkJggg==")!
        let card = CharacterCard(name: "Archiv-Test", description: "Eine geduldige, genaue Ermittlerin.", scenario: "Am Bahnhof", firstMessage: "Guten Abend, {{user}}.", tags: ["Mystery"], creator: "Testurheber")
        let payload = Data("chara\0".utf8) + Data(try CardCodec.encode(card).base64EncodedString().utf8)
        let typeAndPayload = Data("tEXt".utf8) + payload
        var crc: UInt32 = 0xffffffff
        for byte in typeAndPayload { crc ^= UInt32(byte); for _ in 0..<8 { crc = crc & 1 != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1 } }
        func word(_ value: UInt32) -> Data { var bytes = value.bigEndian; return withUnsafeBytes(of: &bytes) { Data($0) } }
        return image.dropLast(12) + word(UInt32(payload.count)) + typeAndPayload + word(crc ^ 0xffffffff) + image.suffix(12)
    }
}
