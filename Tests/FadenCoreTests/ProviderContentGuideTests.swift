import XCTest
@testable import FadenCore

final class ProviderContentGuideTests: XCTestCase {
    func testExistingAccountsAreNotMarkedAsExplicitRoleplayProviders() {
        for preset in [APIProviderPreset.openAI, .claude, .gemini, .deepSeek] {
            let guide = preset.connection().contentGuide
            XCTAssertEqual(guide.erotic, .limited)
            XCTAssertNotNil(guide.source)
        }
        XCTAssertEqual(Connection.horde.contentGuide.erotic, .wide)
        XCTAssertEqual(Connection.horde.contentGuide.violence, .wide)
        XCTAssertEqual(Connection(name: "Lokal", kind: .local).contentGuide.erotic, .modelDependent)
        XCTAssertEqual(Connection(name: "Unbekannt", kind: .compatible).contentGuide.erotic, .unverified)
        XCTAssertEqual(Connection(name: "Free Router", kind: .openRouter).contentGuide.erotic, .modelDependent)
    }
    func testModelDependentProviderDoesNotGiveEveryModelTheSameFreedom() {
        var horde = Connection.horde; horde.models = ["unreviewed-model"]
        XCTAssertEqual(horde.contentGuide.erotic, .modelDependent)
        var nano = APIProviderPreset.nanoGPT.connection()
        nano.models = ["z-ai/glm-5.3-flash-uncensored"]
        XCTAssertEqual(nano.contentGuide.erotic, .wide)
        nano.models.append("claude-model")
        XCTAssertEqual(nano.contentGuide.erotic, .modelDependent)
        nano.models = ["invented-uncensored"]
        XCTAssertEqual(nano.contentGuide.erotic, .modelDependent)
        nano.baseURL = "https://other.example/v1"
        XCTAssertEqual(nano.contentGuide.erotic, .unverified)
    }
    func testFreeOnlyUsesExplicitArliTestConfirmationAndExcludesMeteredBackups() {
        var arli = APIProviderPreset.arli.connection(); arli.enabled = true; arli.models = ["a-roleplay-model"]
        XCTAssertEqual(arli.permittedModels(freeOnly: true), arli.models)
        arli.freeTierConfirmed = false
        XCTAssertTrue(arli.permittedModels(freeOnly: true).isEmpty)
        arli.freeTierConfirmed = true; arli.baseURL = "https://other.example/v1"
        XCTAssertTrue(arli.permittedModels(freeOnly: true).isEmpty)
        for preset in [APIProviderPreset.nanoGPT, .venice] {
            var connection = preset.connection(); connection.models = ["model"]; connection.enabled = true
            XCTAssertTrue(connection.permittedModels(freeOnly: true).isEmpty)
            XCTAssertEqual(connection.permittedModels(freeOnly: false), ["model"])
        }
        XCTAssertFalse(Connection.horde.requiresAPIKey)
        XCTAssertEqual(Connection.horde.permittedModels(freeOnly: true), [HordeCodec.automaticModel])
    }
    func testLegacyMigrationPreservesPriorityAndDoesNotRestoreRemovedHorde() throws {
        let connections = [Connection(name: "Arbeit", kind: .chatGPT, enabled: false), Connection(name: "Eigene", kind: .compatible)]
        var old = Archive(connections: connections); old.providerSetupVersion = nil
        var restored = try JSONDecoder().decode(Archive.self, from: JSONEncoder().encode(old))
        restored.introduceRoleplayProviders()
        XCTAssertEqual(Array(restored.connections.prefix(2)), connections)
        XCTAssertEqual(restored.connections.last?.kind, .aiHorde)
        restored.connections.removeAll { $0.kind == .aiHorde }; restored.introduceRoleplayProviders()
        XCTAssertEqual(restored.connections, connections)
    }
    func testHordeAliasCanReuseActualModelForAnInsightWithoutEscalation() {
        var connection = Connection.horde
        XCTAssertTrue(connection.permitsReuse(of: "koboldcpp/mini-magnum-12b-v1.1", freeOnly: true))
        XCTAssertFalse(connection.permitsReuse(of: "unrelated-model", freeOnly: true))
        connection.enabled = false
        XCTAssertFalse(connection.permitsReuse(of: "koboldcpp/mini-magnum-12b-v1.1", freeOnly: true))
    }
}
