import XCTest
@testable import FadenCore

final class ProviderRequestProblemTests: XCTestCase {
    func testRequestErrorsExplainRolesAndContextInsteadOfOnlyUnsupported() {
        let cases = [("Messages must alternate user and assistant", "Reihenfolge"),
                     ("maximum context length exceeded", "Kontextfenster"),
                     ("reasoning signature missing", "Verlaufsdaten"),
                     ("No endpoints found that match your data policy", "Datenschutzeinstellungen")]
        for (message, expected) in cases {
            let data = try! JSONSerialization.data(withJSONObject: ["error": ["message": message]])
            XCTAssertTrue(ProviderRequestProblem.describe(data).contains(expected))
        }
    }
    func testNestedProviderErrorCanBeClassifiedWithoutEchoingItsText() throws {
        let data = try JSONSerialization.data(withJSONObject: ["error": ["message": "Provider returned error", "metadata": ["raw": "Messages must start with user. PRIVATE_STORY_ECHO"]]])
        let message = ProviderRequestProblem.describe(data)
        XCTAssertTrue(message.contains("Reihenfolge"))
        XCTAssertFalse(message.contains("PRIVATE_STORY_ECHO"))
    }
    func testUnknownErrorsNeverIncludeCredentialsOrSubmittedContent() throws {
        let data = try JSONSerialization.data(withJSONObject: ["error": ["message": "UNTRUSTED_PRIVATE_PROMPT api-key-test-123"]])
        let message = ProviderRequestProblem.describe(data)
        XCTAssertFalse(message.contains("UNTRUSTED_PRIVATE_PROMPT"))
        XCTAssertFalse(message.contains("api-key-test-123"))
    }
}
