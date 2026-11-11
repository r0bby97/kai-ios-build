import XCTest
@testable import FadenCore

final class CardMarkupTests: XCTestCase {
    func testKoreanLayoutBecomesTextAndNeverIncludesCode() {
        let source = #"<style>.box { color:red }</style><div class="box"><h2>성격</h2><p>차분함 &amp; 친절함</p><ul><li>정직함</li><li>호기심</li></ul><script>alert('x')</script></div>"#
        let clean = CardMarkup.clean(source)
        XCTAssertTrue(clean.contains("성격")); XCTAssertTrue(clean.contains("차분함 & 친절함"))
        XCTAssertTrue(clean.contains("• 정직함")); XCTAssertTrue(clean.contains("• 호기심"))
        XCTAssertFalse(clean.contains("<")); XCTAssertFalse(clean.contains("color:red")); XCTAssertFalse(clean.contains("alert"))
    }
    func testQuotedAttributeMayContainAnAngleBracket() {
        XCTAssertEqual(CardMarkup.clean("<span title=\"a > b\">Hallo</span>"), "Hallo")
    }
    func testPlainNarrativeTemplatesAndComparisonsRemainUnchanged() {
        for text in [" 42 ", "\n…🙂\n", "{{char}} meets {{user}}.", "<START>\n2 < 3 and 4 > 1", "<think>fiction</think>"] {
            XCTAssertEqual(CardMarkup.clean(text), text)
        }
    }
    func testEncodedTagsAndNumericUnicodeAreDecoded() {
        XCTAssertEqual(CardMarkup.clean("&lt;p&gt;&#xC548;&#45397; &quot;Hallo&quot;&lt;/p&gt;"), "안녕 \"Hallo\"")
    }
    func testNestedCardDataRetainsKeysAndNumbers() throws {
        let result = CardMarkup.clean(#"{"name":"Mara","age":28,"traits":["<b>ruhig</b>","<div>wachsam</div>"]}"#)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any])
        XCTAssertEqual(object["age"] as? Int, 28)
        XCTAssertEqual(object["traits"] as? [String], ["ruhig", "wachsam"])
    }
    func testAppleRequestsContainWordsInsteadOfCSSOrHTML() throws {
        let batch = CardTranslationBatch(fields: ["description":"<style>css:never</style><p>Hello {{user}}</p><p>안녕하세요</p>"])
        XCTAssertFalse(batch.requests.contains { $0.text.contains("<") || $0.text.contains("css:never") })
        let restored = try batch.restore(Dictionary(uniqueKeysWithValues: batch.requests.map { ($0.id,$0.text) }))
        XCTAssertTrue(restored["description"]?.contains("{{user}}") == true)
    }
}
