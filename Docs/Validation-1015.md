# Kai 1.7.1 / Build 1015

Geprüft am 14. November 2026. [IPA für SideStore](https://github.com/r0bby97/kai-ios-build/releases/download/build-1015/Kai-1.7.1-b1015.ipa). Build und Tests wurden am 11. November abgeschlossen; die Veröffentlichung wird nach der Sitzungsunterbrechung fertig dokumentiert. Quellstand `fa75f417d6fd38fcdcdc820fc2d83e1217b4e22c`.

## Änderungen

HTML wird als Text interpretiert, ohne Webansicht, Skriptausführung oder Laden eingebetteter Ressourcen. Absätze, Listen und Tabellenzeilen bleiben lesbar; CSS, Skripte und Layout-Tags werden entfernt. Numerische und häufige benannte Entities werden decodiert. Koreanische Schrift, Kartenvariablen und Datenstrukturen bleiben erhalten. Normale Prosa, Vergleiche und Rollenspiel-Steuermarker werden nicht pauschal als Tags entfernt. Nicht erkannte Formate bleiben erhalten. Die Originalkarten werden nicht überschrieben.

Die Aufbereitung greift in Kartenansicht, Tagline, Begrüßungsanzeige, Chatdarstellung, Spracherkennung, Übersetzungsanfragen, Charakterdefinition und vorhandenem Figurenverlauf/Weltwissen für die KI. Bereits gespeicherte Karten und Chatbegrüßungen profitieren ohne erneuten Import.

Horde berücksichtigt weitere geeignete Familien, bis zu 32 passende Rechner mit höchstens fünf Modellen und die deklarierte Ausgabe-Geschwindigkeit im Verhältnis zur Server-Bearbeitungszeit. Nach ausdrücklichem NoEligibleWorker wird genau einmal aktualisiert und mit höchstens 256 Ausgabe-Tokens erneut versucht. Persönlichkeit und Nachrichten bleiben unverändert. Anmeldefehler und Kontingente werden respektiert.

## Nachweise

- Öffentlicher [Lauf 43042120432](https://github.com/r0bby97/kai-ios-build/actions/runs/43042120432): **137 Kernlogiktests, 31 iOS-Diensttests und acht betroffene UI-Tests bestanden**, keine Fehler.
- UI: strukturierte Eigenschaften mit eingebettetem HTML, Antwort-Fallback/Speicherung, zweiter Gesprächszug mit Anbieterwechsel, zwei lange Antworten bei offener Tastatur, Profil/Entwurf, fehlende Sprachpakete, öffentliche Originalkarten sowie Bibliothek/Einstellungen/Gesprächsstart.
- Kernlogik: koreanische Absätze/Listen, Entities, Attribute mit Winkelklammern, verschachtelte Daten, keine CSS-Übersetzungsanfragen, alter HTML-Verlauf/Lore, unveränderte Texte/Variablen; Horde-Ausgabegrenzen, fünf Modell-IDs und unveränderter Kontext beim Wiederholungsversuch.
- Die übrigen UI-Fälle wurden für diese gezielte Korrektur nicht erneut ausgeführt. Ihr letzter Nachweis steht in [Validation-1012.md](Validation-1012.md).
- Zwei neutrale echte Horde-Tests am 11. November: erweiterter Pool lieferte über G4-MeroMero eine deutsche Antwort. Kais tatsächlicher Swift-Client lieferte mit vollständiger Charakterdefinition und ca. 1845 geschätzten Kontext-Tokens in 9,57 Sekunden eine deutsche Antwort über Vesper/Nocturne. Ausgabe auf 256 Tokens begrenzt, Abschluss `length`.

Der erste Fehlercode vor der Begrenzung wurde im Live-Clienttest nicht aufgezeichnet; die Ausgabe-Begrenzung kann auch aus dem anonymen Kudos-Kontingent stammen. Das ist kein Beweis für die genaue Ursache der persönlichen NoEligibleWorker-Anfrage. Der explizite NoEligibleWorker-Wiederholungsfall ist separat mit kontrollierten Serverantworten geprüft.

## IPA

Heruntergeladen und geprüft: gültige ZIP-Prüfsummen, Version 1.7.1 / Build 1015, stabile Kennung `dev.r0bby97.faden`, iPhoneOS arm64, enthaltene Metal-Bibliothek. Beide Release-Dateinamen haben identische Bytes; der GitHub-Digest stimmt mit der lokalen SHA-256 überein. UI-Testflags und Testantworten fehlen im Geräteprogramm.

Größe: 14340096 Bytes. SHA-256: `f95be60db89b670347bbe39f29f144a5417665d8186a613a997718aa12ba5a50`.

GitHub meldet **0 abrechenbare macOS-Minuten**. Private Runner bleiben gesperrt; kein weiterer Build wurde für die abschließende Dokumentation gestartet.

Horde-Kapazität bleibt dynamisch. Kürzere Antworten und ein Wechsel zur nächsten eingerichteten Verbindung können weiterhin nötig sein. Echte Apple-Übersetzungen auf dem iPhone bleiben gesondert zu prüfen; der Simulator stellt diese Sprachmodelle nicht bereit.
