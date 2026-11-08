import XCTest
@testable import FadenCore

final class CoreTests: XCTestCase {
    func testStartersAreAvailableAndDistinct() throws {
        let cards = try CharacterCard.starters()
        XCTAssertEqual(cards.count, 24)
        XCTAssertEqual(Set(cards.map(\.id)).count, 24)
        XCTAssertTrue(cards.allSatisfy { !$0.name.isEmpty && !$0.firstMessage.isEmpty && !$0.personality.isEmpty })
    }
    func testRewindRestoresMemoryAndStyleWithoutFutureLeak() throws {
        var story = Story(character: CharacterCard(name: "Mara", firstMessage: "Hallo"))
        let earlier = story.append(role: .user, content: "Ich warte.")
        let future = story.append(role: .user, content: "ZUKUNFTSGEHEIMNIS *Ich gehe in den Garten und finde eine goldene Uhr.*")
        story.memories.append(.init(text: "Die Uhr liegt im Garten", sourceMessageID: future))
        story.memories.append(.init(text: "Eine feste Vorgabe", sourceMessageID: nil))
        try story.rewind(to: earlier)
        XCTAssertEqual(story.activeMessages.count, 2)
        XCTAssertEqual(story.activeMemories.map(\.text), ["Eine feste Vorgabe"])
        XCTAssertEqual(StyleProfile(story: story).sampleCount, 1)
        let prompt = PromptBuilder.build(character: .init(name: "Mara"), story: story, preferences: .init(), contextTokens: 4096)
        XCTAssertFalse(prompt.system.contains("ZUKUNFTSGEHEIMNIS"))
        XCTAssertFalse(prompt.system.contains("Uhr liegt im Garten"))
        XCTAssertFalse(prompt.messages.contains { $0.content.contains("ZUKUNFTSGEHEIMNIS") })
        XCTAssertEqual(story.branches.first?.headID, future)
        try story.rewind(to: future)
        XCTAssertEqual(story.activeMemories.count, 2)
    }
    func testEditingCreatesBranchInsteadOfMutatingHistory() throws {
        var story = Story(character: .init(name: "Mara"))
        let original = story.append(role: .user, content: "Ich gehe links.")
        story.append(role: .assistant, content: "Links liegt ein See.")
        try story.edit(original, text: "Ich gehe rechts.")
        XCTAssertEqual(story.activeMessages.map(\.content), ["Ich gehe rechts."])
        XCTAssertEqual(story.messages.first(where: { $0.id == original })?.content, "Ich gehe links.")
        XCTAssertEqual(story.branches.count, 1)
    }
    func testUnknownRewindIsRejected() {
        var story = Story(character: .init(name: "Mara"))
        XCTAssertThrowsError(try story.rewind(to: UUID()))
    }
    func testJSONCardsV1V2V3AndRoundTrip() throws {
        for root in [#"{"name":"Test","first_mes":"Hallo","personality":"Ruhig"}"#,
            #"{"spec":"chara_card_v2","data":{"name":"Test","first_mes":"Hallo","personality":"Ruhig"}}"#,
            #"{"spec":"chara_card_v3","data":{"name":"Test","first_mes":"Hallo","personality":"Ruhig"}}"#] {
            let card = try CardCodec.decode(Data(root.utf8))
            XCTAssertEqual(card.name, "Test"); XCTAssertEqual(card.firstMessage, "Hallo")
            XCTAssertEqual(try CardCodec.decode(CardCodec.encode(card)).personality, "Ruhig")
        }
    }
    func testPNGCardMetadataAndMalformedLengths() throws {
        let json = Data(#"{"name":"PNG Character","description":"Eine Figur"}"#.utf8)
        let payload = Data("chara\0".utf8) + Data(json.base64EncodedString().utf8)
        var png = Data([137,80,78,71,13,10,26,10])
        let n = UInt32(payload.count)
        png.append(contentsOf: [UInt8((n >> 24) & 255), UInt8((n >> 16) & 255), UInt8((n >> 8) & 255), UInt8(n & 255)])
        png.append(Data("tEXt".utf8)); png.append(payload); png.append(contentsOf: [0,0,0,0])
        XCTAssertEqual(try CardCodec.decode(png).name, "PNG Character")
        png[8] = 255
        XCTAssertThrowsError(try CardCodec.decode(png))
    }
    func testMissingCardNameRejected() { XCTAssertThrowsError(try CardCodec.decode(Data("{}".utf8))) }
    func testFreeModeNeverSelectsPaidOrUnknownEndpoints() {
        let cloud = Connection(name: "Cloud", kind: .openRouter, models: ["openrouter/free", "paid-model", "a/model:free"])
        XCTAssertEqual(cloud.permittedModels(freeOnly: true), ["openrouter/free", "a/model:free"])
        XCTAssertEqual(Connection(name: "Unknown", kind: .compatible, models: ["model"]).permittedModels(freeOnly: true), [])
        XCTAssertEqual(Connection(name: "Paid", kind: .openRouter, models: ["model:free"], allowsCosts: true).permittedModels(freeOnly: true), [])
        XCTAssertEqual(cloud.permittedModels(freeOnly: false).count, 3)
    }
    func testSSEMultilineCRLFAndTerminalEvent() {
        var parser = SSEParser()
        XCTAssertNil(parser.consume(": heartbeat"))
        XCTAssertNil(parser.consume("event: response.output_text.delta\r"))
        XCTAssertNil(parser.consume("data: first\r")); XCTAssertNil(parser.consume("data: second"))
        XCTAssertEqual(parser.consume(""), SSEEvent(name: "response.output_text.delta", data: "first\nsecond"))
        XCTAssertNil(parser.consume("data: [DONE]"))
        XCTAssertEqual(parser.finish(), SSEEvent(name: "message", data: "[DONE]"))
        XCTAssertNil(parser.finish())
    }
    func testPromptStaysWithinConservativeBudget() {
        var story = Story(character: .init(name: "Mara"))
        for i in 0..<40 { story.append(role: i % 2 == 0 ? .user : .assistant, content: String(repeating: "Wald und Erinnerung \(i). ", count: 70)) }
        var preferences = WritingPreferences(); preferences.instructions = String(repeating: "ä🙂", count: 2000)
        let card = CharacterCard(name: "Mara", description: String(repeating: "Beschreibung. ", count: 3000))
        let prompt = PromptBuilder.build(character: card, story: story, preferences: preferences, contextTokens: 4096, outputTokens: 500)
        XCTAssertLessThan(prompt.estimatedTokens, 4096 - 500)
        XCTAssertTrue(prompt.truncated)
        XCTAssertEqual(prompt.messages.last?.role, "assistant")
        XCTAssertFalse(prompt.messages.last?.content.isEmpty ?? true)
    }
    func testUnicodeClippingIsValidAndBounded() {
        let clipped = PromptBuilder.clipped(String(repeating: "🙂ä界", count: 100), bytes: 57)
        XCTAssertLessThanOrEqual(clipped.utf8.count, 57)
        XCTAssertNotNil(clipped.data(using: .utf8))
    }
    func testArchiveRoundTripAndInvalidFutureSchema() throws {
        let card = CharacterCard(name: "Mara")
        var archive = Archive(characters: [card], stories: [Story(character: card)])
        let data = try JSONEncoder().encode(archive)
        try JSONDecoder().decode(Archive.self, from: data).validate()
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("accessToken"))
        archive.schemaVersion = 100
        XCTAssertThrowsError(try archive.validate())
    }
    func testArchiveRejectsCyclesAndDuplicateIDs() throws {
        let card = CharacterCard(name: "Mara")
        var archive = Archive(characters: [card], stories: [Story(character: card)])
        let id = archive.stories[0].append(role: .user, content: "Hallo")
        archive.stories[0].messages[0].parentID = id
        XCTAssertThrowsError(try archive.validate())
        archive.stories = []; archive.characters.append(card)
        XCTAssertThrowsError(try archive.validate())
    }
    func testLoreActivationUsesOnlyCurrentBranch() throws {
        var story = Story(character: .init(name: "Mara"))
        let id = story.append(role: .user, content: "Ein Zimmer")
        story.append(role: .user, content: "Geheimschlüssel")
        try story.rewind(to: id)
        let card = CharacterCard(name: "Mara", lore: [.init(keys: ["Geheimschlüssel"], content: "NICHT SICHTBAR")])
        let prompt = PromptBuilder.build(character: card, story: story, preferences: .init(), contextTokens: 4096)
        XCTAssertFalse(prompt.system.contains("NICHT SICHTBAR"))
    }
    func testGroupSpeakerOrderFollowsSelectedBranch() throws {
        let a = CharacterCard(name: "Mara", firstMessage: "Hallo")
        let b = CharacterCard(name: "Elias")
        var story = Story(characters: [a, b], persona: nil, scenario: nil, greeting: nil)
        XCTAssertTrue(story.isGroup)
        XCTAssertEqual(story.nextSpeakerID, b.id)
        let earlier = story.append(role: .user, content: "Hallo zusammen")
        let last = story.append(role: .assistant, content: "Elias spricht", speakerID: b.id)
        XCTAssertEqual(story.responseOrder(), [a.id])
        XCTAssertEqual(story.responseOrder(allParticipants: true), [a.id, b.id])
        XCTAssertEqual(story.responseOrder(replyingAs: b.id), [b.id])
        try story.rewind(to: earlier)
        XCTAssertEqual(story.nextSpeakerID, b.id)
        try story.edit(last, text: "Elias antwortet anders")
        XCTAssertEqual(story.activeMessages.last?.speakerID, b.id)
    }
    func testGroupPromptIncludesSpeakerPersonaAndCustomScene() {
        let a = CharacterCard(name: "Mara", personality: "Scharfsinnig")
        let b = CharacterCard(name: "Elias", personality: "Gelassen")
        let persona = UserPersona(name: "Reisende", description: "Kartografin aus dem Norden")
        var story = Story(characters: [a, b], persona: persona, scenario: "Eine Sternwarte im Schnee", greeting: nil)
        story.append(role: .user, content: "Wo sind wir?")
        story.append(role: .assistant, content: "In den Bergen.", speakerID: a.id)
        let prompt = PromptBuilder.build(character: b, story: story, preferences: .init(), contextTokens: 8192, participants: [a, b])
        XCTAssertTrue(prompt.system.contains("Reisende"))
        XCTAssertTrue(prompt.system.contains("Kartografin aus dem Norden"))
        XCTAssertTrue(prompt.system.contains("Sternwarte im Schnee"))
        XCTAssertTrue(prompt.system.contains("ausschließlich als Elias"))
        XCTAssertTrue(prompt.messages.contains { $0.content == "Mara: In den Bergen." })
    }
    func testOldBackupsGainNewFeaturesWithoutLosingChats() throws {
        let card = CharacterCard(name: "Mara")
        let original = Archive(characters: [card], stories: [Story(character: card)])
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        for key in ["favoriteIDs", "personas", "scenes", "menuTheme"] { old.removeValue(forKey: key) }
        let decoded = try JSONDecoder().decode(Archive.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertEqual(decoded.stories.count, 1)
        XCTAssertTrue(decoded.personas.isEmpty)
        XCTAssertTrue(decoded.favoriteIDs.isEmpty)
        XCTAssertEqual(decoded.scenes.count, 3)
        XCTAssertEqual(decoded.menuTheme, .dark)
        try decoded.validate()
    }
    func testPersonaIsSnapshotAndEmptyGreetingResetsToEmptyStart() throws {
        let card = CharacterCard(name: "Mara")
        var persona = UserPersona(name: "Reisende", description: "Alte Beschreibung")
        var story = Story(characters: [card], persona: persona, scenario: "Eine Hütte", greeting: "")
        persona.description = "Spätere Beschreibung"
        XCTAssertEqual(story.persona?.description, "Alte Beschreibung")
        story.append(role: .user, content: "Hallo")
        story.append(role: .assistant, content: "Guten Abend", speakerID: card.id)
        XCTAssertNil(story.greetingID)
        try story.rewind(to: story.greetingID)
        XCTAssertTrue(story.activeMessages.isEmpty)
    }
    func testTranslationPreservesTemplateVariablesAndUnicode() {
        let input = "🙂 Hello {{user}}, I am {{char}}.\nKeep {{original}} intact."
        let parts = TemplateText.parts(input)
        XCTAssertEqual(parts.map(\.text).joined(), input)
        XCTAssertEqual(parts.filter(\.isPlaceholder).map(\.text), ["{{user}}", "{{char}}", "{{original}}"])
    }
    func testLongTranslationTextIsChunkedWithoutLosingContent() {
        let input = String(repeating: "Ein längerer Satz mit Unicode 🙂 und Leerzeichen. ", count: 200) + "{{user}}"
        let parts = TemplateText.parts(input)
        XCTAssertEqual(parts.map(\.text).joined(), input)
        XCTAssertTrue(parts.allSatisfy { $0.text.count <= 1600 })
        XCTAssertEqual(parts.last?.text, "{{user}}")
    }
    func testRoleplaySeparatesPrivateThoughtSpeechAndUnquotedContext() {
        let text = #"Ich sehe zum Fenster. *Ich darf ihr "das Geheimnis" nicht verraten.* „Hallo Mara.“ Ich überlege noch."#
        let parts = RoleplayText.parts(text)
        XCTAssertEqual(parts.map(\.text).joined(), text)
        XCTAssertEqual(parts.filter { $0.kind == .speech }.map(\.text), ["„Hallo Mara.“"])
        XCTAssertEqual(parts.filter { $0.kind == .thought }.map(\.text), [#"*Ich darf ihr "das Geheimnis" nicht verraten.*"#])
        XCTAssertTrue(parts.filter { $0.kind == .context }.contains { $0.text.contains("Ich überlege noch") })
        XCTAssertEqual(RoleplayText.parts("Das ist ein Selbstgespräch.").map(\.kind), [.context])
    }
    func testThoughtMarkersOverrideQuotesAndUnclosedThoughtsStayPrivate() {
        let text = #""Hallo *mein "Geheimnis" bleibt privat* Mara.""#
        let parts = RoleplayText.parts(text)
        XCTAssertEqual(parts.map(\.text).joined(), text)
        XCTAssertEqual(parts.filter { $0.kind == .thought }.map(\.text), [#"*mein "Geheimnis" bleibt privat*"#])
        XCTAssertFalse(parts.filter { $0.kind == .speech }.contains { $0.text.contains("Geheimnis") })
        XCTAssertEqual(RoleplayText.parts(#"*Unfertiger Gedanke "auch mit Zitat""#).map(\.kind), [.thought])
        XCTAssertFalse(RoleplayText.parts(#""Nicht abgeschlossen"#).contains { $0.kind == .speech })
        XCTAssertEqual(RoleplayText.parts(#"\*wörtliche Sterne\*"#).map(\.kind), [.context])
        for quoted in [#""Hallo""#, "„Hallo“", "“Hallo”", "«Hallo»", "»Hallo«"] {
            XCTAssertEqual(RoleplayText.parts(quoted).map(\.kind), [.speech])
        }
    }
    func testPromptLabelsThoughtsInCurrentAndOlderMessages() {
        let card = CharacterCard(name: "Mara")
        var story = Story(character: card)
        story.append(role: .user, content: #"*Mein Geheimnis ist der Rubin.* "Guten Tag.""#)
        let prompt = PromptBuilder.build(character: card, story: story, preferences: .init(), contextTokens: 8192)
        XCTAssertTrue(prompt.system.contains("für JEDE Figur unhörbar"))
        XCTAssertTrue(prompt.messages.last?.content.contains("gedanke_privat") == true)
        XCTAssertTrue(prompt.messages.last?.content.contains("laut_gesagt") == true)
        XCTAssertTrue(prompt.messages.last?.content.contains("Rubin") == true, "Narrator must retain plot context without treating it as audible speech")
        story.append(role: .assistant, content: String(repeating: "Die sichtbare Szene geht weiter. ", count: 300))
        story.append(role: .user, content: #""Was weißt du über den Rubin?""#)
        let older = PromptBuilder.build(character: card, story: story, preferences: .init(), contextTokens: 4096)
        XCTAssertTrue(older.system.contains("Ältere Auszüge"))
        XCTAssertTrue(older.system.contains("gedanke_privat"))
    }
    func testEnsembleDetectionDistinguishesCastFromCameos() {
        XCTAssertTrue(CharacterCard(name: "Mara & Elias").cast.isEnsemble)
        XCTAssertEqual(CharacterCard(name: "Mara und Elias").cast.names, ["Mara", "Elias"])
        XCTAssertTrue(CharacterCard(name: "Die Sternwarte", tags: ["multiple_characters"]).cast.isEnsemble)
        XCTAssertTrue(CharacterCard(name: "Reise", description: "Name: Mara\nRuhig.\nName: Elias\nMutig.").cast.isEnsemble)
        XCTAssertTrue(CharacterCard(name: "Freunde", description: "This bot portrays both friends.").cast.isEnsemble)
        XCTAssertTrue(CharacterCard(name: "Freunde", description: "{{char}} consists of two friends.").cast.isEnsemble)
        XCTAssertFalse(CharacterCard(name: "Mara", description: "Mara trifft manchmal ihren Freund Elias.").cast.isEnsemble)
        XCTAssertFalse(CharacterCard(name: "Mara and her secrets").cast.isEnsemble)
        XCTAssertFalse(CharacterCard(name: "Mara", tags: ["female", "romance"]).cast.isEnsemble)
    }
    func testOneEnsembleCardRemainsOneCardWithMultipleVoices() throws {
        let card = CharacterCard(name: "Mara & Elias", description: "Mara ist ruhig. Elias ist mutig.")
        let story = Story(character: card)
        XCTAssertTrue(story.isGroup)
        XCTAssertFalse(story.isMultiCard)
        XCTAssertEqual(story.participantIDs, [card.id])
        XCTAssertEqual(story.responseOrder(allParticipants: true), [card.id])
        let prompt = PromptBuilder.build(character: card, story: story, preferences: .init(), contextTokens: 8192, participants: [card])
        XCTAssertTrue(prompt.system.contains("Mehrpersonen-Karte"))
        XCTAssertTrue(prompt.system.contains("Besetzung: Mara, Elias"))
        XCTAssertTrue(prompt.system.contains("mit klaren Namen"))
        XCTAssertFalse(prompt.system.contains("ausschließlich als Mara & Elias"))
        let restored = try JSONDecoder().decode(Story.self, from: JSONEncoder().encode(story))
        XCTAssertTrue(restored.isGroup)
    }
    func testCastCorrectionAndCardExportRoundTrip() throws {
        var card = CharacterCard(name: "Mara & Elias")
        card.castOverride = .init(isEnsemble: false)
        XCTAssertFalse(card.cast.isEnsemble)
        let decoded = try CardCodec.decode(CardCodec.encode(card))
        XCTAssertFalse(decoded.cast.isEnsemble)
        card.castOverride = .init(isEnsemble: true, names: ["Mara", "Elias"])
        XCTAssertEqual(try CardCodec.decode(CardCodec.encode(card)).cast.names, ["Mara", "Elias"])
        card.castOverride = nil; card.name = "Die Sternwarte"; card.sourceCast = .init(isEnsemble: true, names: ["Mara", "Elias"])
        XCTAssertTrue(card.cast.isEnsemble, "Evidence from source-language tags must survive translation")
    }
    func testDraftsAndMenuThemeSurviveArchiveRoundTripAndBranching() throws {
        let card = CharacterCard(name: "Mara")
        var first = Story(character: card)
        first.draftText = #"*Ein privater Gedanke* "Noch nicht gesendet""#
        var second = Story(character: card); second.draftText = "Ein anderer Entwurf"
        let id = first.append(role: .user, content: "Erzählkontext")
        first.append(role: .assistant, content: "Die Szene")
        try first.rewind(to: id)
        var archive = Archive(characters: [card], stories: [first, second]); archive.menuTheme = .light
        let restored = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(archive))
        XCTAssertEqual(restored.stories[0].draftText, first.draftText)
        XCTAssertEqual(restored.stories[1].draftText, "Ein anderer Entwurf")
        XCTAssertFalse(restored.stories[0].activeMessages.contains { $0.content == first.draftText })
        XCTAssertEqual(restored.menuTheme, .light)
        try restored.validate()
    }
    func testDiscoveryGenresAndCardTypesWorkAcrossSourceLanguages() {
        let english = CharacterCard(name: "Mara", tags: ["Adventure", "Romance", "Sci-Fi"])
        let german = CharacterCard(name: "Mara und Elias", tags: ["Abenteuer", "Romantik", "Science-Fiction"])
        for genre in [CharacterGenre.adventure, .romance, .scienceFiction] {
            XCTAssertTrue(genre.matches(english)); XCTAssertTrue(genre.matches(german))
        }
        XCTAssertFalse(CharacterGenre.horror.matches(german))
        XCTAssertTrue(CharacterKindFilter.ensemble.matches(german))
        XCTAssertFalse(CharacterKindFilter.ensemble.matches(english))
        XCTAssertTrue(CharacterKindFilter.single.matches(english))
        XCTAssertEqual(CharacterGenre.adventure.catalogueTopic, "Adventure")
        XCTAssertNil(CharacterGenre.all.catalogueTopic)
    }
    func testSmallLocalContextsKeepPersonalityAndPerspectiveRules() {
        for name in ["Mara", "Mara & Elias"] {
            let card = CharacterCard(name: name, personality: "MERKMAL_KARTOGRAFIN: freundlich, behutsam und neugierig.")
            var story = Story(character: card); story.append(role: .user, content: #"*Ein Geheimnis* "Hallo.""#)
            let prompt = PromptBuilder.build(character: card, story: story, preferences: .init(), contextTokens: 2048, outputTokens: 400)
            XCTAssertTrue(prompt.system.contains("MERKMAL_KARTOGRAFIN"))
            XCTAssertTrue(prompt.system.contains("für JEDE Figur unhörbar"))
            XCTAssertLessThan(prompt.estimatedTokens, 2048 - 400)
        }
    }
    func testLongBiographiesCannotDisplacePersonalityOrUserAgencyRules() {
        for name in ["Mara", "Mara & Elias"] {
            let card = CharacterCard(name: name,
                description: String(repeating: "Langer Hintergrund ohne Persönlichkeitsmerkmale. ", count: 3000),
                personality: "FIGURENSTIMME: zurückhaltend, trocken humorvoll, misstrauisch.",
                scenario: "Ein nächtliches Büro.", exampleDialogue: "{{user}}: Ich komme mit.\n{{char}}: Warum?")
            var story = Story(character: card)
            for index in 0..<40 { story.append(role: .user, content: "*Ich bin neugierig.* „Frage \(index).“") }
            for context in [2048, 4096, 8192] {
                let prompt = PromptBuilder.build(character: card, story: story, preferences: .init(), contextTokens: context, outputTokens: 400)
                XCTAssertTrue(prompt.system.contains("FIGURENSTIMME"), "Personality must survive biography clipping at \(context)")
                XCTAssertTrue(prompt.system.contains("Keine Rede, Gedanken, Gefühle, Entscheidungen oder Handlungen des Nutzers erfinden"))
                XCTAssertTrue(prompt.system.contains("behalte die eigene Figurenstimme") || !prompt.system.contains("Schreibstil des Nutzers:"))
                XCTAssertLessThan(prompt.estimatedTokens, context - 400)
                XCTAssertEqual(prompt.messages.last?.role, "user")
            }
        }
    }
    func testOmegaverseGenreAliasesAndNormalSearchWords() {
        for text in ["Omegaverse", "Omega-Verse", "Omega Verse", "A/B/O", "a / b / o", "ABO"] {
            XCTAssertTrue(CharacterGenre.omegaverse.matches(.init(name: "Mara", tags: [text])))
            XCTAssertTrue(OmegaverseSearch.containsGenre(text))
            XCTAssertTrue(OmegaverseSearch.containsGenre(OmegaverseSearch.normalized(text)))
        }
        XCTAssertTrue(CharacterGenre.omegaverse.matches(.init(name: "Mara", personality: "An adult character in an Omegaverse world.")))
        XCTAssertFalse(CharacterGenre.omegaverse.matches(.init(name: "Kaboodle", personality: "A space pilot.")))
        XCTAssertEqual(OmegaverseSearch.normalized("Omega-Verse Alpha"), "omegaverse Alpha")
        XCTAssertEqual(OmegaverseSearch.normalized("John"), "John")
    }
    func testJannySearchPreservesPublicMetadataAndNeverInventsDefinitions() throws {
        let id = UUID().uuidString
        let row: [String: Any] = ["id": id, "name": "Mara &amp; Elias", "description": "<p>Adult Omegaverse characters.</p>",
            "tagIds": [26, 50], "avatar": "portrait.png", "isNsfw": true, "personality": "Not a downloadable card definition"]
        let data = try JSONSerialization.data(withJSONObject: ["results": [["hits": [row], "totalHits": 4000, "page": 1, "totalPages": 167]]])
        let page = try JannyCatalogueCodec.decode(data)
        XCTAssertEqual(page.cards.count, 1); XCTAssertEqual(page.total, 4000); XCTAssertTrue(page.hasMore)
        let card = try XCTUnwrap(page.cards.first)
        XCTAssertEqual(card.name, "Mara & Elias"); XCTAssertTrue(card.isAdult); XCTAssertTrue(card.cast.isEnsemble)
        XCTAssertTrue(card.description.isEmpty); XCTAssertTrue(card.personality.isEmpty); XCTAssertTrue(card.firstMessage.isEmpty)
        XCTAssertEqual(CatalogueSource.source(for: card.id), .janny)
        XCTAssertTrue(card.avatarURL?.hasPrefix("https://image.jannyai.com/") == true)
        XCTAssertTrue(CharacterGenre.omegaverse.matches(card))
        XCTAssertEqual(JannyCatalogueCodec.query("A/B/O Alpha", genre: .omegaverse), "omegaverse Alpha")
    }
    func testJannySearchRejectsInvalidIDsAndDoesNotFilterByLanguage() throws {
        let rows: [[String: Any]] = [["id": "../../bad", "name": "Invalid"], ["id": UUID().uuidString, "name": "Анна", "avatar": "../private.png"]]
        let data = try JSONSerialization.data(withJSONObject: ["results": [["hits": rows, "totalHits": 1, "page": 2, "totalPages": 2]]])
        let page = try JannyCatalogueCodec.decode(data)
        XCTAssertEqual(page.cards.map(\.name), ["Анна"]); XCTAssertNil(page.cards.first?.avatarURL); XCTAssertFalse(page.hasMore)
        XCTAssertThrowsError(try JannyCatalogueCodec.decode(Data("{}".utf8)))
        XCTAssertNil(CatalogueSource.source(for: "janny/invalid"))
    }
    func testWordLimitPreservesCompleteWordsAcrossStreamingChunks() {
        var limit = ResponseWordLimiter(maximumWords: 3)
        XCTAssertEqual(limit.append("Ein Ge").text, "Ein Ge")
        XCTAssertFalse(limit.append("dan").reachedLimit)
        XCTAssertFalse(limit.append("ke bleibt").reachedLimit)
        let end = limit.append(" privat und verborgen.")
        XCTAssertTrue(end.reachedLimit); XCTAssertEqual(end.text, "Ein Gedanke bleibt")
        XCTAssertEqual(limit.append(" weitere Wörter").text, end.text)
    }
    func testWordLimitCountsUnicodeAndIgnoresStandalonePunctuation() {
        var limit = ResponseWordLimiter(maximumWords: 2)
        let end = limit.append("„Grüße,“ — *denke* 🙂 später weiter.")
        XCTAssertEqual(end.text, "„Grüße,“ — *denke* 🙂"); XCTAssertTrue(end.reachedLimit)
        var exact = ResponseWordLimiter(maximumWords: 2)
        XCTAssertFalse(exact.append("Ein Satz.").reachedLimit)
    }
    func testWordPreferencesMigrateAndReachTheModelPrompt() throws {
        var preferences = WritingPreferences(); preferences.responseWords = 400
        XCTAssertEqual(preferences.maximumResponseWords, 400)
        XCTAssertEqual(preferences.requestedOutputTokens, 1200)
        let prompt = PromptBuilder.build(character: .init(name: "Mara"), story: Story(character: .init(name: "Mara")), preferences: preferences, contextTokens: 8192)
        XCTAssertTrue(prompt.system.contains("Höchstens 400 Wörter"))
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as? [String: Any])
        legacy.removeValue(forKey: "responseWords")
        let restored = try JSONDecoder().decode(WritingPreferences.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(restored.maximumResponseWords, 266)
        preferences.responseWords = 100_000; XCTAssertEqual(preferences.maximumResponseWords, 2000)
        preferences.responseWords = nil; preferences.responseLength = Int.max; XCTAssertEqual(preferences.maximumResponseWords, 2000)
    }
    func testChatGPTPlanPayloadOmitsUnsupportedFieldsAndKeepsHistory() throws {
        let card = CharacterCard(name: "Mara")
        var story = Story(character: card); story.append(role: .user, content: "„Hallo.“")
        let prompt = PromptBuilder.build(character: card, story: story, preferences: .init(), contextTokens: 8192)
        let data = try InferencePayload.encode(kind: .chatGPT, model: "account-model", prompt: prompt, maxTokens: 1200)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(body["store"] as? Bool, false); XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertEqual(body["instructions"] as? String, prompt.system)
        XCTAssertEqual((body["input"] as? [[String: String]])?.last?["role"], "user")
        for key in ["max_output_tokens", "max_tokens", "temperature", "previous_response_id", "conversation", "background", "metadata"] { XCTAssertNil(body[key], key) }
        let compatible = try InferencePayload.encode(kind: .compatible, model: "api-model", prompt: prompt, maxTokens: 1200)
        let apiBody = try XCTUnwrap(JSONSerialization.jsonObject(with: compatible) as? [String: Any])
        XCTAssertEqual(apiBody["max_tokens"] as? Int, 1200)
        XCTAssertEqual((apiBody["messages"] as? [[String: String]])?.first?["role"], "system")
    }
}
