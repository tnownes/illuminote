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
    
    // Existing drafts for "Add to Existing"
    @Query(sort: \StatementDraft.dateModified, order: .reverse)
    private var drafts: [StatementDraft]
    
    @State private var selectedIDs = Set<UUID>()
    @State private var searchText = ""
    @State private var showDraftPicker = false
    
    var targetDraft: StatementDraft? = nil // If set, we are adding to this draft specifically
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
                List(selection: $selectedIDs) {
                    ForEach(filteredEntries) { entry in
                        VStack(alignment: .leading) {
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                .font(DSFont.heading2)
                                .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                            
                            let excerpt = entry.responses.sorted(by: { $0.stepIndex < $1.stepIndex }).first?.answerText ?? "No content"
                            Text(excerpt)
                                .lineLimit(2)
                                .font(DSFont.subtext)
                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                        }
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.vertical, DSSpacing.sm)
                        .background {
                            if useImmersive {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                            }
                        }
                        .overlay {
                            if useImmersive {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedIDs.contains(entry.id) ? DSColor.goldLight : Color.white.opacity(0.12), lineWidth: selectedIDs.contains(entry.id) ? 2 : 1)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: useImmersive && selectedIDs.contains(entry.id) ? DSColor.goldLight.opacity(0.25) : .clear, radius: 10, x: 0, y: 3)
                        .tag(entry.id)
                        .listRowBackground(useImmersive ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                    }
                }
                .listRowSeparatorTint(useImmersive ? .clear : Color(uiColor: .separator))
                .darkListStyle(enabled: useImmersive, baseBackground: nil)
                .background(Color.clear)
                .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
                .navigationTitle("Select Entries")
                .searchable(text: $searchText, prompt: "Search journal...")
                .environment(\.editMode, .constant(.active))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        if let target = targetDraft {
                            Button("Add") {
                                addToDraft(target)
                                onRefreshed?()
                                dismiss()
                            }
                            .disabled(selectedIDs.isEmpty)
                        } else {
                            Menu("Add") {
                                Menu("Create New Draft") {
                                    ForEach(StatementDraftScope.allCases) { scope in
                                        Button(scope.displayName) {
                                            createNewDraft(scope: scope)
                                        }
                                    }
                                }
                                
                                Button("Add to Existing Draft") {
                                    showDraftPicker = true
                                }
                                .disabled(drafts.isEmpty)
                            }
                            .disabled(selectedIDs.isEmpty)
                        }
                    }
                }
                .sheet(isPresented: $showDraftPicker) {
                    NavigationStack {
                        List(drafts) { draft in
                            Button {
                                addToDraft(draft)
                                showDraftPicker = false
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(draft.title)
                                            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                                        Text("v\(draft.version) • \(draft.dateModified.formatted())")
                                            .font(DSFont.caption)
                                            .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                    }
                                    Spacer()
                                    if draft.isFinal {
                                        Image(systemName: "lock.fill")
                                            .font(DSFont.caption)
                                            .foregroundStyle(useImmersive ? DSColor.textTertiary : .secondary)
                                    }
                                }
                            }
                            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                            .listRowBackground(useImmersive ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                        }
                        .listRowSeparatorTint(useImmersive ? .clear : Color(uiColor: .separator))
                        .darkListStyle(enabled: useImmersive, baseBackground: nil)
                        .navigationTitle("Choose Draft")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showDraftPicker = false }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                    .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
                }
            }
        }
    }
    
    private var filteredEntries: [ExamenSession] {
        if searchText.isEmpty {
            return journalEntries
        } else {
            return journalEntries.filter { session in
                let text = session.responses.map(\.answerText).joined(separator: " ")
                return text.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func createNewDraft(scope: StatementDraftScope = .full) {
        let title = "Draft \(Date.now.formatted(date: .numeric, time: .omitted))"
        let newDraft = StatementDraft(title: title, draftScope: scope)
        
        let sortedSelection = journalEntries.filter { selectedIDs.contains($0.id) }
            .sorted(by: { $0.date < $1.date })
        
        for (index, session) in sortedSelection.enumerated() {
            let content = session.mergedDraftContent()
            
            let section = StatementSection(
                source: .journalEntry,
                content: content,
                order: index,
                sourceID: session.id
            )
            newDraft.sections.append(section)
        }
        
        modelContext.insert(newDraft)
        
        // 🛠 Persist immediately
        do {
            try modelContext.save()
        } catch {
            print("Failed to save new draft from journal selection: \(error)")
        }
        
        onDraftCreated?(newDraft)
        dismiss()
    }
    
    private func addToDraft(_ draft: StatementDraft) {
        let selectedSessions = journalEntries.filter { selectedIDs.contains($0.id) }
        let startOrder = (draft.sections.map { $0.order }.max() ?? -1) + 1
        
        for (index, session) in selectedSessions.sorted(by: { $0.date < $1.date }).enumerated() {
            let content = session.mergedDraftContent()
            
            let section = StatementSection(
                source: .journalEntry,
                content: content,
                order: startOrder + index,
                sourceID: session.id
            )
            draft.sections.append(section)
        }
        
        draft.dateModified = Date()
        
        // 🛠 Persist the update
        do {
            try modelContext.save()
        } catch {
            print("Failed to save draft after adding journal entries: \(error)")
        }
    }
}
