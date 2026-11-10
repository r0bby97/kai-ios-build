# Kai 1.7: Gesprächs- und Entdecken-Korrekturen

Stand: 10. November 2026. 125 Linux-Kernlogiktests bestanden. Die native Freigabe steht vor dem nächsten vollständigen öffentlichen CI-Lauf noch aus. Tests mit kontrollierten Antworten belegen den Ablauf, keine allgemeine literarische Qualität.

## Tatsächliche Funktionsänderungen

- Derselbe aktive Gesprächszweig erreicht jeden ausgewählten Backend-Typ. Eine initiale Kartenbegrüßung bleibt Figurenverlauf im Systemkontext; sie wird nicht als erfundene Nutzernachricht ausgegeben. Aufeinanderfolgende Gruppenbeiträge werden mit Sprecherzuordnung zusammengeführt. Der jüngste Nutzer- und Figurenbeitrag bekommt vorrangig Platz; bekannte Modellgrenzen und ein lokales Maximum von 8192 Tokens begrenzen den Prompt. Unterbrochene Antworten enthalten keine unterstellte Fortsetzung.
- Persönlichkeitsdaten stehen getrennt vom Hintergrund. Verschachtelte Persönlichkeitswerte werden erkannt. Ein kurzer Kern und die Regel, schroffe Figuren nicht automatisch gefällig werden zu lassen, werden am Ende jeder Systemanweisung erneut gesetzt. Das Budget reserviert weiterhin jüngste Dialogbeiträge. Ein kleines 1.7B-Modell wird dadurch nicht so leistungsfähig wie ein größeres Modell.
- Sternchentexte der Nutzerfigur werden vor Anfrage, älteren Auszügen, Lore-Suche und Stilbeispielen entfernt. Erinnerungen, die aus einer Nachricht mit privaten Gedanken stammen, werden vorsorglich ganz aus dem Figurenkontext ausgelassen. Im lokalen Chat bleiben sie erhalten. Bereits früher vom Modell ausgesprochene Lecks werden nicht rückwirkend aus alten Figurenantworten gelöscht.
- OpenRouter-HTTP-401 wird nicht blind als defekter Schlüssel behandelt: Nur wenn GET /api/v1/key den Schlüssel bestätigt, wird der Fehler modellbezogen und ein anderes Modell darf folgen. Scheitert die Prüfung, bleibt der ursprüngliche Zugriffsfehler erhalten. Reihenfolge-/Kontext-/Parameterfehler werden ohne Ausgabe roher Servertexte klassifiziert. Der konkrete persönliche HTTP-400-Fall ist ohne dessen Diagnose nicht sicher einer Ursache zugeordnet.
- Horde NoEligibleWorker erhält genau einen neuen Kapazitätsabruf vor einem begrenzten neuen Versuch, nachdem kein Job angenommen wurde. Freies Ausgabelimit darf die Antwort verkürzen, nicht System oder Verlauf. Echte Kapazität entsteht dadurch nicht. Authentifizierung, Inhaltsablehnung und Kontolimits werden nicht umgangen.
- Ein UIKit-Scroll-Anker besitzt die Position; konkurrierende SwiftUI-Standardanker sind entfernt. Er folgt Größen-/Tastaturänderungen beim Schreiben und Streamen. Manuelles Wegscrollen pausiert das Folgen; Pfeile bleiben reine Navigation ohne Rückspulen.
- Profilbild und Name öffnen die bestehende Karte. Bei mehreren Karten erfolgt erst die Auswahl. Der Inspektor eröffnet kein zweites Gespräch. Separate Persönlichkeitsfelder werden auch dann angezeigt, wenn die Karte eine Beschreibung besitzt.

## Entdecken

Online ist die Standardansicht. Die Quellen sind Alle, Cardex und Chub; gespeicherte JannyAI-Auswahl migriert auf Alle, alte vollständige Karten bleiben verwendbar. Eine Archivvorschau ohne Definition wird nicht erfunden. Geschlecht verwendet explizite Karten-Tags, keine Namens- oder POV-Vermutungen. Mehrere/unklare Figuren werden Diverse / Weitere zugeordnet. Gender- und Genre-Filter lassen sich kombinieren. Genres sind deutsch alphabetisch sortiert, Alle zuerst. Aktive Kriterien und Zurücksetzen sind direkt sichtbar, weitere Filter in einem Blatt.

Live-Cardex-Prüfung: männliches Omegaverse, zweite Seite ohne doppelte IDs und weibliches Omegaverse lieferten gefilterte Karten über den tatsächlichen Core-Suchdienst. Chub-Tags wurden ebenfalls live geprüft. Quellenübergreifende Beliebtheitszahlen werden nicht als vergleichbare globale Rangliste ausgegeben.

## Vor der IPA erforderliche native Prüfung

- Alle Diensttests einschließlich echter Request-Serialisierung des zweiten OpenRouter-Zugs, bestätigter Modell-401 versus Schlüssel-401 und Modell-Kontextgrenze.
- Alle UI-Tests einschließlich zwei Zügen mit Anbieterwechsel, dauerhaftem Entwurf beim Öffnen des Profils, zweimal langer gestreamter Antwort bei offener Tastatur, Pfeilnavigation, unabhängigen Genre-/Gender-Filtern und Übersetzungseinrichtung.
- Geräte-Build ohne KAI_TESTING: ZIP/Version/Build/arm64/Metal und Ausschluss aller Testantworten und Startflags prüfen.

Der Nutzer bestätigt kurze echte Testantworten über kostenlose Cloud, AI Horde, lokales Qwen und ChatGPT Plus. Diese Rückmeldung bestätigt keine vollständigen Rollenspiele. Echte Übersetzung, individuelle Modellannahme, Gedächtnisqualität und Wärmeentwicklung auf dem iPhone bleiben gesonderte Geräteprüfungen. Ohne persönliche Schlüssel können diese Konten hier nicht nachgestellt werden.
