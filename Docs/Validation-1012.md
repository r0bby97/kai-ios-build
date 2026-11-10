# Kai 1.7.0 / Build 1012 – geprüfte IPA

Stand: 10. November 2026. [IPA für SideStore](https://github.com/r0bby97/kai-ios-build/releases/download/build-1012/Kai-1.7.0-b1012.ipa). Öffentlicher Quellstand `150bece49e5e6f252d337f589aa10113cc78189b`. Die Geräte-IPA ist erstellt, heruntergeladen und geprüft; eine vollständige Abnahme mit dem persönlichen iPhone und allen Konten bleibt davon getrennt.

## Testnachweis

Die vollständige Prüfung auf Quellstand 64aa4a9 (öffentlicher Lauf 42877081515) bestand 126 macOS-Kernlogiktests, alle 31 iOS-Diensttests und 22 von 24 Oberflächentests. Zwei Fehler betrafen ausschließlich eine alte JannyAI-Auswahl ohne passenden Picker-Eintrag und den Testzugriff auf zwei gleich benannte Schließen-Schaltflächen.

Der korrigierte Stand 150bece änderte nur die Quellenbindung in LibraryView, die eindeutige Zugänglichkeit der Karten-Schaltfläche und ihren Testselektor sowie die Nachlauf-Auswahl im Workflow. Der anschließende [öffentliche Lauf 42883423389](https://github.com/r0bby97/kai-ios-build/actions/runs/42883423389) bestand erneut 126 Kernlogiktests und alle 37 ausgewählten nativen Tests: 31 Dienste plus sechs Oberflächenabläufe. Darunter sind beide zuvor fehlgeschlagenen Fälle, Cardex/Alle-Quellen, Geschlecht mit Genre, Entwurf über Navigation und Neustart sowie Bibliothek/Einstellungen/Gesprächsstart.

Damit sind alle 24 unterschiedlichen UI-Fälle aus Vollprüfung und gezieltem Nachlauf bestanden. Das ist ausdrücklich kein einzelner erneuter Lauf aller 55 nativen Tests auf dem letzten Commit. Die bereits bestandenen, unveränderten Abläufe bleiben belegt: zwei lange gestreamte Antworten bei offener Tastatur, Pfeile zum Anfang/Ende ohne Rückspulen, zweite Antwort mit Anbieterwechsel und erhaltenem Verlauf, Ausschluss privater Gedanken, lesbare verschachtelte Eigenschaften, Gruppenkarten, Themenwahl, Wortgrenze und Anbieterreihenfolge.

Die Diensttests prüfen die tatsächlich serialisierte zweite OpenRouter-Anfrage mit portablem Verlauf, gültigen Schlüssel bei Modell-401 versus ungültigen Schlüssel, Kontextgrenzen und elf Apple-Übersetzungsfälle. Oberflächliche kontrollierte Testantworten belegen den App-Ablauf, keine allgemeine Modellqualität.

## Binärprüfung

- Version `1.7.0`, Build `1012`, Anzeigename Kai, stabile App-Kennung `dev.r0bby97.faden`.
- iPhoneOS arm64; ZIP-Prüfsummen gültig; Metal-Bibliothek für lokale Modelle enthalten.
- Beide Release-Dateinamen enthalten identische Bytes. GitHub-Digest und lokale SHA-256 stimmen überein.
- Keine Startflags oder Antworttexte der UI-Testfixtures im Geräteprogramm. Der Geräte-Build erfolgt ohne KAI_TESTING.
- Größe: 14337661 Bytes. SHA-256: `0d5ab9be0935e6b4b4fed8f9db60591031d44689eaaec1f519e29af31a057ce7`.

GitHub meldet für diesen öffentlichen Standard-macOS-Lauf **0 abrechenbare Minuten**. Die privaten Runner sind gesperrt; Workflows starten nur manuell. Es wurden keine privaten Actions-Minuten verwendet.

## Noch auf dem Gerät prüfen

Der Nutzer bestätigt kurze echte Antworten über kostenlose Cloud/OpenRouter, AI Horde, lokales Qwen und ChatGPT Plus. Das bestätigt Verbindung und grundlegende Generation, keine beliebig langen Rollenspiele. Der konkrete persönliche OpenRouter-400/401-Fall ist anhand kontrollierter Tests nicht endgültig erklärt. Eine Änderung der Anfrageverarbeitung wurde geprüft; ein echter Kontoversuch ist weiterhin nötig.

Der Simulator stellt keine Apple-Sprachmodelle bereit. Bitte eine englische und eine gemischte Karte mit geladenen Sprachpaketen auf dem iPhone prüfen. Es gibt keine garantierte Übersetzungszeit. Kleine lokale Modelle bleiben in Qualität und Gedächtnis begrenzt; Hintergrundübersetzungen pausieren zwischen Batches während einer Antwort. Wärmeentwicklung ist auf der Hardware zu bewerten.

Private Sternchentexte werden aus neuen KI-Anfragen, Stilbeispielen, Abruf und zugeordneten Erinnerungen entfernt. Bereits früher ausgesprochene Lecks bleiben in alten Figurenantworten gespeichert. Persönlichkeitsanker und Schutz der Nutzerperspektive sind verstärkt, garantieren aber keine fehlerfreie Ausgabe jedes Modells. Eine verlässliche ChatGPT-Restkontingentanzeige ist weiterhin nicht verfügbar.
