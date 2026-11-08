import SwiftUI
import FadenCore

struct StoryListView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    var body: some View {
        NavigationStack {
            List {
                if store.archive.stories.isEmpty {
                    ContentUnavailableView("Dein erstes Gespräch", systemImage: "text.bubble", description: Text("Wähle in Entdecken einen Charakter und beginne deine Geschichte."))
                        .listRowBackground(Color.clear)
                }
                ForEach(store.archive.stories.sorted { $0.updatedAt > $1.updatedAt }.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }) { story in
                    Button { store.presentedStory = .init(id: story.id) } label: {
                        HStack(spacing: 16) {
                            if let card = store.character(story.characterID) { CharacterImage(card: card).frame(width: 56, height: 64).clipShape(RoundedRectangle(cornerRadius: 8)) }
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(story.title).font(.headline).foregroundStyle(.primary); Spacer(); Text(story.updatedAt, style: .date).font(.caption2).foregroundStyle(.secondary) }
                                Text(story.activeMessages.last?.content ?? "Ein neues Gespräch").font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }.padding(.vertical, 8)
                    }.swipeActions {
                        Button("Löschen", role: .destructive) {
                            guard store.generationStoryID != story.id else { store.error = "Bitte zuerst die Antwort stoppen."; return }
                            store.archive.stories.removeAll { $0.id == story.id }; store.save()
                        }
                    }
                }
            }.navigationTitle("Gespräche").searchable(text: $query, prompt: "Gespräch suchen")
        }
    }
}

struct ChatView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let storyID: UUID
    @State private var writingHelp = false
    @State private var memorySheet = false
    @State private var branchSheet = false
    @State private var editing: Message?
    @State private var rewindMessage: Message?
    @State private var reset = false
    @State private var replyMode = "all"
    @State private var followsLatest = true
    @State private var scrollEdge = ChatScrollEdge.bottom
    @State private var scrollRequest = 0
    private var story: Story? { store.story(storyID) }
    private var busy: Bool { store.generationStoryID == storyID }
    private var draft: String { story?.draftText ?? "" }
    private var draftBinding: Binding<String> {
        Binding(get: { store.story(storyID)?.draftText ?? "" }, set: { store.updateDraft($0, storyID: storyID) })
    }
    var body: some View {
        Group {
            if let story {
                let insightGroups = Dictionary(grouping: story.activeInsights, by: \.sourceMessageID)
                Group {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            Color.clear.frame(height: 1).id("chat-start")
                            if let card = store.character(story.characterID) {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                    Text(story.isMultiCard ? "\(story.participantIDs.count) Karten in deiner Geschichte" : story.isGroup ? "Mehrere Figuren · eine gemeinsame Karte" : "Dein Gespräch mit \(card.name)").font(.subheadline.weight(.semibold))
                                        Text(story.persona.map { "Du schreibst als \($0.name)" } ?? card.displayTagline).font(.caption).foregroundStyle(.white.opacity(0.8))
                                    }
                                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 18))
                                    .padding(.top, 105)
                            }
                            ForEach(story.activeMessages) { message in
                                VStack(alignment: .leading, spacing: 14) {
                                    messageView(message, story: story)
                                    ForEach(insightGroups[message.id] ?? []) { insight in
                                        CharacterInsightView(insight: insight, characterName: store.character(insight.characterID)?.name ?? story.title) {
                                            store.mutate(storyID) { $0.insights?.removeAll { $0.id == insight.id } }
                                        }
                                    }
                                }.id(message.id)
                            }
                            if busy {
                                HStack(spacing: 8) { ProgressView().controlSize(.small); Text(store.generationStatus).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                            } else if story.activeMessages.last?.role == .user {
                                Button("Antwort erzeugen", systemImage: "arrow.clockwise") { store.regenerate(storyID) }.buttonStyle(.bordered)
                            }
                            Color.clear.frame(height: 52).id("bottom")
                        }.padding(20)
                            .background { ChatScrollAnchor(edge: scrollEdge, requestID: scrollRequest) }
                    }.scrollDismissesKeyboard(.interactively)
                        .defaultScrollAnchor(.bottom)
                        .defaultScrollAnchor(.top, for: .alignment)
                        .onChange(of: story.activeMessages.count) { _, _ in if followsLatest { jump(to: .bottom) } }
                        .onChange(of: busy) { _, _ in if followsLatest { jump(to: .bottom) } }
                        .onScrollPhaseChange { _, phase in if phase == .interacting { followsLatest = false } }
                        .overlay(alignment: .bottomTrailing) {
                            HStack(spacing: 4) {
                                Button {
                                    followsLatest = false
                                    jump(to: .top)
                                } label: { Image(systemName: "arrow.up.to.line").frame(width: 44, height: 44) }
                                    .accessibilityLabel("Zum Chat-Anfang scrollen").accessibilityIdentifier("scroll-to-chat-start")
                                Button {
                                    followsLatest = true
                                    jump(to: .bottom)
                                } label: { Image(systemName: "arrow.down.to.line").frame(width: 44, height: 44) }
                                    .accessibilityLabel("Zur neuesten Nachricht scrollen").accessibilityIdentifier("scroll-to-chat-latest")
                            }.kaiGlass(radius: 24, interactive: true).padding(.trailing, 20).padding(.bottom, 8)
                        }
                        .safeAreaInset(edge: .bottom) { composer }
                }
                .navigationTitle(story.title).navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { store.presentedStory = nil } label: { Image(systemName: "chevron.left").frame(width: 28, height: 32) }
                            .accessibilityLabel("Schließen")
                    }
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 9) {
                            if let card = store.character(story.characterID) { CharacterImage(card: card).frame(width: 32, height: 32).clipShape(Circle()) }
                            Text(story.title).font(.headline).lineLimit(1)
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Erinnerungen & Schreibstil", systemImage: "bookmark") { memorySheet = true }
                            Button("Gesprächszweige", systemImage: "point.topleft.down.to.point.bottomright.curvepath") { branchSheet = true }
                            Button("Rede & Gedanken", systemImage: "text.quote") { writingHelp = true }
                            Button("Weitererzählen", systemImage: "arrow.right") {
                                store.continueStory(storyID, replyingAs: selectedSpeaker, allParticipants: story.isGroup && replyMode == "all")
                            }.disabled(store.generationStoryID != nil)
                            Button("Zum Anfang zurück", systemImage: "backward.end") { reset = true }.disabled(busy)
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Gesprächsoptionen")
                    }
                }
            } else { ContentUnavailableView("Gespräch nicht gefunden", systemImage: "text.bubble") }
        }
        .background {
            if let story, let card = store.character(story.characterID) { CharacterChatBackground(card: card) }
            else { Color.black.ignoresSafeArea() }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $memorySheet) { MemoryView(storyID: storyID).environment(store).preferredColorScheme(store.archive.menuTheme.colorScheme) }
        .sheet(isPresented: $branchSheet) { BranchView(storyID: storyID).environment(store).preferredColorScheme(store.archive.menuTheme.colorScheme) }
        .sheet(item: $editing) { message in MessageEditor(message: message, storyID: storyID).environment(store).preferredColorScheme(store.archive.menuTheme.colorScheme) }
        .sheet(isPresented: $writingHelp) { WritingHelpView().preferredColorScheme(store.archive.menuTheme.colorScheme) }
        .onDisappear { store.save() }
        .alert("Hinweis", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("Verstanden", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
        .confirmationDialog("Ab dieser Nachricht neu weiterschreiben?", isPresented: Binding(get: { rewindMessage != nil }, set: { if !$0 { rewindMessage = nil } }), titleVisibility: .visible) {
            Button("Hier weiterschreiben") {
                do { try store.mutate(storyID) { try $0.rewind(to: rewindMessage?.id) } } catch { store.error = error.localizedDescription }
                rewindMessage = nil
            }
        } message: { Text("Der bisherige Verlauf bleibt als Gesprächszweig erhalten. Spätere Ereignisse und Stilbeispiele werden für den neuen Zweig nicht verwendet.") }
        .confirmationDialog("Ganz von vorne beginnen?", isPresented: $reset, titleVisibility: .visible) {
            Button("Zur ersten Nachricht zurück") {
                do { try store.mutate(storyID) { story in try story.rewind(to: story.greetingID) } }
                catch { store.error = error.localizedDescription }
            }
        } message: { Text("Dein bisheriger Verlauf wird als Zweig gespeichert.") }
    }
    private func messageView(_ message: Message, story: Story) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(message.role == .user ? story.persona?.name ?? store.archive.preferences.userName : store.character(message.speakerID ?? story.characterID)?.name ?? story.title)
                    .font(.subheadline.weight(.medium)).foregroundStyle(message.role == .user ? Palette.accent : .primary)
                Spacer()
                if message.interrupted && !busy { Text("Unterbrochen").font(.caption).foregroundStyle(.secondary) }
            }
            if message.content.isEmpty { Text("…").foregroundStyle(.secondary) }
            else if message.role == .user {
                roleplayText(message.content).font(.body).lineSpacing(6).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                if RoleplayText.parts(message.content).contains(where: { $0.kind == .thought }) {
                    Label("Gedanken · nur Erzählwissen", systemImage: "thought.bubble").font(.caption2).foregroundStyle(.secondary)
                }
            } else { Text(.init(message.content)).font(.body).lineSpacing(6).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
            if let model = message.model, message.role == .assistant, !message.content.isEmpty {
                Text(model.components(separatedBy: "/").last ?? model).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(message.role == .user ? 0.66 : 0.54), in: RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.09)) }
        .padding(message.role == .user ? .leading : .trailing, 18)
        .contextMenu {
            Button("Kopieren", systemImage: "doc.on.doc") { UIPasteboard.general.string = message.content }
            if !busy {
                Button("Hier weiterschreiben", systemImage: "arrow.uturn.backward") { rewindMessage = message }
                Button("Bearbeiten", systemImage: "pencil") { editing = message }
                Button("Als Erinnerung festhalten", systemImage: "bookmark") {
                    store.mutate(storyID) { $0.memories.append(.init(text: message.content, sourceMessageID: message.id)) }
                }
                if message.id == story.headID && message.role == .assistant && message.parentID != nil {
                    Button("Andere Antwort", systemImage: "arrow.clockwise") { store.regenerate(storyID) }
                }
            }
        }
    }
    private var composer: some View {
        VStack(spacing: 8) {
            if let story, story.isMultiCard {
                HStack {
                    Menu {
                        Button("Alle nacheinander") { replyMode = "all" }
                        Button("Automatisch eine Figur") { replyMode = "auto" }
                        ForEach(story.participantIDs, id: \.self) { id in
                            if let card = store.character(id) { Button(card.name) { replyMode = id } }
                        }
                    } label: { Label(replyTitle, systemImage: "person.2").font(.subheadline) }
                        .disabled(store.generationStoryID != nil).accessibilityLabel("Antwortende Figuren")
                    Spacer()
                    Text("\(story.participantIDs.count) Karten").font(.caption).foregroundStyle(.secondary)
                }.padding(.bottom, 4)
            } else if story?.isGroup == true {
                Label("Gruppenkarte · Figuren antworten gemeinsam", systemImage: "person.2").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom, spacing: 12) {
                TextField("„Rede“ oder *Gedanken*", text: draftBinding, axis: .vertical).lineLimit(1...7)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .accessibilityLabel("Deine Nachricht")
                    .accessibilityIdentifier("chat-draft-input")
                Button {
                    if busy { store.stop() }
                    else { followsLatest = true; store.send(draft, storyID: storyID, replyingAs: selectedSpeaker, allParticipants: story?.isMultiCard == true && replyMode == "all") }
                } label: {
                    Image(systemName: busy ? "stop.fill" : "arrow.up").font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44).background(Palette.accent, in: Circle())
                        .foregroundStyle(.black)
                }.disabled(!busy && (draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.generationStoryID != nil))
                    .accessibilityLabel(busy ? "Antwort stoppen" : "Nachricht senden")
            }.padding(6).kaiGlass(radius: 28, interactive: true)
        }.padding(.horizontal, 16).padding(.vertical, 10)
    }
    private var selectedSpeaker: String? { ["all", "auto"].contains(replyMode) ? nil : replyMode }
    private func jump(to edge: ChatScrollEdge) { scrollEdge = edge; scrollRequest += 1 }
    private func roleplayText(_ content: String) -> Text {
        RoleplayText.parts(content).reduce(Text("")) { combined, part in
            switch part.kind {
            case .thought: combined + Text(part.text).italic().foregroundColor(.white.opacity(0.72))
            case .speech: combined + Text(part.text).fontWeight(.medium)
            case .context: combined + Text(part.text)
            }
        }
    }
    private var replyTitle: String {
        if replyMode == "all" { return "Alle nacheinander" }
        if replyMode == "auto" { return "Automatisch" }
        return store.character(replyMode)?.name ?? "Automatisch"
    }
}

struct MessageEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let message: Message
    let storyID: UUID
    @State private var text = ""
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Die Änderung beginnt einen neuen Gesprächszweig. Der bisherige Verlauf bleibt erhalten.").font(.subheadline).foregroundStyle(.secondary)
                TextEditor(text: $text)
            }.padding(20).navigationTitle("Nachricht bearbeiten").navigationBarTitleDisplayMode(.inline)
                .onAppear { text = message.content }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Speichern") {
                        do { try store.mutate(storyID) { try $0.edit(message.id, text: text) }; dismiss() }
                        catch { store.error = error.localizedDescription }
                    }.disabled(text.isEmpty || store.generationStoryID != nil) }
                }
        }
    }
}

struct MemoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let storyID: UUID
    @State private var note = ""
    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                if let story = store.story(storyID) {
                    if let persona = story.persona {
                        Section("Deine Persona") { Text(persona.name).font(.headline); Text(persona.description).font(.subheadline).foregroundStyle(.secondary) }
                    }
                    if let scene = story.sceneOverride, !scene.isEmpty {
                        Section("Die Szene dieses Gesprächs") { Text(scene).font(.subheadline).foregroundStyle(.secondary) }
                    }
                    if story.isGroup {
                        Section("Anwesende Figuren") {
                            ForEach(story.participantIDs, id: \.self) { id in
                                if let card = store.character(id) {
                                    Text(card.name)
                                    if card.cast.isEnsemble { Text(card.cast.names.isEmpty ? "Mehrere Figuren aus dieser Karte" : card.cast.names.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                                }
                            }
                        }
                    }
                    Section("Dein Schreibstil in diesem Zweig") {
                        Toggle("Aus meinen Nachrichten lernen", isOn: $store.archive.preferences.learnStyle)
                        Text(StyleProfile(story: story).summary).font(.subheadline).foregroundStyle(.secondary)
                        Text("Die App leitet Länge und Format aus deinen Nachrichten ab und gibt passende Stilbeispiele mit. Beim Zurückspulen werden nur frühere Beispiele verwendet.").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Deine festen Schreibvorlieben") {
                        TextEditor(text: $store.archive.preferences.instructions).frame(minHeight: 100)
                        Text("Zum Beispiel: Ich schreibe in der Ich-Perspektive und mag kurze Dialoge. Diese Vorlieben gelten für alle Gespräche.").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Festgehaltene Erinnerungen") {
                        ForEach(story.activeMemories) { memory in
                            Text(memory.text).swipeActions { Button("Löschen", role: .destructive) { store.mutate(storyID) { $0.memories.removeAll { $0.id == memory.id } } } }
                        }
                        TextField("Neue Erinnerung", text: $note, axis: .vertical)
                        Button("Festhalten") {
                            store.mutate(storyID) { $0.memories.append(.init(text: note, sourceMessageID: $0.headID)) }; note = ""
                        }.disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Section("Langer Gesprächsverlauf") {
                        Text("Alle Nachrichten bleiben gespeichert. Für jede Antwort werden der aktuelle Verlauf, festgehaltene Fakten und passende ältere Auszüge zusammengestellt. Gedanken bleiben dabei privates Erzählwissen, keine hörbare Rede. Nicht jede gespeicherte Nachricht passt gleichzeitig in den Modellkontext.").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }.navigationTitle("Erinnerungen").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { store.save(); dismiss() } } }
                .onDisappear { store.save() }
        }
    }
}

struct BranchView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let storyID: UUID
    var body: some View {
        NavigationStack {
            List {
                if let story = store.story(storyID) {
                    if story.branches.isEmpty { Text("Wenn du zurückspulst oder eine Nachricht bearbeitest, bleibt der bisherige Verlauf hier erhalten.").foregroundStyle(.secondary) }
                    ForEach(story.branches.reversed()) { branch in
                        Button {
                            do { try store.mutate(storyID) { try $0.rewind(to: branch.headID, title: "Vor dem Zweigwechsel") }; dismiss() }
                            catch { store.error = error.localizedDescription }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(branch.title).foregroundStyle(.primary)
                                Text(branch.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                                if let message = story.messages.first(where: { $0.id == branch.headID }) {
                                    Text(message.content).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                                }
                            }.padding(.vertical, 8)
                        }.disabled(store.generationStoryID != nil)
                    }
                }
            }.navigationTitle("Gesprächszweige").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }
}
