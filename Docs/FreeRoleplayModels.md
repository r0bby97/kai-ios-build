# KI-Anbindungen für erwachsene Rollenspiele

Stand: 9. November 2026. Untersucht wurden veröffentlichte Inhaltsregeln, API-Zugang, Kosten und erreichbare Schnittstellen. Ein kostenloser Webchat ist kein Nachweis für eine kostenlose API. Es wurden keine persönlichen Chats oder fremden Charakterkarten zur Generierung übermittelt.

## Eingebaut

| Anbindung | Kosten und Grenzen | Tatsächlicher Prüfstand |
| --- | --- | --- |
| **AI Horde** | Kostenlos, auch anonym. Kudos steuern Priorität und teilweise das zulässige Ausgabebudget; Rechner und Warteschlangen bestimmen die Verfügbarkeit. | Native asynchrone Chat-Anbindung implementiert. Echte deutsche Antworten über Mini-Magnum 12B, Stheno 8B und Cydonia 24B erhalten; Cydonia auch mit dem normalen Kai-Rollenspielprompt. Weitere Prüfungen: [Validation-RoleplayProviders.md](Validation-RoleplayProviders.md). |
| **Arli AI** | Offizieller Gratis-Test: fünf Anfragen pro Modell alle zwei Tage, maximal 12K Kontext. Bezahlte Tarife separat. Eigener API-Schlüssel nötig. | Anbieterprofil, Modellauswahl, Inhaltsrichtwert und ausdrückliche Gratis-Testkonto-Einstellung implementiert. Offizielle Modell- und Chat-Routen antworteten ohne Schlüssel mit HTTP 401. Transport lokal geprüft; echte Kontogenerierung noch offen. |
| **NanoGPT API** | Passende offene Modelle sind nach Verbrauch kostenpflichtig. Das kostenlose Web-Modell ist keine kostenlose API für diese Modelle. | Eigenes Anbieterprofil mit offizieller API und Modellliste implementiert. Öffentliche Liste mit 635 Einträgen erreichbar. Transport lokal geprüft; Generierung mit einem persönlichen Schlüssel noch offen. |
| **Venice API** | API-Aufrufe verbrauchen Guthaben. Freie Web-Prompts sind kein kostenloses Kai-Kontingent. | Eigenes Anbieterprofil implementiert. Öffentliche Textmodell-Liste mit 139 Einträgen erreichbar. Dokumentierte Parameter erhalten Kais Charakter-Systemprompt und unterdrücken sichtbare Modellberechnungen. Transport lokal geprüft; persönliche Kontogenerierung noch offen. |

NanoGPT und Venice werden bei eingeschalteter Kostensperre ausgeschlossen. Neue benannte API-Verbindungen starten ausgeschaltet und ohne ausgewählte Modelle. Es werden weder Käufe noch Aufladungen noch neue Benutzerkonten ausgelöst. Arlis Gratis-Einstellung ändert keinen externen Tarif; sie gilt für einen vom Nutzer verwendeten kostenlosen Testzugang.

## AI Horde: Umsetzung und Grenzen

Kai verwendet die öffentliche native Chat-API statt ungeprüfter eigener Tokenizer-Schablonen. Die automatische Rollenspielauswahl berücksichtigt aktuell passende Chat-Rechner für Mini-Magnum, Magnum, Behemoth, Stheno und Cydonia. Ein Modell kommt nur infrage, wenn ein vertrauenswürdiger, nicht pausierter Rechner NSFW-Unterstützung, Chat-Verarbeitung und eine Ablehnung überlaufender Prompts meldet. Reine Text-Worker erscheinen nicht fälschlich als sofort nutzbare Chat-Optionen.

Die Auswahl prüft Kontext und gewünschte Ausgabe vorab. Ist nur eine kürzere Ausgabe möglich, kann sie an die gemeldete Rechnerkapazität angepasst werden, ohne die Nachrichten zu verändern. Es werden keine Charakterregeln abgeschnitten, um einen kleineren Rechner zu erzwingen. Die Anfrage setzt `context_fit: reject`; eine gemeldete nachträgliche Kürzung wird abgelehnt. Interne Berechnungen werden nicht als Figurengedanken dargestellt.

Ein Auftrag wird eingereiht, der Status sichtbar aktualisiert und bei Abbruch, fehlender Kapazität oder Zeitlimit per DELETE beendet. Eine verlorene Eingangsbestätigung wird mit derselben Operationskennung angefragt, damit keine zweite Generierung entsteht. Bei einem ausdrücklich genannten kleineren Gratis-Ausgabebudget darf einmal nur die Ausgabelänge reduziert werden; die Nachrichten und Charakterregeln bleiben erhalten.

Die Wartezeit ist einstellbar. Danach kann die nächste eingerichtete Verbindung übernehmen. Mehrere Horde-Modelle sind Kapazitätsalternativen innerhalb desselben Dienstes und keine unabhängigen Guthabenquellen.

Laut FAQ sind NSFW-Texte erlaubt; einzelne Rechnerbetreiber und Modelle können eigene Regeln haben. Betreiber können die ihnen übermittelten Texte technisch einsehen. Die Horde ist deshalb keine vertrauliche lokale Verarbeitung. Eine kurze funktionierende Antwort belegt noch keine verlässliche deutsche Erzählqualität oder Unterstützung jeder konkreten Szene.

## Weitere geprüfte Kandidaten

| Kandidat | Warum keine weitere kostenlose Kai-Anbindung eingerichtet wurde |
| --- | --- |
| **Routeway** | Zwar kostenlose Modelle, aber die aktuellen Bedingungen untersagen unter anderem Dienste für pornografische/sexuell explizite Inhalte und erwachsene KI-Beziehungen. Für den gewünschten Einsatzzweck ungeeignet. |
| **Chutes** | Aktuell kein Gratis-Tarif. Zusätzliche Regeln für Standardmodelle verbieten explizite sexuelle Inhalte und drastische Gewalt/Gore. |
| **Pollinations** | Quest-/Aktionsguthaben ist nicht als dauerhaftes Gratis-Kontingent zugesichert. Die gefundenen ausdrücklich als RP/uncensored beworbenen Community-Modelle waren als nur bezahlt markiert. Kein belegter kostenloser Ersatz für diesen Zweck. |
| **Infermatic** | Der kostenlose Tarif bietet laut Preistabelle keinen API-Zugang. Bezahlte API-Tarife sind eine mögliche spätere Ergänzung, ersetzen aber keine kostenlose Anbindung. |
| **Featherless** | Kein bestätigter kostenloser API-Tarif. Chat- und Entwicklerangebote haben unterschiedliche Nutzungs- und Abrechnungsbedingungen. |
| **DreamGen** | Kostenloser Web-Einstieg vorhanden; die bekannte API-Modellroute verlangt eine Anmeldung. Ein aktuell offiziell belegtes Gratis-Kontingent für externe API-Nutzung konnte nicht bestätigt werden. |
| **FreeLLMAPI / andere Horde-Frontends** | Eine weitere Oberfläche auf derselben Rechnergemeinschaft wäre keine unabhängige Kapazitäts- oder Kontingentalternative. Kai greift direkt auf Horde zu. |
| **OpenRouter/free** | Bestehende Anbindung bleibt erhalten. Kostenlos und `is_moderated: false` garantieren keine Freigabe durch Modellbetreiber oder Lizenz; der Free-Router ist keine verlässliche Auswahl für explizite Inhalte. |

Lokale Modelle bleiben unabhängig von Cloud-Kontingenten. Das bisherige MLX/Qwen ist auf dem konkreten iPhone noch abzunehmen. Ein großes 12B-/128B-Modell wird nicht automatisch auf das iPhone geladen; die hier beschriebenen großen RP-Modelle laufen auf entfernten Rechnern.

## Inhaltsrichtwerte in der App

Verbindungsübersicht, KI-Rangfolge und Verbindungseditor zeigen Erotik und fiktive Gewalt getrennt: **viel Freiraum**, **eingeschränkt**, **modellabhängig** oder **ungeprüft**. In der Rangfolge öffnet ein Tipp die Erklärung und Anbieterquelle. Die Einordnung beeinflusst nicht automatisch die vom Nutzer festgelegte Priorität.

Eine Plattform mit vielen Modellen erhält keine pauschale Höchsteinstufung. Bei NanoGPT und Arli werden nur konkret geprüfte Modellbezeichnungen enger eingeordnet. Gemischte oder unbekannte Auswahl bleibt modellabhängig; eigene unbekannte API-Adressen bleiben ungeprüft. Die Werte sind keine Garantie einer bestimmten Ausgabe und keine vorgetäuschte prozentuale Freigabe.

## Quellen

- AI Horde FAQ: https://aihorde.net/faq/
- AI Horde Konto und kostenlose Nutzung: https://aihorde.net/register
- API-Schema: https://aihorde.net/api/swagger.json
- Modelle: https://aihorde.net/api/v2/status/models?type=text&chat=true
- Rechner: https://aihorde.net/api/v2/workers?type=text
- Arli Gratis-Test und API: https://www.arliai.com/docs/textgen
- Arli Bedingungen: https://www.arliai.com/terms
- Arli Tarife: https://www.arliai.com/pricing
- NanoGPT offene Modelle: https://nano-gpt.com/use-cases/uncensored-ai
- NanoGPT API: https://nano-gpt.com/api
- Venice API-Abrechnung: https://venice.ai/faqs/all
- Venice Chatparameter: https://docs.venice.ai/api-reference/endpoint/chat/completions
- Routeway Bedingungen: https://routeway.ai/terms
- Chutes Tarife und Bedingungen: https://www.chutes.ai/pricing · https://www.chutes.ai/terms
- Pollinations Bedingungen: https://github.com/pollinations/pollinations/blob/main/pollinations.ai/public/legal/TERMS_OF_SERVICE.md
- Infermatic Tarife: https://infermatic.ai/pricing/
- Featherless Tarife: https://featherless.ai/pricing
- DreamGen: https://dreamgen.com/
