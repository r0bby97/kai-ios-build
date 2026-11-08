import SwiftUI

struct DiagnosticsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Technische Metadaten der letzten 30 Versuche. Enthält keine Chattexte, API-Schlüssel oder Anmeldetokens.").font(.subheadline).foregroundStyle(.secondary)
                    if !store.diagnostics.entries.isEmpty {
                        ShareLink(item: store.diagnostics.text) { Label("Fehlerberichte teilen", systemImage: "square.and.arrow.up") }
                        Button("Alle Berichte kopieren", systemImage: "doc.on.doc") { UIPasteboard.general.string = store.diagnostics.text }
                        Button("Berichte löschen", role: .destructive) { store.diagnostics.clear() }
                    }
                }
                if store.diagnostics.entries.isEmpty { Text("Noch keine Generierung protokolliert.") }
                ForEach(store.diagnostics.entries.reversed()) { entry in
                    Text(entry.readable).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                }
            }.navigationTitle("Fehlerberichte").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }
}
