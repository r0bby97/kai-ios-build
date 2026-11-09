import SwiftUI
import FadenCore

struct ProviderContentLabels: View {
    let connection: Connection
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Erotik: \(connection.contentGuide.erotic.title)")
            Text("Fiktive Gewalt: \(connection.contentGuide.violence.title)")
        }.font(.caption).foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("content-guide-" + connection.id.uuidString)
    }
}

struct ProviderContentButton: View {
    let connection: Connection
    @State private var showing = false
    var body: some View {
        Button { showing = true } label: {
            HStack(alignment: .top, spacing: 8) {
                ProviderContentLabels(connection: connection)
                Image(systemName: "info.circle").font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 5).frame(minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("Inhaltsrichtwerte für \(connection.name): \(connection.contentGuide.summary)")
            .sheet(isPresented: $showing) {
                NavigationStack {
                    Form { ProviderContentSection(connection: connection) }
                        .navigationTitle(connection.name).navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { showing = false } } }
                }.presentationDetents([.medium, .large])
            }
    }
}

struct ProviderContentSection: View {
    let connection: Connection
    var body: some View {
        Section("Themen und Freiraum") {
            LabeledContent("Erotische Inhalte", value: connection.contentGuide.erotic.title)
            LabeledContent("Fiktive Gewalt", value: connection.contentGuide.violence.title)
            Text(connection.contentGuide.explanation).font(.subheadline).foregroundStyle(.secondary)
            if let source = connection.contentGuide.source {
                Link("Regeln und Angaben des Anbieters", destination: source).accessibilityIdentifier("provider-content-source")
            }
            Text("Richtwert nach veröffentlichten Angaben, Stand \(ProviderContentGuide.reviewDate). Die konkrete Ausgabe hängt weiterhin von Modell und Betreiber ab.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
