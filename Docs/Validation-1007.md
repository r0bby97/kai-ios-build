# Kai 1.6.0 · Prüfbuild 1007

Stand: 9. November 2026.

Prüflauf: https://github.com/r0bby97/kai-ios-build/actions/runs/42674887719

Quellcode: `b98bb604c019c5ac720cf587d45cbab903a12655`.

- 63 Kernlogiktests lokal und auf macOS bestanden, einschließlich Erhalt der Katalogangaben, vollständiger Quelladressen und stabiler Karten-ID.
- Fünf iOS-Importtests im optimierten Release bestanden: Browser-Dateiübernahme durch AppStore, Erhalt von Kurzbeschreibung/Tags/Originalbild, signierte Export-URL, Originalbild-Cache, Quellzuordnung eines automatischen WebKit-PNG-Downloads sowie Unterscheidung fehlendes Archiv/Website-Prüfung. Die Datei-/WebKit-Tests verwenden kontrollierte PNG-Karten und eine kontrollierte Exportseite.
- Ein iOS-Bedienungstest der echten öffentlichen JannyAI-Suche mit Omegaverse bestanden. Die unveränderten übrigen Bedienungsabläufe wurden nicht erneut ausgeführt; deren letzter vollständiger Prüflauf ist Build 1006.
- Erst nach den Simulatorprüfungen wurde einmalig die iPhone-IPA gebaut. ZIP, App-Version, Buildnummer, App-Kennung, iPhoneOS-arm64-Produkt, Metal-Ressourcen und Ausschluss der Testantworten aus dem Geräteprodukt geprüft.
- GitHubs Timing-Antwort dieses öffentlichen Standard-Runner-Laufs meldet `billable.MACOS.total_ms = 0`. Tatsächliche Laufzeit: 1.561.000 ms. Kein privater Runner und keine neue Billing-Freigabe.

## Stand des Live-Imports

Der echte JannyAI-WebKit-Prüflauf `42533518813` endete an HTTP 403 mit `websiteVerification: challenge`, Seitentitel „Just a moment…“, ohne heruntergeladene Charakterdefinition. Ein erneuter normaler Direktabruf am 9. November bestätigte HTTP 403 / Website-Prüfung. Eine veröffentlichte Porträt-PNG ließ sich laden, enthielt aber keine Character-Card-Metadaten und wurde nicht als vollständige Figur ausgegeben.

Der App-Code öffnet bei blockiertem Direktabruf die Originalseite, erkennt ihre regulären Download-Steuerelemente und übernimmt heruntergeladene PNG-/JSON-Dateien automatisch. Vorhandene öffentliche Quelllinks bleiben erhalten; alte Adressen werden ergänzt. `www.jannyai.com`, Blob-/CDN-Downloads und Menümetadaten werden berücksichtigt. Originalbilder aus der PNG werden direkt gespeichert. Die App zeigt den Prüfstatus und bietet erneutes Laden an; Website-Verifikationen werden nicht gelöst oder umgangen.

**Eine vollständige Live-Abnahme auf dem iPhone steht aus.** Eine gegebenenfalls notwendige Website-Bestätigung muss auf dem Gerät erfolgen. Die bestandenen kontrollierten Importtests sind kein Nachweis, dass JannyAI jede Anfrage oder jeden Browser freigibt. Persönliche KI-Konten, MLX-Hardware und explizites Erwachsenen-Rollenspiel wurden durch diesen gezielten Lauf nicht neu abgenommen.

IPA: https://github.com/r0bby97/kai-ios-build/releases/download/build-1007/Kai-1.6.0-b1007.ipa

Größe: 14.130.755 Bytes. SHA256: `f9c352a519d72332582ebad89a8148a071fff3982e949d49207f25d566a43e70`.
