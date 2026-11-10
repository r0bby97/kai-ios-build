import XCTest
import Translation
import FadenCore
@testable import Faden

@MainActor final class TranslationTests: XCTestCase {
    func testSetupExplicitlySelectsTheCardTranslationStrategy() throws {
        if #available(iOS 26.4, *) {
            let configuration = AppleCardTranslation.configuration(language: "en")
            XCTAssertEqual(configuration.preferredStrategy, .lowLatency)
            XCTAssertEqual(configuration.source?.languageCode?.identifier, "en")
            XCTAssertEqual(configuration.target?.languageCode?.identifier, "de")
        }
    }

    func testTypedErrorsRemainDistinctInsteadOfUsingTheSharedNSErrorCode() {
        let cases: [(Error, AppleCardTranslation.Failure)] = [
            (TranslationError.internalError, .engine),
            (TranslationError.nothingToTranslate, .nothingToTranslate),
            (TranslationError.unableToIdentifyLanguage, .unidentifiedLanguage),
            (TranslationError.unsupportedSourceLanguage, .unsupportedSource),
            (TranslationError.unsupportedTargetLanguage, .unsupportedTarget),
            (TranslationError.unsupportedLanguagePairing, .unsupportedPair)
        ]
        for (error, expected) in cases { XCTAssertEqual(AppleCardTranslation.failure(error), expected) }
        let generic = NSError(domain: "Translation.TranslationError", code: 1)
        XCTAssertEqual(AppleCardTranslation.failure(generic), .unknown, "A numeric code is not a typed missing-model diagnosis")
    }

    func testOnlyConfirmedMissingModelsOfferLanguageSetup() {
        if #available(iOS 26.0, *) {
            let translator = GermanTranslator()
            let error = translator.translationFailure(TranslationError.notInstalled, language: "en")
            XCTAssertTrue(error is TranslationSetupRequired)
            XCTAssertTrue(translator.missingLanguages.contains("en"))
            XCTAssertTrue(error.localizedDescription.contains("Englisch"))
        }
    }

    func testInternalFailuresDoNotPoisonTheLanguageOrAskForADownload() {
        let translator = GermanTranslator()
        let error = translator.translationFailure(TranslationError.internalError, language: "en")
        XCTAssertFalse(error is TranslationSetupRequired)
        XCTAssertTrue(error.localizedDescription.contains("Apple: engine"))
        XCTAssertTrue(translator.missingLanguages.isEmpty)
        XCTAssertTrue(translator.failedLanguages.isEmpty)
    }

    func testCancelledOrDismissedSessionsDoNotBecomeMissingLanguageFailures() {
        var errors: [Error] = [CancellationError(), CocoaError(.userCancelled)]
        if #available(iOS 26.0, *) { errors.append(TranslationError.alreadyCancelled) }
        let translator = GermanTranslator()
        for error in errors {
            XCTAssertTrue(translator.translationFailure(error, language: "en") is CancellationError)
        }
        XCTAssertTrue(translator.missingLanguages.isEmpty)
        XCTAssertTrue(translator.failedLanguages.isEmpty)
    }

    func testPreparationCannotClaimSuccessWhileTheSessionIsNotReady() throws {
        let translator = GermanTranslator()
        do {
            try AppleCardTranslation.checkPreparation(isReady: false, language: "en")
            XCTFail("An unfinished download must not become a successful setup")
        } catch {
            let reported = translator.translationFailure(error, language: "en")
            XCTAssertTrue(reported is TranslationSetupPending)
            XCTAssertTrue(reported.localizedDescription.contains("noch nicht einsatzbereit"))
            XCTAssertTrue(translator.missingLanguages.contains("en"))
        }
        XCTAssertNoThrow(try AppleCardTranslation.checkPreparation(isReady: true, language: "en"))
    }

    func testOtherCatalogueLanguagesNeverHideEnglishOrOfferGermanToGerman() {
        XCTAssertEqual(AppleCardTranslation.setupLanguages(missing: []), ["en"])
        XCTAssertEqual(AppleCardTranslation.setupLanguages(missing: ["id", "en", "de", "ru"]), ["en", "id", "ru"])
    }

    func testUnknownFailureDoesNotEchoTheSourceTextOrInventMissingPackages() {
        let original = NSError(domain: "Translation.TranslationError", code: 1,
                               userInfo: [NSLocalizedDescriptionKey: "private character definition"])
        let error = GermanTranslator().translationFailure(original, language: "en")
        XCTAssertTrue(error.localizedDescription.contains("Apple: unknown"))
        XCTAssertFalse(error.localizedDescription.contains("private character definition"))
        XCTAssertFalse(error is TranslationSetupRequired)
    }
}
