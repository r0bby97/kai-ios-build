import Foundation
import FadenCore

enum Catalogue {
    static func search(query: String, page: Int, includeAdult: Bool, genre: CharacterGenre = .all, source: CatalogueSource = .chub, gender: CharacterGenderFilter = .all,
                       positions: [CatalogueSource: CataloguePosition]? = nil,
                       updated: @escaping @Sendable (CataloguePage) async -> Void = { _ in }) async throws -> CataloguePage {
        let requested = positions ?? Dictionary(uniqueKeysWithValues: source.sources.map { ($0, CataloguePosition(page: page)) })
        return try await CatalogueSearch.run(source: source, positions: requested, fetch: { current, position in
            try await searchSingle(query: query, position: position, includeAdult: includeAdult, genre: genre, source: current, gender: gender)
        }, updated: updated)
    }
    private static func searchSingle(query: String, position: CataloguePosition, includeAdult: Bool, genre: CharacterGenre, source: CatalogueSource, gender: CharacterGenderFilter) async throws -> CataloguePage {
        if source == .cardex { return try await CardexCatalogueClient(session: CatalogueNetwork.publicDownloadSession).search(query: query, position: position, includeAdult: includeAdult, genre: genre, gender: gender) }
        let page = position.page
        var url = URLComponents(string: "https://api.chub.ai/search")!
        // These genres have text matches in Chub but no matching topic tags.
        let usesTextSearch = genre == .guideverse || genre == .bdsm
        let search = usesTextSearch ? [query, genre.title].filter { !$0.isEmpty }.joined(separator: " ") : OmegaverseSearch.normalized(query)
        url.queryItems = [URLQueryItem(name: "search", value: search), .init(name: "first", value: "24"),
            .init(name: "page", value: String(page)), .init(name: "sort", value: "star_count"),
            .init(name: "asc", value: "false"), .init(name: "nsfw", value: String(includeAdult)),
            .init(name: "venus", value: "false"), .init(name: "min_tokens", value: "50")]
        var topics = usesTextSearch ? [] : [genre.catalogueTopic].compactMap { $0 }
        if let genderTag = gender.catalogueTag { topics.append(genderTag.capitalized) }
        if !topics.isEmpty { url.queryItems?.append(.init(name: "topics", value: topics.joined(separator: ","))) }
        var request = URLRequest(url: url.url!); request.setValue("Kai/1.5", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await CatalogueNetwork.session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw FadenError.network("Der öffentliche Katalog ist gerade nicht erreichbar. Deine Bibliothek bleibt verfügbar.")
        }
        guard data.count < 12 * 1024 * 1024 else { throw FadenError.invalidData("Die Katalogantwort ist zu groß.") }
        let root = try HTTP.object(data)
        let container = root["data"] as? [String: Any] ?? root
        let nodes = container["nodes"] as? [[String: Any]] ?? []
        let cards = nodes.compactMap { item -> CharacterCard? in
            let node = item["node"] as? [String: Any] ?? item
            guard let path = node["fullPath"] as? String, let name = node["name"] as? String else { return nil }
            var result = fromNode(node)
            result.id = "chub/" + path; result.name = name
            result.description = ""
            return result
        }
        return CataloguePage(cards: cards.filter { gender.matches($0) }, hasMore: nodes.count == 24)
    }
    static func detail(_ card: CharacterCard) async throws -> CharacterCard {
        if CatalogueSource.source(for: card.id) == .cardex { return try await CardexCatalogueClient(session: CatalogueNetwork.publicDownloadSession).detail(card) }
        if CatalogueSource.source(for: card.id) == .janny {
            throw FadenError.invalidData("JannyAI ist aus der Online-Suche entfernt. Diese alte Vorschau enthält keine vollständige Charakterdefinition. Neue Karten findest du bei Cardex und Chub.")
        }
        guard card.id.hasPrefix("chub/") else { return card }
        let path = String(card.id.dropFirst(5))
        guard !path.contains(".."), let escaped = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.chub.ai/api/characters/\(escaped)?full=true") else {
            throw FadenError.invalidData("Ungültiger Katalogeintrag.")
        }
        let (data, response) = try await CatalogueNetwork.session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 12 * 1024 * 1024 else {
            throw FadenError.network("Die Charakterdefinition konnte nicht geladen werden.")
        }
        let root = try HTTP.object(data)
        guard let node = root["node"] as? [String: Any] else { throw FadenError.invalidData("Die Definition fehlt.") }
        var result = fromNode(node); result.id = card.id
        result.castOverride = card.castOverride
        result.avatarURL = result.avatarURL ?? card.avatarURL
        result.popularityScore = result.popularityScore ?? card.popularityScore
        return result
    }
    private static func fromNode(_ node: [String: Any]) -> CharacterCard {
        let definition = node["definition"] as? [String: Any] ?? [:]
        func value(_ key: String, fallback: String? = nil) -> String {
            definition[key] as? String ?? node[fallback ?? key] as? String ?? ""
        }
        let path = node["fullPath"] as? String ?? ""
        let labels = node["topics"] as? [String] ?? node["labels"] as? [String] ?? []
        var lore: [LoreEntry] = []
        if let book = definition["embedded_lorebook"] as? [String: Any], let entries = book["entries"] as? [[String: Any]] {
            lore = entries.compactMap { e in
                guard e["enabled"] as? Bool != false, let content = e["content"] as? String else { return nil }
                return LoreEntry(keys: e["keys"] as? [String] ?? [], content: content, alwaysOn: e["constant"] as? Bool ?? false)
            }
        }
        var result = CharacterCard(id: "chub/" + path, name: value("name"), tagline: node["tagline"] as? String ?? "",
            description: value("description"), personality: value("personality"), scenario: value("scenario"),
            firstMessage: value("first_message"), exampleDialogue: value("example_dialogs"),
            systemPrompt: value("system_prompt"), creatorNotes: node["description"] as? String ?? "",
            tags: labels, alternateGreetings: definition["alternate_greetings"] as? [String] ?? [], lore: lore,
            avatarURL: node["avatar_url"] as? String ?? definition["avatar"] as? String,
            sourceURL: "https://chub.ai/characters/" + path, creator: path.components(separatedBy: "/").first ?? "Chub",
            isAdult: node["nsfw_image"] as? Bool ?? false)
        result.popularityScore = node["starCount"] as? Int
        return result
    }
}
