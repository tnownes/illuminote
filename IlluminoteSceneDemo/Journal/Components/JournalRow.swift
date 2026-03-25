import SwiftUI

// MARK: - Row View

struct JournalRow: View {
    let session: ExamenSession
    // Input: list of drafts that use this session
    let references: [(draft: StatementDraft, sectionDate: Date)]
    let onToggleFavorite: () -> Void
    let isHighlighted: Bool
    
    private let journalDateStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Examen Session")
                    .font(DSFont.heading2)
                    .foregroundStyle(DSColor.textPrimary)
                Text(session.date.formatted(journalDateStyle))
                    .font(DSFont.subtext)
                    .foregroundStyle(DSColor.textSecondary)

                // Reference Metadata
                if !references.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        if references.count == 1 {
                            let (draft, date) = references[0]
                            Text("Used in \(draft.title.isEmpty ? "Untitled Draft" : draft.title) · \(date.formatted(.dateTime.month().day()))")
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textTertiary)
                        } else {
                            Text("Used in \(references.count) drafts")
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textTertiary)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer()
            Button(action: onToggleFavorite) {
                Image(systemName: session.isFavorite ? "star.fill" : "star")
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(session.isFavorite ? DSColor.goldLight : DSColor.textTertiary)
            .accessibilityLabel(session.isFavorite ? "Unfavorite" : "Favorite")
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.md)
        .sacredCardStyle(highlighted: isHighlighted)
    }
}
