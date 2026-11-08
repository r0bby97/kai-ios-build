import SwiftUI
import FadenCore

struct CharacterInsightView: View {
    let insight: CharacterInsight
    let characterName: String
    let remove: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("\(insight.kind.title) · \(characterName)", systemImage: insight.kind.symbol)
                .font(.caption.weight(.semibold)).foregroundStyle(Color(red: 0.72, green: 0.83, blue: 0.84))
            Text(insight.text).font(.callout).italic().lineSpacing(5).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Text("Nur für dich · nicht ausgesprochen").font(.caption2).foregroundStyle(.white.opacity(0.65))
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.06, green: 0.13, blue: 0.15).opacity(0.91), in: RoundedRectangle(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.12)) }
            .padding(.horizontal, 10).accessibilityIdentifier("character-insight")
            .contextMenu {
                Button("Kopieren", systemImage: "doc.on.doc") { UIPasteboard.general.string = insight.text }
                Button("Einblick ausblenden", systemImage: "eye.slash", role: .destructive, action: remove)
            }
    }
}
