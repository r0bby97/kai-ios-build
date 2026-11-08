import SwiftUI

enum KaiMotion {
    static func selection(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .snappy(duration: 0.34, extraBounce: 0.06)
    }
}

struct KaiGlassGroup<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        if #available(iOS 26.0, *) { GlassEffectContainer(spacing: 8) { content } }
        else { content }
    }
}

/// One shared selection surface moves and changes width with the selected genre.
struct KaiGenreSelection: View {
    let namespace: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Group {
            if reduceMotion { Capsule().fill(Color.primary) }
            else { Capsule().fill(Color.primary).matchedGeometryEffect(id: "genre-selection", in: namespace) }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct KaiTabEntrance: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entered = false
    func body(content: Content) -> some View {
        content.opacity(reduceMotion || entered ? 1 : 0.78)
            .offset(y: reduceMotion || entered ? 0 : 5)
            .onAppear {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { entered = true }
            }
            .onDisappear { entered = false }
    }
}

/// Glass belongs to controls. Reading surfaces keep a stable contrast over artwork.
private struct KaiGlassSurface: ViewModifier {
    let radius: CGFloat
    let interactive: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Palette.surface, in: RoundedRectangle(cornerRadius: radius))
                .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(Palette.hairline) }
        } else if #available(iOS 26.0, *) {
            content.glassEffect(interactive ? .regular.interactive() : .regular,
                                in: RoundedRectangle(cornerRadius: radius))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
                .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(0.16)) }
        }
    }
}

extension View {
    func kaiTabEntrance() -> some View { modifier(KaiTabEntrance()) }
    func kaiGlass(radius: CGFloat = 22, interactive: Bool = false) -> some View {
        modifier(KaiGlassSurface(radius: radius, interactive: interactive))
    }
}

struct KaiBrand: View {
    var body: some View {
        HStack(spacing: 7) {
            Image("KaiMark").resizable().scaledToFit().frame(width: 29, height: 29)
                .clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityHidden(true)
            Text("Kai").font(.system(.headline, design: .rounded))
        }.accessibilityElement(children: .ignore).accessibilityLabel("Kai")
    }
}
