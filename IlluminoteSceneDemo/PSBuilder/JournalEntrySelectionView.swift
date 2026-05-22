import SwiftUI
import SwiftData

struct JournalEntrySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    // Fetch journal entries (ExamenSession where sessionType != .statementDraft)
    // Note: sessionType check usually needs a predicate, or filtering in memory if type is complex.
    // ExamenType is string, so predicate works.
    @Query(sort: \ExamenSession.date, order: .reverse)
    private var allSessions: [ExamenSession]
    
    private var journalEntries: [ExamenSession] {
        allSessions.filter { $0.sessionType != .statementDraft }
    }
    
    @State private var selectedIDs = Set<UUID>()
    @State private var searchText = ""
    @State private var showDestinationChooser = false
    @State private var persistenceAlert: PersistenceAlertContext?
    
    var targetDraft: StatementDraft? = nil // If set, we are adding to this draft specifically
    var initialWritingTargetID: String? = nil
    var onDraftCreated: ((StatementDraft) -> Void)?
    var onRefreshed: (() -> Void)? // Callback when changes made so caller can update if needed

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if useImmersive {
                    SacredScreenBackground(settings: settings)
                }
                if showDestinationChooser {
                    AddToDraftDestinationView(
                        selectedEntries: selectedEntries,
                        selectedWorkspaceEntries: [],
                        preselectedTargetID: initialWritingTargetID,
                        onDraftCreated: onDraftCreated,
                        onCancel: { showDestinationChooser = false },
                        onComplete: {
                            onRefreshed?()
                            dismiss()
                        }
                    )
                } else {
                    List(selection: $selectedIDs) {
                        ForEach(filteredEntries) { entry in
                            DraftSelectionEntryRow(
                                entry: entry,
                                isSelected: selectedIDs.contains(entry.id)
                            )
                            .tag(entry.id)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listRowSeparatorTint(useImmersive ? .clear : Color(uiColor: .separator))
                    .darkListStyle(enabled: useImmersive, baseBackground: nil)
                    .background(Color.clear)
                    .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
                    .navigationTitle("Choose Reflections")
                    .searchable(text: $searchText, prompt: "Search reflections")
                    .environment(\.editMode, .constant(.active))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            if let target = targetDraft {
                                Button("Add to Draft") {
                                    if addToDraft(target) {
                                        onRefreshed?()
                                        dismiss()
                                    }
                                }
                                .disabled(selectedIDs.isEmpty)
                            } else {
                                Button("Use in Draft") {
                                    showDestinationChooser = true
                                }
                                .disabled(selectedIDs.isEmpty)
                            }
                        }
                    }
                }
            }
            .persistenceFailureAlert($persistenceAlert)
        }
    }
    
    private var filteredEntries: [ExamenSession] {
        if searchText.isEmpty {
            return journalEntries
        } else {
            return journalEntries.filter { session in
                searchHaystack(for: session).localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var selectedEntries: [ExamenSession] {
        journalEntries
            .filter { selectedIDs.contains($0.id) }
            .sorted(by: { $0.date < $1.date })
    }

    private func searchHaystack(for session: ExamenSession) -> String {
        let metadataFields: [String] = [
            session.resolvedPrimaryDetail,
            session.resolvedSecondaryDetail,
            session.resolvedFocusDetail,
            session.location,
            session.notes
        ].compactMap { $0 }

        return """
        \(session.normalizedResponseTexts().joined(separator: "\n\n"))
        \(session.personalStatement)
        \(metadataFields.joined(separator: " "))
        \(session.date.formatted(date: .abbreviated, time: .shortened))
        """
    }
    
    @discardableResult
    private func addToDraft(_ draft: StatementDraft) -> Bool {
        let selectedSessions = journalEntries.filter { selectedIDs.contains($0.id) }
        let startOrder = (draft.sections.map { $0.order }.max() ?? -1) + 1
        let originalModifiedDate = draft.dateModified
        var appendedSections: [StatementSection] = []
        
        for (index, session) in selectedSessions.sorted(by: { $0.date < $1.date }).enumerated() {
            let content = session.mergedDraftContent()
            
            let section = StatementSection(
                source: .journalEntry,
                content: content,
                order: startOrder + index,
                sourceID: session.id
            )
            draft.sections.append(section)
            appendedSections.append(section)
        }
        
        draft.dateModified = Date()

        do {
            try modelContext.persistIfNeeded(for: "add those reflections to the draft")
            return true
        } catch let error as PersistenceOperationError {
            persistenceAlert = error.alertContext
        } catch {
            persistenceAlert = PersistenceAlertContext.saveFailure(
                for: "add those reflections to the draft",
                details: error.localizedDescription
            )
        }

        draft.sections.removeAll { section in
            appendedSections.contains(where: { $0.id == section.id })
        }
        draft.dateModified = originalModifiedDate
        return false
    }
}

private struct DraftSelectionEntryRow: View {
    let entry: ExamenSession
    let isSelected: Bool

    private let journalDateStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)

    private var previewSourceText: String? {
        [
            entry.personalStatement,
            entry.notes ?? "",
            entry.normalizedResponseTexts().first ?? ""
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
    }

    private var headlineText: String {
        if let primary = entry.resolvedPrimaryDetail {
            return primary
        }
        if let secondary = entry.resolvedSecondaryDetail {
            return secondary
        }
        if let previewSourceText {
            return previewSourceText
        }
        return "Reflection"
    }

    private var previewText: String? {
        guard let previewSourceText else { return nil }
        guard previewSourceText != headlineText else { return nil }
        return previewSourceText
    }

    private var metadataLine: String {
        var items: [String] = [entry.date.formatted(journalDateStyle)]

        if let type = entry.experienceType?.canonical, type != .other {
            items.insert(type.displayName, at: 0)
        } else {
            items.insert("Reflection", at: 0)
        }

        if let secondary = entry.resolvedSecondaryDetail, secondary != headlineText {
            items.append(secondary)
        }

        if let focus = entry.resolvedFocusDetail {
            items.append(focus)
        }

        return items.joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(metadataLine)
                .font(DSFont.eyebrow)
                .foregroundStyle(DSColor.quietTextMuted)
                .textCase(.uppercase)
                .fixedSize(horizontal: false, vertical: true)

            Text(headlineText)
                .font(DSFont.heading2)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let previewText {
                Text(previewText)
                    .font(DSFont.supporting)
                    .foregroundStyle(DSColor.quietText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.md)
        .appSurfaceStyle(role: isSelected ? .reading : .interactive, highlighted: isSelected)
    }
}
