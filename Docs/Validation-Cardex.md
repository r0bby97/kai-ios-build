# Cardex und gemeinsame Entdecken-Ansicht

Stand: 9. November 2026. Quellcode vorbereitet; kein neuer GitHub-Actions-Lauf und keine neue IPA gestartet. Der bisherige Download Build 1007 enthält diese Änderungen noch nicht.

## Änderungen

- Unter „Online entdecken“ stehen „Alle“, „Cardex“, „Chub“ und „JannyAI“ zur Auswahl. Neue Installationen starten mit „Alle“; eine zuvor gewählte Datenbank bleibt erhalten.
- Cardex verwendet die öffentliche JSON-API für Suche, Kartenmetadaten und vollständigen Kartenexport. Suchvorschauen werden nicht als Definition importiert. Ein Browser und ein Kartenkonto sind dafür nicht erforderlich.
- Omegaverse, Guideverse und BDSM sowie die vorhandenen Genres werden als Cardex-Tags gesucht. Es gibt keinen Sprachfilter. Die vorhandene Apple-Übersetzung übernimmt Vorschau und vollständige Karte.
- Die gemeinsame Suche startet Quellen parallel, veröffentlicht fertige Ergebnisse sofort und erhält die Reihenfolge innerhalb jeder Quelle. Beliebtheitswerte verschiedener Anbieter werden nicht miteinander verrechnet.
- Jede Quelle behält ihren eigenen Seitenstand beziehungsweise Cardex-Cursor. Ausgefallene Quellen lassen sich separat erneut versuchen, ohne erfolgreiche Seiten zu überspringen. Doppelte IDs werden nicht erneut eingefügt; unterschiedliche Archiv- und Originaleinträge sind nicht pauschal als dieselbe Karte erkannt.
- Die Übersicht nennt die Quelle jeder Karte. Archiv-Tag-Zähler werden nicht als gefilterte Trefferzahlen ausgegeben.
- Direkte Importe erhalten Definition, Szenario, Startnachricht, Lorebook, Tags, Urheberangaben und das zugehörige Kartenbild. Gespeicherte Cardex-Bilder werden über die bestehende Bildpipeline im Hintergrund lokal zwischengespeichert; fertige Übersetzungen und Bearbeitungen bleiben dabei erhalten.
- Scheitert ein JannyAI-Import, öffnet sich kein Browser automatisch. Ein regulärer Website-Download bleibt als optionale Aktion vorhanden. Ein erfolgreicher direkter JannyAI-Download wird weiterhin nicht behauptet.

## Bestandene lokale Prüfungen

1. **75 Swift-Kernlogiktests, null Fehler.** Darunter zwölf neue Tests: vollständiger Transport Suche → Metadaten → Export, Originalbildzuordnung, Lorebook, Cursor, 18+-Filter, ungültige/verborgene Exporte, HTTP-Fehler, Teilergebnisse, getrennte Seitenstände, Deduplizierung und Abbruch.
2. **Echter neuer Cardex-Client:** je 24 Vorschauen für Omegaverse, Guideverse und BDSM. Die Abrufe lagen im erfolgreichen Durchlauf bei ungefähr 0,9–1,8 Sekunden auf dem Arbeitsrechner. Das ist keine Geschwindigkeitszusage für das iPhone oder andere Netze.
3. **Stichwortsuche:** „alpha“ lieferte im echten neuen Client 24 Treffer in etwa 1,9 Sekunden. Eine direkt aus diesen Suchtreffern ausgewählte Karte ließ sich vollständig mit Definition, Startnachricht und Originalbildadresse importieren. Cardex liefert derzeit bei Stichwortsuche plus Beliebtheit HTTP 500; Kai verwendet dafür den funktionierenden Relevanzmodus und zeigt diese Sortierung an. Reine Genreansichten behalten Beliebtheit.
4. **Echtes Nachladen:** zweite Omegaverse-Seite mit weiteren 24 Karten und ohne wiederholte IDs. Dabei wurde ein realer HTTP-400-Fehler korrigiert: Cardex akzeptiert einen Cursor nicht zusammen mit einer Seitennummer größer als eins. Der Regressionstest prüft die korrigierte Anfrage.
5. **Echter vollständiger Import:** der neue Client las eine öffentliche Omegaverse-Karte mit 11.982 Zeichen Definition, 342 Zeichen Szenario und 3.139 Zeichen Startnachricht ein. Das aus den Kartenmetadaten zugeordnete Originalbild lieferte HTTP 200 und 166.394 Bytes. Keine manuelle Browseraktion und keine Anmeldung.
6. **Gemeinsamer App-Suchdienst:** der unveränderte Suchcode aus `App/Services/Catalogue.swift` und `JannyCatalogue.swift` wurde mit einem Linux-URLSession-Adapter ausgeführt. Erste und zweite Omegaverse-Seite lieferten jeweils 24 Cardex- und 24 JannyAI-Vorschauen; Chub lieferte für diesen Tag keine Treffer. Zwischen den Seiten gab es keine wiederholten IDs. Das prüft die Suche, nicht den weiterhin blockierten JannyAI-Download.
7. **Swift-Syntaxprüfung** der geänderten nativen App- und UI-Testdateien sowie `git diff --check` bestanden.

## Noch offen vor IPA-Freigabe

Der neue native UI-Test `testAllSourcesAndCardexAreSelectable` ist vorbereitet, aber noch nicht ausgeführt. SwiftUI-Typprüfung, native Bildcache-Persistenz, Apple-Übersetzung mit installierten Sprachpaketen und die Bedienung der neuen Auswahl sind auf iOS noch zu prüfen. Die Linux-Livetests prüfen keine SwiftUI-Oberfläche und ersetzen diese Abnahme nicht.

Es wurden keine privaten Chats, API-Zugangsdaten oder vollständigen fremden Kartentexte in das öffentliche Repository übernommen. Die neue KI-Recherche ist in [FreeRoleplayModels.md](FreeRoleplayModels.md) dokumentiert; AI Horde ist inzwischen angebunden; die separaten Prüfungen stehen in [Validation-RoleplayProviders.md](Validation-RoleplayProviders.md).
