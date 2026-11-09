import XCTest

@MainActor final class StartupTests: XCTestCase {
    func testLibrarySettingsAndFirstConversation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = offlineArguments()
        app.launch()
        let count = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "24 Charaktere")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 15), "The DEBUG offline fixture should load without a network or account")
        let elias = app.buttons["character-row-faden.original.2"]
        XCTAssertTrue(elias.waitForExistence(timeout: 5), "Discovery should expose character description rows below the featured card")
        app.buttons["Suchfilter"].tap()
        let favorites = app.switches["Nur Favoriten"]
        XCTAssertTrue(favorites.waitForExistence(timeout: 5))
        favorites.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(favorites.value as? String, "1")
        app.navigationBars.buttons["Fertig"].tap()
        XCTAssertTrue(app.staticTexts["Keine Charaktere gefunden"].waitForExistence(timeout: 5))
        app.buttons["Zurücksetzen"].tap()
        XCTAssertTrue(elias.waitForExistence(timeout: 5))
        // Include the actual moving selection in the optional simulator preview.
        app.buttons["Fantasy"].tap()
        app.buttons["Alle"].tap()
        attach(app, name: "Bibliothek")
        app.tabBars.buttons["Einstellungen"].tap()
        let protection = app.switches["Kostenpflichtige API-Modelle ausschließen"]
        XCTAssertTrue(protection.waitForExistence(timeout: 5))
        XCTAssertEqual(protection.value as? String, "1")
        attach(app, name: "Einstellungen")
        app.tabBars.buttons["Entdecken"].tap()
        let mara = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Mara,")).firstMatch
        XCTAssertTrue(mara.waitForExistence(timeout: 5))
        mara.tap()
        let begin = app.buttons["Gespräch beginnen"]
        XCTAssertTrue(begin.waitForExistence(timeout: 5)); begin.tap()
        XCTAssertTrue(app.navigationBars["Gespräch vorbereiten"].waitForExistence(timeout: 5))
        app.buttons["Gespräch beginnen"].tap()
        let options = app.buttons["Gesprächsoptionen"]
        XCTAssertTrue(options.waitForExistence(timeout: 8))
        attach(app, name: "Gespraech")
        let field = app.textFields["Deine Nachricht"].exists ? app.textFields["Deine Nachricht"] : app.textViews["Deine Nachricht"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("Hallo Mara.")
        app.buttons["Nachricht senden"].tap()
        XCTAssertTrue(app.alerts["Hinweis"].waitForExistence(timeout: 8), "An unconfigured provider must produce an honest setup error rather than a fake answer")
        app.alerts.buttons["Verstanden"].tap()
        options.tap()
        app.buttons["Erinnerungen & Schreibstil"].tap()
        XCTAssertTrue(app.navigationBars["Erinnerungen"].waitForExistence(timeout: 5))
        attach(app, name: "Erinnerungen")
        app.navigationBars.buttons["Fertig"].tap()
        app.navigationBars.buttons["Schließen"].tap()
        app.tabBars.buttons["Gespräche"].tap()
        XCTAssertTrue(app.staticTexts["Hallo Mara."].waitForExistence(timeout: 5))
        attach(app, name: "Chatuebersicht")
    }
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testPublicCatalogueAutomaticallyAddsRealCards() {
        let app = XCUIApplication()
        // Hold translation to reproduce a device with unavailable language packs.
        // Public metadata and original artwork must appear independently.
        app.launchArguments = ["-FadenUITestStore", UUID().uuidString, "-KaiUIHoldTranslations", "-includeAdultCatalogue", "NO", "-cataloguePrepareCount", "24", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        let populated = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[1-9][0-9]* Charaktere in deiner Bibliothek")).firstMatch
        XCTAssertTrue(populated.waitForExistence(timeout: 20), "Public previews must appear without awaiting translation")
        XCTAssertFalse(app.buttons["character-row-faden.original.2"].exists, "Production discovery must contain original public cards rather than examples")
        let prepared = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Originalbilder offline")).firstMatch
        XCTAssertTrue(prepared.waitForExistence(timeout: 100), "Definitions and original artwork must finish while translation remains held")
        attach(app, name: "Oeffentliche-Originalkarten")
    }
    func testProductionLibraryStartsWithoutInventedExamples() {
        let app = XCUIApplication()
        app.launchArguments = offlineArguments() + ["-KaiUIPublicLibraryTest"]
        app.launch()
        XCTAssertTrue(app.staticTexts["0 Charaktere in deiner Bibliothek"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Öffentliche Charakterkarten laden"].exists)
        XCTAssertTrue(app.buttons["Karten vorbereiten"].exists)
        XCTAssertFalse(app.buttons["character-row-faden.original.2"].exists)
    }

    func testGroupChatPersonaAndScenarioSetup() {
        let app = XCUIApplication()
        app.launchArguments = offlineArguments()
        app.launch()
        app.buttons["Charakter hinzufügen"].tap()
        app.buttons["Gruppenchat beginnen"].tap()
        XCTAssertTrue(app.navigationBars["Gruppenchat vorbereiten"].waitForExistence(timeout: 5))
        app.buttons["Neue Persona erstellen"].tap()
        let name = app.textFields["Name der Persona"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Reisende")
        app.navigationBars.buttons["Speichern"].tap()
        let scenario = app.buttons["scene-picker"]
        if !scenario.exists { app.swipeUp() }
        scenario.tap()
        app.buttons["Im Nachtzug"].tap()
        attach(app, name: "Gruppenchat-vorbereiten")
        app.buttons["Gruppenchat beginnen"].tap()
        XCTAssertTrue(app.buttons["Antwortende Figuren"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Du schreibst als Reisende"].exists)
        app.buttons["Antwortende Figuren"].tap()
        XCTAssertTrue(app.buttons["Alle nacheinander"].waitForExistence(timeout: 3))
        attach(app, name: "Gruppenchat")
    }
    func testSendFallbackAndPersistAStreamedReply() { assertSendFallbackAndPersist(extraArguments: []) }
    func testReplyRecoveredWhenStreamCallbackDidNotPersistText() { assertSendFallbackAndPersist(extraArguments: ["-KaiUIDropTextCallbacks"]) }
    private func assertSendFallbackAndPersist(extraArguments: [String]) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = offlineArguments() + ["-KaiUIInferenceTest"] + extraArguments
        app.launch()
        openCard("Mara", in: app)
        app.buttons["Gespräch beginnen"].tap()
        XCTAssertTrue(app.navigationBars["Gespräch vorbereiten"].waitForExistence(timeout: 5))
        app.buttons["Gespräch beginnen"].tap()
        XCTAssertTrue(input(app).waitForExistence(timeout: 8))
        input(app).tap(); input(app).typeText("Prüfnachricht: \"Guten Abend.\" *Ich warte.*")
        app.buttons["Nachricht senden"].tap()
        let reply = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Prüfantwort: Mara stellt ihre Tasse ab")).firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 10), "The real request/stream pipeline must fall back after an account-wide 429 and display its response")
        XCTAssertFalse(app.alerts["Hinweis"].exists)
        attach(app, name: "Nutzungstest-Streaming-und-Fallback")
        app.navigationBars.buttons["Schließen"].tap()
        app.tabBars.buttons["Gespräche"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Prüfantwort: Mara stellt ihre Tasse ab")).firstMatch.waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        app.tabBars.buttons["Gespräche"].tap()
        let conversation = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Prüfantwort: Mara stellt ihre Tasse ab")).firstMatch
        XCTAssertTrue(conversation.waitForExistence(timeout: 8)); conversation.tap()
        XCTAssertTrue(reply.waitForExistence(timeout: 8), "The generated message must survive a relaunch")
    }
    func testMissingLanguagePackOffersSetupAndDoesNotStartAnEnglishChat() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = offlineArguments() + ["-KaiUITranslationSetupTest"]
        app.launch()
        openCard("Sprachpaket-Test", in: app)
        let setup = app.buttons["card-language-setup"]
        for _ in 0..<4 { if setup.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(setup.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Gespräch beginnen"].isEnabled)
        setup.tap()
        XCTAssertTrue(app.navigationBars["Deutsch einrichten"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["prepare-language-en"].exists)
    }
    private func offlineArguments() -> [String] {
        ["-FadenUITest", "-FadenUITestStore", UUID().uuidString, "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
    }
    private func input(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "chat-draft-input").firstMatch
    }
    private func openCard(_ name: String, in app: XCUIApplication) {
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8)); card.tap()
    }
    func testDraftSurvivesCardNavigationBackgroundAndRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = offlineArguments(); app.launch()
        openCard("Mara", in: app)
        app.buttons["Gespräch beginnen"].tap()
        XCTAssertTrue(app.navigationBars["Gespräch vorbereiten"].waitForExistence(timeout: 5))
        app.buttons["Gespräch beginnen"].tap()
        XCTAssertTrue(input(app).waitForExistence(timeout: 8))
        var text = "*Mein privater Gedanke* \"Noch nicht gesendet.\""
        input(app).tap(); input(app).typeText(text)
        text = input(app).value as? String ?? ""
        XCTAssertTrue(text.contains("Mein privater Gedanke"))
        app.navigationBars.buttons["Schließen"].tap()
        openCard("Mara", in: app)
        XCTAssertTrue(app.buttons["Gespräch fortsetzen"].waitForExistence(timeout: 5))
        app.buttons["Gespräch fortsetzen"].tap()
        XCTAssertTrue(input(app).waitForExistence(timeout: 8)); XCTAssertEqual(input(app).value as? String, text)
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertEqual(input(app).value as? String, text)
        app.terminate(); app.launch()
        openCard("Mara", in: app); app.buttons["Gespräch fortsetzen"].tap()
        XCTAssertTrue(input(app).waitForExistence(timeout: 8)); XCTAssertEqual(input(app).value as? String, text)
        attach(app, name: "Gespeicherter-Entwurf")
        app.buttons["Nachricht senden"].tap()
        XCTAssertTrue(app.alerts["Hinweis"].waitForExistence(timeout: 8)); app.alerts.buttons["Verstanden"].tap()
        XCTAssertNotEqual(input(app).value as? String, text, "Sending clears only the submitted draft")
    }
    func testMenuThemeCanSwitchAndSurvivesRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = offlineArguments(); app.launch()
        attach(app, name: "Menue-Dunkel")
        func themeControl() -> XCUIElement {
            let control = app.segmentedControls["menu-theme"]
            for _ in 0..<8 { if control.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(control.isHittable); return control
        }
        app.tabBars.buttons["Einstellungen"].tap()
        let control = themeControl()
        XCTAssertTrue(control.buttons["Dunkel"].isSelected)
        control.buttons["Hell"].tap()
        XCTAssertTrue(control.buttons["Hell"].isSelected)
        app.tabBars.buttons["Entdecken"].tap(); attach(app, name: "Menue-Hell")
        app.terminate(); app.launch(); app.tabBars.buttons["Einstellungen"].tap()
        XCTAssertTrue(themeControl().buttons["Hell"].isSelected)
        openLightChat(app)
    }
    private func openLightChat(_ app: XCUIApplication) {
        app.tabBars.buttons["Entdecken"].tap(); openCard("Mara", in: app)
        app.buttons["Gespräch beginnen"].tap()
        XCTAssertTrue(app.navigationBars["Gespräch vorbereiten"].waitForExistence(timeout: 5)); app.buttons["Gespräch beginnen"].tap()
        XCTAssertTrue(app.buttons["Gesprächsoptionen"].waitForExistence(timeout: 8))
        attach(app, name: "Kartenhintergrund-bei-hellem-Menue")
    }
    func testOneCardWithMultiplePeopleStartsAsEnsemble() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = offlineArguments(); app.launch()
        app.buttons["Charakter hinzufügen"].tap(); app.buttons["Charakter erstellen"].tap()
        let name = app.textFields["Name"]; XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Mara & Elias")
        let personality = app.textViews["Persönlichkeit und Hintergrund"]; personality.tap(); personality.typeText("Mara ist ruhig. Elias ist mutig. Beide sind eigenstaendige Figuren.")
        app.navigationBars.buttons["Speichern"].tap()
        let search = app.searchFields.firstMatch; XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Mara & Elias")
        openCard("Mara & Elias", in: app)
        XCTAssertTrue(app.staticTexts["Mehrere Figuren in einer gemeinsamen Karte"].waitForExistence(timeout: 5))
        app.buttons["Gespräch beginnen"].tap()
        XCTAssertTrue(app.navigationBars["Gruppenkarte vorbereiten"].waitForExistence(timeout: 5))
        app.buttons["Gespräch beginnen"].tap()
        XCTAssertTrue(app.staticTexts["Mehrere Figuren · eine gemeinsame Karte"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Antwortende Figuren"].exists, "One multi-character card should be generated as a cast, not separate card requests")
        attach(app, name: "Mehrpersonen-Karte")
    }
    func testScrollButtonsJumpWithoutRewindingTheStory() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = offlineArguments() + ["-KaiUIScrollTest"]; app.launch()
        app.tabBars.buttons["Gespräche"].tap()
        let story = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Mara")).firstMatch
        XCTAssertTrue(story.waitForExistence(timeout: 8)); story.tap()
        let up = app.buttons["scroll-to-chat-start"]
        XCTAssertTrue(up.waitForExistence(timeout: 8)); up.tap()
        let header = app.staticTexts["Dein Gespräch mit Mara"]
        XCTAssertTrue(header.waitForExistence(timeout: 8)); XCTAssertTrue(header.isHittable)
        attach(app, name: "Zum-Chat-Anfang")
        app.buttons["scroll-to-chat-latest"].tap()
        let last = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Scroll-Test Nachricht 90.")).firstMatch
        XCTAssertTrue(last.waitForExistence(timeout: 8))
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: last)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 8), .completed)
        app.navigationBars.buttons["Schließen"].tap()
        let preview = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Scroll-Test Nachricht 90.")).firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "Scrolling must keep the latest story head intact")
    }
    func testAllSourcesAndCardexAreSelectable() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = offlineArguments() + ["-catalogueSource", "all", "-KaiUIHoldTranslations"]
        app.launch()
        app.buttons["Online entdecken"].tap()
        let sources = app.segmentedControls["catalogue-source"]
        XCTAssertTrue(sources.waitForExistence(timeout: 5))
        XCTAssertTrue(sources.buttons["Alle"].isSelected)
        XCTAssertTrue(sources.buttons["Chub"].exists)
        XCTAssertTrue(sources.buttons["JannyAI"].exists)
        sources.buttons["Cardex"].tap()
        app.buttons["Omegaverse"].tap()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "character-row-cardex/")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "Cardex previews must appear without waiting for translation")
        XCTAssertTrue(sources.buttons["Cardex"].isSelected)
        attach(app, name: "Cardex-Omegaverse")
    }
    func testJannySearchOffersTheOmegaverseGenre() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = offlineArguments(); app.launch()
        XCTAssertTrue(app.navigationBars["Kai"].waitForExistence(timeout: 10))
        app.buttons["Online entdecken"].tap()
        let sources = app.segmentedControls["catalogue-source"]
        XCTAssertTrue(sources.waitForExistence(timeout: 5)); sources.buttons["JannyAI"].tap()
        app.buttons["Omegaverse"].tap()
        let count = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Treffer im Katalog")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 60), "The public JannyAI index should return real Omegaverse results")
        XCTAssertFalse(app.staticTexts["Keine Charaktere gefunden"].exists)
        attach(app, name: "JannyAI-Omegaverse")
    }
    func testResponseWordLimitCanBeSelectedAndPersists() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = offlineArguments(); app.launch()
        func wordControl() -> XCUIElement {
            let control = app.descendants(matching: .any).matching(identifier: "response-word-limit").firstMatch
            for _ in 0..<9 { if control.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(control.isHittable); return control
        }
        app.tabBars.buttons["Einstellungen"].tap()
        wordControl().tap(); app.buttons["Bis zu 800 Wörter"].tap()
        let selected = wordControl()
        XCTAssertTrue((selected.label + " " + String(describing: selected.value)).contains("800"))
        attach(app, name: "Wortzahl-Einstellung")
        app.tabBars.buttons["Entdecken"].tap(); app.terminate(); app.launch()
        app.tabBars.buttons["Einstellungen"].tap()
        let restored = wordControl()
        XCTAssertTrue((restored.label + " " + String(describing: restored.value)).contains("800"))
    }
    func testProviderPriorityCanBeDraggedAndPreservesDisabledChatGPT() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = offlineArguments(); app.launch()
        func openOrder() {
            app.tabBars.buttons["Einstellungen"].tap()
            let button = app.buttons["connection-priority-order"]
            for _ in 0..<7 { if button.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(button.isHittable); button.tap()
            XCTAssertTrue(app.navigationBars["KI-Rangfolge"].waitForExistence(timeout: 5))
        }
        openOrder()
        let first = app.cells.containing(.staticText, identifier: "1. Kostenlose Cloud").firstMatch
        let third = app.cells.containing(.staticText, identifier: "3. ChatGPT Plus").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5)); XCTAssertTrue(third.exists)
        XCTAssertEqual(third.switches["ChatGPT Plus verwenden"].firstMatch.value as? String, "0")
        third.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).press(forDuration: 1.2,
            thenDragTo: first.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.15)))
        XCTAssertTrue(app.staticTexts["1. ChatGPT Plus"].waitForExistence(timeout: 8))
        let reordered = app.cells.containing(.staticText, identifier: "1. ChatGPT Plus").firstMatch
        XCTAssertEqual(reordered.switches["ChatGPT Plus verwenden"].firstMatch.value as? String, "0")
        attach(app, name: "KI-Rangfolge")
        app.navigationBars.buttons["Fertig"].tap()
        app.terminate(); app.launch(); openOrder()
        XCTAssertTrue(app.staticTexts["1. ChatGPT Plus"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.cells.containing(.staticText, identifier: "1. ChatGPT Plus").firstMatch.switches["ChatGPT Plus verwenden"].firstMatch.value as? String, "0")
    }
    func testPrivateInsightIsDisplayedAndFrequencyCanBeDisabled() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = offlineArguments() + ["-KaiUIInsightTest"]; app.launch()
        app.tabBars.buttons["Gespräche"].tap()
        let story = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Mara")).firstMatch
        XCTAssertTrue(story.waitForExistence(timeout: 5)); story.tap()
        let insight = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Einblick-Test: In ihrer ersten Nacht")).firstMatch
        XCTAssertTrue(insight.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Nur für dich · nicht ausgesprochen"].exists)
        attach(app, name: "Einblick-Testansicht")
        app.navigationBars.buttons["Schließen"].tap()
        app.tabBars.buttons["Einstellungen"].tap()
        func frequency() -> XCUIElement {
            let control = app.descendants(matching: .any).matching(identifier: "insight-frequency").firstMatch
            for _ in 0..<11 { if control.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(control.isHittable); return control
        }
        frequency().tap(); app.buttons["Aus"].tap()
        let selected = frequency()
        XCTAssertTrue((selected.label + " " + String(describing: selected.value)).contains("Aus"))
        app.terminate(); app.launch(); app.tabBars.buttons["Einstellungen"].tap()
        let restored = frequency()
        XCTAssertTrue((restored.label + " " + String(describing: restored.value)).contains("Aus"))
    }
    func testAPIProviderPresetsExplainAccessAndRequireAKey() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = offlineArguments(); app.launch()
        app.tabBars.buttons["Einstellungen"].tap()
        let add = app.buttons["Anbieter hinzufügen"]
        for _ in 0..<8 { if add.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(add.isHittable); add.tap()
        for title in ["OpenAI API", "Claude API", "Gemini API", "Grok API", "DeepSeek API"] { XCTAssertTrue(app.buttons[title].exists) }
        app.buttons["Claude API"].tap()
        XCTAssertTrue(app.navigationBars["Claude API"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields["API-Schlüssel"].exists)
        XCTAssertTrue(app.textFields["Workspace-ID (falls benötigt)"].exists)
        attach(app, name: "Claude-API-Einrichtung")
        let load = app.buttons["Verfügbare Modelle laden"]
        for _ in 0..<6 { if load.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(load.isHittable); load.tap()
        XCTAssertTrue(app.staticTexts["Bitte zuerst einen API-Schlüssel eintragen."].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Schließen"].tap()
        XCTAssertTrue(add.waitForExistence(timeout: 5)); add.tap(); app.buttons["Gemini API"].tap()
        XCTAssertTrue(app.navigationBars["Gemini API"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.secureTextFields["API-Schlüssel"].exists)
        attach(app, name: "Gemini-API-Einrichtung")
    }
}
