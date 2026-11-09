import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum CardexCatalogueCodec {
    private static let base = URL(string: "https://cardex.zip")!
    public static func validSlug(_ slug: String) -> Bool {
        slug.range(of: #"^[\p{L}\p{N}][\p{L}\p{N}_-]{0,239}$"#, options: .regularExpression) != nil
    }
    public static func cardURL(slug: String) -> URL? {
        validSlug(slug) ? base.appendingPathComponent("c").appendingPathComponent(slug) : nil
    }
    public static func searchURL(query: String, position: CataloguePosition, includeAdult: Bool, genre: CharacterGenre) -> URL {
        var url = URLComponents(url: base.appendingPathComponent("api/v1/search"), resolvingAgainstBaseURL: false)!
        let normalized = String(OmegaverseSearch.normalized(query).prefix(500))
        // Cardex currently returns HTTP 500 for full-text queries sorted by popularity.
        // Its regular relevance search works; browsing without a query keeps popularity order.
        url.queryItems = [.init(name: "sort", value: normalized.isEmpty ? "popular" : "relevance"), .init(name: "kind", value: "character"),
                          .init(name: "mode", value: "fts"), .init(name: "limit", value: "24"),
                          .init(name: "nsfw", value: includeAdult ? "include" : "exclude")]
        if !normalized.isEmpty { url.queryItems?.append(.init(name: "q", value: normalized)) }
        if let tag = genreTag(genre) { url.queryItems?.append(.init(name: "tags", value: tag)) }
        // Cardex rejects combining a cursor with page > 1 (HTTP 400).
        if let cursor = position.cursor { url.queryItems?.append(.init(name: "cursor", value: cursor)) }
        else { url.queryItems?.append(.init(name: "page", value: String(position.page))) }
        return url.url!
    }
    public static func decodeSearch(_ data: Data) throws -> CataloguePage {
        let root = try object(data)
        guard let items = root["items"] as? [[String: Any]], let hasMore = root["has_more"] as? Bool else {
            throw FadenError.invalidData("Cardex hat eine unbekannte Suchantwort geliefert.")
        }
        var seen = Set<String>()
        let cards = items.compactMap { item -> CharacterCard? in
            guard let slug = item["slug"] as? String, validSlug(slug), seen.insert(slug).inserted,
                  item["kind"] as? String != "lorebook", let name = item["name"] as? String,
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let creator = item["creator"] as? [String: Any] ?? [:]
            let image = artworkURL(item["image_url"] as? String) ?? artworkURL(item["thumbnail_url"] as? String)
            var card = CharacterCard(id: "cardex/" + slug, name: name,
                tagline: plainText(item["tagline"] as? String ?? ""), tags: item["tags"] as? [String] ?? [],
                avatarURL: image?.absoluteString, sourceURL: cardURL(slug: slug)?.absoluteString,
                creator: creator["name"] as? String ?? "Cardex", isAdult: item["nsfw"] as? Bool ?? false)
            card.popularityScore = (item["stats"] as? [String: Any])?["popularity"] as? Int
            return card
        }
        // Tag counts describe the whole archive, not the filtered result count.
        return .init(cards: cards, hasMore: hasMore, totalCount: root["total"] as? Int, nextCursor: root["next_cursor"] as? String)
    }
    public struct Export: Sendable {
        public var preview: CharacterCard
        public var downloadURL: URL
    }
    public static func decodeExport(_ data: Data, preview: CharacterCard) throws -> Export {
        let root = try object(data)
        guard let slug = root["card"].flatMap({ $0 as? [String: Any] })?["slug"] as? String,
              preview.id == "cardex/" + slug, validSlug(slug),
              (root["card"] as? [String: Any])?["hidden"] as? Bool != true,
              let files = root["files"] as? [[String: Any]] else {
            throw FadenError.invalidData("Cardex hat keine passende öffentliche Karte geliefert.")
        }
        let visible = files.filter { $0["hidden"] as? Bool != true }
        let ordered = visible.filter { $0["current"] as? Bool == true } + visible.filter { $0["current"] as? Bool != true }
        let download = ordered.compactMap { file -> URL? in
            guard let downloads = file["downloads"] as? [String: Any], let text = downloads["json"] as? String,
                  let url = sameSiteURL(text), url.path.range(of: #"^/api/v1/download/[a-f0-9]{64}$"#, options: .regularExpression) != nil,
                  let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                  items.count == 1, items.first?.name == "mode", items.first?.value == "json" else { return nil }
            return url
        }.first
        guard let download else {
            throw FadenError.invalidData("Für diese Cardex-Karte ist kein vollständiger öffentlicher Export verfügbar. Die Vorschau allein reicht nicht zum Chatten.")
        }
        var card = preview
        let top = root["top"] as? [String: Any] ?? [:]
        if let name = value(top["name"]), !name.isEmpty { card.name = name }
        if let tagline = value(top["tagline"]), !tagline.isEmpty { card.tagline = plainText(tagline) }
        if let creator = value(top["creator"]), !creator.isEmpty { card.creator = creator }
        if let cover = top["cover"] as? [String: Any], let image = cover["image"] as? [String: Any],
           let url = artworkURL(image["url"] as? String) { card.avatarURL = url.absoluteString }
        let tags = (top["tags"] as? [[String: Any]] ?? []).compactMap { $0["label"] as? String }
        if !tags.isEmpty { card.tags = tags }
        card.isAdult = card.isAdult || (root["card"] as? [String: Any])?["nsfw"] as? Bool == true
        card.sourceURL = cardURL(slug: slug)?.absoluteString
        return .init(preview: card, downloadURL: download)
    }
    public static func merging(_ downloaded: CharacterCard, with preview: CharacterCard) throws -> CharacterCard {
        guard downloaded.hasDefinition else {
            throw FadenError.invalidData("Der Cardex-Export enthält keine Charakterdefinition. Es wurde keine leere Karte importiert.")
        }
        var card = downloaded
        card.id = preview.id; card.sourceURL = preview.sourceURL; card.avatarURL = preview.avatarURL
        card.cachedAvatarURL = preview.cachedAvatarURL
        card.tagline = preview.tagline.isEmpty ? card.tagline : preview.tagline
        if card.creator.isEmpty || card.creator == "Importiert" { card.creator = preview.creator }
        card.popularityScore = preview.popularityScore
        card.isAdult = card.isAdult || preview.isAdult
        card.castOverride = preview.castOverride ?? card.castOverride
        var seen = Set<String>()
        card.tags = (card.tags + preview.tags).filter { seen.insert($0.lowercased()).inserted }
        card.languageCode = "pending"
        return card
    }
    private static func object(_ data: Data) throws -> [String: Any] {
        guard data.count <= 12 * 1024 * 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FadenError.invalidData("Cardex hat keine gültige JSON-Antwort geliefert.")
        }
        return object
    }
    private static func sameSiteURL(_ text: String) -> URL? {
        guard let url = URL(string: text, relativeTo: base)?.absoluteURL,
              url.scheme == "https", url.host == "cardex.zip", url.port == nil,
              url.user == nil, url.password == nil, url.fragment == nil else { return nil }
        return url
    }
    private static func artworkURL(_ text: String?) -> URL? {
        guard let text, let url = sameSiteURL(text), url.path.hasPrefix("/i/") || url.path.hasPrefix("/t/") else { return nil }
        return url
    }
    private static func value(_ input: Any?) -> String? { input as? String ?? (input as? [String: Any])?["value"] as? String }
    private static func plainText(_ input: String) -> String {
        input.replacingOccurrences(of: #"<[^>]*>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&nbsp;", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
    private static func genreTag(_ genre: CharacterGenre) -> String? {
        switch genre {
        case .all: nil
        case .omegaverse: "omegaverse"
        case .fantasy: "fantasy"
        case .everyday: "slice-of-life"
        case .noir: "noir"
        case .scienceFiction: "sci-fi"
        case .mystery: "mystery"
        case .adventure: "adventure"
        case .romance: "romance"
        case .horror: "horror"
        case .guideverse: "guideverse"
        case .bdsm: "bdsm"
        }
    }
}

/// The same client runs on iOS and in local transport tests; no browser or account is needed.
public struct CardexCatalogueClient: Sendable {
    private let session: URLSession
    private static let publicSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12; configuration.timeoutIntervalForResource = 25
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }()
    public init(session: URLSession? = nil) { self.session = session ?? Self.publicSession }
    public func search(query: String, position: CataloguePosition = .init(), includeAdult: Bool, genre: CharacterGenre = .all) async throws -> CataloguePage {
        let url = CardexCatalogueCodec.searchURL(query: query, position: position, includeAdult: includeAdult, genre: genre)
        var page = try CardexCatalogueCodec.decodeSearch(await get(url, maximum: 12 * 1024 * 1024))
        if !includeAdult { page.cards.removeAll(where: \.isAdult) }
        return page
    }
    public func detail(_ preview: CharacterCard) async throws -> CharacterCard {
        guard CatalogueSource.source(for: preview.id) == .cardex else { throw FadenError.invalidData("Ungültige Cardex-Karte.") }
        let slug = String(preview.id.dropFirst(7))
        let url = URL(string: "https://cardex.zip/api/v1/cards/")!.appendingPathComponent(slug)
        let metadata = try CardexCatalogueCodec.decodeExport(await get(url, maximum: 12 * 1024 * 1024), preview: preview)
        let data = try await get(metadata.downloadURL, maximum: CardCodec.maximumBytes)
        return try CardexCatalogueCodec.merging(CardCodec.decode(data), with: metadata.preview)
    }
    private func get(_ url: URL, maximum: Int) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Kai/1.6", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            let explanation = code == 429 ? "Zu viele Anfragen. Bitte später erneut versuchen." : "Die öffentliche Anfrage ist fehlgeschlagen."
            throw FadenError.network("Cardex: \(explanation) (HTTP \(code))")
        }
        guard data.count <= maximum else { throw FadenError.invalidData("Die Cardex-Antwort ist zu groß.") }
        return data
    }
}
