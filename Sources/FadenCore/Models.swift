import Foundation

public struct LoreEntry: Codable, Identifiable, Hashable, Sendable {
    public var id = UUID()
    public var keys: [String]
    public var content: String
    public var alwaysOn: Bool
    public init(keys: [String], content: String, alwaysOn: Bool = false) {
        self.keys = keys; self.content = content; self.alwaysOn = alwaysOn
    }
}

public struct CharacterCard: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var tagline: String
    public var description: String
    public var personality: String
    public var scenario: String
    public var firstMessage: String
    public var exampleDialogue: String
    public var systemPrompt: String
    public var creatorNotes: String
    public var tags: [String]
    public var alternateGreetings: [String]
    public var lore: [LoreEntry]
    public var avatarURL: String?
    public var cachedAvatarURL: String?
    public var sourceURL: String?
    public var artwork: String?
    public var creator: String
    public var isAdult: Bool
    public var languageCode: String?
    public var popularityScore: Int?
    public var castOverride: CardCast?
    public var sourceCast: CardCast?
    public var cast: CardCast { castOverride ?? sourceCast ?? CardCastDetector.detect(self) }
    public var displayTagline: String { CardMarkup.plain(tagline) }
    public var isBundledExample: Bool { id.hasPrefix("faden.original.") }
    public var hasDefinition: Bool { !description.isEmpty || !personality.isEmpty }
    public init(id: String = UUID().uuidString, name: String, tagline: String = "",
                description: String = "", personality: String = "", scenario: String = "",
                firstMessage: String = "", exampleDialogue: String = "", systemPrompt: String = "",
                creatorNotes: String = "", tags: [String] = [], alternateGreetings: [String] = [],
                lore: [LoreEntry] = [], avatarURL: String? = nil, sourceURL: String? = nil,
                artwork: String? = nil, creator: String = "Du", isAdult: Bool = false) {
        self.id = id; self.name = name; self.tagline = tagline; self.description = description
        self.personality = personality; self.scenario = scenario; self.firstMessage = firstMessage
        self.exampleDialogue = exampleDialogue; self.systemPrompt = systemPrompt; self.creatorNotes = creatorNotes
        self.tags = tags; self.alternateGreetings = alternateGreetings; self.lore = lore
        self.avatarURL = avatarURL; self.sourceURL = sourceURL; self.artwork = artwork
        self.creator = creator; self.isAdult = isAdult
    }
    public static func starters() throws -> [CharacterCard] {
        guard let url = Bundle.module.url(forResource: "Characters", withExtension: "json") else {
            throw FadenError.invalidData("Die mitgelieferten Charaktere fehlen.")
        }
        return try JSONDecoder().decode([CharacterCard].self, from: Data(contentsOf: url))
    }
}

public enum MessageRole: String, Codable, Sendable { case user, assistant, system }

public struct Message: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var parentID: UUID?
    public var role: MessageRole
    public var content: String
    public var createdAt: Date
    public var model: String?
    public var interrupted: Bool
    public var speakerID: String?
    public init(id: UUID = UUID(), parentID: UUID? = nil, role: MessageRole, content: String,
                model: String? = nil, interrupted: Bool = false, speakerID: String? = nil) {
        self.id = id; self.parentID = parentID; self.role = role; self.content = content
        self.createdAt = Date(); self.model = model; self.interrupted = interrupted
        self.speakerID = speakerID
    }
}

public struct StoryBranch: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var title: String
    public var headID: UUID?
    public var createdAt = Date()
    public init(title: String, headID: UUID?) { self.title = title; self.headID = headID }
}

public struct MemoryNote: Codable, Identifiable, Hashable, Sendable {
    public var id = UUID()
    public var text: String
    public var sourceMessageID: UUID?
    public init(text: String, sourceMessageID: UUID?) {
        self.text = text; self.sourceMessageID = sourceMessageID
    }
}

public struct Story: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var characterID: String
    public var title: String
    public var messages: [Message] = []
    public var headID: UUID?
    public var branches: [StoryBranch] = []
    public var memories: [MemoryNote] = []
    public var createdAt = Date()
    public var updatedAt = Date()
    public var additionalCharacterIDs: [String]?
    public var persona: UserPersona?
    public var sceneOverride: String?
    public var initialMessageID: UUID?
    public var draftText: String?
    public var cardCasts: [String: CardCast]?
    public var insights: [CharacterInsight]?
    public var insightAttemptIDs: [UUID]?
    public var participantIDs: [String] { [characterID] + (additionalCharacterIDs ?? []).filter { $0 != characterID } }
    public var isMultiCard: Bool { participantIDs.count > 1 }
    public var isGroup: Bool { isMultiCard || cardCasts?.values.contains(where: \.isEnsemble) == true }
    public var greetingID: UUID? { initialMessageID ?? messages.first(where: { $0.parentID == nil && $0.role == .assistant })?.id }
    public var nextSpeakerID: String {
        let ids = participantIDs
        let last = activeMessages.last(where: { $0.role == .assistant })?.speakerID ?? characterID
        return ids[((ids.firstIndex(of: last) ?? (ids.count - 1)) + 1) % ids.count]
    }
    public func responseOrder(replyingAs: String? = nil, allParticipants: Bool = false) -> [String] {
        if allParticipants { return participantIDs }
        return [replyingAs.flatMap { participantIDs.contains($0) ? $0 : nil } ?? nextSpeakerID]
    }
    public init(character: CharacterCard, userName: String = "Du") {
        self.characterID = character.id; self.title = character.name
        self.cardCasts = [character.id: character.cast]
        if !character.firstMessage.isEmpty {
            let greeting = Message(role: .assistant,
                content: character.firstMessage.replacingOccurrences(of: "{{char}}", with: character.name)
                    .replacingOccurrences(of: "{{user}}", with: userName), speakerID: character.id)
            self.messages = [greeting]; self.headID = greeting.id
            self.initialMessageID = greeting.id
        }
    }
    public init(characters: [CharacterCard], persona: UserPersona?, scenario: String?, greeting: String?, userName: String = "Du") {
        let first = characters.first ?? CharacterCard(name: "Charakter")
        var opening = first
        if let greeting { opening.firstMessage = greeting }
        self.init(character: opening, userName: persona?.name ?? userName)
        self.additionalCharacterIDs = Array(characters.dropFirst().map(\.id))
        self.cardCasts = Dictionary(characters.map { ($0.id, $0.cast) }, uniquingKeysWith: { first, _ in first })
        self.persona = persona; self.sceneOverride = scenario
        self.title = characters.count > 1 ? characters.map(\.name).joined(separator: " & ") : first.name
    }
    public var activeMessages: [Message] {
        let lookup = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [Message] = []; var seen = Set<UUID>(); var cursor = headID
        while let id = cursor, let message = lookup[id], seen.insert(id).inserted {
            result.append(message); cursor = message.parentID
        }
        return result.reversed()
    }
    public var activeMemories: [MemoryNote] {
        let ids = Set(activeMessages.map(\.id))
        return memories.filter { $0.sourceMessageID == nil || ids.contains($0.sourceMessageID!) }
    }
    @discardableResult public mutating func append(role: MessageRole, content: String,
        model: String? = nil, interrupted: Bool = false, speakerID: String? = nil) -> UUID {
        let message = Message(parentID: headID, role: role, content: content, model: model, interrupted: interrupted, speakerID: speakerID)
        messages.append(message); headID = message.id; updatedAt = Date(); return message.id
    }
    public mutating func rewind(to id: UUID?, title: String = "Vor dem Zurückspulen") throws {
        if let id, !messages.contains(where: { $0.id == id }) { throw FadenError.invalidData("Nachricht nicht gefunden.") }
        if headID == id { return }
        branches.append(StoryBranch(title: title, headID: headID)); headID = id; updatedAt = Date()
    }
    public mutating func edit(_ id: UUID, text: String) throws {
        guard let original = messages.first(where: { $0.id == id }) else {
            throw FadenError.invalidData("Nachricht nicht gefunden.")
        }
        try rewind(to: original.parentID, title: "Vor der Bearbeitung")
        append(role: original.role, content: text, speakerID: original.speakerID)
    }
}

public struct UserPersona: Codable, Identifiable, Hashable, Sendable {
    public var id = UUID()
    public var name: String
    public var description: String
    public init(name: String, description: String = "") { self.name = name; self.description = description }
}
public struct SceneTemplate: Codable, Identifiable, Hashable, Sendable {
    public var id = UUID()
    public var name: String
    public var description: String
    public var greeting: String
    public init(name: String, description: String, greeting: String = "") { self.name = name; self.description = description; self.greeting = greeting }
    public static var initial: [SceneTemplate] { [
        .init(name: "Im Nachtzug", description: "Die erwachsenen Figuren begegnen sich im Speisewagen eines fast leeren Nachtzugs. Draußen zieht die Landschaft vorbei. Ein unvorhergesehener Halt gibt ihnen Zeit für ein Gespräch.", greeting: "Der Zug wird langsamer. Zwischen dem Klirren der Tassen und dem Regen am Fenster entsteht eine kleine Pause, in der ein Gespräch beginnen kann."),
        .init(name: "Ein unerwartetes Wiedersehen", description: "Nach langer Zeit begegnen sich die erwachsenen Figuren an einem unerwarteten Ort. Welche Vorgeschichte sie verbindet, entsteht erst aus dem Gespräch.", greeting: "Für einen Moment bleibt die Zeit stehen. Ein vertrautes Gesicht, ein unerwarteter Ort – und eine Frage, die bisher unbeantwortet blieb."),
        .init(name: "Die letzte offene Tür", description: "Ein Unwetter zwingt die erwachsenen Figuren in denselben Zufluchtsort. Sie kennen einander noch nicht. Draußen ist kein Weiterkommen möglich.", greeting: "Die Tür fällt hinter euch zu. Das Unwetter bleibt draußen, aber mit der plötzlichen Stille beginnt etwas Neues.")
    ] }
}

public struct WritingPreferences: Codable, Sendable {
    public var userName = "Du"
    public var instructions = ""
    public var learnStyle = true
    public var responseLength = 400
    public var responseWords: Int? = 400
    public var insightFrequency: InsightFrequency? = .every20
    public var effectiveInsightFrequency: InsightFrequency { insightFrequency ?? .every20 }
    public var maximumResponseWords: Int { min(2000, max(25, responseWords ?? (min(6000, max(0, responseLength)) * 2 / 3))) }
    public var requestedOutputTokens: Int { maximumResponseWords * 3 }
    public var language = "Deutsch"
    public init() {}
}

public struct StyleProfile: Sendable {
    public var sampleCount: Int
    public var averageWords: Int
    public var usesActions: Bool
    public var usesDialogue: Bool
    public var examples: [String]
    public init(story: Story) {
        let own = Array(story.activeMessages.filter { $0.role == .user }.suffix(30))
        sampleCount = own.count
        averageWords = own.isEmpty ? 0 : own.reduce(0) { $0 + $1.content.split(whereSeparator: \.isWhitespace).count } / own.count
        usesActions = own.filter { $0.content.contains("*") }.count > own.count / 3
        usesDialogue = own.filter { $0.content.contains("\"") || $0.content.contains("„") }.count > own.count / 3
        examples = own.suffix(3).map { String(RoleplayText.visibleText($0.content).prefix(500)) }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    public var summary: String {
        guard sampleCount > 0 else { return "Dein Stil entsteht mit deinen ersten Nachrichten." }
        var parts = ["\(sampleCount) Nachrichten", "etwa \(averageWords) Wörter pro Nachricht"]
        if usesActions { parts.append("private Gedanken in Sternchen") }
        if usesDialogue { parts.append("wörtliche Rede") }
        return parts.joined(separator: " · ")
    }
}

public enum ProviderKind: String, Codable, CaseIterable, Sendable {
    case openRouter, compatible, chatGPT, local, openAI, anthropic, aiHorde
    public var title: String {
        switch self {
        case .openRouter: "OpenRouter"
        case .compatible: "Eigener Anbieter"
        case .chatGPT: "ChatGPT-Konto"
        case .local: "Auf dem iPhone"
        case .openAI: "OpenAI API"
        case .anthropic: "Claude API"
        case .aiHorde: "AI Horde"
        }
    }
}
public struct Connection: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: ProviderKind
    public var baseURL: String
    public var models: [String]
    public var enabled: Bool
    public var allowsCosts: Bool
    public var contextTokens: Int
    public var apiPreset: APIProviderPreset?
    public var workspaceID: String?
    public var freeTierConfirmed: Bool?
    public var hordeWaitSeconds: Int?
    public var requiresAPIKey: Bool { apiPreset != nil || [.openRouter, .openAI, .anthropic].contains(kind) }
    public init(id: UUID = UUID(), name: String, kind: ProviderKind, baseURL: String = "",
                models: [String] = [], enabled: Bool = true, allowsCosts: Bool = false, contextTokens: Int = 8192) {
        self.id = id; self.name = name; self.kind = kind; self.baseURL = baseURL
        self.models = models; self.enabled = enabled; self.allowsCosts = allowsCosts; self.contextTokens = contextTokens
    }
    public static var horde: Connection { .init(name: "AI Horde · Rollenspiel", kind: .aiHorde, baseURL: AIHordeClient.baseURL, models: [HordeCodec.automaticModel], contextTokens: 8192) }
    public static let initial: [Connection] = [
        .init(name: "Kostenlose Cloud", kind: .openRouter, baseURL: "https://openrouter.ai/api/v1", models: ["openrouter/free"]),
        .horde,
        .init(name: "Lokal · Qwen 3", kind: .local, models: ["mlx-community/Qwen3-1.7B-4bit"], contextTokens: 4096),
        .init(name: "ChatGPT Plus", kind: .chatGPT, baseURL: "https://api.openai.com/v1", models: [], enabled: false)
    ]
    public func permittedModels(freeOnly: Bool) -> [String] {
        guard enabled, !(freeOnly && allowsCosts) else { return [] }
        if kind == .openRouter && freeOnly {
            return models.filter { $0 == "openrouter/free" || $0.hasSuffix(":free") }
        }
        // An unpriced third-party endpoint must be explicitly authorized, not assumed free.
        if [.compatible, .openAI, .anthropic].contains(kind) && freeOnly {
            guard apiPreset == .arli, apiPreset?.matches(self) == true, freeTierConfirmed == true else { return [] }
        }
        return models.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    public func permitsReuse(of model: String, freeOnly: Bool) -> Bool {
        let permitted = permittedModels(freeOnly: freeOnly)
        return permitted.contains(model) || (kind == .aiHorde && permitted.contains(HordeCodec.automaticModel) && HordeCodec.isRoleplayModel(model))
    }
}

public struct Archive: Codable, Sendable {
    public var schemaVersion = 1
    public var characters: [CharacterCard]
    public var stories: [Story]
    public var preferences: WritingPreferences
    public var connections: [Connection]
    public var freeOnly: Bool
    public var favoriteIDs: Set<String>
    public var personas: [UserPersona]
    public var scenes: [SceneTemplate]
    public var menuTheme: MenuTheme
    public var providerSetupVersion: Int?
    public var libraryCharacters: [CharacterCard] { characters.filter { !$0.isBundledExample } }
    public init(characters: [CharacterCard] = [], stories: [Story] = [], preferences: WritingPreferences = .init(),
                connections: [Connection] = Connection.initial, freeOnly: Bool = true) {
        self.characters = characters; self.stories = stories; self.preferences = preferences
        self.connections = connections; self.freeOnly = freeOnly
        self.favoriteIDs = []; self.personas = []; self.scenes = SceneTemplate.initial
        self.menuTheme = .dark
        self.providerSetupVersion = 1
    }
    enum CodingKeys: String, CodingKey { case schemaVersion, characters, stories, preferences, connections, freeOnly, favoriteIDs, personas, scenes, menuTheme, providerSetupVersion }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        characters = try values.decode([CharacterCard].self, forKey: .characters)
        stories = try values.decode([Story].self, forKey: .stories)
        preferences = try values.decodeIfPresent(WritingPreferences.self, forKey: .preferences) ?? .init()
        connections = try values.decodeIfPresent([Connection].self, forKey: .connections) ?? Connection.initial
        freeOnly = try values.decodeIfPresent(Bool.self, forKey: .freeOnly) ?? true
        favoriteIDs = try values.decodeIfPresent(Set<String>.self, forKey: .favoriteIDs) ?? []
        personas = try values.decodeIfPresent([UserPersona].self, forKey: .personas) ?? []
        scenes = try values.decodeIfPresent([SceneTemplate].self, forKey: .scenes) ?? SceneTemplate.initial
        menuTheme = try values.decodeIfPresent(MenuTheme.self, forKey: .menuTheme) ?? .dark
        providerSetupVersion = try values.decodeIfPresent(Int.self, forKey: .providerSetupVersion)
    }
    public mutating func introduceRoleplayProviders() {
        guard (providerSetupVersion ?? 0) < 1 else { return }
        if !connections.contains(where: { $0.kind == .aiHorde }) { connections.append(.horde) }
        providerSetupVersion = 1
    }
    public func validate() throws {
        guard schemaVersion == 1 else { throw FadenError.invalidData("Dieses Backup benötigt eine neuere App-Version.") }
        guard Set(characters.map(\.id)).count == characters.count,
              Set(stories.map(\.id)).count == stories.count,
              Set(connections.map(\.id)).count == connections.count,
              Set(personas.map(\.id)).count == personas.count,
              Set(scenes.map(\.id)).count == scenes.count else {
            throw FadenError.invalidData("Das Backup enthält doppelte Kennungen.")
        }
        let cardIDs = Set(characters.map(\.id))
        for story in stories {
            guard story.participantIDs.allSatisfy({ cardIDs.contains($0) }) else { throw FadenError.invalidData("Ein Chat hat einen fehlenden Charakter.") }
            let ids = Set(story.messages.map(\.id))
            guard ids.count == story.messages.count,
                  story.headID == nil || ids.contains(story.headID!),
                  story.messages.allSatisfy({ $0.parentID == nil || ids.contains($0.parentID!) }),
                  story.branches.allSatisfy({ $0.headID == nil || ids.contains($0.headID!) }) else {
                throw FadenError.invalidData("Ein Chat enthält ungültige Verknüpfungen.")
            }
            let insights = story.insights ?? []
            let attempts = story.insightAttemptIDs ?? []
            let replies = Set(story.messages.filter { $0.role == .assistant && !$0.interrupted }.map(\.id))
            guard Set(insights.map(\.id)).count == insights.count,
                  Set(insights.map(\.sourceMessageID)).count == insights.count,
                  Set(attempts).count == attempts.count,
                  attempts.allSatisfy({ replies.contains($0) }),
                  insights.allSatisfy({ replies.contains($0.sourceMessageID) && story.participantIDs.contains($0.characterID) && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw FadenError.invalidData("Ein Chat enthält ungültige Figuren-Einblicke.")
            }
            let lookup = Dictionary(uniqueKeysWithValues: story.messages.map { ($0.id, $0.parentID) })
            var checked = Set<UUID>()
            for message in story.messages where !checked.contains(message.id) {
                var seen = Set<UUID>(); var cursor: UUID? = message.id
                while let id = cursor {
                    if checked.contains(id) { break }
                    guard seen.insert(id).inserted else { throw FadenError.invalidData("Der Chat enthält einen Kreis.") }
                    cursor = lookup[id] ?? nil
                }
                checked.formUnion(seen)
            }
        }
    }
}

public enum FadenError: LocalizedError, Equatable {
    case invalidData(String), network(String), notConfigured, cancelled
    public var errorDescription: String? {
        switch self {
        case .invalidData(let text), .network(let text): text
        case .notConfigured: "Verbinde in den Einstellungen einen KI-Anbieter oder lade das lokale Modell herunter."
        case .cancelled: "Abgebrochen."
        }
    }
}
