import Foundation
import ImageIO
import FadenCore

enum CatalogueNetwork {
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 25
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
    }()
    // Public artwork requests carry no account keys and may follow CDN redirects.
    static let publicDownloadSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 25
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }()
    static func prepare(_ original: CharacterCard, directory: URL) async throws -> CharacterCard {
        var card = original.hasDefinition ? original : try await Catalogue.detail(original)
        card.avatarURL = card.avatarURL ?? original.avatarURL
        card.cachedAvatarURL = original.cachedAvatarURL
        if !original.hasDefinition { card.languageCode = "pending" }
        if let cached = card.cachedAvatarURL, let file = URL(string: cached), file.isFileURL,
           FileManager.default.fileExists(atPath: file.path) { return card }
        guard let text = card.avatarURL, let url = URL(string: text), url.scheme == "https" else { return card }
        do {
            let (data, response) = try await publicDownloadSession.data(from: url)
            try Task.checkCancellation()
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 8 * 1024 * 1024,
                  let image = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(image) > 0 else { return card }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent(UUID().uuidString + ".image")
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            card.cachedAvatarURL = file.absoluteString
        } catch is CancellationError { throw CancellationError() }
        catch { /* Definition remains usable; original artwork can still load online. */ }
        return card
    }
}
