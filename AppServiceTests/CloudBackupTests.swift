import FadenCore
import Foundation
import XCTest
@testable import Faden

final class CloudBackupTests: XCTestCase {
    func testEncryptedBackupRoundTripIncludesConversationAndOptionalCredentials() throws {
        let password = "Testpasswort 1234!"
        let salt = CloudBackupFormat.makeSalt()
        let key = try CloudBackupFormat.deriveKey(password: password, salt: salt)
        let card = CharacterCard(name: "Mara", description: "Archivarin")
        var story = Story(character: card)
        story.append(role: .user, content: "ARCHIV_TEST_PRIVAT")
        let provider = Connection(name: "Test", kind: .openRouter, baseURL: "https://openrouter.ai/api/v1")
        let payload = CloudBackupPayload(
            archive: Archive(characters: [card], stories: [story], connections: [provider]),
            apiKeys: [provider.id: "TEST_API_KEY_NOT_REAL"]
        )

        let encrypted = try CloudBackupFormat.seal(payload, key: key, salt: salt)
        let second = try CloudBackupFormat.seal(payload, key: key, salt: salt)
        XCTAssertNotEqual(encrypted, second)
        XCTAssertNil(encrypted.range(of: Data("ARCHIV_TEST_PRIVAT".utf8)))
        XCTAssertNil(encrypted.range(of: Data("TEST_API_KEY_NOT_REAL".utf8)))

        let restored = try CloudBackupFormat.open(encrypted, password: password)
        XCTAssertEqual(restored.archive.stories.first?.messages.first?.content, "ARCHIV_TEST_PRIVAT")
        XCTAssertEqual(restored.apiKeys, payload.apiKeys)
        XCTAssertThrowsError(try CloudBackupFormat.open(encrypted, password: "Falsches Testpasswort"))
        var damaged = encrypted
        damaged[damaged.count - 1] ^= 1
        XCTAssertThrowsError(try CloudBackupFormat.open(damaged, password: password))
    }

    @MainActor
    func testRestorePreservesExistingChatsAndKeysAndAddsNewOnes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = AppStore(storageDirectory: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let current = Connection(name: "Bestehende Verbindung", kind: .openRouter, baseURL: "https://openrouter.ai/api/v1")
        let imported = Connection(name: "Zweite Verbindung", kind: .openRouter, baseURL: "https://openrouter.ai/api/v1")
        let conflicting = Connection(name: "Eigene URL", kind: .compatible, baseURL: "https://current.example/v1")
        var archivedEndpoint = conflicting
        archivedEndpoint.baseURL = "https://backup.example/v1"
        var keys = [current.id: "existing-synthetic-key"]

        let card = CharacterCard(name: "Mara", description: "Archivarin")
        var currentStory = Story(character: card)
        currentStory.append(role: .user, content: "Aktueller Chat")
        var archivedStory = currentStory
        archivedStory.append(role: .assistant, content: "Alte Version")
        var freshStory = Story(character: card)
        freshStory.append(role: .user, content: "Historischer Chat")

        store.archive = Archive(characters: [card], stories: [currentStory], connections: [current, conflicting])
        let payload = CloudBackupPayload(
            archive: Archive(characters: [card], stories: [archivedStory, freshStory], connections: [current, imported, archivedEndpoint], freeOnly: false),
            apiKeys: [current.id: "old-synthetic-key", imported.id: "restored-synthetic-key", conflicting.id: "other-endpoint-key"]
        )
        _ = try store.restoreCloudBackup(payload, readKey: { keys[$0] ?? "" }, saveKey: { keys[$0] = $1 })

        XCTAssertEqual(store.story(currentStory.id)?.activeMessages.map(\.content), ["Aktueller Chat"])
        XCTAssertEqual(store.story(freshStory.id)?.activeMessages.map(\.content), ["Historischer Chat"])
        XCTAssertEqual(keys[current.id], "existing-synthetic-key")
        XCTAssertEqual(keys[imported.id], "restored-synthetic-key")
        XCTAssertNil(keys[conflicting.id])
        XCTAssertTrue(store.archive.freeOnly)
        XCTAssertEqual(AppStore(storageDirectory: root).archive.stories.count, 2)
    }
}
