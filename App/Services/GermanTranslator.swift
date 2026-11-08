import Foundation
import NaturalLanguage
import Observation
import Translation
import SwiftUI
import FadenCore

enum GermanLanguage {
    static func code(_ text: String) -> String? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > 12 else { return nil }
        let recognizer = NLLanguageRecognizer(); recognizer.processString(String(clean.prefix(6000)))
        return recognizer.dominantLanguage?.rawValue
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
        var continuation: CheckedContinuation<[String: String], Error>
    }
    var current: Job?
    var failedLanguages = Set<String>()
    var missingLanguages = Set<String>()
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
        // Proper names stay intact. A non-Latin displayed name is translated too.
        if card.name.unicodeScalars.contains(where: { (0x0400...0x04ff).contains($0.value) }) { fields["name"] = card.name }
        let fallback = GermanLanguage.code([card.description, card.personality, card.firstMessage, card.scenario].joined(separator: "\n")) ?? "en"
        var groups: [String: [String: String]] = [:]
        for (key, text) in fields where !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let detected = GermanLanguage.code(text)
            let language = detected == "de" ? "de" : text.count < 120 ? fallback : detected ?? fallback
            if language != "de" { groups[language, default: [:]][key] = text }
        }
        for language in groups.keys.sorted() {
            let translated = try await request(groups[language]!, language: language, scope: scope, allowDownload: allowDownload)
            fields.merge(translated) { _, new in new }
        }
        card.name = fields["name"] ?? card.name
        card.tagline = fields["tagline"] ?? card.tagline; card.description = fields["description"] ?? card.description
        card.personality = fields["personality"] ?? card.personality; card.scenario = fields["scenario"] ?? card.scenario
        card.firstMessage = fields["firstMessage"] ?? card.firstMessage; card.exampleDialogue = fields["exampleDialogue"] ?? card.exampleDialogue
        card.systemPrompt = fields["systemPrompt"] ?? card.systemPrompt
        for index in card.alternateGreetings.indices { card.alternateGreetings[index] = fields["greeting.\(index)"] ?? card.alternateGreetings[index] }
        for index in card.lore.indices { card.lore[index].content = fields["lore.\(index)"] ?? card.lore[index].content }
        card.tags = GermanLanguage.tags(card.tags); card.languageCode = "de"
        return card
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
        let status = await LanguageAvailability().status(from: Locale.Language(identifier: language), to: Locale.Language(identifier: "de"))
        switch status {
        case .installed: missingLanguages.remove(language)
        case .supported:
            guard allowDownload else {
                missingLanguages.insert(language)
                throw TranslationSetupRequired(language: language)
            }
        case .unsupported: throw FadenError.network("Diese Sprache wird von der iPhone-Übersetzung derzeit nicht unterstützt.")
        @unknown default: throw FadenError.network("Die Übersetzung ist derzeit nicht verfügbar.")
        }
        if !allowDownload, #available(iOS 26.0, *) {
            let session: TranslationSession
            if #available(iOS 26.4, *) {
                session = TranslationSession(installedSource: Locale.Language(identifier: language), target: Locale.Language(identifier: "de"), preferredStrategy: .lowLatency)
            } else {
                session = TranslationSession(installedSource: Locale.Language(identifier: language), target: Locale.Language(identifier: "de"))
            }
            do { return try await translatedFields(fields, session: session) }
            catch is CancellationError { throw CancellationError() }
            catch {
                let status = await LanguageAvailability().status(from: Locale.Language(identifier: language), to: Locale.Language(identifier: "de"))
                switch status { case .installed: break; default: missingLanguages.insert(language); throw TranslationSetupRequired(language: language) }
                let native = error as NSError
                throw FadenError.network("Apple-Übersetzung fehlgeschlagen (\(native.domain), Code \(native.code)). Bitte die Sprachpakete unter Deutsch einrichten prüfen.")
            }
        }
        guard !failedLanguages.contains(language) else { throw FadenError.network("Für diese Übersetzung werden die Sprachpakete auf deinem iPhone benötigt. Versuche es nach dem Download erneut.") }
        try Task.checkCancellation()
        let id = UUID()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                let job = Job(id: id, scope: scope, language: language, fields: fields, allowDownload: allowDownload, continuation: continuation)
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
                if let language = self?.current?.language { self?.failedLanguages.insert(language) }
                self?.finish(.failure(FadenError.network("Die Übersetzung wartet auf Sprachpakete. Du kannst sie später erneut starten.")), id: id)
            }
        }
    }
    func perform(id: UUID, session: TranslationSession) async {
        guard let job = current, job.id == id, processing != id else { return }
        processing = id
        do {
            if job.allowDownload { try await session.prepareTranslation() }
            let result = try await translatedFields(job.fields, session: session)
            finish(.success(result), id: id)
        } catch {
            guard current?.id == id else { return }
            failedLanguages.insert(job.language)
            finish(.failure(FadenError.network("Die deutsche Übersetzung konnte nicht abgeschlossen werden. Bitte die Sprachpakete auf deinem iPhone laden und erneut versuchen.")), id: id)
        }
    }
    private func translatedFields(_ fields: [String: String], session: TranslationSession) async throws -> [String: String] {
        let plan = CardTranslationBatch(fields: fields)
        let requests = plan.requests.map { TranslationSession.Request(sourceText: $0.text, clientIdentifier: $0.id) }
        var translated: [String: String] = [:]
        for offset in stride(from: 0, to: requests.count, by: 20) {
            try Task.checkCancellation()
            let responses = try await session.translations(from: Array(requests[offset..<min(offset + 20, requests.count)]))
            for response in responses { if let key = response.clientIdentifier { translated[key] = response.targetText } }
        }
        return try plan.restore(translated)
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
            TranslationWorker(translator: translator, jobID: job.id, language: job.language).id(job.id)
        }
    }
}
private struct TranslationWorker: View {
    let translator: GermanTranslator
    let jobID: UUID
    let language: String
    var body: some View {
        Color.clear.frame(width: 1, height: 1).allowsHitTesting(false)
            .translationTask(source: Locale.Language(identifier: language), target: Locale.Language(identifier: "de")) { session in
                await translator.perform(id: jobID, session: session)
            }
    }
}
