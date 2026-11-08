import Foundation
import FadenCore

enum CatalogueDownloadFailure: LocalizedError {
    case verification, unavailable(Int), notArchived, invalidExport
    var errorDescription: String? {
        switch self {
        case .verification: "JannyAI verlangt eine Website-Prüfung (HTTP 403). Kai versucht den regulären Kartendownload im eingebauten Browser."
        case .unavailable(let code): "JannyAI konnte diese Karte nicht liefern (HTTP \(code))."
        case .notArchived: "JannyAI findet für diesen Suchtreffer noch keine vollständige archivierte Karte. Der Suchtext allein enthält keine Chatdefinition."
        case .invalidExport: "JannyAI hat keinen gültigen Kartendownload geliefert. Kai versucht den regulären Export auf der Originalseite."
        }
    }
}
enum JannyCatalogue {
    // Published read-only frontend search key: no user account, inference quota or private data access.
    private static let publicSearchKey = "88a6463b66e04fb07ba87ee3db06af337f492ce511d93df6e2d2968cb2ff2b30"

    static func search(query: String, page: Int, includeAdult: Bool, genre: CharacterGenre) async throws -> CataloguePage {
        var request = URLRequest(url: URL(string: "https://search.jannyai.com/multi-search")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + publicSearchKey, forHTTPHeaderField: "Authorization")
        request.setValue("Kai/1.5", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["queries": [[
            "indexUid": "janny-characters", "q": JannyCatalogueCodec.query(query, genre: genre),
            "page": max(1, page), "hitsPerPage": 24, "filter": includeAdult ? [] : ["isNsfw = false"]
        ]]])
        let (data, response) = try await CatalogueNetwork.session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw FadenError.network("Die JannyAI-Suche ist gerade nicht erreichbar. Versuche es später erneut oder verwende Chub.")
        }
        let result = try JannyCatalogueCodec.decode(data)
        return CataloguePage(cards: result.cards, hasMore: result.hasMore, totalCount: result.total)
    }

    static func detail(_ card: CharacterCard, session: URLSession = CatalogueNetwork.session, downloadSession: URLSession = CatalogueNetwork.publicDownloadSession) async throws -> CharacterCard {
        guard CatalogueSource.source(for: card.id) == .janny else { throw FadenError.invalidData("Ungültige JannyAI-Karte.") }
        var request = URLRequest(url: URL(string: "https://api.jannyai.com/api/v1/download")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Kai/1.5", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["characterId": String(card.id.dropFirst(6))])
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 403, (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "cf-mitigated") == "challenge" || String(decoding: data.prefix(8192), as: UTF8.self).contains("cf-chl-") { throw CatalogueDownloadFailure.verification }
        guard code == 200, data.count < 1_000_000 else { throw CatalogueDownloadFailure.unavailable(code) }
        let object = try HTTP.object(data)
        if object["status"] as? String == "error", (object["error"] as? String ?? "").localizedCaseInsensitiveContains("Unable to find character") { throw CatalogueDownloadFailure.notArchived }
        guard object["status"] as? String == "ok", let text = object["downloadUrl"] as? String else { throw downloadUnavailable }
        guard let url = URL(string: text), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { throw downloadUnavailable }
        let (png, downloadResponse) = try await downloadSession.data(from: url)
        guard (downloadResponse as? HTTPURLResponse)?.statusCode == 200 else { throw downloadUnavailable }
        var full = try CardCodec.decode(png)
        guard !full.description.isEmpty || !full.personality.isEmpty else { throw downloadUnavailable }
        full.id = card.id; full.sourceURL = card.sourceURL; full.avatarURL = card.avatarURL ?? full.avatarURL
        full.cachedAvatarURL = card.cachedAvatarURL
        if full.tagline.isEmpty { full.tagline = card.tagline }
        if full.creatorNotes.isEmpty { full.creatorNotes = card.creatorNotes }
        var seenTags = Set(full.tags.map { $0.lowercased() })
        full.tags += card.tags.filter { seenTags.insert($0.lowercased()).inserted }
        full.isAdult = card.isAdult; full.castOverride = card.castOverride
        return full
    }
    private static var downloadUnavailable: CatalogueDownloadFailure { .invalidExport }
}
