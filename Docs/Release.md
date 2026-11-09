Kai 1.6.0 – Prüfbuild

Cardex ergänzt den öffentlichen Kartenkatalog um einen direkten Import vollständiger Charakterkarten und ihrer Kartenbilder. „Online entdecken“ bietet „Alle“, „Cardex“, „Chub“ und „JannyAI“ an. Die gemeinsame Ansicht veröffentlicht Quellen unabhängig und behält beim Nachladen getrennte Seitenstände. Übersetzung und Bilder blockieren die Suchvorschau nicht.

Lokal bestehen 75 Kernlogiktests sowie echte Cardex-Such-, Nachlade- und Importprüfungen. Die gemeinsame Suche wurde mit dem App-Suchdienst auf dem Arbeitsrechner geprüft. Die neue native iOS-Bedienprüfung und Bildcache-Abnahme stehen noch aus; siehe Docs/Validation-Cardex.md. Es wurde dafür bislang keine neue IPA und kein Actions-Lauf gestartet.

Builds starten ausschließlich manuell im öffentlichen Repository; private Jobs sind gesperrt. JannyAI-Suche funktioniert, sein direkter Kartendownload bleibt durch Website-Prüfungen eingeschränkt. Es öffnet sich bei einem Fehler kein Browser automatisch. Echte KI-Konten und lokale MLX-Generierung auf dem konkreten iPhone bleiben gesondert abzunehmen. Der vollständige Anforderungsabgleich steht in Docs/Requirements.md.

- Generierung wird anhand des tatsächlich gespeicherten Nachrichtentexts und eines separaten Backend-Ergebnisses geprüft. Die gemeinsame pauschale Fehlermeldung wurde entfernt. Ein Callback-Verlust kann aus derselben empfangenen Antwort wiederhergestellt werden, ohne eine zweite Anfrage zu senden.
- ChatGPT und OpenRouter lesen auch reine finale Antwort-Snapshots und gültige JSON-Antworten aus derselben Anfrage. Interne Berechnungen bleiben von sichtbarem Antworttext getrennt.
- Fehlerberichte speichern Buildnummer, Modell, HTTP-Status, Ereignis-/Zeichenzahlen, Tokenangaben und Abschlussgrund. Sie lassen sich in den Einstellungen kopieren oder teilen und enthalten keine Chattexte oder Zugangsdaten.
- Jede Verbindung bietet einen kurzen unabhängigen Generierungstest. Die Kostensperre gilt dabei weiterhin.
- Nach einer leeren oder vorübergehend fehlgeschlagenen Free-Router-Antwort werden bis zu drei aktuell als kostenlos ausgewiesene Textmodelle automatisch probiert. Kontoweite Nutzungslimits werden respektiert.
- Apple übersetzt Kartentexte auf dem iPhone. Ab iOS 26 werden installierte Sprachen direkt angesprochen; ab iOS 26.4 nutzt Kai ausdrücklich den schnellen Übersetzungsmodus. Fehlende Pakete werden sofort mit „Deutsch einrichten“ gemeldet. Der einmalige Download erfolgt sichtbar in einer eigenen Einrichtung; es gibt keine Google- oder KI-Anfrage für die Übersetzung.
- Neue öffentliche Kartengespräche werden erst nach erfolgreicher Übersetzung angelegt. Die originale Begrüßung und alternative Einstiege werden aus der übersetzten Karte übernommen.
- Die Übersetzung entfernt unbekannte Genre- und Rollentags nicht mehr. Vorschauen ohne Chatdefinition sind in der Übersicht ausdrücklich gekennzeichnet.
- JannyAI erhält Kurzbeschreibung, Katalog-Tags, Originalbild und Quellverweis auch nach dem PNG-Import. Signierte Download-URLs und reguläre CDN-Weiterleitungen werden unterstützt. Neue Transport-/Browser-Tests prüfen eine vollständige PNG-Karte mit Definition und Originalbild.
- JannyAI unterscheidet HTTP 403/Website-Prüfung von einer nicht lieferbaren Karte. Ein regulärer Website-Export bleibt optional erreichbar. Fehlgeschlagene Direktimporte öffnen keinen Browser automatisch und erzeugen keine leeren Chatkarten.
- Omegaverse, BDSM und Guideverse werden auch bei Cardex als Genres gesucht. BDSM und Guideverse sind weiterhin eigene Suchgenres in Bibliothek, Chub und JannyAI. Separate Esper-/Guide-Reiter werden nicht angelegt.

Die bereits geprüften unveränderten Chatfunktionen ersetzen keine native Abnahme der neuen Cardex-Oberfläche. Apple-Übersetzung mit installierten Sprachpaketen und lokale Modellleistung benötigen weiterhin einen echten Gerätetest.
