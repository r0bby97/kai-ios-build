# Kai auf deinem iPhone

Kai hieß vorher Faden. Installation und Updates verwenden weiterhin dieselbe App-Kennung; Chats, Entwürfe und Anmeldungen bleiben im vorhandenen App-Speicher.

## Installation mit vorhandenem SideStore

1. Die Datei **Kai.ipa** auf dem iPhone in Dateien speichern.
2. In SideStore über **+** diese IPA auswählen und mit demselben Apple-Konto signieren, das du bereits verwendest.

Die App-Kennung bleibt `dev.r0bby97.faden`. Für spätere Versionen die neue IPA als Update derselben App installieren. Die App nicht vorher löschen. Vor einem Update in Kai unter **Einstellungen → Backup exportieren** eine zusätzliche Sicherung erstellen.

SideStore muss die Signatur rechtzeitig erneuern. Beim kostenlosen Apple-Konto gelten weiterhin dessen App- und Signaturlimits; die App enthält keine Erweiterungen und benötigt keine zweite App-Kennung.

## Erster Start

- Unter **Entdecken → Deine Bibliothek** erscheinen öffentliche Originalkarten. Alte mitgelieferte Beispielkarten werden ausgeblendet; vorhandene Chats bleiben erhalten.
- Beim ersten Start bereitet Kai bis zu 60 beliebte öffentliche Chub-Karten vor. Namen und Vorschautexte erscheinen pro Katalogseite sofort. Definitionen und unveränderte Originalbilder werden anschließend mit begrenzter Parallelität lokal gespeichert. Unter **Karten vorbereiten** sind 24, 60 oder 120 Karten wählbar; Abbrechen behält bereits geladene Karten. Der restliche Katalog bleibt über **Online entdecken** zugänglich.
- Unter **Online entdecken** lädt die App Charaktere direkt aus Chub. Suche, weitere Ergebnisse und der Schalter für Inhalte für Erwachsene stehen dort bereit. Eine Online-Karte vor dem ersten Gespräch vollständig laden lassen.
- Eigene PNG-/JSON-Karten lassen sich über **+ → Karte importieren** ergänzen. Eigene Figuren können direkt in der App erstellt werden.
- **Gespräche** zeigt deine bisherigen Chats mit letzter Nachricht und Suchfunktion. Auf einer bereits verwendeten Karte führt **Gespräch fortsetzen** zum jüngsten Einzelkarten-Chat; **Neues Gespräch beginnen** startet einen getrennten Verlauf.
- Genre-Schaltflächen, Kartentyp (einzelne Figur oder Gruppenkarte) und Favoriten helfen beim Suchen. Bei **Online entdecken** wird das Genre direkt an Chub übergeben. Kartentyp und Favoriten filtern die geladenen Treffer; **Weitere Charaktere laden** durchsucht weitere Seiten. Die Reihenfolge bleibt nach Beliebtheit, ohne Sprachfilter.

## Darstellung, Schreibweise und Entwürfe

Unter **Einstellungen → Darstellung** kannst du zwischen **Dunkel** und **Hell** umschalten. Dunkel ist vorausgewählt. Diese Einstellung gilt nur für Menüs. Der Chat verwendet immer das Bild seiner Hauptkarte als Hintergrund, mit abgedunkelten Textflächen für die Lesbarkeit. Bei einer Kombination mehrerer Karten bleibt das Bild der zuerst gewählten Karte der Hintergrund.

- `„Das sage ich dir.“` oder `"Das sage ich dir."`: ausdrücklich zum Gegenüber gesprochene Rede.
- `*Das denke ich nur.*`: private Gedanken oder innere Erzählregie. Anführungszeichen innerhalb von Gedanken machen sie nicht hörbar.
- Text ohne Anführungszeichen ist Erzählkontext und wird nicht automatisch gesprochen. Sichtbare Handlungen können wahrgenommen werden; Selbstgespräche und Gedanken werden nicht automatisch geteilt.

Die App übermittelt diese Abschnitte getrennt gekennzeichnet und fordert die KI auf, Erzählwissen von Figurenwissen zu trennen, auch bei Erinnerungen und älteren Auszügen. Das Modell erhält die Gedanken als Erzählkontext; dies ist eine Erzählregel und keine technische Geheimhaltung gegenüber dem KI-Anbieter. Wie zuverlässig eine Figur die Regel befolgt, hängt auch vom Modell ab. Hinweise stehen im Gesprächsmenü unter **Rede & Gedanken**.

Ungesendeter Text wird pro Chat lokal gespeichert. Er bleibt beim Wechsel zur Kartenübersicht, beim Wechsel zu einer anderen App und nach einem normalen Neustart erhalten. Absenden leert nur den eingereichten Entwurf; ein Anbieterfehler löscht die bereits gesendete Nachricht nicht aus dem Verlauf. Entwürfe werden kurz verzögert gespeichert; Schließen des Chats und Wechsel in den Hintergrund sichern zusätzlich sofort. Beim abrupten Beenden während des Tippens können die letzten Bruchteile einer Sekunde fehlen.

## KI auswählen

**Ohne zusätzliche laufende Kosten:** In **Einstellungen → Lokales Modell laden** die Modellgewichte herunterladen. Das erste Laden benötigt WLAN beziehungsweise Datenvolumen und freien Speicherplatz. Der Standard ist ein kleines quantisiertes Qwen-3-Modell; andere kompatible MLX-Modelle können über die lokale Verbindung eingestellt werden. Nach einem App-Neustart erneut laden, bereits heruntergeladene Dateien werden wiederverwendet.

**Kostenlose Cloud:** In der Verbindung **Kostenlose Cloud** einen eigenen OpenRouter-API-Schlüssel eintragen. `openrouter/free` ist vorausgewählt; kostenlose einzelne Modelle können über die Modellauswahl hinzugefügt werden. Die kostenlosen Kontingente und Anbieterregeln gelten weiterhin.

**ChatGPT-Kontingent:** In **ChatGPT Plus → Mit ChatGPT fortfahren** die offizielle Anmeldung und Kontingentfreigabe durchführen. Danach ein Modell aus der vom Konto gelieferten Liste wählen und speichern. Diese Funktion hängt von der Verfügbarkeit des offiziellen Anmeldewegs für dein Konto ab. Normale API-Guthaben werden nicht als Bestandteil deines Plus-Abos ausgegeben.

Weitere Anbieter sind über **Anbieter hinzufügen** möglich, wenn sie einen kompatiblen offiziellen API-Zugang bereitstellen. Ein beliebiges Premium-Abonnement enthält nicht automatisch API-Nutzung.

Die Reihenfolge der Verbindungen ist die Priorität. Unter **Rangfolge ändern** können sie an den Griffen verschoben werden. Die Schalter neben jeder Verbindung steuern, welche Anbieter automatisch verwendet werden. Schalte ChatGPT aus, wenn du das Kontingent fürs Arbeiten reservieren möchtest; die Anmeldung bleibt gespeichert. Bei neuen Installationen steht ChatGPT ausgeschaltet an letzter Stelle. Der Schalter **Kostenpflichtige API-Modelle ausschließen** ist standardmäßig aktiv. Bei ChatGPT zusätzlich die Nutzung weiterer Credits für Apps in den ChatGPT-Nutzungseinstellungen ausschalten, wenn keine zusätzlichen Kosten entstehen sollen; diese externe Einstellung kann Kai nicht prüfen. Ein kontoweites Limit wird nicht durch neue Accounts oder weitere Schlüssel umgangen.

## Erinnern und zurückspulen

- Eine Nachricht lange drücken, um sie zu kopieren, zu bearbeiten, als Erinnerung festzuhalten oder genau dort weiterzuschreiben.
- Im Gesprächsmenü **Erinnerungen & Schreibstil** sind eigene Schreibvorlieben, erkannte Stileigenschaften und festgehaltene Fakten sichtbar.
- Zurückspulen und Bearbeiten bewahren den bisherigen Verlauf unter **Gesprächszweige** auf.
- Erinnerungen, ältere Auszüge und gelernter Stil folgen dem ausgewählten Gesprächszweig. Ereignisse aus späteren oder anderen Zweigen werden nicht in den neuen Kontext übernommen.
- Der gesamte Chat wird lokal gespeichert. Welche Ausschnitte das Modell gleichzeitig erhält, hängt von dessen Kontextfenster ab. Gespeichert bedeutet nicht, dass jede Nachricht bei jeder Antwort vollständig übertragen wird.

## Personas, Szenarien und Gruppen

- Beim Start eines Gesprächs kannst du deine eigene Persona wählen, eine neue Persona anlegen, ein Szenario auswählen und den Einstieg bearbeiten. Vorlagen lassen sich außerdem in den Einstellungen verwalten.
- Personas beschreiben deine Rolle und deinen Hintergrund; Schreibstil-Vorlieben beschreiben, wie du schreiben möchtest. Beides kann unabhängig voneinander eingestellt werden.
- Karten mit mehreren Figuren werden anhand von Titel, Tags und Kartendefinition als **Gruppenkarten** erkannt. Eine solche Karte benötigt keine zusätzlich hinzugefügten Charaktere. Das Modell spielt ihre enthaltenen Figuren gemeinsam und ordnet Beiträge mit Namen zu. Nicht jede Figur muss auf jede Nachricht antworten. Die Erkennung kann unter **Karte bearbeiten → Figuren in dieser Karte** korrigiert werden; Figurennamen lassen sich dort ergänzen.
- Über **+ → Gruppenchat beginnen** oder durch Hinzufügen weiterer Karten beim Gesprächsstart entsteht zusätzlich eine Gruppe aus bis zu vier Karten. Jede davon kann selbst eine Mehrpersonen-Karte sein.
- Beim Kombinieren mehrerer Karten wählst du **Alle nacheinander**, **Automatisch eine Figur** oder einen bestimmten Kartennamen. Eine Gruppenrunde erzeugt eine Antwort pro Karte und verwendet entsprechend mehr Modellanfragen. Eine gemeinsame Mehrpersonen-Karte wird dagegen in einer Anfrage gespielt.
- Jede Antwort wird mit dem Namen der sprechenden Figur gespeichert. Die nächste Figur erhält den bisherigen gemeinsamen Verlauf. Erzeugte Antworten können mit **Weitererzählen** auch ohne neue Nutzernachricht fortgeführt werden.
- Persona und Szenario sind Kopien der gewählten Vorlagen. Spätere Vorlagenänderungen verändern bestehende Gespräche nicht.
- Charaktere können in ihrer Detailansicht als Favoriten markiert und in der Bibliothek über **Suchfilter → Nur Favoriten** gefiltert werden.

## Deutsch und Übersetzung

Die Oberfläche und die vorgegebene Antwortsprache sind Deutsch. Öffentliche Charakterkarten werden nach Beliebtheit geladen, ohne nach ihrer Ausgangssprache zu filtern oder deutschsprachige Karten vorzuziehen. Die App übersetzt Beschreibungen, Szenarien, Begrüßungen und Rolleninformationen mit Apples lokaler Übersetzung. Character-Card-Variablen wie `{{user}}` bleiben dabei erhalten.

Fehlende Sprachpakete werden unter **Karten vorbereiten → Deutschübersetzung einrichten** ausdrücklich geladen. Automatische Übersetzungen verwenden bereits installierte Sprachpakete und halten die Kartensuche nicht auf. Bis zur Fertigstellung sind die Originaltexte mit Kennzeichnung sichtbar und nutzbar. In der Detailansicht kann **Auf Deutsch übersetzen** den Paketdownload ebenfalls anstoßen. Es gibt keinen Sprachfilter.

Diese iOS-Funktion benötigt ein echtes Gerät und kann im Simulator nicht mit realen Sprachpaketen getestet werden. Kai benötigt iOS 18 oder neuer; dein iPhone 17 unterstützt das.

## Grenzen der bisherigen Prüfung

Die Kernlogik lässt sich unabhängig von iOS mit `swift test` prüfen. Ein erfolgreicher macOS-Gerätebuild ist zusätzlich erforderlich, bevor eine IPA ausgeliefert wird. Installation, lokale Geschwindigkeit, Speicherbedarf und die Anmeldung mit deinem konkreten Konto müssen auf deinem iPhone geprüft werden. Die App behauptet diese Gerätetests nicht als bereits erfolgt.

## Omegaverse und zusätzliche Datenbank

Unter **Entdecken → Online entdecken** kannst du zwischen **Chub** und **JannyAI** wählen. **Omegaverse** ist ein eigenes Genre. Omega-Verse, Omega Verse, A/B/O und ABO werden beim Suchen berücksichtigt; der Genre-Filter funktioniert auch in deiner gespeicherten Bibliothek. Viele Treffer sind als Inhalte für Erwachsene markiert und erscheinen erst mit aktiviertem entsprechenden Schalter.

Die öffentliche JannyAI-Suche ergänzt den Janitor-Katalog ohne zusätzliche KI-Verbindung. Sie liefert die Reihenfolge nach Suchrelevanz; Chub bleibt nach Beliebtheit sortiert. Es gibt keine Sprachfilter. Angezeigte Suchtreffer enthalten zunächst die öffentliche Beschreibung; vor einem neuen Gespräch wird die echte freigegebene Definition geladen. Die Übersetzung folgt getrennt.

Wenn JannyAI den direkten Download blockiert, wähle **Originalkarte im Browser herunterladen** und nutze dort den regulären PNG-/JSON-Download. Der integrierte Browser übernimmt solche Downloads in Kai. Website-Anmeldung, Kontoprüfungen und Einschränkungen der Quelle gelten weiter. Ein sichtbarer Suchtreffer garantiert keinen freigegebenen Kartendownload. Kai ersetzt fehlende Definitionen nicht durch erfundene Karten. Die direkte Download-Anfrage war beim Test vom Arbeitsrechner aus blockiert; der Website-Download bleibt auf dem iPhone zu prüfen.

## Im Chat schnell nach oben

Die schwebenden **↑**- und **↓**-Pfeile oberhalb des Eingabefelds springen zum Chat-Anfang und zur neuesten Nachricht. Das verändert weder Nachrichten noch den ausgewählten Gesprächszweig. Wenn du mit dem Pfeil nach oben springst, ziehen neu eintreffende Nachrichten dich nicht automatisch wieder nach unten. Der Abwärtspfeil oder das Absenden einer Nachricht aktiviert das Folgen des aktuellen Verlaufs wieder.

## Antwortlänge in Wörtern

Unter **Einstellungen → Schreiben → Maximale Wortzahl** kannst du beispielsweise **Bis zu 400 Wörter** wählen. Über die zusätzliche Feinwahl sind 25 bis 2.000 Wörter möglich. Die Grenze gilt pro erzeugter KI-Nachricht, auch bei einer Karte mit mehreren Figuren. Bei einer Runde aus mehreren Karten hat jede Antwort ihre eigene Grenze.

Die KI erhält die Vorgabe, vorher natürlich abzuschließen. Überschreitet sie die Grenze, beendet Kai die Ausgabe an einer Wortgrenze. Die letzte Formulierung kann dann unvollständig sein. Wörter mit Buchstaben oder Zahlen werden anhand von Leerraum gezählt; einzelne Satzzeichen oder Emojis zählen nicht als Wörter. Kurze Antworten dürfen kürzer bleiben. Das verfügbare Kontextfenster und Anbietergrenzen können eine längere Ausgabe zusätzlich begrenzen. Ältere Längeneinstellungen werden beim Update übernommen und als Wortobergrenze dargestellt.


## Gedanken und Erinnerungen der Figur

Unter **Einstellungen → Hinter den Zeilen → Gelegentliche Einblicke** wählst du Aus, etwa alle 10 oder etwa alle 20 KI-Antworten. Standard ist etwa 20. Der Abstand schwankt um bis zu zwei Antworten; Begrüßung, Nutzertexte und unterbrochene Antworten zählen nicht. Ein Einblick erscheint erst nach einer fertig erzeugten Antwort, nicht rückwirkend beim Öffnen eines Chats.

Die gesonderte Karte „Nur für dich · nicht ausgesprochen“ zeigt einen Gedanken oder eine Erinnerung der Figur. Sie kann thematisch neben der aktuellen Szene liegen. Das ist Leserwissen und wird nicht automatisch zu Wissen deiner Persona oder anderer Figuren. Die App führt Einblicke getrennt vom Dialog und berücksichtigt nur den aktuellen Gesprächszweig. Im Kontextmenü kannst du einen Einblick kopieren oder ausblenden.

Ein Einblick kostet eine zusätzliche kurze KI-Anfrage beim Anbieter der gerade abgeschlossenen Antwort, maximal 80 Wörter. Die App wechselt dafür nicht zu einem anderen Anbieter. Bei fehlendem Kontingent oder Abbruch wird er übersprungen; die fertige Chatantwort bleibt erhalten. Bei Gruppenchats kann nach der Runde ein Einblick zur zuletzt antwortenden Karte erscheinen.

Unter **Einstellungen → Kartensuche** steuerst du 18+-Karten. Das beeinflusst die öffentliche Suche; es schaltet keine Beschränkungen eines KI-Anbieters frei.


## Weitere KI-Anbieter

Unter **Einstellungen → Anbieter hinzufügen** gibt es **OpenAI API**, **Claude API**, **Gemini API**, **Grok API** und **DeepSeek API**. Trage den offiziellen API-Schlüssel ein, lade die verfügbaren Modelle, wähle ein Textmodell und speichere. Neue API-Verbindungen sind zunächst ausgeschaltet. Aktiviere sie bewusst und passe ihre Rangfolge an. Solange **Kostenpflichtige API-Modelle ausschließen** aktiv ist, werden diese API-Verbindungen übersprungen; die App kann deren kontospezifische Preise und Gratiskontingente nicht sicher prüfen.

**ChatGPT-Konto** verwendet weiterhin die gesonderte offizielle Kontingentanmeldung. **OpenAI API** verwendet dagegen einen API-Schlüssel mit eigener Abrechnung. Claude verbindet ein Console-Konto; Pro allein enthält keine API-Nutzung, bestimmte Max-/Ultra-/Team-Tarife können verknüpfbare API-Credits enthalten. Gemini nutzt ein AI-Studio-Projekt, dessen Modell und Abrechnung über Free Tier oder Kosten entscheiden. Grok-API-Nutzung wird laut Anbieter getrennt vom Abo-Pool abgerechnet. DeepSeek nutzt API-Guthaben. Kai übernimmt keine Anmeldetokens aus fremden Chat-Apps.

Für bestimmte Claude-API-Schlüssel wird zusätzlich eine Workspace-ID benötigt; das Feld ist optional. Schlüssel bleiben im iOS-Schlüsselbund.

**Kostenlose Cloud** verwendet OpenRouters wechselnden Gratis-Pool und wählt pro Anfrage ein verfügbares Gratis-Modell. Ein OpenRouter-Zugang enthält keine Premium-Abos anderer Apps. Am 8. November 2026 enthielt die geprüfte öffentliche Modellliste keine kostenlosen GPT-, Claude- oder Gemini-Textmodelle; unter anderem waren Google Gemma 4 und NVIDIA Nemotron kostenlos vorhanden. Verfügbarkeit kann sich ändern. Gemini-API-Gratiskontingente sind davon getrennt.

Offizielle Informationen:

- [Claude-Konten und API-Credits](https://support.claude.com/en/articles/8987223-can-i-have-a-claude-account-and-a-console-account)
- [Claude-Zugang für Drittanbieter](https://support.claude.com/en/articles/13189465-log-in-to-your-claude-account)
- [Gemini-API-Preise und Free Tier](https://ai.google.dev/gemini-api/docs/pricing)
- [Grok-API und Abo-Abrechnung](https://x.ai/pricing)
- [DeepSeek-API-Einstieg](https://api-docs.deepseek.com/)
- [OpenRouter-Gratisvarianten](https://openrouter.ai/docs/guides/routing/model-variants/free)

## OpenRouter kostenlos einrichten

Beim Erstellen des Schlüssels kann **Credit Limit: No Limit** und **Reset: None** gewählt werden. Das kauft kein Guthaben; es setzt lediglich keine zusätzliche Geldgrenze pro Schlüssel. Kein Guthaben kaufen und keine automatische Aufladung aktivieren. In Kai **Kostenpflichtige API-Modelle ausschließen** eingeschaltet lassen und **openrouter/free** wählen. Kostenloses Tages- und Anfragelimit bleiben davon unabhängig. Ein Schlüssel mit Geldbudget null ist kein verlässlicher Schalter für kostenlosen Modellzugriff.

## Leere KI-Antworten prüfen

Kai 1.5 akzeptiert dokumentierte ChatGPT-Streams ohne Content-Type und unterscheidet OpenRouter-Fehler beim Streaming. Bei lokalen Modellen folgt nach dem Laden ein kurzer Generierungstest; vorhandene Gewichte werden weiterverwendet. Eine leere lokale Ausgabe zeigt Tokenzahl und Stoppgrund. ChatGPT-/OpenRouter-Zugangsdaten gehören ausschließlich in die App-Einstellungen, nicht in Fehlermeldungen oder Chatnachrichten.

## Diagnose ab Kai 1.6

Unter **Einstellungen → Fehlerberichte** stehen die letzten 30 Generierungsversuche mit Buildnummer, HTTP-Status, Ereignissen, sichtbarer Textlänge, Tokenangaben und Stoppgrund. API-Schlüssel, Tokens und Chattexte werden nicht protokolliert. Unter jeder Verbindung kann **Testantwort erzeugen** ohne Charakterkarte einen kurzen Gruß anfordern; die normale Kostensperre bleibt aktiv. Dies trennt ein Transport-/Modellproblem von der Verarbeitung einer Karte.

Kartentexte werden ausschließlich mit **Apple auf dem iPhone** übersetzt. Ab iOS 26 laufen installierte Sprachpaare direkt ohne UI-Warteschlange; ab iOS 26.4 wird der schnelle Modus verwendet. Fehlt ein Sprachpaar, erscheint sofort **Deutsch einrichten** in der Karte und der Bibliothek. Darüber wird der einmalige Paketdownload sichtbar gestartet. Nach erfolgreicher Einrichtung wird die offene Karte automatisch erneut übersetzt. Es gibt keine Online-Übersetzungsquote und keine Übertragung der Kartentexte an Google. Neue öffentliche Kartengespräche warten auf die Übersetzung, statt eine englische Originalbegrüßung zu übernehmen.

JannyAI kann automatisierte Abrufe durch eine Website-Prüfung sperren (HTTP 403). Kai öffnet dann den regulären Export im eingebauten Browser und versucht, die öffentlichen Download-Steuerelemente automatisch auszulösen. Verifikationen müssen gegebenenfalls auf der Website bestätigt werden. Fertige PNG-/JSON-Downloads werden direkt übernommen; versteckte Definitionen werden weder extrahiert noch erfunden. Ein universell unbeaufsichtigter Download lässt sich für diese Quelle nicht garantieren.
