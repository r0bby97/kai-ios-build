# Build-Ausführung und Actions-Budget

Stand: 9. November 2026.

- Code-Pushes lösen keine Builds aus. Beide Prüfabläufe erfordern `workflow_dispatch`.
- Die Jobs prüfen `github.event.repository.private == false`, bevor ein Runner gestartet wird. Im privaten Repository wird kein Mac-Job ausgeführt.
- Das bereits vom Nutzer freigegebene öffentliche Repository `r0bby97/kai-ios-build` verwendet den Standard-Runner `macos-26`.
- Die GitHub-Timing-Antwort für den erfolgreichen Lauf `42529215243` meldet für macOS `total_ms: 0` unter `billable`. Der tatsächliche Lauf dauerte 2.503.000 ms; tatsächliche Dauer und abgerechnete Minuten sind verschiedene Werte.
- GitHub dokumentiert Standard-Runner in öffentlichen Repositories als kostenlos. Das private monatliche 2.000-Minuten-Kontingent wird dadurch nicht erhöht oder verändert.
- Lokale Kernlogiktests laufen zuerst. Für iOS-Änderungen folgt ein gezielter Simulatorlauf. Nur nach erfolgreichen Prüfungen wird das iPhone-Geräteprodukt gebaut und als IPA veröffentlicht.
- `ONLY_ACTIVE_ARCH=YES` verhindert den unnötigen Bau einer zweiten Simulatorarchitektur.
- Erfolgreiche IPAs liegen in GitHub Releases. Ein zusätzliches identisches Actions-Artifact wird nicht erzeugt; Fehlerdiagnosen bleiben begrenzt aufbewahrt.

Offizielle Dokumentation: https://docs.github.com/en/actions/concepts/billing-and-usage

Die gezielte Auswahl `janny-import` umfasst die Importtests einschließlich echter Dateiübernahme, Originalbild, Menümetadaten und Quellzuordnung sowie den öffentlichen Janny-Suchablauf. Sie behauptet keine erneute vollständige Abnahme der unveränderten Chatfunktionen oder erfolgreicher persönlicher KI-Konten.
