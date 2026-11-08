import SwiftUI
import FadenCore

@main struct FadenApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environment(store)
                .tint(Palette.accent)
                .preferredColorScheme(store.archive.menuTheme.colorScheme)
                .onChange(of: scenePhase) { _, phase in if phase != .active { store.save() } }
                .onOpenURL { store.importFile($0) }
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        @Bindable var store = store
        TabView {
            LibraryView().kaiTabEntrance().tabItem { Label("Entdecken", systemImage: "books.vertical") }
            StoryListView().kaiTabEntrance().tabItem { Label("Gespräche", systemImage: "text.bubble") }
            SettingsView().kaiTabEntrance().tabItem { Label("Einstellungen", systemImage: "slider.horizontal.3") }
        }
        .overlay {
            if store.startingConversation {
                ProgressView("Deutsches Gespräch vorbereiten …").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
        }
        .task { await store.preloadCatalogue() }
        .background { TranslationHost(translator: store.translator, scope: "main") }
        .fullScreenCover(item: $store.presentedStory) { route in
            NavigationStack { ChatView(storyID: route.id) }.environment(store).preferredColorScheme(.dark)
        }
        .alert("Hinweis", isPresented: Binding(get: { store.error != nil && store.presentedStory == nil }, set: { if !$0 { store.error = nil } })) {
            Button("Verstanden", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}

enum Palette {
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 1, green: 0.56, blue: 0.45, alpha: 1) : UIColor(red: 0.72, green: 0.24, blue: 0.18, alpha: 1)
    })
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.065, green: 0.075, blue: 0.085, alpha: 1) : UIColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.115, green: 0.13, blue: 0.145, alpha: 1) : UIColor(red: 1, green: 0.99, blue: 0.97, alpha: 1)
    })
    static let hairline = Color.primary.opacity(0.09)
}

extension MenuTheme {
    var colorScheme: ColorScheme { self == .dark ? .dark : .light }
}

/// The same artwork as the card fills the chat, independently of menu appearance.
struct CharacterChatBackground: View {
    let card: CharacterCard
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.09, green: 0.10, blue: 0.11)
                CharacterImage(card: card)
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.26), .black.opacity(0.66)], startPoint: .top, endPoint: .bottom)
            }
        }.ignoresSafeArea().accessibilityIdentifier("character-chat-background")
    }
}

struct CharacterImage: View {
    let card: CharacterCard
    var body: some View {
        Group {
            if let text = card.cachedAvatarURL, let url = URL(string: text), url.isFileURL,
               let image = CharacterArtworkCache.image(at: url) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let artwork = card.artwork {
                Image(artwork).resizable().scaledToFill()
            } else if let text = card.avatarURL, let url = URL(string: text), url.isFileURL,
                      let image = CharacterArtworkCache.image(at: url) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let text = card.avatarURL, let url = URL(string: text), url.scheme == "https" {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { placeholder }
                }
            } else { placeholder }
        }.clipped().contentShape(Rectangle()).allowsHitTesting(false).accessibilityHidden(true)
    }
    private var placeholder: some View {
        ZStack {
            Color(uiColor: .tertiarySystemFill)
            Image(systemName: "photo").font(.system(size: 28, weight: .light)).foregroundStyle(.secondary)
        }
    }
}

struct GenreLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8).padding(.vertical, 5)
            .background(Palette.background, in: RoundedRectangle(cornerRadius: 5))
    }
}
