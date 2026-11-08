# Kai 1.6.0 · Prüfbuild 1006

Prüflauf: https://github.com/r0bby97/kai-ios-build/actions/runs/42529215243

Der Lauf vom 8. November 2026 ist erfolgreich abgeschlossen. Dies ist **keine vollständige Live-Abnahme** aller vereinbarten Anforderungen.

| Prüfung | Ergebnis und Aussagegrenze |
| --- | --- |
| 61 Kernlogiktests | Bestanden. Unter anderem Verlauf/Zweige, Entwürfe, Erinnerung, Kontextbudget, Rollenperspektive, Wortgrenzen, Kartenformate und Stream-Auswertung. |
| 10 iOS-Import-/Transporttests im optimierten Release | Bestanden. Kontrollierte HTTP-Antworten für Streams, Fehler und native Sprachpaket-Anforderung. Die vier neuen Kartentests prüfen signierte Export-URLs, vollständige PNG-Definitionen, erhaltene Menüangaben, Originalbild-Cache, getrennte Archiv-/Verifikationsfehler und die automatische Übernahme eines normalen Website-PNG-Downloads in WKWebView. Der Website-Test verwendet eine kontrollierte Testseite, nicht einen freigegebenen Live-Janny-Export. |
| 16 vollständige Bedienungstests im optimierten Release | Bestanden. Einschließlich Senden/Fallback/Speichern, Wiederherstellung aus dem Backend-Ergebnis, Entwürfen, Themes, Personas, Szenarien, Gruppen, Rangfolge, Wortzahl, Scrollen und sichtbarer Sprachpaket-Einrichtung bei gesperrtem englischem Gesprächseinstieg. Die generierten Testantworten kommen aus kontrollierten Transportantworten, nicht aus den persönlichen KI-Konten des Nutzers. |
| Öffentlicher Chub-Katalog | Suche sowie Vorbereitung mit echten Vorschauen und Originalbildern im Simulator bestanden, während die Übersetzung gezielt zurückgehalten wird. Dies ist keine Messung der Netzwerkgeschwindigkeit auf dem iPhone des Nutzers. |
| Öffentliche JannyAI-Suche | Live-Suchtest mit Omegaverse bestanden. Vollständige Live-Exporte sind dadurch nicht nachgewiesen. Drei direkte Exporte und eine Originalseite wurden beim Arbeitsrechner-Test mit HTTP 403 / Website-Prüfung blockiert. |
| Geräteprodukt | Release für iPhoneOS arm64 gebaut. ZIP-Prüfsummen, Version/Build, App-Kennung, Metal-Ressourcen, Produktionsausschluss der Testantworten und SHA256 mit veröffentlichtem Asset abgeglichen. |
| ChatGPT/OpenRouter-Konten, MLX und Apple-Übersetzung auf dem iPhone | Noch nicht nach den Korrekturen erfolgreich abgenommen. Keine Zugangsdaten des Nutzers auf CI. |
| Verlässliches explizites Erwachsenen-Rollenspiel | Mit der bisherigen Anbieter-/Modellauswahl noch nicht abgenommen; siehe ProviderContentRules.md. |

Quellcode des geprüften App-Builds: `4fb779e949822b976a86863b8bb9076c17b2cfc6`. Spätere reine Dokumentationscommits ändern das geprüfte App-Produkt nicht.

IPA: `Kai-1.6.0-b1006.ipa`, 14.122.162 Bytes.

SHA256: `bdf8a8e8c674d652d1a05906bc38cd6bfd3e7d151e30a97a3633c860ec24801d`.

Die 24 älteren eigenen Beispielkarten bleiben als Kompatibilitätsressource für alte Gespräche enthalten. Sie werden bei normaler Entdeckung und einer frischen Bibliothek nicht angezeigt. Reguläre Karten verwenden ihre Originalbilder.
