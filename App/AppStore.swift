import Foundation
import Observation
import FadenCore

struct StoryRoute: Identifiable { var id: UUID }

@MainActor @Observable final class AppStore {
    var archive: Archive
    var error: String?
    var presentedStory: StoryRoute?
    var generationStoryID: UUID?
    var startingConversation = false
    var generationStatus = ""
    var promptInfo = ""
    var preloadingCatalogue = false
    var catalogueStatus: String?
    var catalogueProcessed = 0
    var catalogueTarget = 0
    var translatingCatalogue = false
    var catalogueTranslationStatus: String?
    private var catalogueTask: Task<Void, Never>?
    private var catalogueTranslationTask: Task<Void, Never>?
    private var lastCatalogueSave = Date.distantPast
    var libraryCharacters: [CharacterCard] {
        #if DEBUG || KAI_TESTING
        if ProcessInfo.processInfo.arguments.contains("-FadenUITest") && !ProcessInfo.processInfo.arguments.contains("-KaiUIPublicLibraryTest") { return archive.characters }
        #endif
        return archive.libraryCharacters
    }
    let diagnostics = DiagnosticLog()
    let local = LocalEngine()
    let auth = ChatGPTAuth()
    let translator = GermanTranslator()
    private var generation: Task<Void, Never>?
    private var draftSave: Task<Void, Never>?
    private var lastStreamSave = Date.distantPast
    private let directory: URL
    private var stateURL: URL { directory.appendingPathComponent("archive.json") }
    private var recoveryURL: URL { directory.appendingPathComponent("archive.previous.json") }

    init() {
        var storeName = "Faden"
        #if DEBUG || KAI_TESTING
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-FadenUITestStore"), arguments.indices.contains(flag + 1),
           let identifier = UUID(uuidString: arguments[flag + 1]) { storeName = "FadenUITest-\(identifier.uuidString)" }
        #endif
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(storeName, isDirectory: true)
        archive = Archive()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: directory.path)
            if FileManager.default.fileExists(atPath: stateURL.path) {
                do { archive = try Self.decode(Data(contentsOf: stateURL)) }
                catch {
                    let bad = directory.appendingPathComponent("archive.damaged.\(Int(Date().timeIntervalSince1970)).json")
                    try? FileManager.default.copyItem(at: stateURL, to: bad)
                    if let data = try? Data(contentsOf: recoveryURL), let recovered = try? Self.decode(data) {
                        archive = recovered; self.error = "Der letzte Speicherstand war beschädigt. Die vorherige Sicherung wurde wiederhergestellt."
                    } else {
                        archive = Archive()
                        self.error = "Der Speicherstand konnte nicht gelesen werden. Die beschädigte Datei wurde zur Wiederherstellung aufbewahrt."
                    }
                }
            } else { archive = Archive() }
        } catch { self.error = "Lokaler Speicher: \(error.localizedDescription)" }
        #if DEBUG || KAI_TESTING
        if arguments.contains("-FadenUITest"), !arguments.contains("-KaiUIPublicLibraryTest"), archive.characters.isEmpty {
            archive.characters = (try? CharacterCard.starters()) ?? []
        }
        #endif
        archive.preferences.language = "Deutsch"
        for index in archive.stories.indices where archive.stories[index].cardCasts == nil {
            archive.stories[index].cardCasts = Dictionary(archive.stories[index].participantIDs.compactMap { id in
                archive.characters.first(where: { $0.id == id }).map { (id, $0.cast) }
            }, uniquingKeysWith: { first, _ in first })
        }
        #if DEBUG || KAI_TESTING
        if arguments.contains("-KaiUIInferenceTest") {
            archive.freeOnly = false
            archive.connections = [
                .init(name: "UI-Test: kontoweites Limit", kind: .compatible, baseURL: "https://kai-ui-test.invalid/v1", models: ["blocked", "must-skip"]),
                .init(name: "UI-Test: zweiter Anbieter", kind: .compatible, baseURL: "https://kai-ui-test.invalid/v1", models: ["working"])
            ]
            archive.preferences.insightFrequency = .off
        }
        if arguments.contains("-KaiUIInsightTest"), archive.stories.isEmpty, let card = archive.characters.first {
            var story = Story(character: card)
            story.append(role: .user, content: "Einblick-Test: Eine ruhige Szene.")
            let reply = story.append(role: .assistant, content: "Mara stellt die Lampe auf den Tisch und wartet.", speakerID: card.id)
            story.insights = [.init(sourceMessageID: reply, characterID: card.id, kind: .memory, text: "Einblick-Test: In ihrer ersten Nacht im Büro hatte Mara die Lampe bis zum Morgen brennen lassen. Das Licht half ihr damals, das fremde Zimmer zu einem vertrauten Ort zu machen.")]
            story.insightAttemptIDs = [reply]
            archive.stories = [story]; save()
        }
        if arguments.contains("-KaiUIScrollTest"), archive.stories.isEmpty, let card = archive.characters.first {
            var story = Story(character: card)
            for index in 1...90 {
                story.append(role: index.isMultiple(of: 2) ? .assistant : .user,
                    content: "Scroll-Test Nachricht \(index). " + String(repeating: "Die Geschichte geht im Lesetest weiter. ", count: 6), speakerID: card.id)
            }
            archive.stories = [story]; save()
        }
        #endif
    }
    static func decode(_ data: Data) throws -> Archive {
        guard data.count <= 60 * 1024 * 1024 else { throw FadenError.invalidData("Das Backup ist zu groß (maximal 60 MB).") }
        let value = try JSONDecoder().decode(Archive.self, from: data); try value.validate(); return value
    }
    func save() {
        do {
            let data = try JSONEncoder().encode(archive)
            // Keep a last-known-valid copy without replacing it with a damaged primary file.
            if let previous = try? Data(contentsOf: stateURL), (try? Self.decode(previous)) != nil {
                try previous.write(to: recoveryURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
            try data.write(to: stateURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { self.error = "Speichern fehlgeschlagen: \(error.localizedDescription)" }
    }
    func character(_ id: String) -> CharacterCard? { archive.characters.first { $0.id == id } }
    func story(_ id: UUID) -> Story? { archive.stories.first { $0.id == id } }
    func updateDraft(_ text: String, storyID: UUID) {
        guard let index = archive.stories.firstIndex(where: { $0.id == storyID }) else { return }
        archive.stories[index].draftText = text.isEmpty ? nil : text
        draftSave?.cancel()
        draftSave = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(400)); try Task.checkCancellation() }
            catch { return }
            self?.save()
        }
    }
    func preloadCatalogue(force: Bool = false) async {
        guard !ProcessInfo.processInfo.arguments.contains("-FadenUITest") else { return }
        #if DEBUG || KAI_TESTING
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil,
           !ProcessInfo.processInfo.arguments.contains("-FadenUITestStore") { return }
        #endif
        let saved = UserDefaults.standard.integer(forKey: "cataloguePrepareCount")
        startCataloguePreparation(count: [24, 60, 120].contains(saved) ? saved : 60, force: force)
    }
    func startCataloguePreparation(count: Int, force: Bool = true) {
        guard !preloadingCatalogue else { return }
        let count = min(120, max(1, count))
        let cached = archive.libraryCharacters.filter { $0.id.hasPrefix("chub/") }
        if !force, cached.count >= count, cached.prefix(count).allSatisfy({ $0.hasDefinition && ($0.avatarURL == nil || $0.cachedAvatarURL != nil) }) {
            catalogueStatus = "\(cached.count) öffentliche Karten verfügbar"
            retryCatalogueTranslations(); return
        }
        preloadingCatalogue = true; catalogueProcessed = 0; catalogueTarget = 0
        catalogueStatus = "Kartentexte aus Chub werden geladen …"
        catalogueTask = Task { [weak self] in await self?.prepareCatalogue(count: count) }
    }
    func cancelCataloguePreparation() { catalogueTask?.cancel() }
    private func prepareCatalogue(count: Int) async {
        defer { preloadingCatalogue = false; catalogueTask = nil; save() }
        var ordered: [String] = []
        var pageFailure = false
        let includeAdult = UserDefaults.standard.object(forKey: "includeAdultCatalogue") as? Bool ?? true
        do {
            for page in 1...max(1, (count + 23) / 24) {
                try Task.checkCancellation()
                let result: CataloguePage
                do { result = try await Catalogue.search(query: "", page: page, includeAdult: includeAdult) }
                catch is CancellationError { throw CancellationError() }
                catch { pageFailure = true; break }
                let helperTags = Set(["meta", "helpers", "card builder", "prompt"])
                let previews = Array(result.cards.filter { card in
                    !ordered.contains(card.id) && !card.tags.contains(where: { helperTags.contains($0.lowercased()) })
                }.prefix(max(0, count - ordered.count)))
                ordered += previews.map(\.id)
                archive.characters = CatalogueLibrary.merging(previews, into: archive.characters, order: ordered)
                save() // Publish names, text and original image URLs before any translation.
                catalogueStatus = "\(ordered.count) Kartentexte verfügbar · Originalbilder laden separat"
                if ordered.count >= count || !result.hasMore { break }
            }
            try Task.checkCancellation()
            guard !ordered.isEmpty else { throw FadenError.network("Chub ist gerade nicht erreichbar.") }
            let cards = ordered.compactMap { character($0) }
            let pending = cards.filter { card in
                !card.hasDefinition || (card.avatarURL != nil && (card.cachedAvatarURL.flatMap(URL.init(string:)).map { !FileManager.default.fileExists(atPath: $0.path) } ?? true))
            }
            catalogueTarget = pending.count
            let artworkDirectory = directory.appendingPathComponent("OriginalArtwork", isDirectory: true)
            try await CataloguePreparation.run(cards: pending, fetch: { [weak self] card in
                try await self?.waitForCatalogueWork()
                return try await CatalogueNetwork.prepare(card, directory: artworkDirectory)
            }, finished: { [weak self] result in await self?.acceptPreparedCard(result) })
            let full = ordered.compactMap { character($0) }.filter(\.hasDefinition).count
            let images = ordered.compactMap { character($0) }.filter { $0.cachedAvatarURL != nil }.count
            catalogueStatus = "\(ordered.count) Karten · \(full) Definitionen · \(images) Originalbilder offline" + (pageFailure ? " · weitere Katalogseiten derzeit nicht erreichbar" : "")
            retryCatalogueTranslations()
        } catch is CancellationError { catalogueStatus = "Vorbereitung gestoppt · geladene Karten bleiben verfügbar" }
        catch { catalogueStatus = "Katalog nicht erreichbar. Unter Online entdecken kannst du Chub oder JannyAI erneut versuchen." }
    }
    private func waitForCatalogueWork() async throws {
        while generationStoryID != nil || startingConversation || ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical {
            if preloadingCatalogue { catalogueStatus = "Kartenvorbereitung pausiert während KI-Antwort oder hoher Geräteauslastung" }
            try await Task.sleep(for: .seconds(2))
        }
        try Task.checkCancellation()
    }
    private func acceptPreparedCard(_ result: CataloguePreparationResult) {
        catalogueProcessed += 1
        if var card = result.card, let index = archive.characters.firstIndex(where: { $0.id == result.id }) {
            let current = archive.characters[index]
            if current.hasDefinition { // Preserve translations or edits that finished during image download.
                let image = card.cachedAvatarURL
                card = current; card.cachedAvatarURL = image ?? current.cachedAvatarURL
            }
            archive.characters[index] = card
            retryCatalogueTranslations()
        }
        catalogueStatus = "\(catalogueProcessed) von \(catalogueTarget) Karten vorbereitet · Texte bereits verfügbar"
        if Date().timeIntervalSince(lastCatalogueSave) > 1 { save(); lastCatalogueSave = Date() }
    }
    func retryCatalogueTranslations(force: Bool = false) {
        if force { translator.clearFailures() }
        guard catalogueTranslationTask == nil else { return }
        translatingCatalogue = true
        catalogueTranslationTask = Task { [weak self] in
            guard let self else { return }
            defer { self.translatingCatalogue = false; self.catalogueTranslationTask = nil; self.save() }
            var attempted = Set<String>(); var translated = 0
            while let card = self.archive.libraryCharacters.first(where: { $0.hasDefinition && $0.languageCode != "de" && !attempted.contains($0.id) }) {
                if Task.isCancelled { break }
                attempted.insert(card.id)
                self.catalogueTranslationStatus = "Deutschübersetzung: \(translated) fertig · Originalkarten sind bereits verfügbar"
                do {
                    try await self.waitForCatalogueWork()
                    var localized = try await self.translator.germanize(card)
                    if let current = self.character(card.id), current.description == card.description, current.personality == card.personality {
                        localized.cachedAvatarURL = current.cachedAvatarURL
                        self.addCard(localized); translated += 1
                    }
                } catch is CancellationError { break }
                catch { /* Missing language packs must never block discovery or offline preparation. */ }
            }
            let pending = self.archive.libraryCharacters.filter { $0.hasDefinition && $0.languageCode != "de" }.count
            self.catalogueTranslationStatus = pending == 0 ? nil : "Deutschübersetzung für \(pending) Karten noch ausstehend"
        }
    }
    func mutate(_ id: UUID, _ edit: (inout Story) throws -> Void) rethrows {
        guard let index = archive.stories.firstIndex(where: { $0.id == id }) else { return }
        try edit(&archive.stories[index]); save()
    }
    func addCard(_ card: CharacterCard) {
        if let index = archive.characters.firstIndex(where: { $0.id == card.id }) { archive.characters[index] = card }
        else { archive.characters.append(card) }
        for index in archive.stories.indices where archive.stories[index].participantIDs.contains(card.id) {
            if archive.stories[index].cardCasts == nil { archive.stories[index].cardCasts = [:] }
            archive.stories[index].cardCasts?[card.id] = card.cast
        }
        save()
    }
    func start(_ character: CharacterCard) {
        start(characters: [character], persona: nil, scene: nil, greeting: nil)
    }
    func start(characters: [CharacterCard], persona: UserPersona?, scene: String?, greeting: String?) {
        guard !characters.isEmpty, !startingConversation else { return }
        startingConversation = true
        Task {
            defer { startingConversation = false }
            do {
                var localized: [CharacterCard] = []
                for original in characters {
                    var card = original
                    if CatalogueSource.source(for: card.id) != nil {
                        if !card.hasDefinition { card = try await Catalogue.detail(card) }
                        if card.languageCode != "de" { card = try await translator.germanize(card, scope: "chat-start") }
                    }
                    localized.append(card)
                }
                var opening = greeting; var scenario = scene
                if let before = characters.first, let after = localized.first, before.id == after.id {
                    if greeting == before.firstMessage { opening = after.firstMessage }
                    else if let greeting, let i = before.alternateGreetings.firstIndex(of: greeting), after.alternateGreetings.indices.contains(i) { opening = after.alternateGreetings[i] }
                    if scene == before.scenario { scenario = after.scenario }
                }
                for card in localized { addCard(card) }
                let story = Story(characters: localized, persona: persona, scenario: scenario, greeting: opening, userName: archive.preferences.userName)
                archive.stories.insert(story, at: 0); save(); presentedStory = StoryRoute(id: story.id)
            } catch { self.error = "Das Gespräch wurde noch nicht gestartet: " + error.localizedDescription }
        }
    }
    func toggleFavorite(_ card: CharacterCard) {
        if archive.favoriteIDs.contains(card.id) { archive.favoriteIDs.remove(card.id) }
        else { addCard(card); archive.favoriteIDs.insert(card.id) }
        save()
    }
    func importFile(_ url: URL, origin: CharacterCard? = nil, onImported: ((CharacterCard) -> Void)? = nil) {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard (attributes[.size] as? NSNumber)?.intValue ?? 0 <= CardCodec.maximumBytes else {
                throw FadenError.invalidData("Die Karte ist zu groß. Backups bitte in den Einstellungen importieren.")
            }
            var card = try CardCodec.decode(Data(contentsOf: url), filename: url.lastPathComponent)
            if let origin {
                guard !card.description.isEmpty || !card.personality.isEmpty else { throw FadenError.invalidData("Die heruntergeladene Karte enthält keine freigegebene Definition.") }
                card.id = origin.id; card.sourceURL = origin.sourceURL; card.isAdult = origin.isAdult
            }
            if url.pathExtension.lowercased() == "png" {
                let imageURL = directory.appendingPathComponent("\(UUID().uuidString).png")
                try Data(contentsOf: url).write(to: imageURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                card.avatarURL = imageURL.absoluteString
            }
            let imported = card
            Task {
                do { let localized = try await translator.germanize(imported); addCard(localized); onImported?(localized) }
                catch {
                    var pending = imported; pending.languageCode = "pending"; addCard(pending)
                    onImported?(pending)
                    self.error = "Karte importiert. Die deutsche Übersetzung kann nach dem Laden der Sprachpakete nachgeholt werden."
                }
            }
        } catch { self.error = error.localizedDescription }
    }
    func importBackup(_ url: URL) throws {
        guard generation == nil else { throw FadenError.invalidData("Bitte zuerst die laufende Antwort stoppen.") }
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        let value = try Self.decode(Data(contentsOf: url))
        // Import is a merge; an existing story is never erased by a backup with the same ID.
        for card in value.characters where !archive.characters.contains(where: { $0.id == card.id }) { archive.characters.append(card) }
        for story in value.stories where !archive.stories.contains(where: { $0.id == story.id }) { archive.stories.append(story) }
        archive.preferences = value.preferences
        archive.preferences.language = "Deutsch"
        archive.menuTheme = value.menuTheme
        archive.favoriteIDs.formUnion(value.favoriteIDs)
        for persona in value.personas where !archive.personas.contains(where: { $0.id == persona.id }) { archive.personas.append(persona) }
        for scene in value.scenes where !archive.scenes.contains(where: { $0.id == scene.id }) { archive.scenes.append(scene) }
        for var connection in value.connections where !archive.connections.contains(where: { $0.id == connection.id }) {
            connection.enabled = false
            archive.connections.append(connection)
        }
        // Importing a backup cannot turn off the current spending protection.
        save()
    }
    func backupURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Kai-Backup.json")
        var portable = archive
        // A backup contains connection settings but never credentials or device-local image paths.
        for index in portable.characters.indices where portable.characters[index].avatarURL?.hasPrefix("file:") == true {
            portable.characters[index].avatarURL = nil
        }
        for index in portable.characters.indices { portable.characters[index].cachedAvatarURL = nil }
        try JSONEncoder().encode(portable).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return url
    }
    func send(_ text: String, storyID: UUID, replyingAs: String? = nil, allParticipants: Bool = false) {
        guard generation == nil, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        mutate(storyID) { $0.draftText = nil; $0.append(role: .user, content: text) }
        respond(storyID, replyingAs: replyingAs, allParticipants: allParticipants)
    }
    func regenerate(_ storyID: UUID) {
        guard generation == nil, let story = story(storyID) else { return }
        do {
            if story.activeMessages.last?.role == .assistant {
                try mutate(storyID) { try $0.rewind(to: story.activeMessages.last?.parentID, title: "Alternative Antwort") }
            }
            guard self.story(storyID)?.activeMessages.isEmpty == false else { return }
            respond(storyID, replyingAs: story.activeMessages.last?.speakerID ?? story.characterID)
        } catch { self.error = error.localizedDescription }
    }
    func stop() { generation?.cancel() }
    func continueStory(_ storyID: UUID, replyingAs: String? = nil, allParticipants: Bool = false) {
        respond(storyID, replyingAs: replyingAs, allParticipants: allParticipants)
    }
    private func respond(_ storyID: UUID, replyingAs: String? = nil, allParticipants: Bool = false) {
        guard generation == nil, let story = story(storyID) else { return }
        let speakers = story.responseOrder(replyingAs: replyingAs, allParticipants: allParticipants)
        generationStoryID = storyID
        generation = Task { [weak self] in
            guard let self else { return }
            defer { self.generation = nil; self.generationStoryID = nil; self.save() }
            var completedReply: CompletedReply?
            for speakerID in speakers {
                do { try Task.checkCancellation(); completedReply = try await self.generateResponse(storyID, speakerID: speakerID) }
                catch {
                    if !Task.isCancelled && !(error is CancellationError) { self.error = error.localizedDescription }
                    return
                }
            }
            if let completedReply, !Task.isCancelled { await self.generateInsight(storyID, after: completedReply) }
        }
    }
    private struct CompletedReply {
        var messageID: UUID
        var speakerID: String
        var connection: Connection
        var model: String
    }
    private func generateResponse(_ storyID: UUID, speakerID: String) async throws -> CompletedReply {
        guard let snapshot = story(storyID), let character = character(speakerID) else { throw FadenError.invalidData("Die Figur wurde nicht gefunden.") }
        generationStatus = "\(character.name) · Verbindung wird gewählt"
        let assistantID = UUID()
        mutate(storyID) { story in
            let message = Message(id: assistantID, parentID: story.headID, role: .assistant, content: "", interrupted: true, speakerID: speakerID)
            story.messages.append(message); story.headID = assistantID
        }
        let connections = archive.connections; let prefs = archive.preferences; let freeOnly = archive.freeOnly
            var problems: [String] = []
            outer: for connection in connections {
                var models = connection.permittedModels(freeOnly: freeOnly)
                var nextModel = 0; var expandedFreeRouter = false
                while nextModel < models.count {
                    let model = models[nextModel]; nextModel += 1
                    if Task.isCancelled { break outer }
                    if connection.kind == .local && self.local.loadedID != model { continue }
                    let key = Keychain.string("provider.\(connection.id)")
                    if connection.requiresAPIKey && key.isEmpty { continue }
                    if connection.kind == .chatGPT && self.auth.credential(connection.id) == nil { continue }
                    let outputBudget = min(prefs.requestedOutputTokens, max(128, connection.contextTokens / 3))
                    let prompt = PromptBuilder.build(character: character, story: snapshot, preferences: prefs,
                        contextTokens: connection.contextTokens, outputTokens: outputBudget,
                        participants: snapshot.participantIDs.compactMap { self.character($0) })
                    self.promptInfo = "ca. \(prompt.estimatedTokens) Kontext-Tokens · \(prompt.retrievedCount) ältere Auszüge"
                    self.generationStatus = "\(character.name) · \(connection.name)"
                    var limiter = ResponseWordLimiter(maximumWords: prefs.maximumResponseWords)
                    let onDelta: @MainActor (String) -> Bool = { [weak self] delta in
                        guard let self, !delta.isEmpty else { return false }
                        #if DEBUG || KAI_TESTING
                        if ProcessInfo.processInfo.arguments.contains("-KaiUIDropTextCallbacks") { return false }
                        #endif
                        let limited = limiter.append(delta)
                        if let si = self.archive.stories.firstIndex(where: { $0.id == storyID }),
                           let mi = self.archive.stories[si].messages.firstIndex(where: { $0.id == assistantID }) {
                            self.archive.stories[si].messages[mi].content = limited.text
                            self.archive.stories[si].messages[mi].model = model
                            self.archive.stories[si].updatedAt = Date()
                            if Date().timeIntervalSince(self.lastStreamSave) > 2 { self.save(); self.lastStreamSave = Date() }
                        }
                        return limited.reachedLimit
                    }
                    do {
                        let result: InferenceResult
                        if connection.kind == .local {
                            result = try await self.local.generate(id: model, prompt: prompt, maxTokens: outputBudget, onDelta: onDelta)
                        } else {
                            let credential = connection.kind == .chatGPT ? try await self.auth.accessToken(connection.id) : key
                            result = try await CloudEngine.generate(connection: connection, model: model, key: credential,
                                prompt: prompt, maxTokens: outputBudget, onDelta: onDelta)
                        }
                        // Verify the stored message, rather than a captured Boolean across await.
                        // The engine result can restore an answer if a callback failed to persist it.
                        var report = result.diagnostic
                        if self.replyText(storyID, messageID: assistantID).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            var recovered = ResponseWordLimiter(maximumWords: prefs.maximumResponseWords)
                            let text = recovered.append(result.text).text
                            self.mutate(storyID) { story in
                                if let i = story.messages.firstIndex(where: { $0.id == assistantID }) { story.messages[i].content = text; story.messages[i].model = model }
                            }
                            report.outcome = "Antwort aus Ergebnis wiederhergestellt"
                        }
                        self.diagnostics.append(report)
                        guard !self.replyText(storyID, messageID: assistantID).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            throw ProviderFailure(text: "Die empfangene Antwort konnte nicht im Gespräch gespeichert werden. Fehlerberichte enthalten die Transportdaten.")
                        }
                        self.mutate(storyID) { story in
                            if let i = story.messages.firstIndex(where: { $0.id == assistantID }) { story.messages[i].interrupted = false }
                        }
                        return CompletedReply(messageID: assistantID, speakerID: speakerID, connection: connection, model: model)
                    } catch {
                        if Task.isCancelled || error is CancellationError { break outer }
                        problems.append("\(connection.name) · \(model): \(error.localizedDescription)")
                        if let report = (error as? ProviderFailure)?.diagnostic { self.diagnostics.append(report) }
                        if !self.replyText(storyID, messageID: assistantID).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { break outer } // Never splice another model onto a partial answer.
                        if let failure = error as? ProviderFailure, failure.blocksConnection || !failure.retryable { break }
                        if connection.kind == .openRouter, models.contains("openrouter/free"), !expandedFreeRouter {
                            expandedFreeRouter = true
                            if let extra = try? await CloudEngine.freeFallbackModels(connection: connection, key: key, excluding: models) { models += extra }
                        }
                    }
                }
            }
            if self.replyText(storyID, messageID: assistantID).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.mutate(storyID) { story in
                    story.messages.removeAll { $0.id == assistantID }; story.headID = snapshot.headID
                }
            }
            if Task.isCancelled { throw CancellationError() }
            throw FadenError.network(problems.isEmpty ? FadenError.notConfigured.localizedDescription : problems.joined(separator: "\n\n"))
    }
    private func replyText(_ storyID: UUID, messageID: UUID) -> String {
        story(storyID)?.messages.first(where: { $0.id == messageID })?.content ?? ""
    }
    private func generateInsight(_ storyID: UUID, after reply: CompletedReply) async {
        guard let snapshot = story(storyID), snapshot.headID == reply.messageID,
              InsightSchedule.isDue(story: snapshot, frequency: archive.preferences.effectiveInsightFrequency),
              let character = character(reply.speakerID),
              let connection = archive.connections.first(where: { $0.id == reply.connection.id }),
              connection.permittedModels(freeOnly: archive.freeOnly).contains(reply.model) else { return }
        // An optional aside never escalates to a different account or paid fallback.
        let kind = InsightSchedule.kind(for: reply.messageID)
        mutate(storyID) { story in
            if story.insightAttemptIDs == nil { story.insightAttemptIDs = [] }
            story.insightAttemptIDs?.append(reply.messageID)
        }
        generationStatus = "Einblick in \(character.name) · \(connection.name)"
        let outputBudget = min(320, max(128, connection.contextTokens / 3))
        let prompt = InsightPromptBuilder.build(character: character, story: snapshot, kind: kind, contextTokens: connection.contextTokens)
        var limiter = ResponseWordLimiter(maximumWords: 80)
        var text = ""
        let onDelta: @MainActor (String) -> Bool = { delta in
            let result = limiter.append(delta); text = result.text; return result.reachedLimit
        }
        do {
            try Task.checkCancellation()
            if connection.kind == .local {
                _ = try await local.generate(id: reply.model, prompt: prompt, maxTokens: outputBudget, onDelta: onDelta)
            } else {
                let key = connection.kind == .chatGPT ? try await auth.accessToken(connection.id) : Keychain.string("provider.\(connection.id)")
                _ = try await CloudEngine.generate(connection: connection, model: reply.model, key: key, prompt: prompt, maxTokens: outputBudget, onDelta: onDelta)
            }
            try Task.checkCancellation()
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, story(storyID)?.headID == reply.messageID,
                  archive.preferences.effectiveInsightFrequency != .off,
                  archive.connections.first(where: { $0.id == connection.id })?.enabled == true else { return }
            mutate(storyID) { story in
                if story.insights == nil { story.insights = [] }
                story.insights?.append(CharacterInsight(sourceMessageID: reply.messageID, characterID: reply.speakerID, kind: kind, text: trimmed, model: reply.model))
            }
        } catch {
            // Keep the completed dialogue intact. Retry only after the next scheduled gap.
        }
    }
}
