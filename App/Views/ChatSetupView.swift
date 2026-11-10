import SwiftUI
import FadenCore

struct ChatConfiguration {
    var characters: [CharacterCard]
    var persona: UserPersona?
    var scenario: String
    var greeting: String
}

struct ChatSetupView: View {
    @Environment(AppStore.self) private var store
    let initial: [CharacterCard]
    var groupMode = false
    let onStart: (ChatConfiguration) -> Void
    @State private var selected: [String] = []
    @State private var personaID: UUID?
    @State private var sceneID: UUID?
    @State private var scenario = ""
    @State private var greeting = ""
    @State private var greetingIndex = 0
    @State private var newPersona: UserPersona?
    @State private var newScene: SceneTemplate?
    private var cards: [CharacterCard] {
        selected.compactMap { id in initial.first(where: { $0.id == id }) ?? store.character(id) }
    }
    private var available: [CharacterCard] {
        initial + store.libraryCharacters.filter { card in !initial.contains(where: { $0.id == card.id }) }
    }
    private var containsEnsemble: Bool { cards.contains { $0.cast.isEnsemble } }
    var body: some View {
        Form {
            Section {
                ForEach(cards) { card in
                    Button {
                        selected.removeAll { $0 == card.id }
                    } label: {
                        HStack(spacing: 12) {
                            CharacterImage(card: card).frame(width: 36, height: 44).clipShape(RoundedRectangle(cornerRadius: 6))
                            Text(card.name).foregroundStyle(.primary)
                            if card.cast.isEnsemble { Image(systemName: "person.2.fill").accessibilityLabel("Gruppenkarte") }
                            Spacer()
                            Image(systemName: selected.contains(card.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(selected.contains(card.id) ? Palette.accent : .secondary)
                        }
                    }.accessibilityLabel("Figur \(card.name)")
                }
                Menu("Figur hinzufügen", systemImage: "person.badge.plus") {
                    ForEach(available.filter { !selected.contains($0.id) }) { card in
                        Button(card.name) { if selected.count < 4 { selected.append(card.id) } }
                    }
                }.disabled(selected.count >= 4)
            } header: { Text("\(selected.count) von 4 Karten ausgewählt") }
            footer: { Text(containsEnsemble ? "Diese Karte enthält bereits mehrere Figuren. Sie werden gemeinsam aus ihrer Kartendefinition gespielt; du musst keine weiteren Karten hinzufügen." : "Du kannst auch mehrere einzelne Karten zu einem privaten Gruppenchat kombinieren und gezielt eine Karte antworten lassen.") }
            Section("Deine Rolle") {
                Picker("Persona", selection: $personaID) {
                    Text(store.archive.preferences.userName).tag(Optional<UUID>.none)
                    ForEach(store.archive.personas) { persona in Text(persona.name).tag(Optional(persona.id)) }
                }
                if let persona = store.archive.personas.first(where: { $0.id == personaID }) { Text(persona.description).font(.subheadline).foregroundStyle(.secondary) }
                Button("Neue Persona erstellen") { newPersona = UserPersona(name: "") }
            }
            Section("Die Szene") {
                Picker("Szenario", selection: $sceneID) {
                    Text("Charakter-Vorgabe").tag(Optional<UUID>.none)
                    ForEach(store.archive.scenes) { scene in Text(scene.name).tag(Optional(scene.id)) }
                }.accessibilityIdentifier("scene-picker")
                TextEditor(text: $scenario).frame(minHeight: 100).accessibilityLabel("Szenariobeschreibung")
                Button("Als eigenes Szenario speichern") { newScene = SceneTemplate(name: "", description: scenario, greeting: greeting) }
            }
            Section {
                if let first = cards.first, !first.alternateGreetings.isEmpty {
                    Picker("Alternative Begrüßung", selection: $greetingIndex) {
                        Text("Original").tag(0)
                        ForEach(Array(first.alternateGreetings.indices), id: \.self) { Text("Variante \($0 + 1)").tag($0 + 1) }
                    }
                }
                TextEditor(text: $greeting).frame(minHeight: 120).accessibilityLabel("Gesprächseinstieg")
                Button("Ohne Begrüßung starten") { greeting = "" }.accessibilityIdentifier("clear-start-greeting")
            } header: { Text("Gesprächseinstieg") }
            footer: { Text("Nur dieser ausgewählte Einstieg wird vor dem Start ins Deutsche übersetzt. Lange Karteneigenschaften und andere Sprachen werden getrennt vorbereitet. Du kannst den Einstieg leer lassen und selbst beginnen; dafür sind keine Übersetzungspakete nötig. Persona und Szene bleiben für dieses Gespräch gespeichert.") }
        }
        .navigationTitle(groupMode ? "Gruppenchat vorbereiten" : containsEnsemble ? "Gruppenkarte vorbereiten" : "Gespräch vorbereiten").navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                onStart(.init(characters: cards, persona: store.archive.personas.first { $0.id == personaID }, scenario: scenario, greeting: greeting))
            } label: {
                Text(cards.count > 1 ? "Gruppenchat beginnen" : "Gespräch beginnen").frame(maxWidth: .infinity).frame(height: 48)
            }.buttonStyle(.borderedProminent).disabled(cards.count < (groupMode ? 2 : 1)).padding(16).background(.bar)
        }
        .onAppear {
            if selected.isEmpty {
                selected = (initial.isEmpty ? Array(store.archive.characters.prefix(groupMode ? 2 : 1)) : initial).map(\.id)
                resetOpening()
            }
        }
        .onChange(of: selected.first) { _, _ in if sceneID == nil { resetOpening() } }
        .onChange(of: sceneID) { _, _ in
            if let scene = store.archive.scenes.first(where: { $0.id == sceneID }) { scenario = scene.description; greeting = scene.greeting }
            else { resetOpening() }
        }
        .onChange(of: greetingIndex) { _, index in
            if let card = cards.first { greeting = index == 0 ? card.firstMessage : card.alternateGreetings[safe: index - 1] ?? card.firstMessage }
        }
        .sheet(item: $newPersona) { persona in PersonaEditor(original: persona) { personaID = $0.id }.environment(store) }
        .sheet(item: $newScene) { scene in SceneEditor(original: scene) { sceneID = $0.id }.environment(store) }
    }
    private func resetOpening() { scenario = cards.first?.scenario ?? ""; greeting = cards.first?.firstMessage ?? ""; greetingIndex = 0 }
}

struct PersonaEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: UserPersona
    var onSave: ((UserPersona) -> Void)?
    @State private var name = ""
    @State private var details = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Deine Figur") { TextField("Name der Persona", text: $name) }
                Section("Hintergrund, Auftreten und Beziehung") {
                    TextEditor(text: $details).frame(minHeight: 220).accessibilityLabel("Persona-Beschreibung")
                    Text("Beschreibe, als wer du mit den Charakteren sprichst. Die Persona ist deine bewusste Rollenbeschreibung; dein gelernter Schreibstil bleibt separat einstellbar.").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Persona").navigationBarTitleDisplayMode(.inline)
                .onAppear { name = original.name; details = original.description }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Speichern") {
                        var value = original; value.name = name; value.description = details
                        if let i = store.archive.personas.firstIndex(where: { $0.id == value.id }) { store.archive.personas[i] = value }
                        else { store.archive.personas.append(value) }
                        store.save(); onSave?(value); dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
        }
    }
}

struct SceneEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: SceneTemplate
    var onSave: ((SceneTemplate) -> Void)?
    @State private var name = ""
    @State private var details = ""
    @State private var greeting = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Szenario") { TextField("Name des Szenarios", text: $name) }
                Section("Ort, Ausgangslage und Atmosphäre") { TextEditor(text: $details).frame(minHeight: 160).accessibilityLabel("Szenario-Beschreibung") }
                Section("Gesprächseinstieg") { TextEditor(text: $greeting).frame(minHeight: 120).accessibilityLabel("Szenario-Einstieg") }
            }.navigationTitle("Eigenes Szenario").navigationBarTitleDisplayMode(.inline)
                .onAppear { name = original.name; details = original.description; greeting = original.greeting }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Speichern") {
                        var value = original; value.name = name; value.description = details; value.greeting = greeting
                        if let i = store.archive.scenes.firstIndex(where: { $0.id == value.id }) { store.archive.scenes[i] = value }
                        else { store.archive.scenes.append(value) }
                        store.save(); onSave?(value); dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || details.isEmpty) }
                }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
