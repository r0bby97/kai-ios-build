# Apple-Kartenübersetzung und Gesprächsstart

Stand: 10. November 2026, Änderungen für Kai 1.7. Ausgangspunkt: Build 1008 meldet nach erfolgreicher Einrichtung weiterhin TranslationError Code 1; gemischte Karten laden lange und sperren den Gesprächsstart.

## Behobene Ablauffehler

Einrichtung und direkte Übersetzung wählten zuvor unterschiedliche Strategien. Ab iOS 26.4 verwenden Konfiguration, installierte Sitzung und LanguageAvailability dieselbe Strategie, bevorzugt lowLatency. Nur bei dort nicht unterstützten Sprachen wird highFidelity geprüft. Ab iOS 26 wird die konkrete Sitzungsbereitschaft nach der Vorbereitung geprüft. Typisierte Apple-Fehler ersetzen die ungeeignete Auswertung des NSError-Zahlencodes. Nur bestätigtes notInstalled sperrt die Sprache bis zur Einrichtung; Abbruch und interne Fehler tun das nicht. Englisch → Deutsch bleibt ausdrücklich sichtbar.

Die Übersetzung arbeitet pro Textfeld und bei gemischten Schriften pro Abschnitt, statt die gesamte Karte einer Sprache zuzuordnen. JSON-/W++-Daten werden als Daten gelesen: übersetzt werden Textwerte, nicht Schlüssel, Zahlen, Eigennamen oder Kartenvariablen. Die Rückgabe behält die Datenstruktur; die Ansicht stellt sie lesbar dar. Normale Prosa und nicht erkannte Formate bleiben normale Texte. Der Parser führt keinen Code aus.

Kleine Vierer-Batches zeigen Abschnittsfortschritt. Bis zu 512 übersetzte Abschnitte werden während des App-Laufs wiederverwendet; eine fertig übersetzte Karte wird gespeichert. Ein später fehlgeschlagener Abschnitt verwirft die zwischengespeicherte Übersetzung nicht. Ein Batch hat eine begrenzte Wartezeit; Hintergrundarbeit pausiert zwischen Batches während der KI-Antwort oder eines priorisierten Gesprächseinstiegs.

Der Start wartet nur auf den ausgewählten Einstieg. Eine leere Begrüßung startet ohne Übersetzungspaket; die vollständige Originaldefinition bleibt der KI verfügbar und wird nachträglich vorbereitet. Die Detailansicht sperrt nicht mehr bis zur Übersetzung aller Lore-Einträge und alternativen Begrüßungen. Es gibt keine Übersetzungsanfrage an Google oder einen Cloud-KI-Anbieter.

## Nachweis und Grenzen

125 lokale Kernlogiktests bestanden, einschließlich Struktur, Variablen, gemischten Schriften und Textgrenzen. Alle elf nativen Übersetzungs-Diensttests sowie die Einrichtungs- und Startabläufe sind bestanden. Testprovenienz und IPA-Prüfung: [Validation-1012.md](Validation-1012.md).

Der Simulator stellt keine echten Apple-Übersetzungsmodelle bereit. Deshalb sind erfolgreiche SDK-/Logik-/UI-Tests kein Nachweis einer echten Übersetzung auf dem iPhone. Benötigt wird anschließend ein Versuch mit einer englischen und einer gemischten Karte auf dem Gerät. Keine garantierte Sekundenangabe und keine Behauptung, jede individuelle Ursache von Code 1 sei damit nachgewiesen. Ein einzelner lateinischer Absatz mit mehreren Sprachen kann weiterhin eine ungenaue automatische Spracherkennung ergeben.

## Apple-Referenzen

- [Strategien](https://developer.apple.com/documentation/translation/translationsession/strategy)
- [Verfügbarkeit passend zur Strategie](https://developer.apple.com/documentation/translation/languageavailability/init(preferredstrategy:))
- [Bereitschaft](https://developer.apple.com/documentation/translation/translationsession/isready)
- [Typisierte Fehler](https://developer.apple.com/documentation/translation/translationerror)
