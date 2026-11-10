import XCTest
@testable import FadenCore

final class CharacterVoiceTests: XCTestCase {
    func testAntagonistTraitsRemainAnchoredDespiteFriendlyUserStyleAndLongHistory() {
        let traits = "STIMME_VAREK: kalt, herrisch und spöttisch; vertraut Fremden nicht."
        let card = CharacterCard(name: "Varek", description: String(repeating: "Eine lange Biografie. ", count: 2000), personality: traits)
        var story = Story(character: card)
        for i in 0..<30 {
            story.append(role: .user, content: "„Danke, das ist lieb von dir! Frage \(i).“")
            story.append(role: .assistant, content: "Er verschränkt die Arme. „Was willst du?“")
        }
        story.append(role: .user, content: "„Ich warte auf deine Antwort.“")
        for context in [2048, 4096, 8192] {
            let prompt = PromptBuilder.build(character: card, story: story, preferences: .init(), contextTokens: context, outputTokens: 400)
            let tail = String(prompt.system.suffix(1100))
            XCTAssertTrue(tail.contains("STIMME_VAREK"))
            XCTAssertTrue(tail.contains("Annäherung und Wandel brauchen Ereignisse"))
            XCTAssertTrue(tail.contains("Nutzerstil bestimmt nur Format und Tempo"))
            XCTAssertTrue(tail.contains("Keine Rede, Gedanken, Gefühle, Entscheidungen oder Handlungen des Nutzers erfinden"))
            XCTAssertLessThan(prompt.estimatedTokens, context - 400)
            XCTAssertEqual(prompt.chatCompatible.messages.last?.role, "user")
            XCTAssertTrue(prompt.chatCompatible.system.contains(traits))
        }
    }
    func testWarmPersonalityRetainsItsOwnAnchor() {
        let card = CharacterCard(name: "Mara", personality: "Warmherzig und geduldig.")
        let prompt = PromptBuilder.build(character: card, story: Story(character: card), preferences: .init(), contextTokens: 4096)
        XCTAssertTrue(prompt.system.hasSuffix("Figurenkern für diese Antwort: Warmherzig und geduldig."))
    }
}
