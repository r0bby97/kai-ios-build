import Foundation

public enum JannyWebsite {
    public static func cardURL(id: String, name: String) -> URL? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        let slug = name.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en"))
            .lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let tail = slug.isEmpty ? "character" : "character-" + String(slug.prefix(120))
        return URL(string: "https://jannyai.com/characters/" + uuid.uuidString.lowercased() + "_" + tail)
    }
    public static func cardID(in url: URL) -> String? {
        guard url.scheme == "https", ["jannyai.com", "www.jannyai.com"].contains(url.host?.lowercased() ?? ""),
              url.path.hasPrefix("/characters/") else { return nil }
        let segment = String(url.path.dropFirst("/characters/".count))
        guard segment.count >= 36, let id = UUID(uuidString: String(segment.prefix(36))) else { return nil }
        let suffix = segment.dropFirst(36)
        guard suffix.isEmpty || (suffix.first == "_" && !suffix.contains("/")) else { return nil }
        return id.uuidString.lowercased()
    }
    public static func sourceURL(for card: CharacterCard) -> URL? {
        guard CatalogueSource.source(for: card.id) == .janny else { return nil }
        let id = String(card.id.dropFirst(6)).lowercased()
        if let text = card.sourceURL, let url = URL(string: text), cardID(in: url) == id, url.path.contains("_") { return url }
        return cardURL(id: id, name: card.name)
    }
    public static func merging(_ downloaded: CharacterCard, with preview: CharacterCard) -> CharacterCard {
        var card = downloaded
        guard CatalogueSource.source(for: preview.id) == .janny else { return card }
        card.id = preview.id
        card.sourceURL = sourceURL(for: preview)?.absoluteString
        if card.tagline.isEmpty { card.tagline = preview.tagline }
        if card.creatorNotes.isEmpty { card.creatorNotes = preview.creatorNotes }
        var seen = Set(card.tags.map { $0.lowercased() })
        card.tags += preview.tags.filter { seen.insert($0.lowercased()).inserted }
        card.avatarURL = preview.avatarURL ?? card.avatarURL
        card.cachedAvatarURL = preview.cachedAvatarURL ?? card.cachedAvatarURL
        card.castOverride = preview.castOverride ?? card.castOverride
        card.isAdult = preview.isAdult || card.isAdult
        return card
    }
    // Operates on visible public download controls only. It never inspects
    // serialized definitions, cookies, verification frames or account tokens.
    public static let exportScript = """
    (() => {
      const controls = [...document.querySelectorAll('button,a,[role="menuitem"]')];
      const candidate = controls.find(e => {
        if (e.dataset.kaiClicked || e.disabled || !e.getClientRects().length || getComputedStyle(e).visibility === 'hidden') return false;
        const label = (e.innerText || e.getAttribute('aria-label') || '').replace(/[()]/g, ' ').trim().replace(/\\s+/g, ' ');
        return /^(?:(?:download|export|herunterladen)(?: (?:as|als|character|card|karte|png|json|sillytavern|format|file))*|png|json)$/i.test(label);
      });
      if (candidate) { candidate.dataset.kaiClicked = '1'; candidate.click(); return true; }
      return false;
    })()
    """
}
