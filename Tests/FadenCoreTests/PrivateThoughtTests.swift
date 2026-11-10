import XCTest
@testable import FadenCore

final class PrivateThoughtTests: XCTestCase {
    private let secret = "VERBORGENER_INHALT_918372"
    func testPrivateContentCannotReachPromptMemoryStyleLoreOrOldExcerpts() {
        var card = CharacterCard(name: "Mara", personality: "Ruhig und aufmerksam.")
        card.lore = [.init(keys: [secret.lowercased()], content: "LORE_NUR_DURCH_GEDANKE_AKTIVIERT")]
        var story = Story(character: card)
        let original = story.append(role: .user, content: "Ich gehe über die Straße. *\(secret)* \"Ach hallo.\"")
        story.memories.append(.init(text: secret, sourceMessageID: original))
        for _ in 0..<12 {
            story.append(role: .assistant, content: String(repeating: "Mara wartet am Fenster. ", count: 60))
            story.append(role: .user, content: "*\(secret)* \"Guten Tag.\"")
        }
        for context in [2048, 4096, 8192] {
            let prompt = PromptBuilder.build(character: card, story: story, preferences: .init(), contextTokens: context)
            let sent = prompt.system + prompt.messages.map(\.content).joined()
            XCTAssertFalse(sent.contains(secret))
            XCTAssertFalse(sent.contains("LORE_NUR_DURCH_GEDANKE_AKTIVIERT"))
            XCTAssertTrue(sent.contains("laut_gesagt"))
        }
        XCTAssertTrue(story.activeMessages.contains { $0.content.contains(secret) })
        XCTAssertTrue(StyleProfile(story: story).examples.allSatisfy { !$0.contains(secret) })
    }
    func testPrivateTextOverridesNestedQuotesAndUnfinishedThoughts() {
        for text in ["*\(secret)* \"Hallo\"", "\"Hallo *\(secret)* Mara\"", "**\(secret)**", "*\(secret) ohne Ende"] {
            XCTAssertFalse(RoleplayText.promptContent(text).contains(secret))
            XCTAssertFalse(RoleplayText.visibleText(text).contains(secret))
        }
        XCTAssertTrue(RoleplayText.promptContent("*\(secret)*").contains("keine neue wahrnehmbare"))
    }
    func testWeatherThoughtIsNotAvailableToTheCharacterButSpeechAndActionAre() {
        let text = #"Ich gehe über die Straße. *Was für ein Scheißwetter.* "Ach hallo.""#
        let prompt = RoleplayText.promptContent(text)
        XCTAssertFalse(prompt.contains("Scheißwetter"))
        XCTAssertTrue(prompt.contains("Straße"))
        XCTAssertTrue(prompt.contains("Ach hallo"))
        XCTAssertTrue(prompt.contains("erzaehlkontext_nicht_gesprochen"))
    }
    func testTypingMistakesArePreservedButTheCharacterIsToldNotToComment() {
        let card = CharacterCard(name: "Mara", personality: "Ruhig und aufmerksam.")
        var story = Story(character: card)
        story.append(role: .user, content: #""Hlo wie getz?""#)
        let prompt = PromptBuilder.build(character: card, story: story, preferences: .init(), contextTokens: 4096)
        XCTAssertTrue(prompt.system.contains("Tippfehler sinngemäß verstehen und niemals kommentieren oder korrigieren"))
        XCTAssertTrue(prompt.messages.last?.content.contains("Hlo wie getz?") == true)
        XCTAssertEqual(story.activeMessages.last?.content, #""Hlo wie getz?""#)
    }
}
