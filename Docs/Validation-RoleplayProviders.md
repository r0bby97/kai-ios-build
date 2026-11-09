# KI-Anbindungen und Inhaltsrichtwerte: Prüfstand

Stand: 9. November 2026. Änderungen sind Quellcode, noch keine neue IPA. Kein GitHub-Actions-Lauf wurde gestartet.

## Umsetzung

- AI Horde ist als kostenloser Anbieter mit anonymem Zugang und optionalem Schlüssel eingebaut. Neue Installationen erhalten die Verbindung; ältere Archive bekommen sie einmalig am Ende der vorhandenen Rangfolge. Eine anschließend entfernte Horde-Verbindung wird nicht bei jedem Start wieder hinzugefügt.
- Die native Chat-Schnittstelle erhält Systemprompt und Dialog getrennt. Nur gemeldete passende NSFW-Chat-Rechner werden ausgewählt; interne Berechnungen bleiben von sichtbarem Text getrennt.
- Auftragsbestätigung, Wartestatus, Antwort, Kontolimit, fehlende Kapazität, Abbruch und Zeitlimit sind getrennte Zustände. Bei Fehlern greift die vorhandene Anbieter-Rangfolge. Teilantworten werden nicht mit einem anderen Modell vermischt.
- Operationskennungen verhindern doppelte Generierungen bei einer verlorenen Eingangsbestätigung. Abbruch und Zeitlimit löschen einen bestätigten Auftrag auch dann, wenn die aufrufende Task bereits abgebrochen ist.
- Die Gratis-Ausgabe kann auf ein vom Dienst ausdrücklich genanntes kleineres Budget begrenzt werden. Charakter- und Nachrichtenkontext werden dabei nicht verändert.
- Arli, NanoGPT und Venice haben eigene Anbieterprofile. Bezahlte Anbindungen starten deaktiviert; die Kostensperre schließt sie aus. Ein Arli-Testkonto muss ausdrücklich als solches verwendet werden.
- Inhaltsrichtwerte für Erotik und fiktive Gewalt sind in Übersicht, Rangfolge und Verbindungseditor sichtbar. Ein Tipp in der Rangfolge zeigt Erklärung, Quelle und Prüfdatum. Unbekannte Endpunkte oder nicht geprüfte Modellmischungen erhalten keine erfundene uneingeschränkte Freigabe.
- Das tatsächliche Horde-Modell wird im Ergebnis und Fehlerbericht geführt. Optionale Charaktereinblicke können denselben erfolgreichen Anbieter und dasselbe Modell weiterverwenden.

## Bestanden

1. **92 Kernlogiktests, null Fehler.** Neu geprüft sind unter anderem Chat-Transport, fehlender Kontext, private Berechnungen, Kontolimit, explizites Gratis-Ausgabebudget, verlorene Bestätigung, Zeitlimit und DELETE, Task-Abbruch und DELETE, fremdes Modell, unzulässige Kontextkürzung, Inhaltsrichtwerte, Kostensperre und Migration.
2. **Fünf zusätzliche Tests des tatsächlichen App-Modell-/Generierungsdienstes für diese Anbieter, null Fehler.** Der unveränderte `CloudEngine.swift` und die neuen `RoleplayProviderTests.swift` wurden lokal in einem separaten Swift-Paket ausgeführt. Ein Linux-Adapter stellt die JSON-Byteiteration bereit. Das prüft die App-Verkabelung, Authentifizierungsheader, offiziellen Endpunkte, Modelllisten, Statusrückgabe, Konto-Limit-Weitergabe und Schlüsselbindung. Es ist keine iOS-Streaming-Abnahme.
3. **Echte anonyme Generierung über Stheno:** Anfrage über den neuen Horde-Client mit synthetischem deutschem Gruß, Antwort empfangen, 44 Ausgabetokens und 145 Zeichen, HTTP 200.
4. **Echte anonyme Generierung gezielt über Mini-Magnum 12B:** synthetischer deutscher Gruß, Antwort empfangen, 45 Ausgabetokens und 168 Zeichen, HTTP 200. Es waren 28 Statusabrufe nötig; der kostenlose Dienst antwortet nicht immer sofort.
5. **Echter Rollenspielprompt:** Der unveränderte `PromptBuilder` erzeugte für eine synthetische erwachsene Archivarin den normalen Kai-Kontext (Schätzung: 1.445 Tokens, bis zu 400 Wörter). Der neue Client forderte 1.200 Ausgabetokens an. Die automatische Auswahl nutzte Cydonia 24B v4.3 und lieferte eine deutsche Rollen-Antwort mit 117 Wörtern / 190 Ausgabetokens in rund 12,4 Sekunden. Das belegt den normalen Promptweg; es ist keine Abnahme langer Geschichten oder jeder Stilregel.
6. **Anbieter-Verfügbarkeit:** NanoGPT lieferte eine öffentliche Modellliste mit 635 Einträgen, Venice eine Textmodell-Liste mit 139 Einträgen. Die regulären Arli-Modell- und Chat-Routen verweigerten Anfragen ohne Schlüssel mit HTTP 401. Keine persönliche Arli-/NanoGPT-/Venice-Generierung wird als bestanden behauptet.
7. Swift-Syntaxprüfung aller geänderten App-/UI-Testdateien und `git diff --check` bestanden.

Die Tests verwenden ausschließlich synthetische harmlose Begrüßungen beziehungsweise Testdaten. Sie belegen weder die Qualität langer deutscher Rollenspiele noch eine Freigabe jeder expliziten Szene. API-Inhaltsrichtwerte beruhen auf veröffentlichten Regeln, nicht auf einem Versuch, Schutzregeln auszutricksen.

## Noch offen vor IPA-Freigabe

Der native iOS-Bedientest `testProviderContentGuidanceIsVisibleInPriorityOverview` ist vorbereitet. Die native SwiftUI-Typprüfung, Darstellung auf dem iPhone, tatsächliche iOS-URLSession-Integration und Kontogenerierung der schlüsselpflichtigen Anbieter bleiben zu prüfen. Lokale Modellleistung und Apple-Sprachpakete auf dem iPhone bleiben eigene Abnahmepunkte. Die frühere IPA Build 1007 enthält weder diese Änderungen noch die neuen Cardex-Funktionen.

Es wurden keine privaten Unterhaltungen, fremden Kartentexte oder Zugangsdaten in das Repository übernommen. Recherche und ausgeschlossene Kandidaten: [FreeRoleplayModels.md](FreeRoleplayModels.md).
