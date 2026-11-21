Kai 1.8.0 – Automatische Cloud-Sicherung

Unter Einstellungen → Deine Daten → Automatische Sicherung wählst du einen Ordner in iCloud Drive oder bei einem anderen Dateianbieter mit beschreibbarem Ordnerzugriff. Kai sichert Änderungen automatisch und zeigt den Zeitpunkt und die Größe der zuletzt geschriebenen Sicherung an. Dein Dateianbieter übernimmt den Upload.

Chats, Kartentexte und Einstellungen werden auf dem iPhone mit einem Wiederherstellungspasswort verschlüsselt. API-Schlüssel kannst du separat zur Sicherung hinzufügen. ChatGPT-Anmeldungen, Bilder und lokale KI-Modelle bleiben auf dem Gerät beziehungsweise können wieder geladen werden.

Nach einer Neuinstallation wählst du denselben Cloud-Ordner aus, öffnest eine Sicherung und gibst das Passwort ein. Die Wiederherstellung führt Inhalte zusammen und lässt bestehende Chats und Schlüssel bestehen. Separate Dateien pro Einrichtung schützen ältere Sicherungen davor, von einer frischen Installation überschrieben zu werden.

Die Korrektur für Cardex-Exportlinks aus Kai 1.7.2 ist enthalten.

Der [öffentliche Prüflauf](https://github.com/r0bby97/kai-ios-build/actions/runs/44896842900) bestand 138 Kernlogiktests, 33 iOS-Diensttests und drei gezielte Oberflächentests. Die Backup-Tests decken Verschlüsselung, falsche Passwörter, beschädigte Dateien und das Zusammenführen von Gesprächen und Zugangsdaten ab. Diego und drei weitere Cardex-Karten lieferten beim direkten Export eine vollständige Definition und Begrüßung.

Die IPA wurde heruntergeladen und auf Version 1.8.0, Build 1018, unveränderte App-Kennung und iPhoneOS-arm64 geprüft. SHA-256 `b2f7bfd9d91e6c97150626d7f853a4e7a1c6b53f8d27c6e2c829ba1509cfc1e6`. GitHub meldet null abrechenbare macOS-Minuten.

Der Simulator prüft die Einrichtung und Wiederherstellung mit lokalen Testdaten. Der Upload in einen persönlichen Cloud-Ordner hängt vom Dateianbieter ab und ist auf dem iPhone zu prüfen. Google Drive kann über die Dateien-App verwendet werden, wenn es Kai einen beschreibbaren Ordner anbietet.
