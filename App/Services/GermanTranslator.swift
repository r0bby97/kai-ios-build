import Foundation
import NaturalLanguage
import Observation
import Translation
import SwiftUI
import FadenCore

enum GermanLanguage {
    static func code(_ text: String) -> String? {
        let source = CardStructuredText.parse(text).map { $0.translationFields.sorted(by: { $0.key < $1.key }).map(\.value).joined(separator: "\n") } ?? text
        let clean = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > 12 else { return nil }
        let recognizer = NLLanguageRecognizer(); recognizer.processString(String(clean.prefix(6000)))
        guard let dominant = recognizer.dominantLanguage,
              (recognizer.languageHypotheses(withMaximum: 2)[dominant] ?? 0) >= 0.6 else { return nil }
        return dominant.rawValue
    }
    static func segmentCode(_ text: String, fallback: String) -> String {
        if text.unicodeScalars.contains(where: { (0xac00...0xd7af).contains($0.value) || (0x1100...0x11ff).contains($0.value) }) { return "ko" }
        return code(text) ?? fallback
    }
    static func tags(_ tags: [String]) -> [String] {
        let map = ["bdsm":"BDSM", "guideverse":"Guideverse", "guide-verse":"Guideverse", "esperverse":"Esperverse", "esper":"Esper", "guide":"Guide", "omegaverse":"Omegaverse", "omega-verse":"Omegaverse", "a/b/o":"Omegaverse", "abo":"Omegaverse", "female":"Weiblich", "male":"Männlich", "romance":"Romantik", "fantasy":"Fantasy", "adventure":"Abenteuer", "sci-fi":"Science-Fiction", "science fiction":"Science-Fiction", "mystery":"Mystery", "horror":"Horror", "slice of life":"Alltag", "german":"Deutsch", "deutsch":"Deutsch", "nsfw":"Erwachsene", "sfw":"Allgemein", "oc":"Originalfigur", "vampire":"Vampir", "detective":"Detektiv", "original":"Original", "dominant":"Dominant", "multiple characters":"Gruppenkarte", "multiple_characters":"Gruppenkarte", "multi-character":"Gruppenkarte", "groupchat":"Gruppenkarte", "group chat":"Gruppenkarte"]
        var seen = Set<String>()
        return tags.compactMap { tag in
            let value = map[tag.lowercased()] ?? tag
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, seen.insert(value.lowercased()).inserted else { return nil }; return value
        }
    }
}

struct TranslationSetupRequired: LocalizedError {
    var language: String
    var errorDescription: String? {
        let name = Locale(identifier: "de").localizedString(forLanguageCode: language) ?? language
        return "Für \(name) → Deutsch fehlen noch Apple-Sprachpakete. Tippe auf Deutsch einrichten, um sie einmalig zu laden. Die Karte wurde noch nicht als übersetzt markiert."
    }
}

@MainActor @Observable final class GermanTranslator {
    struct Job: Identifiable {
        var id = UUID()
        var scope: String
        var language: String
        var fields: [String: String]
        var allowDownload: Bool
        var highFidelity: Bool
        var continuation: CheckedContinuation<[String: String], Error>
    }
    var current: Job?
    var failedLanguages = Set<String>()
    var missingLanguages = Set<String>()
    struct Progress {
        var completed: Int
        var total: Int
        var language: String?
        var message: String {
            let name = language.flatMap { Locale(identifier: "de").localizedString(forLanguageCode: $0) }
            return "\(completed) von \(total) Textabschnitten" + (name.map { " · \($0) → Deutsch" } ?? "")
        }
    }
    var progress: [String: Progress] = [:]
    var pauseBackground = false
    @ObservationIgnored private var preparingGreeting = false
    @ObservationIgnored private var activeBatch = false
    private struct CacheKey: Hashable { var language: String; var text: String }
    @ObservationIgnored private var cache: [CacheKey: String] = [:]
    @ObservationIgnored private var cacheOrder: [CacheKey] = []
    private var waiting: [Job] = []
    private var processing: UUID?
    private var timer: Task<Void, Never>?

    func germanize(_ original: CharacterCard, scope: String = "main", allowDownload: Bool = false) async throws -> CharacterCard {
        if original.languageCode == "de" { return original }
        #if DEBUG || KAI_TESTING
        if ProcessInfo.processInfo.arguments.contains("-KaiUIHoldTranslations") { try await Task.sleep(for: .seconds(120)) }
        #endif
        return try await germanizeApple(original, scope: scope, allowDownload: allowDownload)
    }
    private func germanizeApple(_ original: CharacterCard, scope: String = "main", allowDownload: Bool = false) async throws -> CharacterCard {
        if original.languageCode == "de" { return original }
        var card = original
        // Retain evidence from original tags before translating or simplifying labels.
        if card.sourceCast == nil { card.sourceCast = CardCastDetector.detect(original) }
        var fields = ["tagline": card.tagline, "description": card.description, "personality": card.personality,
            "scenario": card.scenario, "firstMessage": card.firstMessage, "exampleDialogue": card.exampleDialogue, "systemPrompt": card.systemPrompt]
        for (i, value) in card.alternateGreetings.enumerated() { fields["greeting.\(i)"] = value }
        for (i, value) in card.lore.enumerated() { fields["lore.\(i)"] = value.content }
        // Proper names do not require a separate language pack.
        let fallback = [card.firstMessage, card.description, card.personality, card.scenario].compactMap(GermanLanguage.code).first ?? "en"
        fields = try await translate(fields, fallback: fallback, scope: scope, allowDownload: allowDownload)
        card.tagline = fields["tagline"] ?? card.tagline; card.description = fields["description"] ?? card.description
        card.personality = fields["personality"] ?? card.personality; card.scenario = fields["scenario"] ?? card.scenario
        card.firstMessage = fields["firstMessage"] ?? card.firstMessage; card.exampleDialogue = fields["exampleDialogue"] ?? card.exampleDialogue
        card.systemPrompt = fields["systemPrompt"] ?? card.systemPrompt
        for index in card.alternateGreetings.indices { card.alternateGreetings[index] = fields["greeting.\(index)"] ?? card.alternateGreetings[index] }
        for index in card.lore.indices { card.lore[index].content = fields["lore.\(index)"] ?? card.lore[index].content }
        card.tags = GermanLanguage.tags(card.tags); card.languageCode = "de"
        return card
    }
    func germanizeGreeting(_ text: String, fallback: String = "en") async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
        preparingGreeting = true
        defer { preparingGreeting = false }
        return try await translate(["greeting": text], fallback: GermanLanguage.code(text) ?? fallback, scope: "chat-start", allowDownload: false)["greeting"] ?? text
    }
    private func translate(_ fields: [String: String], fallback: String, scope: String, allowDownload: Bool) async throws -> [String: String] {
        let plan = CardTranslationBatch(fields: fields)
        guard !plan.requests.isEmpty else { return try plan.restore([:]) }
        progress[scope] = .init(completed: 0, total: plan.requests.count)
        defer { progress[scope] = nil }
        var translated: [String: String] = [:], groups: [String: [String: String]] = [:]
        for request in plan.requests {
            let language = GermanLanguage.segmentCode(request.text, fallback: fallback)
            if language == "de" { translated[request.id] = request.text; progress[scope]?.completed += 1 }
            else if let cached = cache[.init(language: language, text: request.text)] {
                translated[request.id] = cached; progress[scope]?.completed += 1
            } else { groups[language, default: [:]][request.id] = request.text }
        }
        for language in groups.keys.sorted() {
            try Task.checkCancellation()
            progress[scope]?.language = language
            let result = try await request(groups[language]!, language: language, scope: scope, allowDownload: allowDownload)
            translated.merge(result) { _, new in new }
        }
        return try plan.restore(translated)
    }
    func clearFailures() { failedLanguages.removeAll() }
    func prepare(language: String, scope: String) async throws {
        failedLanguages.remove(language)
        _ = try await request([:], language: language, scope: scope, allowDownload: true)
        missingLanguages.remove(language)
    }
    private func request(_ fields: [String: String], language: String, scope: String, allowDownload: Bool = false) async throws -> [String: String] {
        #if targetEnvironment(simulator)
        missingLanguages.insert(language)
        throw TranslationSetupRequired(language: language)
        #else
        let resolved = await AppleCardTranslation.resolve(language: language)
        switch resolved.status {
        case .installed: missingLanguages.remove(language); failedLanguages.remove(language)
        case .supported:
            guard allowDownload else {
                missingLanguages.insert(language)
                throw TranslationSetupRequired(language: language)
            }
        case .unsupported: throw FadenError.network("Diese Sprache wird von der iPhone-Übersetzung derzeit nicht unterstützt.")
        @unknown default: throw FadenError.network("Die Übersetzung ist derzeit nicht verfügbar.")
        }
        if !allowDownload, #available(iOS 26.0, *) {
            let session = AppleCardTranslation.installedSession(language: language, highFidelity: resolved.highFidelity)
            do { return try await translatedFields(fields, session: session, language: language, scope: scope) }
            catch is CancellationError { throw CancellationError() }
            catch {
                throw translationFailure(error, language: language)
            }
        }
        guard !failedLanguages.contains(language) else { throw FadenError.network("Für diese Übersetzung werden die Sprachpakete auf deinem iPhone benötigt. Versuche es nach dem Download erneut.") }
        try Task.checkCancellation()
        let id = UUID()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                let job = Job(id: id, scope: scope, language: language, fields: fields, allowDownload: allowDownload, highFidelity: resolved.highFidelity, continuation: continuation)
                if allowDownload { waiting.insert(job, at: 0) } else { waiting.append(job) }
                startNext()
            }
        }, onCancel: { Task { @MainActor in self.cancel(id: id) } })
        #endif
    }
    private func startNext() {
        guard current == nil, !waiting.isEmpty else { return }
        while !waiting.isEmpty {
            let next = waiting.removeFirst()
            if failedLanguages.contains(next.language) {
                next.continuation.resume(throwing: FadenError.network("Die Sprachpakete für die deutsche Übersetzung sind noch nicht bereit."))
            } else { current = next; break }
        }
        guard current != nil else { return }
        let id = current!.id
        let timeout = current!.allowDownload ? 240 : 45
        timer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            if !Task.isCancelled, self?.current?.id == id {
                self?.finish(.failure(FadenError.network("Die Apple-Übersetzung hat das Zeitlimit erreicht. Bitte erneut versuchen; ein fehlendes Sprachpaket ist damit nicht bestätigt.")), id: id)
            }
        }
    }
    func perform(id: UUID, session: TranslationSession) async {
        guard let job = current, job.id == id, processing != id else { return }
        processing = id
        do {
            if job.allowDownload {
                try await session.prepareTranslation()
                if #available(iOS 26.0, *) {
                    try AppleCardTranslation.checkPreparation(isReady: await session.isReady, language: job.language)
                }
            }
            let result = try await translatedFields(job.fields, session: session, language: job.language, scope: job.scope)
            finish(.success(result), id: id)
        } catch {
            guard current?.id == id else { return }
            finish(.failure(translationFailure(error, language: job.language)), id: id)
        }
    }
    func translationFailure(_ error: Error, language: String) -> Error {
        if error is FadenError { return error }
        if error is TranslationSetupPending {
            missingLanguages.insert(language)
            return error
        }
        let kind = AppleCardTranslation.failure(error)
        if kind == .cancelled { return CancellationError() }
        if kind == .notInstalled {
            missingLanguages.insert(language); failedLanguages.insert(language)
            return TranslationSetupRequired(language: language)
        }
        return AppleCardTranslationFailure(kind: kind)
    }
    private func translatedFields(_ fields: [String: String], session: TranslationSession, language: String, scope: String) async throws -> [String: String] {
        let requests = fields.sorted(by: { $0.key < $1.key }).map { TranslationSession.Request(sourceText: $0.value, clientIdentifier: $0.key) }
        var translated: [String: String] = [:]
        for offset in stride(from: 0, to: requests.count, by: 4) {
            try Task.checkCancellation()
            let responses = try await runBatch(Array(requests[offset..<min(offset + 4, requests.count)]), session: session, scope: scope)
            for response in responses {
                guard let key = response.clientIdentifier, let original = fields[key], !response.targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw FadenError.invalidData("Apple hat einen Textabschnitt nicht vollständig übersetzt. Die Karte bleibt im Original erhalten.")
                }
                if translated[key] == nil { progress[scope]?.completed += 1 }
                translated[key] = response.targetText
                let cacheKey = CacheKey(language: language, text: original)
                if cache[cacheKey] == nil { cacheOrder.append(cacheKey) }
                cache[cacheKey] = response.targetText
                while cacheOrder.count > 512 { cache.removeValue(forKey: cacheOrder.removeFirst()) }
            }
        }
        guard translated.count == fields.count else { throw FadenError.invalidData("Apple hat nicht alle Textabschnitte zurückgeliefert. Die Karte wurde nicht als deutsch markiert.") }
        return translated
    }
    private func runBatch(_ requests: [TranslationSession.Request], session: TranslationSession, scope: String) async throws -> [TranslationSession.Response] {
        var canPause = false
        if #available(iOS 26.0, *) { canPause = true }
        while activeBatch || (canPause && scope != "chat-start" && (preparingGreeting || pauseBackground)) {
            try await Task.sleep(for: .milliseconds(100))
        }
        try Task.checkCancellation()
        activeBatch = true
        defer { activeBatch = false }
        var timedOut = false
        let timeout = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(20)) } catch { return }
            if #available(iOS 26.0, *) { timedOut = true; session.cancel() }
        }
        defer { timeout.cancel() }
        do { return try await session.translations(from: requests) }
        catch {
            if Task.isCancelled { throw CancellationError() }
            if timedOut { throw FadenError.network("Apple benötigt für diesen Textabschnitt zu lange. Die fertigen Abschnitte bleiben zwischengespeichert; du kannst die Übersetzung erneut versuchen.") }
            throw error
        }
    }
    private func cancel(id: UUID) {
        if current?.id == id { finish(.failure(CancellationError()), id: id) }
        else if let index = waiting.firstIndex(where: { $0.id == id }) {
            let job = waiting.remove(at: index); job.continuation.resume(throwing: CancellationError())
        }
    }
    private func finish(_ result: Result<[String: String], Error>, id: UUID) {
        guard let job = current, job.id == id else { return }
        current = nil; processing = nil; timer?.cancel(); timer = nil
        job.continuation.resume(with: result)
        Task { @MainActor in await Task.yield(); startNext() }
    }
}

struct TranslationHost: View {
    let translator: GermanTranslator
    let scope: String
    var body: some View {
        if let job = translator.current, job.scope == scope {
            TranslationWorker(translator: translator, jobID: job.id, language: job.language, highFidelity: job.highFidelity).id(job.id)
        }
    }
}
private struct TranslationWorker: View {
    let translator: GermanTranslator
    let jobID: UUID
    let language: String
    let highFidelity: Bool
    var body: some View {
        Color.clear.frame(width: 1, height: 1).allowsHitTesting(false)
            .translationTask(AppleCardTranslation.configuration(language: language, highFidelity: highFidelity)) { session in
                await translator.perform(id: jobID, session: session)
            }
    }
}
