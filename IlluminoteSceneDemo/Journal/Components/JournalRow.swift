import SwiftUI

// MARK: - Row View

struct JournalRow: View {
    let session: ExamenSession
    // Input: list of drafts that use this session
    let references: [(draft: StatementDraft, sectionDate: Date)]
    let onToggleFavorite: () -> Void
    let isHighlighted: Bool
    
    private let journalDateStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)

    private var experienceLabel: String {
        session.experienceType?.displayName ?? "Reflection"
    }

    private var previewSourceText: String? {
        [
            session.personalStatement,
            session.notes ?? "",
            session.responses
                .sorted { $0.stepIndex < $1.stepIndex }
                .map(\.answerText)
                .first ?? ""
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
    }

    private var headlineText: String {
        if let primary = session.resolvedPrimaryDetail {
            return primary
        }
        if let secondary = session.resolvedSecondaryDetail {
            return secondary
        }
        if let previewSourceText {
            return previewSourceText
        }
        return "Examen Reflection"
    }

    private var previewText: String? {
        guard let previewSourceText else { return nil }
        guard previewSourceText != headlineText else { return nil }
        return previewSourceText
    }

    private var metadataLine: String {
        var items: [String] = [session.date.formatted(journalDateStyle)]

        if let type = session.experienceType?.canonical, type != .other {
            items.insert(experienceLabel, at: 0)
        } else {
            items.insert("Reflection", at: 0)
        }

        if let secondary = session.resolvedSecondaryDetail, secondary != headlineText {
            items.append(secondary)
        }

        if let focus = session.resolvedFocusDetail {
            items.append(focus)
        }

        if session.hours > 0 {
            items.append("\(session.hours.journalFormattedOneDecimal) hours")
        }

        return items.joined(separator: " • ")
    }

    private var referencesText: String? {
        guard !references.isEmpty else { return nil }

        if references.count == 1 {
            let (draft, date) = references[0]
            return "Used in \(draft.title.isEmpty ? "Untitled Draft" : draft.title) on \(date.formatted(.dateTime.month().day()))"
        }

        return "Used in \(references.count) drafts"
    }

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text(metadataLine)
                    .font(DSFont.eyebrow)
                    .foregroundStyle(DSColor.quietTextMuted)
                    .textCase(.uppercase)
                    .fixedSize(horizontal: false, vertical: true)

                Text(headlineText)
                    .font(DSFont.body.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let previewText {
                    Text(previewText)
                        .font(DSFont.supporting)
                        .foregroundStyle(DSColor.quietText)
                        .lineLimit(2)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let referencesText {
                    Text(referencesText)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)

            Spacer(minLength: DSSpacing.xs)

            Button(action: onToggleFavorite) {
                Image(systemName: session.isFavorite ? "star.fill" : "star")
                    .imageScale(.medium)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(DSColor.quietSurface)
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(session.isFavorite ? DSColor.goldLight : DSColor.quietTextMuted)
            .accessibilityLabel(session.isFavorite ? "Unfavorite" : "Favorite")
            .accessibilityIdentifier("journal.favoriteButton")
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.md)
        .appSurfaceStyle(role: isHighlighted ? .reading : .interactive, highlighted: isHighlighted)
    }
}

private extension Double {
    var journalFormattedOneDecimal: String {
        String(format: "%.1f", self)
    }
}
