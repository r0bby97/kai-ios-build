import Foundation
import CryptoKit
import FadenCore

/// Uses Google's public translation web endpoint, not an LLM or a user's inference account.
/// This endpoint has no availability guarantee. Respect throttling and fail within seconds.
actor GoogleCardTranslator {
    static let shared = GoogleCardTranslator()
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5; config.timeoutIntervalForResource = 8
        config.httpCookieStorage = nil; config.httpAdditionalHeaders = ["User-Agent": "Kai/1.6"]
        return URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
    }()
    private var inFlight: [String: Task<String, Error>] = [:]
    private var cooldown: Date?
    private var foregroundWaiters = 0
    private let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Kai-German", isDirectory: true)
    func translate(_ text: String, foreground: Bool = false) async throws -> String {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return text }
        let plan = TranslationPlan(text)
        var translated: [String] = []
        for chunk in plan.chunks { try Task.checkCancellation(); translated.append(try await translateChunk(chunk, foreground: foreground)) }
        return try plan.restore(translated)
    }
    private func translateChunk(_ text: String, foreground: Bool) async throws -> String {
        let key = SHA256.hash(data: Data(("de-v1\n" + text).utf8)).map { String(format: "%02x", $0) }.joined()
        let file = directory.appendingPathComponent(key)
        if let data = try? Data(contentsOf: file), let cached = String(data: data, encoding: .utf8), !cached.isEmpty { return cached }
        if let pending = inFlight[key] { return try await pending.value }
        if foreground { foregroundWaiters += 1 }
        defer { if foreground { foregroundWaiters -= 1 } }
        while inFlight.count >= 3 || (!foreground && foregroundWaiters > 0) { try await Task.sleep(for: .milliseconds(100)) }
        if let pending = inFlight[key] { return try await pending.value }
        if let cooldown, cooldown > Date() { throw FadenError.network("Google begrenzt Übersetzungsanfragen gerade. Bitte in einer Minute erneut versuchen.") }
        let requestSession = session
        let task = Task<String, Error> {
            var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
            components.queryItems = [.init(name: "client", value: "gtx"), .init(name: "sl", value: "auto"), .init(name: "tl", value: "de"), .init(name: "dt", value: "t"), .init(name: "q", value: text)]
            let (data, response) = try await requestSession.data(from: components.url!)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200, data.count < 512_000 else { throw TranslationFailure(status: status) }
            guard let root = try JSONSerialization.jsonObject(with: data) as? [Any], let segments = root.first as? [[Any]] else { throw FadenError.invalidData("Die Übersetzungsantwort ist nicht lesbar.") }
            let result = segments.compactMap { $0.first as? String }.joined()
            guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw FadenError.invalidData("Die Übersetzung lieferte keinen Text.") }
            return result
        }
        inFlight[key] = task
        defer { inFlight.removeValue(forKey: key) }
        do {
            let result = try await task.value
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? Data(result.utf8).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return result
        } catch let failure as TranslationFailure {
            if failure.status == 429 { cooldown = Date().addingTimeInterval(60) }
            throw FadenError.network("Online-Übersetzung derzeit nicht verfügbar (HTTP \(failure.status)). Die Anfrage wurde beendet; bitte später erneut versuchen oder Apple-Übersetzung wählen.")
        } catch { throw FadenError.network("Online-Übersetzung nach spätestens acht Sekunden abgebrochen. Prüfe die Internetverbindung oder wähle Apple-Übersetzung.") }
    }
    private struct TranslationFailure: Error { var status: Int }
}
