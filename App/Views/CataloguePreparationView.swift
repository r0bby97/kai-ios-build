import SwiftUI
import FadenCore

struct CataloguePreparationView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cataloguePrepareCount") private var count = 60
    @State private var languageSetup = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Anzahl Karten", selection: $count) {
                        ForEach([24, 60, 120], id: \.self) { Text("\($0) Karten").tag($0) }
                    }.disabled(store.preloadingCatalogue)
                    Text("Öffentliche Chub-Karten nach Beliebtheit. Texte erscheinen zuerst; Definitionen und Originalbilder werden anschließend für die Offline-Nutzung gespeichert.").font(.subheadline).foregroundStyle(.secondary)
                    if store.preloadingCatalogue {
                        if store.catalogueTarget > 0 { ProgressView(value: Double(store.catalogueProcessed), total: Double(store.catalogueTarget)) }
                        else { ProgressView() }
                        Button("Vorbereitung abbrechen", role: .cancel) { store.cancelCataloguePreparation() }
                    } else {
                        Button("\(count) Karten mit Originalbildern vorbereiten") { store.startCataloguePreparation(count: count) }
                    }
                    if let status = store.catalogueStatus { Text(status).font(.caption).foregroundStyle(.secondary) }
                } header: { Text("Offline-Bibliothek") }
                Section {
                    if let status = store.catalogueTranslationStatus { Text(status).font(.subheadline).foregroundStyle(.secondary) }
                    Text("Die Deutschübersetzung läuft getrennt mit Apple auf dem iPhone. Fehlende Sprachpakete werden einmalig über Deutschübersetzung einrichten geladen.").font(.subheadline).foregroundStyle(.secondary)
                    Button("Deutschübersetzung einrichten") { languageSetup = true }
                    Button("Übersetzungen erneut starten") { store.retryCatalogueTranslations(force: true) }.disabled(store.translatingCatalogue)
                } header: { Text("Sprache") }
            }.navigationTitle("Karten vorbereiten").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
                .sheet(isPresented: $languageSetup) { TranslationSetupView().environment(store) }
        }
    }
}

struct TranslationSetupView: View {
    var onReady: (() -> Void)? = nil
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var scope = UUID().uuidString
    @State private var loading: String?
    @State private var status: String?
    private var languages: [String] { store.translator.missingLanguages.isEmpty ? ["en"] : store.translator.missingLanguages.sorted() }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Lade einmalig die Apple-Sprachpakete. Danach kann Kai Kartentexte auf dem iPhone ins Deutsche übersetzen. Originalkarten und Bilder sind davon unabhängig verfügbar.")
                    ForEach(languages, id: \.self) { language in
                        Button("\(Locale(identifier: "de").localizedString(forLanguageCode: language) ?? language) → Deutsch einrichten") {
                            loading = language; status = nil
                            Task {
                                do {
                                    try await store.translator.prepare(language: language, scope: scope)
                                    status = "Sprachpakete sind bereit. Die Kartenübersetzung wird fortgesetzt."
                                    onReady?()
                                    store.retryCatalogueTranslations(force: true)
                                    if onReady != nil { dismiss() }
                                } catch { status = error.localizedDescription }
                                loading = nil
                            }
                        }.disabled(loading != nil)
                    }
                    if loading != nil { ProgressView("Sprachpakete werden vorbereitet …") }
                    if let status { Text(status).font(.subheadline).foregroundStyle(.secondary) }
                }
            }.navigationTitle("Deutsch einrichten").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
                .background { TranslationHost(translator: store.translator, scope: scope) }
        }
    }
}
