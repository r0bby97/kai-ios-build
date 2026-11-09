# Kostenlose KI für erwachsene Rollenspiele

Geprüft am 9. November 2026. Gewünscht sind sexuelle Erwachsenenthemen und fiktive Gewalt. Dies ist eine Anbieter- und Verfügbarkeitsprüfung, kein bestandener Test expliziter Ausgaben oder deutscher Erzählqualität. Es wurden keine persönlichen Chattexte oder Charakterkarten zur Generierung übermittelt.

## Ergebnis: AI Horde zuerst prüfen

AI Horde ist ein kostenloser, von freiwilligen Rechnerbetreibern getragener Text- und Bildgenerierungsdienst. Laut offizieller FAQ sind NSFW-Texte erlaubt. Die FAQ nennt keine allgemeine dienstweite Textzensur, weist aber auf individuelle Worker-Regeln hin. Das ist keine Zusage für jede konkrete Szene.

Die öffentliche Textmodell-API antwortete mit HTTP 200 und 26 angebotenen Modellen. Die Worker-API meldete 34 Text-Worker; aktive Worker für Mini-Magnum, Behemoth, Stheno und Cydonia gaben `nsfw: true` an.

| Verfügbarer Modelltyp | Aktuell gemeldete Kapazität | Einschätzung für Kai |
| --- | --- | --- |
| Mini-Magnum 12B v1.1 | Zwei geprüfte Worker: 12.288 beziehungsweise 16.384 Kontexttokens; maximal 2.048 beziehungsweise 1.024 Ausgabetokens. | Interessantester kostenloser Kandidat für längere Rollenspielantworten und Erinnerung. Deutschqualität und tatsächlich erlaubtes Budget eines Zugangs müssen geprüft werden. |
| Behemoth 128B v3 | Zwei Worker: 12.800 beziehungsweise 20.480 Kontexttokens und 1.200 beziehungsweise 1.024 Ausgabetokens. | Größeres Modell; bei der Abfrage längere Warteschlange. Kein verlässlicher schneller Ersatz für eine bezahlte API. |
| Stheno 8B v3.2 | 4.096/8.192 Kontexttokens, 512/240 Ausgabetokens je Worker. | Rollenspielkandidat, für 400 deutsche Wörter teilweise zu geringe Ausgabegrenzen. |
| Cydonia-Familie | Unterschiedliche Worker; teils nur 512–1.024 Kontexttokens gemeldet. | Verfügbar, unter diesen aktuell gemeldeten Grenzen aber keine erste Wahl für lange, charaktertreue Gespräche. |

Diese Angaben sind ein Zeitpunktbild. Sie beschreiben Worker-Angebote und garantieren nicht, dass anonyme Anfragen diese gesamten Budgets nutzen dürfen. Das muss mit den aktuellen Anfrage-/Kudos-Grenzen zusammen geprüft werden.

### Kosten, Konten und Datenschutz

- Generierung ist laut Betreiber kostenlos; Kudos steuern die Priorität, nicht eine verpflichtende Geldzahlung. Anonyme Nutzung wird unterstützt und ist nachrangig. Ein regulärer kostenloser Zugang kann die Wartezeit verbessern.
- Modellangebot und Wartezeiten hängen von freiwilligen Workern ab. Die Statusantwort zeigte je nach Modell Schätzungen von Sekunden bis mehreren Minuten. Das sind keine garantierten Antwortzeiten.
- Laut FAQ können technisch versierte Worker-Betreiber Prompts und erzeugte Texte einsehen oder speichern. Sie sehen dabei nicht automatisch Nutzer-ID oder IP-Adresse. Diese Cloud ist deshalb nicht als vertrauliche lokale Verarbeitung darzustellen.
- Kai benötigt dafür einen eigenen Adapter für asynchrone Aufträge, Warteschlangenstatus und Abbruch; die API ist keine unmittelbar austauschbare OpenAI-Chat-API. Dieser Adapter ist noch nicht implementiert.

## Andere Möglichkeiten

**Venice:** Der Dienst bietet offene Textmodelle an, aber die aktuelle FAQ stellt klar, dass API-Aufrufe pro Token Credits beziehungsweise Guthaben verbrauchen, auch wenn ein Modell in der Web-App gratis nutzbar ist. Für eine integrierte Kai-Anbindung daher keine belegte dauerhaft kostenlose Lösung. Die freie Weboberfläche wird nicht automatisiert oder als versteckte API verwendet.

**OpenRouter/free:** Die aktuelle öffentliche Liste enthält kostenlose Textmodelle. Das Kennzeichen `is_moderated: false` belegt keine Freigabe erotischer oder drastischer Inhalte. Modelllizenzen, Anbieterregeln und Antwortverhalten müssen separat passen. Der zufällige Free-Router ist deshalb keine verlässlich erwachsenentaugliche Modellauswahl.

**Lokale Rollenspielmodelle:** Nach dem Download entstehen keine Cloud-Gebühren und kein freiwilliger Worker erhält den Chat. Das bisherige Qwen-Modell ist jedoch nicht als zuverlässige Lösung für die gewünschten Themen abgenommen. Größere RP-Modelle benötigen deutlich mehr Arbeitsspeicher und Rechenleistung; auf dem iPhone 17 sind Temperatur, Tempo, Kontext und deutsche Ausgabe praktisch zu testen. Die oben genannten 12B-/128B-Modelle sind Cloud-Kandidaten, keine Empfehlung für direkten Betrieb auf diesem iPhone.

## Quellen

- Erlaubte NSFW-Texte, Worker-Regeln und Einsicht in Prompts: https://aihorde.net/faq/
- Kostenloser Dienst und reguläre Zugänge: https://aihorde.net/register
- Aktuelle Textmodelle: https://aihorde.net/api/v2/status/models?type=text
- Aktuelle Text-Worker: https://aihorde.net/api/v2/workers?type=text
- API-Schema: https://aihorde.net/api/swagger.json
- Venice API-Kosten: https://venice.ai/faqs/all
- Venice Nutzungsbedingungen: https://venice.ai/legal/tos
- OpenRouter Modellübersicht: https://openrouter.ai/api/v1/models
