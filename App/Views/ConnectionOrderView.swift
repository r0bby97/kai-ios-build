import SwiftUI
import FadenCore

struct ConnectionSettingsRow: View {
    @Environment(AppStore.self) private var store
    let connection: Connection
    let edit: () -> Void
    private var position: Int { (store.archive.connections.firstIndex(where: { $0.id == connection.id }) ?? 0) + 1 }
    var body: some View {
        HStack(spacing: 12) {
            Button(action: edit) {
                HStack(spacing: 12) {
                    Text("\(position)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 16)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(connection.name).foregroundStyle(.primary)
                        Text(connection.models.isEmpty ? "Noch kein Modell ausgewählt" : connection.models.joined(separator: " → "))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        ProviderContentLabels(connection: connection)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("\(position). \(connection.name) bearbeiten")
            Toggle("\(connection.name) verwenden", isOn: Binding(get: {
                store.archive.connections.first(where: { $0.id == connection.id })?.enabled ?? false
            }, set: { enabled in
                if let index = store.archive.connections.firstIndex(where: { $0.id == connection.id }) {
                    store.archive.connections[index].enabled = enabled; store.save()
                }
            })).labelsHidden().accessibilityIdentifier("connection-enabled-" + connection.id.uuidString)
        }.padding(.vertical, 4)
    }
}

struct ConnectionOrderView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        @Bindable var store = store
        NavigationStack {
            List {
                Section {
                    ForEach($store.archive.connections) { $connection in
                        let position = (store.archive.connections.firstIndex(where: { $0.id == connection.id }) ?? 0) + 1
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(position). \(connection.name)").font(.headline)
                                    .accessibilityIdentifier("priority-title-" + connection.id.uuidString)
                                Text(connection.enabled ? "Wird bei Bedarf verwendet" : "Ausgeschaltet")
                                    .font(.caption).foregroundStyle(.secondary)
                                ProviderContentButton(connection: connection)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Toggle("\(connection.name) verwenden", isOn: $connection.enabled).labelsHidden()
                        }.padding(.vertical, 8)
                    }.onMove { source, destination in
                        store.archive.connections.move(fromOffsets: source, toOffset: destination); store.save()
                    }
                } footer: {
                    Text("Ziehe die Griffe rechts. Die oberste aktive und eingerichtete Verbindung startet zuerst. Die Hinweise zu Erotik und fiktiver Gewalt sind Richtwerte; tippe darauf für Details. Ausgeschaltete Verbindungen werden übersprungen. Änderungen gelten ab der nächsten Antwort.")
                }
            }.environment(\.editMode, .constant(.active))
                .navigationTitle("KI-Rangfolge").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { store.save(); dismiss() } } }
                .onDisappear { store.save() }
        }
    }
}
