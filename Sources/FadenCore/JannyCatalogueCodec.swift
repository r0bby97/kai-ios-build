import Foundation

public struct JannyCatalogueResult: Sendable {
    public var cards: [CharacterCard]
    public var total: Int
    public var hasMore: Bool
}

/// Reads only the public search index. Full definitions must come from a permitted card download.
public enum JannyCatalogueCodec {
    public static func decode(_ data: Data) throws -> JannyCatalogueResult {
        guard data.count <= 12 * 1024 * 1024,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [[String: Any]], let result = results.first,
              let hits = result["hits"] as? [[String: Any]] else {
            throw FadenError.invalidData("JannyAI hat eine unbekannte Katalogantwort geliefert.")
        }
        let cards = hits.compactMap { hit -> CharacterCard? in
            guard let id = hit["id"] as? String, UUID(uuidString: id) != nil,
                  let name = hit["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let blurb = plainText(hit["description"] as? String ?? "")
            let tags = (hit["tagIds"] as? [Int] ?? []).compactMap { tagNames[$0] }
            var avatar: String?
            if let path = hit["avatar"] as? String, !path.contains(".."), !path.contains(":") {
                var url = URL(string: "https://image.jannyai.com/bot-avatars/")!
                url.appendPathComponent(path)
                avatar = url.absoluteString
            }
            return CharacterCard(id: "janny/" + id.lowercased(), name: plainText(name), tagline: String(blurb.prefix(220)),
                creatorNotes: blurb, tags: tags, avatarURL: avatar,
                sourceURL: JannyWebsite.cardURL(id: id, name: plainText(name))?.absoluteString, creator: "JannyAI-Katalog", isAdult: hit["isNsfw"] as? Bool ?? false)
        }
        let total = max(0, result["totalHits"] as? Int ?? result["estimatedTotalHits"] as? Int ?? cards.count)
        let page = result["page"] as? Int ?? 1
        let pages = result["totalPages"] as? Int ?? 1
        return .init(cards: cards, total: total, hasMore: page < pages)
    }
    public static func query(_ input: String, genre: CharacterGenre) -> String {
        let query = OmegaverseSearch.normalized(input)
        guard let topic = genre.catalogueTopic else { return query }
        if genre == .omegaverse, OmegaverseSearch.containsGenre(query) { return query }
        return [query, topic].filter { !$0.isEmpty }.joined(separator: " ")
    }
    private static func plainText(_ input: String) -> String {
        input.replacingOccurrences(of: #"<[^>]*>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static let tagNames = [1: "Male", 2: "Female", 3: "Non-binary", 5: "OC", 6: "Fictional", 8: "Game", 9: "Anime",
        10: "Historical", 11: "Royalty", 12: "Detective", 15: "Magical", 16: "Non-human", 17: "Monster", 22: "Vampire",
        25: "Elf", 26: "Multiple Characters", 28: "Dominant", 29: "Submissive", 30: "Scenario", 38: "RPG", 42: "AnyPOV",
        43: "Angst", 44: "Demi-Human", 45: "Enemies to Lovers", 46: "Smut", 47: "MLM", 48: "WLW", 49: "Action",
        50: "Romance", 51: "Horror", 52: "Slice of Life", 53: "Fantasy", 54: "Drama", 55: "Comedy", 56: "Mystery", 57: "Sci-Fi"]
}
