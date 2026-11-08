import SwiftUI
import SafariServices
import UniformTypeIdentifiers
import FadenCore

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: Connection?
    @State private var importing = false
    @State private var exported: URL?
    @State private var showExport = false
    @State private var download = false
    @State private var connectionOrder = false
    @AppStorage("includeAdultCatalogue") private var includeAdult = true
    @State private var preparationSheet = false
    @State private var diagnosticsSheet = false
    @AppStorage("translationEngine") private var translationEngine = "google"
    @State private var localModel = "mlx-community/Qwen3-1.7B-4bit"
    @State private var personaEditor: UserPersona?
    @State private var sceneEditor: SceneTemplate?
    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        Image("KaiMark").resizable().scaledToFit().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Deine Geschichten").font(.title2.weight(.semibold))
                            Text("Auf deinem iPhone, in deinem Tempo").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 12)
                    TextField("Dein Name im Chat", text: $store.archive.preferences.userName)
                }
                Section {
                    Picker("Menüdesign", selection: $store.archive.menuTheme) {
                        ForEach(MenuTheme.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("menu-theme")
                } header: { Text("Darstellung") }
                footer: { Text("Hell oder Dunkel gilt für die Menüs. Im Chat bleibt das Bild der Charakterkarte der Hintergrund.") }
                Section {
                    Toggle("18+-Karten anzeigen", isOn: $includeAdult)
                } header: { Text("Kartensuche") }
                footer: { Text("Bezieht Inhalte für Erwachsene in die Online-Suche ein. Für KI-Antworten gelten die Inhaltsregeln des jeweiligen Anbieters.") }
                Section {
                    Toggle("Kostenpflichtige API-Modelle ausschließen", isOn: $store.archive.freeOnly)
                } footer: {
                    Text("Verwendet lokale Modelle, ausdrücklich kostenlose OpenRouter-Modelle und freigegebenes ChatGPT-Kontingent. Eigene API-Verbindungen werden übersprungen. Bei ChatGPT gelten zusätzlich deine dortigen Credit-Einstellungen. Kai löst keine Käufe oder Aufladungen aus.")
                }
                Section {
                    Button("Rangfolge ändern", systemImage: "arrow.up.arrow.down") { connectionOrder = true }
                        .accessibilityIdentifier("connection-priority-order")
                    ForEach(store.archive.connections) { connection in
                        ConnectionSettingsRow(connection: connection) { editing = connection }
                    }
                    Menu("Anbieter hinzufügen", systemImage: "plus") {
                        Button("OpenRouter") { editing = Connection(name: "OpenRouter", kind: .openRouter, baseURL: "https://openrouter.ai/api/v1", models: ["openrouter/free"]) }
                        Button("ChatGPT-Konto") { editing = Connection(name: "ChatGPT-Konto", kind: .chatGPT, baseURL: "https://api.openai.com/v1") }
                        ForEach(APIProviderPreset.allCases) { preset in
                            Button(preset.title) { editing = preset.connection() }
                        }
                        Button("Eigene API-Verbindung") { editing = Connection(name: "Eigener Anbieter", kind: .compatible, allowsCosts: true) }
                        Button("Lokales Modell") { editing = Connection(name: "Auf dem iPhone", kind: .local, models: ["mlx-community/Qwen3-1.7B-4bit"], contextTokens: 4096) }
                    }
                } header: { Text("KI-Verbindungen · Reihenfolge ist Priorität") }
                footer: { Text("Aktive Verbindungen werden von oben nach unten probiert. Unter Rangfolge ändern kannst du sie ziehen. Schalte ChatGPT aus, wenn du dein Arbeitskontingent schonen möchtest; die Anmeldung bleibt gespeichert. Bei einem kontoweiten Limit werden andere Modelle desselben Kontos übersprungen. Eine begonnene Antwort wird nicht mit einem anderen Modell vermischt.") }
                Section("Auf deinem iPhone") {
                    Text(store.local.status).font(.subheadline)
                    if store.local.loading { ProgressView(value: store.local.progress) }
                    Button("Lokales Modell laden") {
                        localModel = store.archive.connections.first(where: { $0.kind == .local })?.models.first ?? "mlx-community/Qwen3-1.7B-4bit"
                        download = true
                    }.disabled(store.local.loading || store.generationStoryID != nil)
                    if store.local.loadedID != nil { Button("Arbeitsspeicher freigeben") { store.local.unload() }.disabled(store.generationStoryID != nil) }
                    Text("Die Modellgewichte werden einmalig heruntergeladen. Danach läuft die Textgenerierung auf dem Gerät. Nach einem Neustart bitte erneut laden; vorhandene Dateien werden wiederverwendet. Qualität und Kontextlänge hängen vom gewählten Modell und freien Speicher ab.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Schreiben") {
                    LabeledContent("Sprache", value: "Deutsch")
                    Picker("Karten übersetzen mit", selection: $translationEngine) {
                        Text("Google · online").tag("google")
                        Text("Apple · auf dem iPhone").tag("apple")
                    }
                    Text("Google übersetzt Kartentexte über seine öffentliche Web-Schnittstelle und benötigt keine Sprachpakete oder KI-Tokens. Kartentexte werden dafür an Google übertragen. Apple bleibt als lokale Alternative verfügbar.").font(.caption).foregroundStyle(.secondary)
                    Button("Karten vorbereiten und Deutsch einrichten") { preparationSheet = true }
                    Button("Ausstehende Kartenübersetzungen erneut versuchen") { store.retryCatalogueTranslations(force: true) }.disabled(store.translatingCatalogue)
                    Text("Karten werden unabhängig von ihrer Ausgangssprache ins Deutsche übersetzt und gespeichert. Google benötigt eine Internetverbindung, Apple einmalig lokale Sprachpakete. Die Wahl ändert nicht die Reihenfolge der Karten.").font(.caption).foregroundStyle(.secondary)
                    Picker("Maximale Wortzahl", selection: Binding(get: { store.archive.preferences.maximumResponseWords }, set: { store.archive.preferences.responseWords = $0 })) {
                        let limits = Array(Set([50, 100, 200, 400, 800, 1200, store.archive.preferences.maximumResponseWords])).sorted()
                        ForEach(limits, id: \.self) { Text("Bis zu \($0) Wörter").tag($0) }
                    }.accessibilityIdentifier("response-word-limit")
                    Stepper("Bis zu \(store.archive.preferences.maximumResponseWords) Wörter", value: Binding(get: { store.archive.preferences.maximumResponseWords }, set: { store.archive.preferences.responseWords = $0 }), in: 25...2000, step: 25)
                    Text("Die Wortzahl ist eine Obergrenze pro Antwort. Die KI darf kürzer antworten; längere Antworten benötigen mehr Zeit und Kontingent. Ein kleines Kontextfenster kann die Ausgabe zusätzlich verkürzen.").font(.caption).foregroundStyle(.secondary)
                    Toggle("Meinen Schreibstil berücksichtigen", isOn: $store.archive.preferences.learnStyle)
                    TextField("Feste Schreibvorlieben", text: $store.archive.preferences.instructions, axis: .vertical).lineLimit(2...6)
                    Text("„So spreche ich mit der Figur.“ · *So denke ich, ohne dass die Figur es hört.* Text ohne Anführungszeichen bleibt Erzählkontext und wird nicht automatisch laut gesagt.").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Picker("Gelegentliche Einblicke", selection: Binding(get: { store.archive.preferences.effectiveInsightFrequency }, set: { store.archive.preferences.insightFrequency = $0; store.save() })) {
                        ForEach(InsightFrequency.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.accessibilityIdentifier("insight-frequency")
                    Text("Gedanken oder Erinnerungen der Figur erscheinen als eigener, privater Einblick. Der Abstand variiert etwas; es zählt die Zahl abgeschlossener KI-Antworten, ohne Begrüßung.").font(.caption).foregroundStyle(.secondary)
                    Text("Ein Einblick nutzt eine zusätzliche kurze Anfrage beim selben Anbieter wie die Antwort. Ist er nicht verfügbar, wird der Einblick übersprungen. Dafür wird kein anderer Anbieter eingeschaltet.").font(.caption).foregroundStyle(.secondary)
                } header: { Text("Hinter den Zeilen") }
                Section("Deine Personas") {
                    ForEach(store.archive.personas) { persona in
                        Button(persona.name) { personaEditor = persona }
                            .swipeActions { Button("Löschen", role: .destructive) { store.archive.personas.removeAll { $0.id == persona.id }; store.save() } }
                    }
                    Button("Persona hinzufügen", systemImage: "person.badge.plus") { personaEditor = UserPersona(name: "") }
                    Text("Wähle beim Gesprächsstart, als wer du schreibst. Bestehende Gespräche behalten ihre Persona, auch wenn du eine Vorlage später änderst.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Deine Szenarien") {
                    ForEach(store.archive.scenes) { scene in
                        Button(scene.name) { sceneEditor = scene }
                            .swipeActions { Button("Löschen", role: .destructive) { store.archive.scenes.removeAll { $0.id == scene.id }; store.save() } }
                    }
                    Button("Szenario hinzufügen", systemImage: "text.book.closed") { sceneEditor = SceneTemplate(name: "", description: "") }
                }
                Section("Deine Daten") {
                    Button("Fehlerberichte", systemImage: "stethoscope") { diagnosticsSheet = true }
                    Button("Backup exportieren", systemImage: "square.and.arrow.up") {
                        do { exported = try store.backupURL(); showExport = true } catch { store.error = error.localizedDescription }
                    }
                    Button("Backup zusammenführen", systemImage: "square.and.arrow.down") { importing = true }
                    Text("Backups enthalten Chats, Karten und Einstellungen, aber keine API-Schlüssel oder Anmeldetokens. Bestehende Chats werden beim Import nicht überschrieben. Exportiere vor einem App-Update ein Backup und installiere Updates über dieselbe App-Kennung.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Über Kai") {
                    LabeledContent("Version", value: "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))")
                    Text("Originalkarten aus Chub und JannyAI · Offline-Bibliothek · private Gesprächszweige")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Link("Unslop · Designleitfaden von Damir Sokolovsky", destination: URL(string: "https://github.com/heydamir/unslop")!).font(.caption)
                    Link("Quellcode", destination: URL(string: "https://github.com/r0bby97/kai-ios-build")!)
                    Text("Chats bleiben lokal gespeichert. Für Cloud-Antworten wird der ausgewählte Kontext an den jeweiligen Anbieter übertragen. Online-Katalog und Modell-Downloads kontaktieren deren Betreiber. Kai enthält keine Analyse- oder Werbe-SDKs.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Einstellungen")
                .sheet(isPresented: $diagnosticsSheet) { DiagnosticsView().environment(store) }
                .sheet(isPresented: $preparationSheet) { CataloguePreparationView().environment(store) }
                .sheet(isPresented: $connectionOrder) { ConnectionOrderView().environment(store) }
                .onDisappear { store.save() }
                .onChange(of: store.archive.menuTheme) { _, _ in store.save() }
                .sheet(item: $editing) { connection in ConnectionEditor(original: connection).environment(store) }
                .sheet(isPresented: $showExport) { if let exported { ShareSheet(items: [exported]) } }
                .sheet(item: $personaEditor) { PersonaEditor(original: $0).environment(store) }
                .sheet(item: $sceneEditor) { SceneEditor(original: $0).environment(store) }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                    do { try store.importBackup(result.get()) } catch { store.error = error.localizedDescription }
                }
                .confirmationDialog("Lokales Modell herunterladen und laden?", isPresented: $download, titleVisibility: .visible) {
                    Button("Modell laden") { Task { do { try await store.local.load(id: localModel) } catch { if let report = (error as? ProviderFailure)?.diagnostic { store.diagnostics.append(report) }; store.error = error.localizedDescription } } }
                } message: { Text("\(localModel)\nDer erste Download benötigt je nach Modell mehrere hundert MB bis einige GB. Nutze dafür möglichst WLAN.") }
        }
    }
}

struct ConnectionEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: Connection
    @State private var value = Connection(name: "", kind: .compatible)
    @State private var key = ""
    @State private var modelText = ""
    @State private var models: [RemoteModel] = []
    @State private var loading = false
    @State private var modelSearch = ""
    @State private var failure: String?
    @State private var email = ""
    @State private var revoke = false
    @State private var testResult: String?
    @State private var diagnosticsSheet = false
    private var visibleModels: [RemoteModel] {
        models.filter { (modelSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(modelSearch) || $0.id.localizedCaseInsensitiveContains(modelSearch)) &&
            (value.kind != .openRouter || !store.archive.freeOnly || $0.id.hasSuffix(":free") || $0.id == "openrouter/free") }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Verbindung") {
                    TextField("Name", text: $value.name)
                    Toggle("Aktiv", isOn: $value.enabled)
                    LabeledContent("Typ", value: value.apiPreset?.title ?? value.kind.title)
                    if value.kind == .compatible && value.apiPreset == nil {
                        TextField("HTTPS-Basisadresse, z. B. …/v1", text: $value.baseURL).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        Toggle("Zusätzliche Kosten erlaubt", isOn: $value.allowsCosts)
                        Text("Abos sind nur nutzbar, wenn der Anbieter einen offiziellen API-Zugang dafür bereitstellt. Ein beliebiges Premium-Abo enthält nicht automatisch API-Nutzung.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if value.kind == .chatGPT {
                    Section("ChatGPT-Konto") {
                        if !email.isEmpty { LabeledContent("Verbunden", value: email) }
                        Button("Mit ChatGPT fortfahren") {
                            failure = nil
                            Task {
                                do {
                                    try await store.auth.connect(value.id)
                                    email = store.auth.credential(value.id)?.email ?? ""
                                    await fetchModels()
                                    if parsedModels.isEmpty, let first = models.first { modelText = first.id }
                                } catch { if error as? FadenError != .cancelled { failure = error.localizedDescription } }
                            }
                        }.disabled(store.auth.signingIn)
                        if store.auth.signingIn { ProgressView("Warte auf Anmeldung") }
                        if !email.isEmpty {
                            Button("Konto trennen", role: .destructive) { revoke = true }
                        }
                        Link("ChatGPT-Nutzung und Kontingent verwalten", destination: URL(string: "https://chatgpt.com/settings/usage")!)
                        Text("Offizielle Anmeldung für lokal betriebene Clients. Verfügbarkeit und Modellzugriff hängen von deinem Konto ab. Die Nutzung teilt dein bestehendes Kontingent; OpenAI-Regeln gelten weiterhin. Eine normale API-Abrechnung wird dadurch nicht aktiviert.")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Wenn du keine zusätzlichen Kosten möchtest, deaktiviere in den ChatGPT-Nutzungseinstellungen zusätzliche Credits für Apps. Kai kann diese externe Kontoeinstellung nicht prüfen.").font(.caption).foregroundStyle(.secondary)
                    }
                } else if value.kind != .local {
                    Section("API-Zugang") {
                        if let preset = value.apiPreset {
                            Text(preset.accountNote).font(.subheadline).foregroundStyle(.secondary)
                            Link("API-Schlüssel erstellen", destination: preset.keyURL)
                        }
                        SecureField("API-Schlüssel", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                        if value.kind == .anthropic {
                            TextField("Workspace-ID (falls benötigt)", text: Binding(get: { value.workspaceID ?? "" }, set: { value.workspaceID = $0.isEmpty ? nil : $0 }))
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                        }
                        if value.kind == .openRouter { Link("OpenRouter-Schlüssel erstellen", destination: URL(string: "https://openrouter.ai/keys")!) }
                        Text("Der Schlüssel wird im iOS-Schlüsselbund gespeichert und nicht ins Backup aufgenommen.").font(.caption).foregroundStyle(.secondary)
                        if value.apiPreset != nil && store.archive.freeOnly {
                            Text("Diese API-Verbindung wird beim Chatten übersprungen, solange in den Einstellungen „Kostenpflichtige API-Modelle ausschließen“ eingeschaltet ist.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    TextField("Modell-IDs, eine pro Zeile", text: $modelText, axis: .vertical).lineLimit(2...8).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if value.kind != .local { Button("Verfügbare Modelle laden") { Task { await fetchModels() } }.disabled(loading) }
                    if loading { ProgressView() }
                    if let failure { Text(failure).font(.subheadline).foregroundStyle(.red) }
                    Picker("Kontextfenster", selection: $value.contextTokens) {
                        ForEach([2048, 4096, 8192, 16384, 32768, 65536], id: \.self) { Text("\($0) Tokens").tag($0) }
                    }
                } header: { Text("Modelle · zuerst die oberste ID") }
                footer: {
                    Text(value.kind == .local ? "Für das iPhone zunächst ein kleines quantisiertes MLX-Modell verwenden, etwa mlx-community/Qwen3-1.7B-4bit. Das Modell muss vor dem ersten Chat ausdrücklich geladen werden." : value.kind == .openRouter ? "openrouter/free wechselt zwischen verfügbaren Gratis-Modellen. Bestimmte Modellfamilien und Premium-Abos anderer Apps sind darin nicht zugesichert. Kostenlose Varianten enden auf :free." : "Lade die aktuellen Modelle mit deinem Zugang und wähle ein Textmodell. Die oberste ausgewählte Modell-ID wird zuerst probiert. Kontext und Ausgabe müssen vom Modell unterstützt werden.")
                }
                Section("Verbindung prüfen") {
                    Button("Testantwort erzeugen", systemImage: "stethoscope") { Task { await testConnection() } }.disabled(loading)
                    Text("Sendet einen kurzen Gruß an genau diese Verbindung, ohne Kartenkontext. Die bestehende Kostensperre gilt weiterhin.").font(.caption).foregroundStyle(.secondary)
                    if let testResult { Text(testResult).font(.subheadline).textSelection(.enabled) }
                    Button("Technische Fehlerberichte öffnen") { diagnosticsSheet = true }
                }
                if !models.isEmpty {
                    Section("Modellauswahl") {
                        TextField("Modell suchen", text: $modelSearch)
                        ForEach(Array(visibleModels.prefix(100))) { model in
                            Button {
                                var ids = parsedModels
                                if ids.contains(model.id) { ids.removeAll { $0 == model.id } } else { ids.append(model.id) }
                                modelText = ids.joined(separator: "\n")
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) { Text(model.name).foregroundStyle(.primary); Text(model.id).font(.caption).foregroundStyle(.secondary) }
                                    Spacer(); if parsedModels.contains(model.id) { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                }
                if store.archive.connections.contains(where: { $0.id == value.id }) {
                    Section { Button("Verbindung entfernen", role: .destructive) {
                        store.archive.connections.removeAll { $0.id == value.id }; Keychain.delete("provider.\(value.id)"); store.save(); dismiss()
                    }.disabled(value.kind == .chatGPT && !email.isEmpty) }
                }
            }.navigationTitle(value.apiPreset?.title ?? value.kind.title).navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $diagnosticsSheet) { DiagnosticsView().environment(store) }
                .onAppear { value = original; key = Keychain.string("provider.\(original.id)"); modelText = original.models.joined(separator: "\n"); email = store.auth.credential(original.id)?.email ?? "" }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Speichern") { save() }.disabled(value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
                .sheet(isPresented: Binding(get: { store.auth.browserURL != nil }, set: { if !$0 { store.auth.cancel() } })) {
                    if let url = store.auth.browserURL { SafariView(url: url).ignoresSafeArea() }
                }
                .confirmationDialog("ChatGPT-Verbindung trennen?", isPresented: $revoke, titleVisibility: .visible) {
                    Button("Trennen", role: .destructive) { Task {
                        let success = await store.auth.disconnect(value.id); email = ""
                        if !success { failure = "Lokal getrennt. Der Widerruf bei ChatGPT konnte nicht bestätigt werden. Die Verbindung kannst du zusätzlich in den ChatGPT-Einstellungen entfernen." }
                    } }
                }
        }
    }
    private var parsedModels: [String] {
        var seen = Set<String>()
        return modelText.split(whereSeparator: { $0 == "\n" || $0 == "," }).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
    private func save() {
        do {
            if value.kind != .local { _ = try HTTP.requireHTTPS(value.baseURL) }
            value.models = parsedModels
            if let index = store.archive.connections.firstIndex(where: { $0.id == value.id }) { store.archive.connections[index] = value }
            else { store.archive.connections.append(value) }
            if value.kind != .chatGPT && value.kind != .local { try Keychain.save(key.trimmingCharacters(in: .whitespacesAndNewlines), key: "provider.\(value.id)") }
            store.save(); dismiss()
        } catch { failure = error.localizedDescription }
    }
    private func testConnection() async {
        loading = true; failure = nil; testResult = nil
        defer { loading = false }
        do {
            var candidate = value; candidate.models = parsedModels; candidate.enabled = true
            guard let model = candidate.permittedModels(freeOnly: store.archive.freeOnly).first else {
                throw FadenError.invalidData("Wähle ein erlaubtes Modell. Die Kostensperre kann kostenpflichtige API-Verbindungen ausschließen.")
            }
            let prompt = BuiltPrompt(system: "Antworte auf Deutsch mit einem kurzen Gruß.", messages: [.init(role: "user", content: "Hallo.")], retrievedCount: 0, truncated: false)
            var limiter = ResponseWordLimiter(maximumWords: 12)
            let result: InferenceResult
            if candidate.kind == .local {
                result = try await store.local.generate(id: model, prompt: prompt, maxTokens: 64) { limiter.append($0).reachedLimit }
            } else {
                let credential = candidate.kind == .chatGPT ? try await store.auth.accessToken(candidate.id) : key.trimmingCharacters(in: .whitespacesAndNewlines)
                if candidate.requiresAPIKey && credential.isEmpty { throw FadenError.invalidData("Bitte zuerst den API-Schlüssel eintragen.") }
                result = try await CloudEngine.generate(connection: candidate, model: model, key: credential, prompt: prompt, maxTokens: 64) { limiter.append($0).reachedLimit }
            }
            store.diagnostics.append(result.diagnostic)
            testResult = "Test erfolgreich: " + String(result.text.prefix(300))
        } catch {
            if let report = (error as? ProviderFailure)?.diagnostic { store.diagnostics.append(report) }
            failure = error.localizedDescription
        }
    }
    private func fetchModels() async {
        loading = true; failure = nil; defer { loading = false }
        do {
            if value.requiresAPIKey && key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw FadenError.invalidData("Bitte zuerst einen API-Schlüssel eintragen.")
            }
            let credential = value.kind == .chatGPT ? try await store.auth.accessToken(value.id) : key.trimmingCharacters(in: .whitespacesAndNewlines)
            models = try await CloudEngine.models(connection: value, key: credential)
            if value.kind == .openRouter && !models.contains(where: { $0.id == "openrouter/free" }) {
                models.insert(.init(id: "openrouter/free", name: "Automatische kostenlose Auswahl", isFree: true), at: 0)
            }
        } catch { failure = error.localizedDescription }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
