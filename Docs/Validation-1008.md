# Kai 1.6.0 · Prüfbuild 1008

Stand: 10. November 2026. Der vollständige Build wurde am 9. November abgeschlossen.

Prüflauf: https://github.com/r0bby97/kai-ios-build/actions/runs/42696543306

Quellcode: `48d3dcc161bd06f311967be44761cc3fc648844e`.

## Bestandene Prüfungen

- **92 Kernlogiktests** auf macOS, keine Fehler.
- **16 iOS-Diensttests** im optimierten Release, keine Fehler. Geprüft wurden Streaming und endgültige Antworten, Anbieterfehler, Horde-Auftragsstatus, Schlüsselbindung, offizielle API-Endpunkte und Modelllisten sowie kontrollierter PNG-/Dateiimport einschließlich Originalbildcache.
- **18 iOS-Oberflächentests**, keine Fehler und keine übersprungenen Tests. Darunter die neue Cardex-/Alle-Auswahl, Inhaltsrichtwerte mit Quellenlink, Ziehen und Speichern der Anbieterreihenfolge, echte öffentliche JannyAI-Suche, Antwortspeicherung/Fallback mit kontrolliertem Transport, Entwürfe, Gruppen, Menüs, Wortgrenze und Scrolltasten.
- `xcresulttool`: **34 native Tests bestanden**, `failedTests = 0`, `skippedTests = 0`, Ergebnis `Passed`, iPhone-17-Simulator mit iOS 26.4.1. Zusammen mit den Kernlogiktests sind das 126 bestandene CI-Tests.
- Erst anschließend wurde die iPhone-IPA gebaut. Die heruntergeladene Datei wurde auf ZIP-Integrität, Version 1.6.0, Build 1008, App-Kennung `dev.r0bby97.faden`, physisches iPhoneOS-arm64-Produkt und Metal-Ressourcen geprüft. Die beiden Release-Dateinamen liefern identische Bytes; GitHubs SHA256-Digest stimmt überein. Testantworten und Testschalter sind im Geräteprodukt nicht enthalten.
- GitHubs Timing-Antwort meldet `billable.MACOS.total_ms = 0`. Gesamtlaufzeit: 2.237.000 ms. Der manuelle öffentliche Standard-Runner-Lauf nutzt kein privates Minutenkontingent. Dokumentationsänderungen starten keinen weiteren Build.

## Zusätzliche Live-Prüfungen

Der neue Horde-Client erhielt echte deutsche Antworten über Stheno 8B, Mini-Magnum 12B und Cydonia 24B. Der Cydonia-Test verwendete den normalen Kai-Promptweg mit einer synthetischen erwachsenen Figur. Der neue Cardex-Client lieferte Suche, Nachladen, vollständige Definition und die Adresse des zugehörigen Originalbilds; der Bildabruf war erfolgreich. Details und Grenzen: [KI-Anbindungen](Validation-RoleplayProviders.md) und [Cardex](Validation-Cardex.md).

Die kontrollierten Dienst-/UI-Tests sind keine Generierungsabnahme persönlicher ChatGPT-/OpenRouter-/Arli-/NanoGPT-/Venice-Konten. Lokale MLX-Leistung und Apple-Sprachpakete auf dem konkreten iPhone bleiben zu bestätigen. Der direkte Live-JannyAI-Download bleibt durch Website-Prüfungen eingeschränkt; die erfolgreiche Suche und kontrollierten Importtests lösen das nicht. Inhaltsrichtwerte beruhen auf veröffentlichten Angaben und garantieren keine bestimmte Szene.

## Download

IPA: https://github.com/r0bby97/kai-ios-build/releases/download/build-1008/Kai-1.6.0-b1008.ipa

Größe: **14.242.830 Bytes**. SHA256: `92f5b29bcdc98fc49ae28566011f3f3abdf48984e84efd36e080c1df63680a84`.

Die IPA ist für die Signierung mit SideStore vorgesehen. Eine frische Installation verwendet dieselbe App-Kennung; das vorherige Löschen der alten App entfernt lokale Chats und Downloads. Ein vorhandener Export kann vor dem Löschen gesichert werden.
