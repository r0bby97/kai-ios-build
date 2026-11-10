import Foundation
import Translation

/// Setup and translation must select the same engine. On newer iPhones Apple's
/// default can be highFidelity, whose installed assets do not prepare lowLatency.
enum AppleCardTranslation {
    static func configuration(language: String) -> TranslationSession.Configuration {
        let source = Locale.Language(identifier: language)
        let target = Locale.Language(identifier: "de")
        if #available(iOS 26.4, *) {
            return .init(source: source, target: target, preferredStrategy: .lowLatency)
        }
        return .init(source: source, target: target)
    }

    @available(iOS 26.0, *)
    static func installedSession(language: String) -> TranslationSession {
        let source = Locale.Language(identifier: language)
        let target = Locale.Language(identifier: "de")
        if #available(iOS 26.4, *) {
            return .init(installedSource: source, target: target,
                         preferredStrategy: configuration(language: language).preferredStrategy)
        }
        return .init(installedSource: source, target: target)
    }

    enum Failure: String {
        case notInstalled, cancelled, unsupportedSource, unsupportedTarget, unsupportedPair
        case nothingToTranslate, unidentifiedLanguage, engine, unknown
    }

    static func failure(_ error: Error) -> Failure {
        if error is CancellationError || (error as? CocoaError)?.code == .userCancelled { return .cancelled }
        if #available(iOS 26.0, *) {
            if TranslationError.notInstalled ~= error { return .notInstalled }
            if TranslationError.alreadyCancelled ~= error { return .cancelled }
        }
        // TranslationError is a Swift struct. Its NSError code does not identify
        // its individual cases; match Apple's typed values instead.
        switch error {
        case TranslationError.unsupportedSourceLanguage: return .unsupportedSource
        case TranslationError.unsupportedTargetLanguage: return .unsupportedTarget
        case TranslationError.unsupportedLanguagePairing: return .unsupportedPair
        case TranslationError.nothingToTranslate: return .nothingToTranslate
        case TranslationError.unableToIdentifyLanguage: return .unidentifiedLanguage
        case TranslationError.internalError: return .engine
        default: return .unknown
        }
    }

    static func checkPreparation(isReady: Bool, language: String) throws {
        guard isReady else { throw TranslationSetupPending(language: language) }
    }

    static func setupLanguages(missing: Set<String>) -> [String] {
        ["en"] + missing.subtracting(["en", "de"]).sorted()
    }
}

struct TranslationSetupPending: LocalizedError {
    let language: String
    var errorDescription: String? {
        let name = Locale(identifier: "de").localizedString(forLanguageCode: language) ?? language
        return "Die Sprachpakete für \(name) → Deutsch sind noch nicht einsatzbereit. Falls der Download läuft, lasse ihn abschließen und tippe danach erneut auf Einrichten. Die Karten wurden noch nicht als übersetzt markiert."
    }
}

struct AppleCardTranslationFailure: LocalizedError {
    let kind: AppleCardTranslation.Failure
    var errorDescription: String? {
        let reason: String
        switch kind {
        case .engine:
            reason = "Interner Fehler der Apple-Übersetzung. Versuche die Kartenübersetzung erneut. Bleibt der Fehler bestehen, starte das iPhone neu. Das ist kein Nachweis für fehlende Sprachpakete."
        case .unsupportedSource, .unsupportedTarget, .unsupportedPair:
            reason = "Apple unterstützt diese Ausgangssprache oder dieses Sprachpaar für die Kartenübersetzung nicht."
        case .nothingToTranslate:
            reason = "Apple konnte diesen Textabschnitt nicht übersetzen, weil er keinen übersetzbaren Inhalt erkannt hat."
        case .unidentifiedLanguage:
            reason = "Apple konnte die Ausgangssprache des Textabschnitts nicht erkennen."
        case .notInstalled:
            reason = "Die für die Kartenübersetzung benötigten Apple-Sprachpakete sind noch nicht bereit."
        case .cancelled:
            reason = "Die Übersetzung wurde abgebrochen."
        case .unknown:
            reason = "Die Apple-Übersetzung ist fehlgeschlagen. Bitte erneut versuchen. Fehlende Sprachpakete wurden nicht bestätigt."
        }
        return "\(reason) [Apple: \(kind.rawValue)]"
    }
}
