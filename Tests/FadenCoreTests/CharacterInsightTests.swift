import XCTest
@testable import FadenCore

final class CharacterInsightTests: XCTestCase {
    func testScheduleIsStableSpacedAndCountsOnlyFinishedReplies() {
        var story = Story(character: .init(name: "Mara", firstMessage: "Hallo"))
        let gap = InsightSchedule.spacing(frequency: .every10, previous: story.id)!
        XCTAssertTrue((8...12).contains(gap))
        XCTAssertEqual(InsightSchedule.spacing(frequency: .every10, previous: story.id), gap)
        XCTAssertTrue((18...22).contains(InsightSchedule.spacing(frequency: .every20, previous: story.id)!))
        for _ in 0..<gap - 1 { story.append(role: .assistant, content: "Ein Dialogbeitrag.") }
        XCTAssertFalse(InsightSchedule.isDue(story: story, frequency: .every10))
        story.append(role: .user, content: "Ein Nutzerbeitrag.")
        story.append(role: .assistant, content: "", interrupted: true)
        XCTAssertFalse(InsightSchedule.isDue(story: story, frequency: .every10))
        let anchor = story.append(role: .assistant, content: "Ein abgeschlossener Beitrag.")
        XCTAssertTrue(InsightSchedule.isDue(story: story, frequency: .every10))
        XCTAssertFalse(InsightSchedule.isDue(story: story, frequency: .off))
        story.insightAttemptIDs = [anchor] // Also spaces out skipped/cancelled optional requests.
        XCTAssertFalse(InsightSchedule.isDue(story: story, frequency: .every10))
        story.append(role: .assistant, content: "Der nächste Dialogbeitrag.")
        XCTAssertFalse(InsightSchedule.isDue(story: story, frequency: .every10))
    }

    func testInsightsArePrivateBranchDataNotDialogueOrOtherCharactersKnowledge() throws {
        let mara = CharacterCard(name: "Mara", personality: "Eine vorsichtige Detektivin.")
        let elias = CharacterCard(name: "Elias", personality: "Ein ruhiger Zugbegleiter.")
        var story = Story(characters: [mara, elias], persona: nil, scenario: nil, greeting: nil)
        let earlier = story.append(role: .user, content: "„Guten Abend.“")
        let future = story.append(role: .assistant, content: "„Guten Abend.“", speakerID: mara.id)
        story.insightAttemptIDs = [future]
        story.insights = [.init(sourceMessageID: future, characterID: mara.id, kind: .memory, text: "PRIVATER_FIGURENHINTERGRUND: Ein alter Schlüssel erinnert sie an ihre erste Wohnung.")]
        let own = PromptBuilder.build(character: mara, story: story, preferences: .init(), contextTokens: 8192, participants: [mara, elias])
        XCTAssertTrue(own.system.contains("PRIVATER_FIGURENHINTERGRUND"))
        XCTAssertFalse(own.messages.contains { $0.content.contains("PRIVATER_FIGURENHINTERGRUND") })
        XCTAssertFalse(PromptBuilder.build(character: elias, story: story, preferences: .init(), contextTokens: 8192, participants: [mara, elias]).system.contains("PRIVATER_FIGURENHINTERGRUND"))
        try story.rewind(to: earlier)
        XCTAssertTrue(story.activeInsights.isEmpty)
        XCTAssertFalse(PromptBuilder.build(character: mara, story: story, preferences: .init(), contextTokens: 8192).system.contains("PRIVATER_FIGURENHINTERGRUND"))
        try story.rewind(to: future)
        XCTAssertEqual(story.activeInsights.count, 1)
        XCTAssertEqual(story.activeMessages.count, 2, "An aside must never become a dialogue turn")
        let archive = Archive(characters: [mara, elias], stories: [story])
        let restored = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(archive))
        try restored.validate()
        XCTAssertEqual(restored.stories.first?.activeInsights.first?.text, story.insights?.first?.text)
    }

    func testOlderBackupsMigrateAndDisabledInsightsPersist() throws {
        let card = CharacterCard(name: "Mara")
        var archive = Archive(characters: [card], stories: [Story(character: card)])
        var value = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(archive)) as? [String: Any])
        var prefs = try XCTUnwrap(value["preferences"] as? [String: Any]); prefs.removeValue(forKey: "insightFrequency"); value["preferences"] = prefs
        let legacy = try JSONDecoder().decode(Archive.self, from: JSONSerialization.data(withJSONObject: value))
        XCTAssertEqual(legacy.preferences.effectiveInsightFrequency, .every20)
        XCTAssertTrue(legacy.stories[0].activeInsights.isEmpty)
        archive.preferences.insightFrequency = .off
        let restored = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(archive))
        XCTAssertEqual(restored.preferences.effectiveInsightFrequency, .off)
    }

    func testBackupRejectsOrphanedInsightsUserAnchorsAndOtherCharacters() throws {
        let card = CharacterCard(name: "Mara")
        var story = Story(character: card)
        let user = story.append(role: .user, content: "Hallo")
        let reply = story.append(role: .assistant, content: "Hallo zurück")
        for anchor in [UUID(), user] {
            story.insights = [.init(sourceMessageID: anchor, characterID: card.id, kind: .thought, text: "Ein privater Gedanke.")]
            XCTAssertThrowsError(try Archive(characters: [card], stories: [story]).validate())
        }
        story.insights = [.init(sourceMessageID: reply, characterID: "missing-character", kind: .thought, text: "Gedanke")]
        XCTAssertThrowsError(try Archive(characters: [card], stories: [story]).validate())
        story.insights = nil; story.insightAttemptIDs = [UUID()]
        XCTAssertThrowsError(try Archive(characters: [card], stories: [story]).validate())
    }

    func testInsightPromptKeepsPersonalityWithinBudgetWithoutContinuingScene() {
        let card = CharacterCard(name: "Mara & Elias", description: String(repeating: "Lange Biografie. ", count: 4000), personality: "FIGURENSTIMME: ruhig und trocken humorvoll.")
        let story = Story(character: card)
        for context in [2048, 4096, 8192] {
            for kind in [CharacterInsightKind.thought, .memory] {
                let prompt = InsightPromptBuilder.build(character: card, story: story, kind: kind, contextTokens: context)
                XCTAssertTrue(prompt.system.contains("FIGURENSTIMME"))
                XCTAssertTrue(prompt.system.contains("keine Fortsetzung der aktuellen Szene"))
                XCTAssertTrue(prompt.system.contains("privates Leserwissen"))
                XCTAssertTrue(prompt.system.contains("höchstens 80 Wörter"))
                XCTAssertLessThan(prompt.estimatedTokens, context - 320)
            }
        }
    }

    func testPriorityAndDisabledAccountsSurviveBackup() throws {
        XCTAssertEqual(Connection.initial.first?.kind, .openRouter)
        XCTAssertEqual(Connection.initial.last?.kind, .chatGPT)
        XCTAssertEqual(Connection.initial.last?.enabled, false)
        var chatGPT = Connection(name: "Arbeit", kind: .chatGPT, models: ["test-model"], enabled: false)
        let free = Connection(name: "Kostenlos", kind: .openRouter, models: ["openrouter/free"])
        let local = Connection(name: "Lokal", kind: .local, models: ["local-model"])
        var archive = Archive(connections: [free, local, chatGPT])
        archive.connections.swapAt(0, 2)
        let restored = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(archive))
        XCTAssertEqual(restored.connections.map(\.id), [chatGPT.id, local.id, free.id])
        XCTAssertEqual(restored.connections.flatMap { $0.permittedModels(freeOnly: true) }, ["local-model", "openrouter/free"])
        chatGPT.enabled = true
        XCTAssertEqual(chatGPT.permittedModels(freeOnly: true), ["test-model"])
    }
}
