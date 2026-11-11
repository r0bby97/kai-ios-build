import SwiftUI
import FadenCore

struct CardReadableText: View {
    let text: String
    private let rows: [CardPropertyRow]?
    init(_ text: String) { let clean = CardMarkup.clean(text); self.text = clean; rows = CardStructuredText.parse(clean)?.rows }
    var body: some View {
        if let rows {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 5) {
                        if let title = row.title {
                            Text(title).font(row.isHeading ? .headline : .subheadline.weight(.semibold))
                                .foregroundStyle(row.isHeading ? Color.primary : Color.secondary)
                        }
                        if !row.text.isEmpty { Text(row.text).font(.body).textSelection(.enabled) }
                    }.padding(.leading, CGFloat(row.depth) * 12).frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                }
            }.accessibilityElement(children: .contain).accessibilityIdentifier("readable-card-properties")
        } else { Text(text).font(.body).textSelection(.enabled) }
    }
}
