import SwiftUI
import UniformTypeIdentifiers

struct CloudBackupView: View {
    @Environment(AppStore.self) private var store
    @State private var pickingFolder = false
    @State private var recoveryPassword = ""
    @State private var confirmPassword = ""
    @State private var includeKeys = false
    @State private var restoring: CloudBackupFile?
    @State private var result: String?

    private var backup: CloudBackup { store.cloudBackup }

    var body: some View {
        Form {
            Section {
                if let folder = backup.folderName {
                    LabeledContent("Ordner", value: folder)
                }
                Button(backup.folderName == nil ? "Cloud-Ordner wählen" : "Anderen Ordner wählen", systemImage: "folder") {
                    pickingFolder = true
                }
                .disabled(backup.busy)
                if backup.busy { ProgressView("Sicherung wird verarbeitet …") }
                if let failure = backup.failure { Text(failure).foregroundStyle(.red) }
            } footer: {
                Text("Wähle einen Ordner in iCloud Drive oder bei einem anderen Anbieter, der in Dateien Ordnerzugriff erlaubt. Der Anbieter übernimmt den Upload der verschlüsselten Sicherung.")
            }

            if backup.folderName != nil {
                if backup.enabled { automaticSection }
                else { setupSection }
                restoreSection
            }
        }
        .navigationTitle("Automatische Sicherung")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { selection in
            switch selection {
            case .success(let folder): Task { await backup.selectFolder(folder) }
            case .failure(let error): backup.failure = error.localizedDescription
            }
        }
        .sheet(item: $restoring) { file in
            RestoreCloudBackupView(file: file) { result = $0 }
        }
        .task { await backup.refreshFiles() }
    }

    private var automaticSection: some View {
        Section("Automatische Sicherung") {
            if let date = backup.lastSavedAt {
                LabeledContent("Zuletzt im Ordner gespeichert") { Text(date, format: .dateTime.day().month().hour().minute()) }
            }
            if let bytes = backup.size {
                LabeledContent("Größe", value: ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
            }
            Toggle("API-Schlüssel mitsichern", isOn: Binding(get: { backup.includesAPIKeys }, set: { include in
                if backup.setIncludesAPIKeys(include) { store.queueCloudBackup(immediately: true) }
            }))
            .disabled(backup.busy)
            Button("Jetzt sichern", systemImage: "arrow.clockwise") { store.queueCloudBackup(immediately: true) }
                .disabled(backup.busy || store.generationStoryID != nil)
            Button("Automatische Sicherung ausschalten") { backup.pause() }
                .disabled(backup.busy)
        }
    }

    private var setupSection: some View {
        Section {
            SecureField("Wiederherstellungspasswort", text: $recoveryPassword)
                .textContentType(.newPassword)
            SecureField("Passwort wiederholen", text: $confirmPassword)
                .textContentType(.newPassword)
            Toggle("API-Schlüssel mitsichern", isOn: $includeKeys)
            Button("Automatische Sicherung einschalten", systemImage: "lock.shield") {
                Task {
                    if await backup.enable(password: recoveryPassword, includeKeys: includeKeys) {
                        recoveryPassword = ""
                        confirmPassword = ""
                        store.queueCloudBackup(immediately: true)
                    }
                }
            }
            .disabled(backup.busy || recoveryPassword.count < 12 || recoveryPassword != confirmPassword)
        } footer: {
            Text("Mindestens 12 Zeichen. Bewahre das Passwort für die Wiederherstellung auf, etwa in der Passwörter-App. Gesichert werden Chats, Karten und Einstellungen. Bilder, KI-Modelle und ChatGPT-Anmeldungen werden ausgelassen.")
        }
    }

    private var restoreSection: some View {
        Section {
            if backup.files.isEmpty {
                Text("Im Ordner wurden keine Kai-Sicherungen gefunden.").foregroundStyle(.secondary)
            }
            ForEach(backup.files) { file in
                Button {
                    restoring = file
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(file.date, format: .dateTime.day().month(.wide).year().hour().minute())
                        Text(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(backup.busy || store.generationStoryID != nil)
            }
            Button("Sicherungen neu laden", systemImage: "arrow.clockwise") {
                Task { await backup.refreshFiles() }
            }
            .disabled(backup.busy)
            if let result { Text(result).foregroundStyle(.secondary) }
        } header: {
            Text("Wiederherstellen")
        } footer: {
            Text("Sicherungen werden zusammengeführt. Bereits vorhandene Chats und eingetragene Schlüssel behalten Vorrang.")
        }
    }
}

private struct RestoreCloudBackupView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let file: CloudBackupFile
    let onRestored: (String) -> Void
    @State private var password = ""
    @State private var failure: String?
    @State private var loading = false

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Sicherung") { Text(file.date, format: .dateTime.day().month().year().hour().minute()) }
                SecureField("Wiederherstellungspasswort", text: $password)
                    .textContentType(.password)
                if let failure { Text(failure).foregroundStyle(.red) }
                if loading { ProgressView("Sicherung wird geöffnet …") }
                Button("Wiederherstellen", systemImage: "arrow.down.doc") {
                    Task {
                        loading = true
                        defer { loading = false }
                        failure = nil
                        do {
                            let payload = try await store.cloudBackup.read(file, password: password)
                            let result = try store.restoreCloudBackup(payload)
                            password = ""
                            onRestored(result)
                            dismiss()
                        } catch {
                            failure = error.localizedDescription
                        }
                    }
                }
                .disabled(loading || password.isEmpty)
            }
            .navigationTitle("Sicherung öffnen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }.disabled(loading)
                }
            }
        }
        .interactiveDismissDisabled(loading)
    }
}
