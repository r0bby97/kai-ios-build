import SwiftUI

struct WritingHelpView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Gesprochene Rede") {
                    Text(verbatim: "„Ich bin froh, dich zu sehen.“").font(.body.weight(.medium))
                    Text("Nur Text in geschlossenen Anführungszeichen außerhalb von Sternchen wird ausdrücklich zum Gegenüber gesagt. Gerade und typografische Anführungszeichen funktionieren beide.")
                }
                Section("Private Gedanken") {
                    Text(verbatim: "*Ich bin mir nicht sicher, ob ich ihr vertraue.*").italic()
                    Text("Diese Gedanken bleiben als deine Erzählnotizen im lokalen Verlauf. Ihr Text wird nicht an die Figuren-KI geschickt, auch nicht über Stilbeispiele oder automatisch verknüpfte Erinnerungen. Ein Zitat innerhalb eines Gedankens bleibt ebenfalls privat.")
                }
                Section("Erzählkontext") {
                    Text("Ich stelle die Tasse auf den Tisch.")
                    Text("Text ohne Anführungszeichen ist nicht automatisch gesprochene Rede. Er kann eine Beschreibung oder ein Selbstgespräch sein. Figuren können auf ausdrücklich sichtbare Handlungen reagieren.")
                }
                Section("Dein Entwurf bleibt") {
                    Text("Ungesendeter Text wird pro Gespräch auf deinem iPhone gespeichert. Er bleibt beim Schließen des Chats, beim App-Wechsel und nach einem Neustart erhalten. Erst Absenden leert das Eingabefeld.")
                }
            }.navigationTitle("Rede & Gedanken").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }
}
