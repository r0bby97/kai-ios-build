# Kai – Abgleich der vereinbarten Anforderungen

Stand: 10. November 2026. [Build 1012](Validation-1012.md) deckt 126 Kernlogik-, 31 iOS-Dienst- und alle 24 Oberflächenfälle aus Vollprüfung und gezieltem Nachlauf ab; die heruntergeladene IPA ist geprüft. „Implementiert“ beschreibt keine erfolgreiche Abnahme mit sämtlichen Konten und dem iPhone des Nutzers. Die App ist noch nicht als vollständig auf dem echten Gerät abgenommen freigegeben.

| Anforderung | Tatsächlicher Stand |
| --- | --- |
| iPhone-App ohne eigenen Mac, IPA für SideStore | SwiftUI-Projekt und öffentlicher macOS-Build vorhanden. IPA 1.7.0 / 1012 nach nativen Prüfungen gebaut und heruntergeladen geprüft. |
| Frische Installation | Mit derselben stabilen App-Kennung möglich, indem die bisherige Installation vorher entfernt wird. Dabei werden lokale Chats und Downloads gelöscht. |
| Name Kai und ausgewähltes Symbol | Implementiert. |
| Öffentliche Karten schon beim Start | Chub-Vorschauen werden automatisch nach Beliebtheit geladen; 24/60/120 Karten können vorbereitet werden, Standard 60. Keine erfundenen Beispielkarten in der normalen Entdecken-Ansicht. |
| Originalbilder und kartenabhängiger Chat-Hintergrund | Implementiert; Bilder werden unabhängig vom Text nachgeladen und lokal zwischengespeichert. |
| Aussagekräftige Karten im Menü | Name, Kurzbeschreibung, Tags, Bild und Quelle werden dargestellt. Kontrollierte native Transporttests bestätigen den Erhalt dieser Angaben auch bei fehlenden PNG-Katalogmetadaten. JannyAI ist auf Wunsch nicht mehr als aktive Quelle enthalten. |
| JannyAI entfernen | Auf Wunsch aus aktiver Suche und Quellenwahl entfernt. Alte vollständige Importe bleiben erhalten; neue Suche verwendet Cardex und Chub. |
| Cardex als weitere Datenbank | Echte Live-Suche für Omegaverse, Guideverse und BDSM, Nachladen sowie vollständiger JSON-Import mit zugehörigem Kartenbild lokal geprüft. SwiftUI-Typprüfung und Auswahl im iPhone-Simulator bestanden. Echte Geräteabnahme bleibt offen. |
| Alle Quellen unter Online entdecken | Implementiert: Alle, Cardex, Chub. Treffer erscheinen je Quelle unabhängig; Fehler und Seitenstände bleiben getrennt. Gemeinsame Live-Suche über den App-Suchdienst, Kernlogiktests und neuer iOS-Bedientest bestanden. |
| Eigener PNG-/JSON-Import und Karteneditor | Implementiert. |
| Deutsch, keine Sortierung oder Sperre nach Ausgangssprache | Deutsche Oberfläche und Antwortvorgabe. Apple übersetzt die Kartendefinition einschließlich Begrüßungen; Sprachpakete werden ausdrücklich eingerichtet. Tatsächliche Übersetzung mit installierten Paketen noch auf einem iPhone zu prüfen. |
| Beliebtheit statt ausschließlich deutsche Karten | Chub nach Beliebtheit, unabhängig von der Ausgangssprache. Cardex nutzt Beliebtheit bei Genre-Browsing und Quellrelevanz bei Stichwortsuche. Quellenwerte werden nicht global gleichgesetzt. |
| Online entdecken, Bibliothek, Chatübersicht, Suche und Filter | Implementiert; Bibliothek enthält lokal gespeicherte Karten. Online-Suche ist davon getrennt. |
| Genres einschließlich Omegaverse, Guideverse und BDSM | Implementiert für Bibliothek, Chub und Cardex. Chub verwendet für Guideverse und BDSM die Textsuche, weil die entsprechenden Tags keine Treffer liefern. |
| Personas, Szenarien und Gruppen | Implementiert, einschließlich Erkennung von Mehrpersonen-Karten und zusätzlicher Kombination eigener Karten. |
| Gesprochener Text, private Gedanken und sonstiger Erzähltext | Private Sternchentexte bleiben lokal und werden aus KI-Anfrage, Auszügen und Stilbeispielen entfernt. Anführungszeichen markieren Rede. Unmarkierter Text wird nicht automatisch als Rede behandelt. Modelltreue bleibt im echten Gespräch zu prüfen. |
| Keine Übernahme meiner Rede, Gedanken oder Entscheidungen | Wiederkehrende Regeln und Kontextbudget für Charakter/Perspektive implementiert. Kein Modell kann dafür eine fehlerfreie Ausgabe garantieren. |
| Charakterpersönlichkeit und Schreibstil merken | Charakterregeln, branchenspezifischer Kontext, ältere Auszüge und bearbeitbare Schreibvorlieben implementiert. Kein unbegrenztes Modell-Kontextfenster. |
| Chat zurückspulen und Zweige anlegen | Implementiert; Erinnerung und Stil folgen dem gewählten Zweig. |
| Schnell zum Anfang und Ende scrollen | Implementiert, ohne den Verlauf zurückzusetzen. |
| Ungesendete Entwürfe erhalten | Speicherung pro Gespräch bei Navigation, Hintergrundwechsel und Neustart implementiert. |
| Dunkel/Hell und Liquid-Animationen | Implementiert für Menüs; Chat-Hintergrund bleibt kartenabhängig. Einstellungen zu reduzierter Bewegung/Transparenz werden berücksichtigt. |
| Antwortlänge, z. B. bis 400 Wörter | Implementiert mit Wortobergrenze und begrenztem Ausgabetokenbudget. |
| Gelegentliche separate Gedanken/Erinnerungen der Figur | Implementiert; abschaltbar, etwa alle 10 oder 20 Antworten, getrennt vom Dialog. |
| Anbieter nach Priorität verschieben, bei verbrauchtem Kontingent wechseln | Implementiert; kontoweite Limits sperren weitere Modelle desselben Kontos. Begonnene Antworten werden nicht mit einem anderen Modell vermischt. |
| Kostenlose Cloud und automatischer Modellwechsel | AI Horde mit anonymem Zugang, Kapazitätsprüfung, Wartestatus und Abbruch eingebaut; deutsche Live-Antworten über Mini-Magnum, Stheno und Cydonia erhalten. Arli-Testzugang ergänzt, klein limitiert. OpenRouter/free bleibt verfügbar. Keine Konto-Neuanlage zum Umgehen von Limits. |
| Weitere KI-Anbieter für erwachsene Rollenspiele | Arli, NanoGPT und Venice als offizielle API-Optionen ergänzt. Arli hat ein kleines Gratis-Testkontingent; NanoGPT und Venice sind kostenpflichtig und bei aktiver Kostensperre ausgeschlossen. Persönliche API-Konten noch nicht abgenommen. |
| Inhaltsrichtwerte in der KI-Rangfolge | Implementiert und neuer nativer Bedientest bestanden: Erotik und fiktive Gewalt getrennt, mit Erklärung und Quellenlink. Je nach Anbieter und Modellauswahl viel Freiraum, eingeschränkt, modellabhängig oder ungeprüft. Keine vorgetäuschte Prozentfreigabe. |
| ChatGPT Plus anmelden | Offizieller Anmeldeweg implementiert. Kurze echte Testantwort vom Nutzer bestätigt; lange mehrzügige Rollenspiele separat zu prüfen. |
| Fünf weitere verbreitete Anbieter / Premium-Konten | OpenAI-, Claude-, Gemini-, Grok- und DeepSeek-API-Anbindungen implementiert. **Keine universelle Anmeldung mit deren Verbraucher-Premium-Abos.** API-Abrechnung und Abo-Leistungen sind getrennt. |
| Verbleibendes ChatGPT-Kontingent und Reset anzeigen | **Keine verlässliche Live-Anzeige implementiert.** Bisher nur Verweis auf die offizielle Nutzungsübersicht; keine erfundenen Resttoken oder Reset-Zeiten. |
| Lokales kleines Modell | MLX/Qwen-Anbindung und kurzer Generierungstest implementiert. Kurze echte Antwort vom Nutzer bestätigt; Qualität und Wärmeentwicklung bei langen Chats weiter zu prüfen. |
| Freie 18+-Themen einschließlich expliziter Sexualität und Gewalt | AI Horde mit NSFW-Chat-Rechnern und weitere passende API-Optionen ergänzt. Inhaltsrichtwerte sind sichtbar. Harmlose Live-Rollenspiele funktionieren; die Ausgabe jeder konkreten expliziten Szene wird nicht zugesichert. Modell- und Betreiberregeln gelten weiterhin. |
| Limits umgehen / ständig Konten neu erzeugen | Nicht implementiert. Anbieterlimits werden respektiert; kein automatisches Anlegen neuer Konten. |
| Verständliche Fehler statt nur „kein Text“ | Transportdaten, HTTP-Status, Ereignisse, Textlänge, Tokenangaben und Abschlussgrund werden getrennt protokolliert. Keine Zugangsdaten oder Chattexte in Fehlerberichten. |
| Verwendung vor Freigabe testen | Build 1012: 126 Kernlogik-, 31 iOS-Dienst- und alle 24 Oberflächenfälle über Vollprüfung und Nachlauf bestanden. Echte Horde-Generierung und Cardex-Suche/-Import zusätzlich geprüft. Live-Janny, tatsächliche persönliche KI-Konten, Apple-Sprachpakete und lokales MLX auf Hardware sind noch keine bestandene Gesamtabnahme. |

## Änderungen in der geprüften IPA

Die Änderungen sind gebaut und geprüft; [Validation-1012.md](Validation-1012.md) erklärt den vollständigen Testlauf, zwei korrigierte UI-Fälle und den gezielten Nachlauf. Details: [ConversationFixes.md](ConversationFixes.md) und [TranslationFix.md](TranslationFix.md).

Enthalten: Online als Startansicht, unabhängige Gender-/Genre-Filter mit alphabetischen Genres, lesbare Datenstrukturen, Profil öffnet Karte, Gesprächsstart nach nur gewählter Begrüßung, verbesserte Mehrsprachübersetzung, privater Gedankeninhalt bleibt lokal, portabler Modellwechsel, stärkere Persönlichkeitsverankerung, Tippfehlertoleranz und einheitliches Scroll-Verhalten. Reale Apple-Übersetzungen auf dem iPhone und die konkreten persönlichen OpenRouter-Fehler sind damit noch nicht als vollständig erfolgreich abgenommen bestätigt.

Die geprüften Anbieterregeln sind in [ProviderContentRules.md](ProviderContentRules.md) getrennt nach Erotik und Gewalt dokumentiert.
