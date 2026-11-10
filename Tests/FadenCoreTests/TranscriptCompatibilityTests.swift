import XCTest
@testable import FadenCore

final class TranscriptCompatibilityTests: XCTestCase {
    func testSecondTurnKeepsTheOpeningAndBothUserTurnsInPortableOrder() throws {
        let prompt = BuiltPrompt(system: "Mara bleibt ruhig.", messages: [
            .init(role: "assistant", content: "GESCHRIEBENE_BEGRUESSUNG"),
            .init(role: "user", content: "ERSTE_NUTZERNACHRICHT"),
            .init(role: "assistant", content: "ERSTE_ECHTE_ANTWORT"),
            .init(role: "user", content: "ZWEITE_NUTZERNACHRICHT")
        ], retrievedCount: 0, truncated: false)
        let normalized = prompt.chatCompatible
        XCTAssertTrue(normalized.system.contains("GESCHRIEBENE_BEGRUESSUNG"))
        XCTAssertEqual(normalized.messages.map(\.role), ["user", "assistant", "user"])
        XCTAssertTrue(normalized.messages[1].content.contains("ERSTE_ECHTE_ANTWORT"))
        XCTAssertTrue(normalized.messages[2].content.contains("ZWEITE_NUTZERNACHRICHT"))
        for kind in [ProviderKind.openRouter, .openAI, .chatGPT, .anthropic] {
            let data = try InferencePayload.encode(kind: kind, model: "synthetic", prompt: prompt, maxTokens: 64)
            let json = try XCTUnwrap(String(data: data, encoding: .utf8))
            for marker in ["GESCHRIEBENE_BEGRUESSUNG", "ERSTE_NUTZERNACHRICHT", "ERSTE_ECHTE_ANTWORT", "ZWEITE_NUTZERNACHRICHT"] {
                XCTAssertEqual(json.components(separatedBy: marker).count - 1, 1, "Every written contribution must occur once for \(kind)")
            }
        }
    }
    func testConsecutiveGroupRepliesRetainTheirSpeakersAndDoNotInventAUser() {
        let prompt = BuiltPrompt(system: "Deutsch", messages: [
            .init(role: "user", content: "Hallo."), .init(role: "assistant", content: "Mara: Guten Abend."),
            .init(role: "assistant", content: "Elias: Willkommen."), .init(role: "user", content: "Danke.")
        ], retrievedCount: 0, truncated: false).chatCompatible
        XCTAssertEqual(prompt.messages.map(\.role), ["user", "assistant", "user"])
        XCTAssertTrue(prompt.messages[1].content.contains("Mara:"))
        XCTAssertTrue(prompt.messages[1].content.contains("Elias:"))
    }
    func testContinuationIsIdempotentAndKeepsExistingAssistantText() {
        let first = BuiltPrompt(system: "Deutsch", messages: [.init(role: "assistant", content: "Mara wartet.")], retrievedCount: 0, truncated: false).chatCompatible
        let second = first.chatCompatible
        XCTAssertEqual(first.system, second.system)
        XCTAssertEqual(first.messages, second.messages)
        XCTAssertTrue(first.system.contains("Mara wartet."))
        XCTAssertEqual(first.messages.last?.role, "user")
    }
}
