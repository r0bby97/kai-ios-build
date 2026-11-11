import SwiftUI
import UniformTypeIdentifiers
import FadenCore

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var source = 1
    @State private var query = ""
    @State private var genre = CharacterGenre.all
    @State private var gender = CharacterGenderFilter.all
    @State private var kind = CharacterKindFilter.all
    @State private var favoritesOnly = false
    @State private var online: [CharacterCard] = []
    @State private var page = 1
    @State private var hasMore = false
    @State private var loading = false
    @State private var catalogueError: String?
    @State private var totalHits: Int?
    @State private var cataloguePositions: [CatalogueSource: CataloguePosition]?
    @State private var catalogueNotices: [CatalogueNotice] = []
    @State private var loadID = UUID()
    @State private var previewTranslationTask: Task<Void, Never>?
    @State private var preparationSheet = false
    @State private var languageSetup = false
    @AppStorage("catalogueSource") private var catalogueSourceRaw = CatalogueSource.all.rawValue
    @AppStorage("includeAdultCatalogue") private var includeAdult = true
    @State private var selected: CharacterCard?
    @State private var importing = false
    @State private var creating = false
    @State private var groupCreating = false
    @State private var showingFilters = false
    @Namespace private var genreSelection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var catalogueSource: CatalogueSource { (CatalogueSource(rawValue: catalogueSourceRaw) ?? .all).discoverySelection }
    private var filtered: [CharacterCard] {
        let cards = source == 0 ? store.libraryCharacters : online
        return cards.filter { card in
            (source == 1 || genre.matches(card)) && gender.matches(card) && kind.matches(card) && (!favoritesOnly || store.archive.favoriteIDs.contains(card.id)) && (source == 1 || query.isEmpty ||
            OmegaverseSearch.normalized(card.name + " " + card.tagline + " " + card.creator + " " + card.tags.joined(separator: " ")).localizedCaseInsensitiveContains(OmegaverseSearch.normalized(query)))
        }
    }
    private var featured: CharacterCard? {
        source == 0 && query.isEmpty && genre == .all && gender == .all && kind == .all && !favoritesOnly ? filtered.first : nil
    }
    private var rows: [CharacterCard] { filtered.filter { $0.id != featured?.id } }
    private var activeFilterCount: Int { (gender == .all ? 0 : 1) + (kind == .all ? 0 : 1) + (favoritesOnly ? 1 : 0) }
    private var filterSummary: String {
        [gender == .all ? nil : gender.title, genre == .all ? nil : genre.title,
         kind == .all ? nil : kind.title, favoritesOnly ? "Favoriten" : nil].compactMap { $0 }.joined(separator: " · ")
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    discoveryHeader
                    Picker("Bibliothek", selection: $source) {
                        Text("Deine Bibliothek").tag(0)
                        Text("Online entdecken").tag(1)
                    }.pickerStyle(.segmented)
                    if source == 1 {
                        Picker("Kartendatenbank", selection: Binding(get: { catalogueSource.rawValue }, set: { catalogueSourceRaw = $0 })) {
                            ForEach(CatalogueSource.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                        }.pickerStyle(.segmented).accessibilityIdentifier("catalogue-source")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Figuren").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Picker("Geschlecht der Figuren", selection: $gender) {
                            ForEach(CharacterGenderFilter.allCases, id: \.self) { item in
                                Text(item == .other ? "Divers+" : item.title).tag(item)
                            }
                        }.pickerStyle(.segmented).accessibilityIdentifier("character-gender")
                    }
                    if gender == .other {
                        Text("Diverse, gemischte oder nicht angegebene Geschlechter. Die Zuordnung verwendet die Angaben der Karte, nicht deine Rolle im Chat.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Genre").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        genreBar
                    }
                    if source == 0 { preparationStatus }
                    if genre != .all || activeFilterCount > 0 {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(filterSummary).font(.subheadline.weight(.medium))
                                Text("\(filtered.count) passende geladene Karten").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Zurücksetzen") { genre = .all; gender = .all; kind = .all; favoritesOnly = false }.font(.caption)
                        }
                    }
                    if source == 1 { catalogueSummary }
                    if source == 1, !catalogueNotices.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(catalogueNotices, id: \.source) { notice in
                                Label("\(notice.source.title): \(notice.message)", systemImage: "exclamationmark.circle")
                            }
                            Text("Treffer der übrigen Quellen bleiben verfügbar.")
                            Button("Fehlende Quellen erneut versuchen") { Task { await load(reset: false, retryFailuresOnly: true) } }.disabled(loading)
                        }.font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("catalogue-source-notices")
                    }
                    if let catalogueError, source == 1 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(catalogueError).font(.subheadline).foregroundStyle(.secondary)
                            Button("Erneut laden") { Task { await load(reset: true) } }
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
                    }
                    if let featured {
                        cardButton(featured) { FeaturedCharacter(card: featured) }
                    }
                    LazyVStack(spacing: 12) {
                        ForEach(rows) { card in
                            cardButton(card) { CharacterDiscoveryRow(card: card, favorite: store.archive.favoriteIDs.contains(card.id)) }
                                .accessibilityIdentifier("character-row-" + card.id)
                        }
                    }.accessibilityIdentifier("character-description-list")
                    if loading { ProgressView("Charaktere werden geladen").frame(maxWidth: .infinity).padding() }
                    if source == 1, hasMore, !loading {
                        Button("Weitere Charaktere laden") { Task { await load(reset: false) } }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                    }
                    if filtered.isEmpty && !loading && catalogueError == nil && !(source == 0 && store.libraryCharacters.isEmpty) {
                        ContentUnavailableView("Keine Charaktere gefunden", systemImage: "magnifyingglass", description: Text("Versuche einen anderen Suchbegriff oder importiere eine Karte."))
                    }
                    if source == 1 {
                        DisclosureGroup("Hinweise zur Quelle") {
                            Text(catalogueSource.discoveryNote + " Die Geschlechtszuordnung nutzt Karten-Tags. Divers+ sowie Kartentyp und Favoriten filtern geladene Treffer; weitere Karten lassen sich nachladen.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.font(.subheadline)
                    }
                }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 28)
            }
            .background(Palette.background).navigationTitle("Kai").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Charaktere suchen")
            .task(id: "\(source):\(query):\(includeAdult):\(genre.rawValue):\(gender.rawValue):\(catalogueSourceRaw)") {
                guard source == 1 else { return }
                do { try await Task.sleep(for: .milliseconds(350)); try Task.checkCancellation(); await load(reset: true) } catch {}
            }
            .refreshable { if source == 1 { await load(reset: true) } else { await store.preloadCatalogue(force: true) } }
            .onDisappear { previewTranslationTask?.cancel() }
            .onAppear { if CatalogueSource(rawValue: catalogueSourceRaw) == .janny { catalogueSourceRaw = CatalogueSource.all.rawValue } }
            .toolbar {
                ToolbarItem(placement: .principal) { KaiBrand() }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Karte importieren", systemImage: "square.and.arrow.down") { importing = true }
                        Button("Charakter erstellen", systemImage: "plus") { creating = true }
                        Button("Gruppenchat beginnen", systemImage: "person.2") { groupCreating = true }
                    } label: { Image(systemName: "plus").frame(width: 44, height: 44) }.accessibilityLabel("Charakter hinzufügen")
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .png]) { result in
                switch result { case .success(let url): store.importFile(url); case .failure(let error): store.error = error.localizedDescription }
            }
            .sheet(isPresented: $showingFilters) { filterSheet }
            .sheet(isPresented: $preparationSheet) { CataloguePreparationView().environment(store) }
            .sheet(isPresented: $languageSetup) { TranslationSetupView().environment(store) }
            .sheet(item: $selected) { card in CharacterDetail(card: card).environment(store) }
            .sheet(isPresented: $creating) { CharacterEditor().environment(store) }
            .sheet(isPresented: $groupCreating) {
                NavigationStack {
                    ChatSetupView(initial: [], groupMode: true) { config in
                        groupCreating = false
                        Task { try? await Task.sleep(for: .milliseconds(450)); store.start(characters: config.characters, persona: config.persona, scene: config.scenario, greeting: config.greeting) }
                    }.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { groupCreating = false } } }
                }.environment(store)
            }
        }
    }
    private var discoveryHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Entdecken").font(.system(.title, weight: .bold))
                Text(source == 0 ? "\(store.libraryCharacters.count) Charaktere in deiner Bibliothek" : catalogueSource == .all ? "Cardex · Chub" : "Charaktere aus \(catalogueSource.title)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { showingFilters = true } label: {
                Image(systemName: activeFilterCount == 0 ? "slider.horizontal.3" : "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 19, weight: .medium)).frame(width: 46, height: 46)
                    .kaiGlass(radius: 23, interactive: true)
            }.foregroundStyle(.primary).accessibilityLabel("Suchfilter")
                .accessibilityValue(activeFilterCount == 0 ? "Keine zusätzlichen Filter" : "\(activeFilterCount) aktiv")
        }
    }
    private var preparationStatus: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.libraryCharacters.isEmpty {
                Label("Öffentliche Charakterkarten laden", systemImage: "square.stack").font(.headline)
                Text("Kartentexte erscheinen zuerst. Die Originalbilder und vollständigen Definitionen folgen unabhängig davon.").font(.subheadline).foregroundStyle(.secondary)
            }
            if let status = store.catalogueStatus {
                HStack(alignment: .top, spacing: 8) {
                    if store.preloadingCatalogue { ProgressView().controlSize(.small) }
                    Text(status).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("catalogue-preparation-status")
                }
            }
            if store.preloadingCatalogue, store.catalogueTarget > 0 {
                ProgressView(value: Double(store.catalogueProcessed), total: Double(store.catalogueTarget))
            }
            if let status = store.catalogueTranslationStatus { Text(status).font(.caption).foregroundStyle(.secondary) }
            Button("Karten vorbereiten", systemImage: "arrow.down.circle") { preparationSheet = true }.font(.subheadline)
            if !store.translator.missingLanguages.isEmpty { Button("Deutsch einrichten", systemImage: "character.bubble") { languageSetup = true }.font(.subheadline) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var genreBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CharacterGenre.allCases, id: \.self) { item in
                    Button { genre = item } label: {
                        Text(item.title).font(.subheadline.weight(genre == item ? .semibold : .regular))
                            .foregroundStyle(genre == item ? Color(uiColor: .systemBackground) : Color.primary)
                            .padding(.horizontal, 16).frame(minHeight: 44)
                            .background {
                                if genre == item { KaiGenreSelection(namespace: genreSelection) }
                                else { Capsule().fill(Color.primary.opacity(0.045)) }
                            }.contentShape(Capsule())
                    }.buttonStyle(.plain).accessibilityIdentifier("genre-" + item.rawValue)
                        .accessibilityAddTraits(genre == item ? .isSelected : [])
                }
            }
        }.accessibilityIdentifier("genre-tabs").animation(KaiMotion.selection(reduceMotion: reduceMotion), value: genre)
    }
    private var catalogueSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Auch Inhalte für Erwachsene anzeigen", isOn: $includeAdult).font(.subheadline)
            if genre == .omegaverse, !includeAdult {
                Text("Viele Omegaverse-Karten sind als Inhalte für Erwachsene markiert und derzeit ausgeblendet.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text(catalogueSource.sortDescription(query: query))
                Spacer()
                if let totalHits, catalogueSource != .all { Text("\(totalHits.formatted(.number.locale(Locale(identifier: "de_DE")))) Treffer im Katalog") }
            }.font(.caption).foregroundStyle(.secondary)
        }
    }
    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("Charaktere") {
                    Picker("Kartentyp", selection: $kind) {
                        ForEach(CharacterKindFilter.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Toggle("Nur Favoriten", isOn: $favoritesOnly)
                }
                Section {
                    Text("Geschlecht, Genre und Suche lassen sich in der Übersicht kombinieren. Karten ohne klare Geschlechtsangabe stehen unter Divers+. Bei Online-Karten gelten Kartentyp und Favoriten für die bereits geladenen Treffer.").font(.subheadline).foregroundStyle(.secondary)
                    Button("Alle Filter zurücksetzen") { kind = .all; favoritesOnly = false; genre = .all; gender = .all }
                }
            }.navigationTitle("Suchfilter").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { showingFilters = false } } }
        }.presentationDetents([.medium, .large])
    }
    private func cardButton<Content: View>(_ card: CharacterCard, @ViewBuilder content: () -> Content) -> some View {
        Button { selected = card } label: { content().contentShape(Rectangle()) }.buttonStyle(.plain)
            .accessibilityLabel("\(card.name), \(card.displayTagline)")
            .contextMenu {
                if source == 0 {
                    Button(store.archive.favoriteIDs.contains(card.id) ? "Aus Favoriten entfernen" : "Als Favorit merken", systemImage: "star") { store.toggleFavorite(card) }
                }
            }
    }
    private func load(reset: Bool, retryFailuresOnly: Bool = false) async {
        if loading && !reset { return }
        let requestedQuery = query; let requestedAdult = includeAdult; let requestedGenre = genre; let requestedSource = catalogueSource; let requestedGender = gender
        let requestID = UUID(); loadID = requestID
        previewTranslationTask?.cancel(); previewTranslationTask = nil
        loading = true; catalogueError = nil
        let previousCards = reset ? [] : online
        let previousPositions = reset ? nil : cataloguePositions
        let failedSources = Set(catalogueNotices.map(\.source))
        let positions = retryFailuresOnly ? previousPositions?.filter { failedSources.contains($0.key) } : previousPositions
        if reset { online = []; hasMore = false; totalHits = nil; cataloguePositions = nil; catalogueNotices = [] }
        defer { if loadID == requestID { loading = false } }
        let nextPage = reset ? 1 : page + 1
        do {
            let result = try await Catalogue.search(query: requestedQuery, page: nextPage, includeAdult: requestedAdult, genre: requestedGenre, source: requestedSource, gender: requestedGender, positions: positions, updated: { partial in
                await MainActor.run {
                    guard loadID == requestID, source == 1, query == requestedQuery, includeAdult == requestedAdult,
                          genre == requestedGenre, gender == requestedGender, catalogueSource == requestedSource else { return }
                    let previews = cataloguePreviews(partial.cards)
                    let ids = Set(previousCards.map(\.id))
                    online = cataloguePreviews(previousCards) + previews.filter { !ids.contains($0.id) }
                    catalogueNotices = partial.notices
                    translatePreviews(requestID: requestID)
                }
            })
            try Task.checkCancellation()
            guard loadID == requestID, query == requestedQuery, includeAdult == requestedAdult, genre == requestedGenre, gender == requestedGender, catalogueSource == requestedSource else { return }
            let previews = cataloguePreviews(result.cards)
            let ids = Set(previousCards.map(\.id)); online = cataloguePreviews(previousCards) + previews.filter { !ids.contains($0.id) }
            translatePreviews(requestID: requestID)
            if retryFailuresOnly {
                var combined = previousPositions ?? [:]
                for current in failedSources { combined[current] = result.continuations[current] }
                cataloguePositions = combined
            } else { cataloguePositions = result.continuations }
            catalogueNotices = result.notices
            hasMore = !(cataloguePositions?.isEmpty ?? true); page = nextPage
            if !retryFailuresOnly { totalHits = result.totalCount }
        } catch is CancellationError {} catch { if loadID == requestID { catalogueError = error.localizedDescription } }
    }
    private func cataloguePreviews(_ cards: [CharacterCard]) -> [CharacterCard] {
        cards.map { original in
            if let cached = store.character(original.id), cached.hasDefinition { return cached }
            if let translated = online.first(where: { $0.id == original.id && $0.languageCode == "de" }) { return translated }
            var card = original
            if card.languageCode != "de" { card.languageCode = "pending" }
            return card
        }
    }
    private func translatePreviews(requestID: UUID) {
        guard previewTranslationTask == nil else { return }
        previewTranslationTask = Task {
            defer { if loadID == requestID { previewTranslationTask = nil } }
            var attempted = Set<String>()
            // New source results join the queue while translation is running.
            while !Task.isCancelled, loadID == requestID,
                  let card = online.first(where: { $0.languageCode != "de" && !attempted.contains($0.id) }) {
                attempted.insert(card.id)
                do {
                    let translated = try await store.translator.germanize(card)
                    guard !Task.isCancelled, loadID == requestID else { return }
                    if let index = online.firstIndex(where: { $0.id == card.id }) { online[index] = translated }
                } catch is CancellationError { return } catch { }
            }
        }
    }
}

private struct FeaturedCharacter: View {
    let card: CharacterCard
    var body: some View {
        CharacterImage(card: card).frame(height: 228).frame(maxWidth: .infinity)
            .overlay { LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom) }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if card.cast.isEnsemble { Label("Gruppenkarte", systemImage: "person.2.fill").font(.caption) }
                        Text(card.name).font(.system(.title, weight: .semibold)).lineLimit(2)
                        if card.languageCode == "pending" { Text(card.hasDefinition ? "Originaltext · Deutsch folgt" : "Vorschau · Definition noch nicht geladen").font(.caption) }
                        Text(card.displayTagline).font(.subheadline).lineLimit(2)
                    }
                    Spacer(minLength: 12)
                    Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36).kaiGlass(radius: 18, interactive: true)
                }.foregroundStyle(.white).padding(18)
            }.clipShape(RoundedRectangle(cornerRadius: 24)).contentShape(RoundedRectangle(cornerRadius: 24))
    }
}

private struct CharacterDiscoveryRow: View {
    let card: CharacterCard
    let favorite: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    private var summary: String {
        let text = !card.description.isEmpty ? card.description : !card.scenario.isEmpty ? card.scenario : card.displayTagline
        return text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            CharacterImage(card: card).frame(width: typeSize.isAccessibilitySize ? 70 : 94, height: 116)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(card.name).font(.headline).lineLimit(2)
                    Spacer(minLength: 0)
                    if favorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(Palette.accent) }
                    if card.cast.isEnsemble { Image(systemName: "person.2.fill").font(.caption).accessibilityLabel("Gruppenkarte") }
                }
                if card.languageCode == "pending" { Text(card.hasDefinition ? "Originaltext · Deutsch folgt" : "Vorschau · Definition noch nicht geladen").font(.caption2).foregroundStyle(.secondary) }
                if let source = CatalogueSource.source(for: card.id) { Text(source.title).font(.caption2.weight(.medium)).foregroundStyle(.secondary) }
                if !card.displayTagline.isEmpty { Text(card.displayTagline).font(.subheadline).lineLimit(2) }
                if summary != card.displayTagline { Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(typeSize.isAccessibilitySize ? 4 : 3) }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 3)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary).padding(.top, 5)
        }.foregroundStyle(.primary).padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 22))
            .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(Palette.hairline) }
    }
}

struct CharacterDetail: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var card: CharacterCard
    var allowsStartingConversation = true
    @State private var loading = false
    @State private var failure: String?
    @State private var editing = false
    @State private var translating = false
    @State private var translationNotice: String?
    @State private var translationScope = UUID().uuidString
    @State private var needsTranslationSetup = false
    @State private var languageSetup = false
    private var previousStory: Story? {
        store.archive.stories.filter { $0.characterID == card.id && !$0.isMultiCard }.max { $0.updatedAt < $1.updatedAt }
    }
    private var startUnavailableReason: String? {
        if loading { return "Die vollständige Charakterkarte wird noch geladen." }
        if !card.hasDefinition { return "Zum Gesprächsstart fehlt die vollständige Charakterdefinition." }
        return nil
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CharacterImage(card: card).frame(height: 280).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.name).font(.system(.largeTitle, design: .serif)).accessibilityIdentifier("character-detail-title")
                        Text(card.displayTagline).font(.title3).foregroundStyle(.secondary)
                        Text("Von \(card.creator)").font(.caption).foregroundStyle(.secondary)
                        if card.cast.isEnsemble {
                            Label("Mehrere Figuren in einer gemeinsamen Karte", systemImage: "person.2.fill").font(.subheadline)
                            if !card.cast.names.isEmpty { Text(card.cast.names.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(Array(card.tags.prefix(8).enumerated()), id: \.offset) { _, tag in GenreLabel(text: tag) } } }
                    if loading { ProgressView("Vollständige Charakterkarte laden") }
                    if let failure {
                        Text(failure).foregroundStyle(.red)
                        Button("Karte erneut laden") { Task { await fetch() } }
                    }
                    if card.languageCode == "pending", card.hasDefinition {
                        Text("Kartentexte werden getrennt übersetzt. Du kannst bereits ein Gespräch vorbereiten; vor dem Start wird nur dein gewählter Einstieg übersetzt.").font(.caption).foregroundStyle(.secondary)
                        if translating { ProgressView(store.translator.progress[translationScope]?.message ?? "Ins Deutsche übersetzen …") }
                        else if needsTranslationSetup { Button("Deutsch einrichten", systemImage: "character.bubble") { languageSetup = true }.accessibilityIdentifier("card-language-setup") }
                        else { Button("Auf Deutsch übersetzen") { store.translator.clearFailures(); Task { await fetch() } } }
                        if let translationNotice { Text(translationNotice).font(.caption).foregroundStyle(.secondary) }
                    }
                    if card.hasDefinition {
                      CardReadableText(card.description.isEmpty ? card.personality : card.description)
                      if !card.description.isEmpty && !card.personality.isEmpty && card.personality != card.description {
                        Text("Persönlichkeit und Stimme").font(.system(.title2, design: .serif))
                        CardReadableText(card.personality)
                      }
                      if !card.scenario.isEmpty { Text("Die Szene").font(.system(.title2, design: .serif)); CardReadableText(card.scenario) }
                      if !card.firstMessage.isEmpty {
                        Text("Der erste Satz").font(.system(.title2, design: .serif))
                        Text(CardMarkup.plain(card.firstMessage)).foregroundStyle(.secondary).padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                      }
                    }
                    if let source = card.sourceURL, let url = URL(string: source), url.scheme == "https" { Link("Originalkarte und Urheber", destination: url).font(.subheadline) }
                    Button("In Bibliothek speichern", systemImage: "bookmark") { store.addCard(card); dismiss() }.disabled(loading || !card.hasDefinition)
                }.padding(20)
            }.background(Palette.background)
                .safeAreaInset(edge: .bottom) {
                  if allowsStartingConversation {
                  VStack(spacing: 8) {
                    if let reason = startUnavailableReason {
                        Text(reason).font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("conversation-start-unavailable")
                    }
                    if card.hasDefinition && card.languageCode == "pending" {
                        Text("Zum Start wird nur die gewählte Begrüßung vorbereitet. Du kannst den Einstieg auch leer lassen und selbst beginnen.")
                            .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("greeting-only-start")
                    }
                    if let previousStory {
                        Button {
                            dismiss()
                            Task { try? await Task.sleep(for: .milliseconds(450)); store.presentedStory = .init(id: previousStory.id) }
                        } label: { Text("Gespräch fortsetzen").frame(maxWidth: .infinity).frame(height: 44) }
                            .buttonStyle(.borderedProminent)
                    }
                    NavigationLink {
                        ChatSetupView(initial: [card]) { config in
                            dismiss()
                            Task { try? await Task.sleep(for: .milliseconds(450)); store.start(characters: config.characters, persona: config.persona, scene: config.scenario, greeting: config.greeting) }
                        }
                    } label: {
                        Text(previousStory == nil ? "Gespräch beginnen" : "Neues Gespräch beginnen").frame(maxWidth: .infinity).frame(height: 44)
                    }.buttonStyle(.bordered).disabled(loading || !card.hasDefinition)
                  }.padding(16).background(.bar)
                  }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() }.accessibilityIdentifier("close-character-detail") }
                    ToolbarItem(placement: .primaryAction) {
                        HStack {
                            Button { store.toggleFavorite(card) } label: { Image(systemName: store.archive.favoriteIDs.contains(card.id) ? "star.fill" : "star") }
                                .accessibilityLabel("Favorit umschalten").disabled(loading || !card.hasDefinition)
                            Button("Bearbeiten", systemImage: "pencil") { editing = true }.disabled(loading)
                        }
                    }
                }
                .task { await fetch() }
                .background { TranslationHost(translator: store.translator, scope: translationScope) }
                .sheet(isPresented: $languageSetup) {
                    TranslationSetupView(onReady: { needsTranslationSetup = false; Task { await fetch() } }).environment(store)
                }
                .sheet(isPresented: $editing) { CharacterEditor(original: card) { card = $0 }.environment(store) }
        }
    }
    private func fetch(allowDownload: Bool = false) async {
        if let cached = store.character(card.id), cached.hasDefinition { card = cached }
        guard CatalogueSource.source(for: card.id) != nil || card.languageCode == "pending" else { return }
        failure = nil
        if !card.hasDefinition {
            loading = true
            do { card = try await Catalogue.detail(card) }
            catch {
                failure = error.localizedDescription; loading = false
                return
            }
            loading = false
        }
        guard card.languageCode != "de" else { return }
        card.languageCode = "pending"; translating = true; translationNotice = nil
        defer { translating = false }
        do {
            card = try await store.translator.germanize(card, scope: translationScope, allowDownload: allowDownload)
            if store.character(card.id) != nil { store.addCard(card) }
        } catch is CancellationError { }
        catch { needsTranslationSetup = error is TranslationSetupRequired; translationNotice = error.localizedDescription }
    }

}

struct CharacterEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: CharacterCard?
    var onSave: ((CharacterCard) -> Void)?
    @State private var name = ""
    @State private var tagline = ""
    @State private var personality = ""
    @State private var scenario = ""
    @State private var greeting = ""
    @State private var castMode = "auto"
    @State private var castNames = ""
    init(original: CharacterCard? = nil, onSave: ((CharacterCard) -> Void)? = nil) { self.original = original; self.onSave = onSave }
    var body: some View {
        NavigationStack {
            Form {
                Section("Charakter") { TextField("Name", text: $name); TextField("Ein Satz über den Charakter", text: $tagline) }
                Section("Persönlichkeit und Hintergrund") { TextEditor(text: $personality).frame(minHeight: 160).accessibilityLabel("Persönlichkeit und Hintergrund") }
                Section("Ausgangsszene") { TextEditor(text: $scenario).frame(minHeight: 100) }
                Section("Erste Nachricht") { TextEditor(text: $greeting).frame(minHeight: 100) }
                Section {
                    Picker("Besetzung", selection: $castMode) {
                        Text("Automatisch erkennen").tag("auto")
                        Text("Einzelne Figur").tag("single")
                        Text("Mehrere Figuren").tag("ensemble")
                    }
                    if castMode == "ensemble" { TextField("Figurennamen, durch Komma getrennt", text: $castNames) }
                    if let original, castMode == "auto" {
                        Text(original.cast.isEnsemble ? "Als gemeinsame Mehrpersonen-Karte erkannt" : "Als einzelne Figur erkannt").font(.caption).foregroundStyle(.secondary)
                    }
                } header: { Text("Figuren in dieser Karte") }
                footer: { Text("Die Erkennung nutzt Titel, Tags und Kartendefinition. Hier kannst du sie korrigieren, ohne zusätzliche Karten anzulegen.") }
            }.navigationTitle(original == nil ? "Eigener Charakter" : "Charakter bearbeiten").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Speichern") {
                        var card = original ?? CharacterCard(name: name)
                        card.name = name; card.tagline = tagline; card.personality = personality; card.scenario = scenario; card.firstMessage = greeting
                        card.castOverride = castMode == "auto" ? nil : CardCast(isEnsemble: castMode == "ensemble", names: castNames.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
                        store.addCard(card); onSave?(card); dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || personality.isEmpty) }
                }
                .onAppear { if let original {
                    name = original.name; tagline = original.tagline; personality = original.personality; scenario = original.scenario; greeting = original.firstMessage
                    castMode = original.castOverride.map { $0.isEnsemble ? "ensemble" : "single" } ?? "auto"
                    castNames = (original.castOverride?.names ?? original.cast.names).joined(separator: ", ")
                } }
        }
    }
}
