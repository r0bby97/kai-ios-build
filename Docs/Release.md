Kai 1.6.0

- Generierung wird anhand des tatsächlich gespeicherten Nachrichtentexts und eines separaten Backend-Ergebnisses geprüft. Die gemeinsame pauschale Fehlermeldung wurde entfernt. Ein Callback-Verlust kann aus derselben empfangenen Antwort wiederhergestellt werden, ohne eine zweite Anfrage zu senden.
- ChatGPT und OpenRouter lesen auch reine finale Antwort-Snapshots und gültige JSON-Antworten aus derselben Anfrage. Interne Berechnungen bleiben von sichtbarem Antworttext getrennt.
- Fehlerberichte speichern Buildnummer, Modell, HTTP-Status, Ereignis-/Zeichenzahlen, Tokenangaben und Abschlussgrund. Sie lassen sich in den Einstellungen kopieren oder teilen und enthalten keine Chattexte oder Zugangsdaten.
- Jede Verbindung bietet einen kurzen unabhängigen Generierungstest. Die Kostensperre gilt dabei weiterhin.
- Nach einer leeren oder vorübergehend fehlgeschlagenen Free-Router-Antwort werden bis zu drei aktuell als kostenlos ausgewiesene Textmodelle automatisch probiert. Kontoweite Nutzungslimits werden respektiert.
- Google übersetzt Kartentexte über seine öffentliche Web-Schnittstelle, ohne KI-Kontingent oder lokale Sprachpakete. Ergebnisse werden gespeichert; einzelne Abrufe enden spätestens nach acht Sekunden. Apple bleibt als lokale Alternative wählbar. Die öffentliche Google-Schnittstelle bietet keine Verfügbarkeitsgarantie.
- Neue öffentliche Kartengespräche werden erst nach erfolgreicher Übersetzung angelegt. Die originale Begrüßung und alternative Einstiege werden aus der übersetzten Karte übernommen.
- JannyAI unterscheidet HTTP 403/Website-Prüfung von einer nicht lieferbaren Karte. Der eingebaute Browser versucht den regulären öffentlichen PNG-/JSON-Export automatisch zu öffnen und übernimmt fertige Downloads. Eine von der Website verlangte Verifikation bleibt sichtbar; sie wird nicht umgangen. Ein vollständig automatischer JannyAI-Download ist bei solchen Prüfungen nicht zugesichert.
- Guideverse ist als eigenes Suchgenre vorhanden. Separate Esper-/Guide-Reiter werden nicht angelegt.

Validierung umfasst Kernlogik, HTTP-/Übersetzungstests, die normalen Bedienabläufe und zusätzlich optimierte Release-Tests für Stream und Nachrichtenspeicherung. Echte ChatGPT-/OpenRouter-Konten sowie MLX auf einem echten iPhone sind nicht durch Testantworten ersetzt.

Die eindeutig benannte IPA kann frisch über SideStore installiert werden. Beim Löschen der alten App werden deren lokale Chats und Downloads entfernt.
