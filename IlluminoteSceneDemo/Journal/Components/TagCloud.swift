import SwiftUI

// Grid-based tag cloud (iOS 16+ friendly)
struct TagCloud: View {
    let tags: [String]
    let onRemove: (String) -> Void
    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                TagChip(text: tag) { onRemove(tag) }
            }
        }
    }
}


struct TagChip: View {
    let text: String
    let onRemove: () -> Void
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textPrimary)
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "xmark.circle.fill").imageScale(.small)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DSColor.textTertiary)
            .accessibilityLabel("Remove tag \(text)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(DSColor.divider, lineWidth: 1))
    }
}
