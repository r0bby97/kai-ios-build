# Apple-Kartenübersetzung nach erfolgreicher Einrichtung

Stand: 10. November 2026. Ausgangspunkt ist Build 1008: „Sprachpakete sind bereit“, anschließend `Translation.TranslationError`, Code 1. Die neue Korrektur ist zunächst Quellcode; die native Prüfung erfolgt vor dem nächsten IPA-Build.

## Ursache im App-Ablauf

Kais direkte Kartenübersetzung wählte ab iOS 26.4 ausdrücklich `lowLatency`. Die SwiftUI-Sitzung für „Deutsch einrichten“ verwendete dagegen den Apple-Standard. Dieser kann auf Geräten mit Apple Intelligence `highFidelity` sein und andere Modellressourcen verwenden. Eine erfolgreiche Vorbereitung dieser Sitzung bestätigt deshalb nicht die Ressourcen des anschließend benutzten Modus. Das ist ein belegter Widerspruch im Code; ohne Gerätelog ist damit nicht jede individuelle Apple-Fehlerursache nachgewiesen.

Zusätzlich wurden unterschiedliche Apple-Fehler pauschal als Sprachpaketproblem ausgegeben. Die NSError-Brücke eines Swift-Fehlers ist keine verlässliche Fallunterscheidung. Einrichtungsfehler, Abbruch, nicht unterstützte Sprache und interner Dienstfehler müssen getrennt behandelt werden.

## Korrektur

- Einrichtung und direkte Übersetzung beziehen die Strategie aus derselben Konfiguration. Auf iOS 26.4 und neuer wird für beide der schnelle, lokale Modus verwendet.
- Nach der Vorbereitung wird ab iOS 26 die Bereitschaft der konkreten Sitzung geprüft. Ein noch laufender Download wird nicht als „bereit“ gemeldet.
- Fehler werden anhand der offiziellen `TranslationError`-Werte erkannt. Nur ein bestätigtes `notInstalled` erzeugt die Aufforderung zur Sprachpaketeinrichtung. Abbruch und interne Fehler sperren eine Sprache nicht dauerhaft.
- Reine Zahlen, Satzzeichen und Kartenvariablen bleiben unverändert erhalten und werden nicht als eigene Übersetzungsanfragen gesendet. Fehlende Übersetzungen echter Textteile bleiben ein Fehler; eine Karte wird nicht teilweise als deutsch gespeichert.
- „Englisch → Deutsch“ bleibt unabhängig von anderen Katalogsprachen in der Einrichtung sichtbar. Zusätzliche Sprachen sind als Ausgangssprachen anderer Karten erklärt, ohne Sprachfilter im Katalog.
- Unter Einstellungen → Schreiben gibt es einen direkten Knopf „Deutschübersetzung einrichten“. Eine Kartenvorbereitung ist dafür nicht nötig.

## Prüfung

Lokal: **94 Kernlogiktests bestanden**, darunter Zahlenerhalt, Variablen und Textgrenzen. Swift-Syntaxprüfung und `git diff --check` bestanden. Acht native Diensttests für Strategie, Fehlerklassifikation, bestätigte fehlende Pakete, Abbruch, unvollständige Vorbereitung und Sprachenauswahl sowie ein neuer Einrichtungs-Bedientest sind vorbereitet.

Der einmalige öffentliche Build prüft die nativen Diensttests und die betroffenen Bedienungsabläufe vor der Geräte-IPA. Unveränderte übrige UI-Tests werden nicht erneut ausgeführt; ihr letzter vollständiger Prüflauf bleibt Build 1008. Private Minuten werden nicht verwendet.

Apple stellt auf dem Simulator keine echten Übersetzungsmodelle bereit. Deshalb sind die native API-/Logikprüfung und die UI-Navigation kein Nachweis einer echten Kartenübersetzung auf dem iPhone. Die abschließende Übersetzung mit geladenen Paketen muss auf dem Gerät geprüft werden. Es werden keine Kartentexte an einen Cloud-Übersetzer oder KI-Anbieter weitergeleitet.

## Offizielle Referenzen

- [Schneller lokaler Modus und dessen Sprachmodelle](https://developer.apple.com/documentation/translation/translationsession/strategy/lowlatency)
- [Apple-Intelligence-Modus](https://developer.apple.com/documentation/translation/translationsession/strategy/highfidelity)
- [Strategie einer SwiftUI-Übersetzungssitzung](https://developer.apple.com/documentation/translation/translationsession/configuration/init(source:target:preferredstrategy:))
- [Vorbereitung und bereits laufende Downloads](https://developer.apple.com/documentation/translation/translationsession/preparetranslation())
- [Bereitschaft der konkreten Sitzung](https://developer.apple.com/documentation/translation/translationsession/isready)
- [Unterscheidbare Fehlerfälle](https://developer.apple.com/documentation/translation/translationerror)
