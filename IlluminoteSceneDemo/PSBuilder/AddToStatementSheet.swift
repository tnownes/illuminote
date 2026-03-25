import SwiftUI
import SwiftData

struct AddToStatementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    var selectedEntries: [ExamenSession]
    
    @Query(sort: \StatementDraft.dateModified, order: .reverse)
    private var drafts: [StatementDraft]

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if useImmersive {
                    SacredScreenBackground(settings: settings)
                }
                List {
                    Section {
                        Menu {
                            ForEach(StatementDraftScope.allCases) { scope in
                                Button(scope.displayName) {
                                    createNewDraft(scope: scope)
                                }
                            }
                        } label: {
                            Label("Create New Draft", systemImage: "plus.square")
                        }
                        .foregroundStyle(useImmersive ? DSColor.goldLight : .accentColor)
                        .padding(.vertical, DSSpacing.sm)
                        .if(useImmersive) { view in
                            view.sacredCardStyle(highlighted: true)
                        }
                    }
                    .listRowBackground(useImmersive ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                    
                    if !drafts.isEmpty {
                        Section(
                            header: Group {
                                if useImmersive {
                                    DarkSectionHeader(title: "Add to Existing Draft")
                                } else {
                                    Text("Add to Existing Draft")
                                }
                            }
                        ) {
                            ForEach(drafts) { draft in
                                Button {
                                    addToDraft(draft)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(draft.title)
                                                .font(DSFont.body)
                                                .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                                            Text("v\(draft.version)")
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
                                .disabled(draft.isFinal || draft.isLocked)
                                .padding(.horizontal, DSSpacing.md)
                                .padding(.vertical, DSSpacing.sm)
                                .if(useImmersive) { view in
                                    view.sacredCardStyle(highlighted: false)
                                }
                                .listRowBackground(useImmersive ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                            }
                        }
                    }
                }
                .listRowSeparatorTint(useImmersive ? .clear : Color(uiColor: .separator))
                .darkListStyle(enabled: useImmersive, baseBackground: nil)
                .background(Color.clear)
                .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
                .navigationTitle("Add to Statement")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }
    
    private func createNewDraft(scope: StatementDraftScope = .full) {
        let title = "Draft \(Date.now.formatted(date: .numeric, time: .omitted))"
        let newDraft = StatementDraft(title: title, draftScope: scope)
        
        appendEntries(to: newDraft)
        modelContext.insert(newDraft)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save new draft: \(error)")
        }
        
        dismiss()
    }
    
    private func addToDraft(_ draft: StatementDraft) {
        appendEntries(to: draft)
        draft.dateModified = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save updated draft: \(error)")
        }
        
        dismiss()
    }
    
    private func appendEntries(to draft: StatementDraft) {
        // Find the next available order index
        let startOrder = (draft.sections.map { $0.order }.max() ?? -1) + 1
        
        // Sort selected entries by date (ascending)
        let sorted = selectedEntries.sorted(by: { $0.date < $1.date })
        
        for (index, entry) in sorted.enumerated() {
            let content = entry.mergedDraftContent()
            
            let section = StatementSection(
                source: .journalEntry,
                content: content,
                order: startOrder + index,
                sourceID: entry.id
            )
            draft.sections.append(section)
        }
    }
}
