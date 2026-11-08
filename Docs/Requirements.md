# Kai – Abgleich der vereinbarten Anforderungen

Stand: 8. November 2026. „Implementiert“ beschreibt den Quellcode, nicht die erfolgreiche Abnahme mit den Konten und dem iPhone des Nutzers. Die App ist noch nicht als vollständig abgenommen freigegeben.

| Anforderung | Tatsächlicher Stand |
| --- | --- |
| iPhone-App ohne eigenen Mac, IPA für SideStore | SwiftUI-Projekt und öffentlicher macOS-Build vorhanden. Die endgültige IPA-Freigabe steht aus. |
| Frische Installation | Mit derselben stabilen App-Kennung möglich, indem die bisherige Installation vorher entfernt wird. Dabei werden lokale Chats und Downloads gelöscht. |
| Name Kai und ausgewähltes Symbol | Implementiert. |
| Öffentliche Karten schon beim Start | Chub-Vorschauen werden automatisch nach Beliebtheit geladen; 24/60/120 Karten können vorbereitet werden, Standard 60. Keine erfundenen Beispielkarten in der normalen Entdecken-Ansicht. |
| Originalbilder und kartenabhängiger Chat-Hintergrund | Implementiert; Bilder werden unabhängig vom Text nachgeladen und lokal zwischengespeichert. |
| Aussagekräftige Karten im Menü | Name, Kurzbeschreibung, Tags, Bild und Quelle werden dargestellt. Janny-Export soll diese Angaben erhalten, wenn sie in der PNG fehlen; dafür ist ein neuer vollständiger Transporttest vorgesehen. |
| JannyAI vollständig automatisch importieren | **Offener Abnahmeblocker.** Direkter Export plus automatischer regulärer Browser-Download implementiert. Live-Suche funktioniert; drei geprüfte Exporte und eine Originalseite werden vom Arbeitsrechner mit HTTP 403 / Cloudflare challenge gesperrt. Keine erfolgreiche Live-Abnahme behauptet. |
| Eigener PNG-/JSON-Import und Karteneditor | Implementiert. |
| Deutsch, keine Sortierung oder Sperre nach Ausgangssprache | Deutsche Oberfläche und Antwortvorgabe. Apple übersetzt die Kartendefinition einschließlich Begrüßungen; Sprachpakete werden ausdrücklich eingerichtet. Tatsächliche Übersetzung mit installierten Paketen noch auf einem iPhone zu prüfen. |
| Beliebtheit statt ausschließlich deutsche Karten | Chub nach Beliebtheit, unabhängig von der Ausgangssprache. JannyAI liefert Suchrelevanz und keine verlässlichen Beliebtheitswerte; eine beliebtheitsbasierte Reihenfolge ist dort nicht zugesichert. |
| Online entdecken, Bibliothek, Chatübersicht, Suche und Filter | Implementiert; Bibliothek enthält lokal gespeicherte Karten. Online-Suche ist davon getrennt. |
| Genres einschließlich Omegaverse, Guideverse und BDSM | Implementiert für Bibliothek und beide Suchquellen. Chub verwendet für Guideverse und BDSM die Textsuche, weil die entsprechenden Tags keine Treffer liefern. |
| Personas, Szenarien und Gruppen | Implementiert, einschließlich Erkennung von Mehrpersonen-Karten und zusätzlicher Kombination eigener Karten. |
| Gesprochener Text, private Gedanken und sonstiger Erzähltext | Klassifikation und Promptregeln implementiert. Anführungszeichen markieren Rede; Sternchen Gedanken. Unmarkierter Text wird nicht automatisch als Rede behandelt. Modelltreue bleibt im echten Gespräch zu prüfen. |
| Keine Übernahme meiner Rede, Gedanken oder Entscheidungen | Wiederkehrende Regeln und Kontextbudget für Charakter/Perspektive implementiert. Kein Modell kann dafür eine fehlerfreie Ausgabe garantieren. |
| Charakterpersönlichkeit und Schreibstil merken | Charakterregeln, branchenspezifischer Kontext, ältere Auszüge und bearbeitbare Schreibvorlieben implementiert. Kein unbegrenztes Modell-Kontextfenster. |
| Chat zurückspulen und Zweige anlegen | Implementiert; Erinnerung und Stil folgen dem gewählten Zweig. |
| Schnell zum Anfang und Ende scrollen | Implementiert, ohne den Verlauf zurückzusetzen. |
| Ungesendete Entwürfe erhalten | Speicherung pro Gespräch bei Navigation, Hintergrundwechsel und Neustart implementiert. |
| Dunkel/Hell und Liquid-Animationen | Implementiert für Menüs; Chat-Hintergrund bleibt kartenabhängig. Einstellungen zu reduzierter Bewegung/Transparenz werden berücksichtigt. |
| Antwortlänge, z. B. bis 400 Wörter | Implementiert mit Wortobergrenze und begrenztem Ausgabetokenbudget. |
| Gelegentliche separate Gedanken/Erinnerungen der Figur | Implementiert; abschaltbar, etwa alle 10 oder 20 Antworten, getrennt vom Dialog. |
| Anbieter nach Priorität verschieben, bei verbrauchtem Kontingent wechseln | Implementiert; kontoweite Limits sperren weitere Modelle desselben Kontos. Begonnene Antworten werden nicht mit einem anderen Modell vermischt. |
| Kostenlose Cloud und automatischer Modellwechsel | OpenRouter/free plus begrenzte Auswahl aktuell kostenlos gelisteter Textmodelle implementiert. Tageslimits, Verfügbarkeit und Inhaltsregeln gelten weiterhin. |
| ChatGPT Plus anmelden | Offizieller Anmeldeweg implementiert. Erfolgreiche Generierung mit dem konkreten Nutzerkonto nach den Korrekturen noch nicht bestätigt. |
| Fünf weitere verbreitete Anbieter / Premium-Konten | OpenAI-, Claude-, Gemini-, Grok- und DeepSeek-API-Anbindungen implementiert. **Keine universelle Anmeldung mit deren Verbraucher-Premium-Abos.** API-Abrechnung und Abo-Leistungen sind getrennt. |
| Verbleibendes ChatGPT-Kontingent und Reset anzeigen | **Keine verlässliche Live-Anzeige implementiert.** Bisher nur Verweis auf die offizielle Nutzungsübersicht; keine erfundenen Resttoken oder Reset-Zeiten. |
| Lokales kleines Modell | MLX/Qwen-Anbindung und kurzer Generierungstest implementiert. Erfolgreiche Antwort und Leistung auf dem konkreten iPhone noch zu bestätigen. |
| Freie 18+-Themen einschließlich expliziter Sexualität und Gewalt | **Durch die bisherige Modellauswahl nicht zuverlässig erfüllt.** Ein 18+-Katalogschalter ersetzt keine passende, dafür zugelassene Modell-/Betreiberkombination. |
| Limits umgehen / ständig Konten neu erzeugen | Nicht implementiert. Anbieterlimits werden respektiert; kein automatisches Anlegen neuer Konten. |
| Verständliche Fehler statt nur „kein Text“ | Transportdaten, HTTP-Status, Ereignisse, Textlänge, Tokenangaben und Abschlussgrund werden getrennt protokolliert. Keine Zugangsdaten oder Chattexte in Fehlerberichten. |
| Verwendung vor Freigabe testen | Kernlogik, Transport und Bedienung werden automatisiert geprüft. Live-Janny, tatsächliche KI-Konten, Apple-Sprachpakete und lokales MLX auf Hardware sind noch keine bestandene Gesamtabnahme. |

## Konkrete JannyAI-Prüfung

Die installierte Version 1.5 verwendete für Download-URLs die Prüfung einer API-Basisadresse (`HTTP.requireHTTPS`) und eine Sitzung ohne Weiterleitungen. Das konnte signierte URLs mit Parametern und reguläre CDN-Weiterleitungen ablehnen. Der neue Code trennt diese Dateidownloads von authentifizierten API-Verbindungen. PNG-Metadaten liefern die echte Chatdefinition; Suchtexte werden nicht als Persönlichkeit ausgegeben. Eine Website-Verifikation, ein nicht archivierter Treffer und ein ungültiger Export erhalten unterschiedliche Fehler.

Die Browserstrecke verwendet die normalen öffentlichen Download-Steuerelemente und übernimmt die fertige PNG-/JSON-Datei automatisch. Es werden keine fremden Sitzungstokens ausgelesen, keine Prüfungen gelöst und keine verborgenen Definitionen rekonstruiert. Solange keine vollständige Live-Karte erfolgreich importiert wurde, bleibt die Anforderung offen.
