import XCTest
@testable import FadenCore

final class CardStructuredTextTests: XCTestCase {
    func testNestedPropertiesBecomeReadableLabelsAndListsWithoutSyntax() throws {
        let source = #"[{"name":"Mara","age":0,"active":false,"personality":{"traits":["ruhig","wachsam"]}}]"#
        let parsed = try XCTUnwrap(CardStructuredText.parse(source))
        XCTAssertTrue(parsed.rows.contains { $0.title == "Alter" && $0.text == "0" })
        XCTAssertTrue(parsed.rows.contains { $0.title == "active" && $0.text == "Nein" })
        XCTAssertTrue(parsed.rows.contains { $0.title == "Eigenschaften" && $0.text.contains("• ruhig") })
        XCTAssertFalse(parsed.plainText.contains("{\""))
        XCTAssertFalse(parsed.plainText.contains("[\""))
    }
    func testNarrativeAndExecutableCodeAreNeverMistakenForData() {
        for text in ["[Sie schaut (kurz) zum Fenster.]", "Ich sage: {vielleicht später}.", "{onLoad: run(), next: execute()}", "[Name(\"Mara\") Ich gehe hinaus. Age(28)]"] {
            XCTAssertNil(CardStructuredText.parse(text))
        }
    }
    func testWppPropertiesRetainDuplicateValuesAndQuotedLists() throws {
        let source = #"[Character("Mara"){Age("28")Personality("calm" + "observant")Likes("tea")Likes("books")}]"#
        let parsed = try XCTUnwrap(CardStructuredText.parse(source))
        XCTAssertTrue(parsed.plainText.contains("Mara"))
        XCTAssertTrue(parsed.plainText.contains("tea"))
        XCTAssertTrue(parsed.plainText.contains("books"))
        XCTAssertTrue(parsed.rows.contains { $0.title == "Persönlichkeit" && $0.text.contains("• calm") })
    }
    func testTranslatingStructuredValuesPreservesNamesKeysTypesAndPlaceholders() throws {
        let source = #"{"name":"Mara","age":28,"active":false,"personality":["calm","observant"],"greeting":"Hello {{user}}."}"#
        let plan = CardTranslationBatch(fields: ["description": source])
        XCTAssertFalse(plan.requests.contains { $0.text.contains("{{user}}") || $0.text.contains("Mara") || $0.text == "28" })
        let results = Dictionary(uniqueKeysWithValues: plan.requests.map { ($0.id, $0.text.replacingOccurrences(of: "calm", with: "ruhig").replacingOccurrences(of: "observant", with: "wachsam").replacingOccurrences(of: "Hello", with: "Hallo")) })
        let restored = try XCTUnwrap(try plan.restore(results)["description"])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(restored.utf8)) as? [String: Any])
        XCTAssertEqual(object["name"] as? String, "Mara")
        XCTAssertEqual(object["age"] as? Int, 28)
        XCTAssertEqual(object["active"] as? Bool, false)
        XCTAssertEqual(object["personality"] as? [String], ["ruhig", "wachsam"])
        XCTAssertEqual(object["greeting"] as? String, "Hallo {{user}}.")
    }
    func testPropertyPathsDoNotCollideWhenKeysContainSlashesOrTildes() throws {
        let parsed = try XCTUnwrap(CardStructuredText.parse(#"{"a/b":"first","a":{"b":"second"},"~":"third"}"#))
        XCTAssertEqual(parsed.translationFields.count, 3)
        XCTAssertEqual(Set(parsed.translationFields.values), ["first", "second", "third"])
    }
    func testMixedWritingSystemsAndLineEndingsRestoreExactly() throws {
        let source = "Hello {{user}}.\r\n안녕하세요. English again.\nTo jest polskie zdanie."
        let plan = CardTranslationBatch(fields: ["body": source])
        XCTAssertTrue(plan.requests.contains { $0.text.contains("안녕하세요") && !$0.text.contains("English") })
        let unchanged = Dictionary(uniqueKeysWithValues: plan.requests.map { ($0.id, $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) })
        XCTAssertEqual(try plan.restore(unchanged)["body"], source)
    }
    func testExcessiveStructureFallsBackInsteadOfDroppingInformation() {
        XCTAssertNil(CardStructuredText.parse(String(repeating: " ", count: 256 * 1024 + 1) + "{}"))
        let deep = String(repeating: "{\"inner\":", count: 14) + "\"value\"" + String(repeating: "}", count: 14)
        XCTAssertNil(CardStructuredText.parse(deep))
    }
    func testSmallLocalContextExtractsPersonalityHiddenInAPropertyObject() {
        let description = "{\"name\":\"Mara\",\"background\":\"" + String(repeating: "An old archive. ", count: 500) + "\",\"personality\":\"MERKMAL_LEISE Stimme und bedachte Antworten.\"}"
        let card = CharacterCard(name: "Mara", description: description)
        var story = Story(character: card)
        story.append(role: .assistant, content: "LETZTE_FIGURENANTWORT " + String(repeating: "Mara wartet. ", count: 200))
        story.append(role: .user, content: "LETZTE_NUTZERNACHRICHT " + String(repeating: "Ich gehe weiter. ", count: 200))
        let prompt = PromptBuilder.build(character: card, story: story, preferences: .init(), contextTokens: 2048, outputTokens: 400)
        XCTAssertTrue(prompt.system.contains("MERKMAL_LEISE"))
        XCTAssertTrue(prompt.messages.contains { $0.role == "assistant" && $0.content.contains("LETZTE_FIGURENANTWORT") })
        XCTAssertTrue(prompt.messages.contains { $0.role == "user" && $0.content.contains("LETZTE_NUTZERNACHRICHT") })
    }
    #if canImport(Darwin)
    func testAppleJSON5ReadsSingleQuotesAndUnquotedKeysAsData() throws {
        let parsed = try XCTUnwrap(CardStructuredText.parse("[{name:'Mara', age:28, personality:['calm',],},]"))
        XCTAssertTrue(parsed.plainText.contains("Mara"))
        XCTAssertTrue(parsed.plainText.contains("calm"))
    }
    #endif
}
