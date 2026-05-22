import SwiftUI
import SwiftData

struct StatementDraftEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Bindable var draft: StatementDraft
    @State private var showingJournalPicker = false
    @State private var showingAIAdvisor = false
    @State private var showingAIUnavailableAlert = false
    @State private var persistenceAlert: PersistenceAlertContext?
    @State private var loadedDraftFingerprint = ""

    private enum ReviewState {
        case notReviewed
        case reviewed
        case needsReReview
    }

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }

    private var allowsAdvisor: Bool {
        AppSettings.featurePolicy.allowsAdvisor
    }

    private var currentDraftTextForStatus: String {
        let sectionText = draft.sections
            .sorted(by: { $0.order < $1.order })
            .map(\.content)
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !sectionText.isEmpty {
            return sectionText
        }

        if let data = draft.richTextData,
           let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
           ) {
            return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return ""
    }

    private var reviewState: ReviewState {
        guard let snapshot = AdvisorFeedbackStore.loadLatest(for: draft.id) else {
            return .notReviewed
        }
        guard !currentDraftTextForStatus.isEmpty else {
            return .notReviewed
        }
        let currentHash = AdvisorFeedbackStore.hash(for: currentDraftTextForStatus)
        return snapshot.analyzedTextHash == currentHash ? .reviewed : .needsReReview
    }

    private var reviewStateLabel: String {
        switch reviewState {
        case .notReviewed: return "Not Yet Reviewed"
        case .reviewed: return "Reviewed"
        case .needsReReview: return "Updated Since Review"
        }
    }

    private var reviewStateForeground: Color {
        switch reviewState {
        case .notReviewed:
            return useImmersive ? DSColor.textSecondary : .secondary
        case .reviewed:
            return useImmersive ? DSColor.success : .green
        case .needsReReview:
            return useImmersive ? DSColor.warning : .orange
        }
    }

    private var reviewStateBackground: Color {
        switch reviewState {
        case .notReviewed:
            return useImmersive ? DSColor.surfaceElevated : Color(uiColor: .tertiarySystemFill)
        case .reviewed:
            return useImmersive ? DSColor.success.opacity(0.18) : Color.green.opacity(0.14)
        case .needsReReview:
            return useImmersive ? DSColor.warning.opacity(0.18) : Color.orange.opacity(0.14)
        }
    }

    private var reviewStateChip: some View {
        Text(reviewStateLabel)
            .font(DSFont.caption)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(reviewStateForeground)
            .background(Capsule().fill(reviewStateBackground))
    }

    private var headerTitle: String {
        if !draft.title.isEmpty {
            return draft.title
        }
        return draft.isSnapshot ? "Snapshot" : "Writing Draft"
    }
    
    var body: some View {
        ZStack {
            if useImmersive {
                SacredScreenBackground(settings: settings)
            }
            List {
                Section {
                    TextField("Draft Title", text: $draft.title)
                        .font(DSFont.heading2)
                        .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                        .padding(.vertical, DSSpacing.sm)
                        .if(useImmersive) { view in
                            view.sacredCardStyle(highlighted: false)
                        }
                }
                .listRowBackground(useImmersive ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                
                Section(
                    header: Group {
                        if useImmersive {
                            DarkSectionHeader(title: "Sections")
                        } else {
                            Text("Sections")
                        }
                    }
                ) {
                    if draft.sections.isEmpty {
                        if useImmersive {
                            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                                Label("No Content", systemImage: "doc.text")
                                    .font(DSFont.heading2)
                                    .foregroundStyle(DSColor.textPrimary)
                                Text("Add journal notes or manual sections.")
                                    .font(DSFont.subtext)
                                    .foregroundStyle(DSColor.textSecondary)
                            }
                            .padding(.vertical, DSSpacing.sm)
                            .sacredCardStyle(highlighted: false)
                        } else {
                            ContentUnavailableView(
                                "No Content",
                                systemImage: "doc.text",
                                description: Text("Add journal notes or manual sections.")
                            )
                        }
                    } else {
                        ForEach(draft.sections.sorted(by: { $0.order < $1.order })) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(section.source.displayName)
                                        .font(DSFont.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(useImmersive ? DSColor.surfaceElevated : Color(uiColor: .quaternarySystemFill)))
                                    
                                    Text(section.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(DSFont.caption)
                                        .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                    
                                    Spacer()
                                }
                                
                                TextEditor(text: Binding(
                                    get: { section.content },
                                    set: { section.content = $0 }
                                ))
                                .frame(minHeight: 100)
                                .font(DSFont.body)
                                .scrollContentBackground(.hidden)
                                .background(useImmersive ? DSColor.backgroundSecondary : Color.clear)
                                .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .padding(.vertical, 4)
                            .if(useImmersive) { view in
                                view.sacredCardStyle(highlighted: false)
                            }
                            .listRowBackground(useImmersive ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                        }
                        .onDelete(perform: deleteSection)
                        .onMove(perform: moveSection)
                    }
                }
            }
            .listRowSeparatorTint(useImmersive ? .clear : Color(uiColor: .separator))
            .darkListStyle(enabled: useImmersive, baseBackground: nil)
            .background(Color.clear)
            .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 3) {
                        Text(headerTitle)
                            .font(DSFont.heading2)
                            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if allowsAdvisor {
                            reviewStateChip
                        }
                    }
                }
                if allowsAdvisor {
                    ToolbarItem(placement: .topBarTrailing) {
                        if DeviceCapabilities.hasSufficientMemoryForAI {
                            Button {
                                showingAIAdvisor = true
                            } label: {
                                Label("AI Advisor", systemImage: "sparkles")
                            }
                        } else {
                            Button {
                                showingAIUnavailableAlert = true
                            } label: {
                                Label("AI Advisor", systemImage: "sparkles")
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingJournalPicker = true
                        } label: {
                            Label("Add Journal Notes", systemImage: "book")
                        }
                        
                        Button {
                            addManualSection()
                        } label: {
                            Label("Add Manual Section", systemImage: "note.text.badge.plus")
                        }
                        
                        Divider()
                        
                        Button {
                            saveAsNewVersion()
                        } label: {
                            Label("Save as New Version", systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            saveSnapshot()
                        } label: {
                            Label("Save Snapshot", systemImage: "checkmark.seal")
                        }
                    } label: {
                        Label("Options", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingJournalPicker) {
                JournalEntrySelectionView(targetDraft: draft)
                    .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
            }
            .sheet(isPresented: $showingAIAdvisor) {
                // Future PR: Pass actual track and content properly aligned to new AIAdvisorPromptBuilder
                AIAdvisorPanel(
                    draftContent: advisorSeedText,
                    draftID: draft.id,
                    initialGuidelineScope: draft.draftScope.asAdvisorGuidelineScope
                )
            }
            .alert("Device Not Supported", isPresented: $showingAIUnavailableAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The AI Advisor feature runs entirely on-device to protect your privacy and requires at least 8GB of memory (e.g., iPhone 15 Pro or newer).")
            }
            .persistenceFailureAlert($persistenceAlert)
            .onAppear {
                if !allowsAdvisor {
                    showingAIAdvisor = false
                    showingAIUnavailableAlert = false
                }
                loadedDraftFingerprint = draftFingerprint
            }
            .onDisappear {
                persistDraftChangesIfNeeded("save this draft")
            }
        }
    }
    
    private func deleteSection(at offsets: IndexSet) {
        // Since we are iterating over a sorted array, we need to map offsets back to the real object
        let sortedSections = draft.sections.sorted(by: { $0.order < $1.order })
        for index in offsets {
            let section = sortedSections[index]
            modelContext.delete(section)
            // Remove from draft.sections via array mutation or rely on relationship cascade?
            // Relationship cascade handles delete from persistence, but we should remove from the array to update UI immediately?
            // Actually, deleting from context handles it if relationship is valid. 
            // Better to remove from the array directly.
            if let idx = draft.sections.firstIndex(of: section) {
                draft.sections.remove(at: idx)
            }
        }
        persistDraftChanges("delete that section")
    }
    
    private func moveSection(from source: IndexSet, to destination: Int) {
        var sortedSections = draft.sections.sorted(by: { $0.order < $1.order })
        sortedSections.move(fromOffsets: source, toOffset: destination)
        
        // Re-assign order
        for (index, section) in sortedSections.enumerated() {
            section.order = index
        }
        persistDraftChanges("reorder those sections")
    }
    
    private func addManualSection() {
        let newOrder = (draft.sections.map { $0.order }.max() ?? -1) + 1
        let section = StatementSection(source: .manual, content: "", order: newOrder)
        draft.sections.append(section)
        draft.dateModified = Date()
        persistDraftChanges("add a manual section")
    }
    
    private func saveAsNewVersion() {
        let newVersion = draft.version + 1
        let newDraft = StatementDraft(
            title: draft.title,
            version: newVersion,
            draftScope: draft.draftScope,
            writingTargetID: draft.writingTargetID,
            writingTargetCategory: draft.writingTargetCategory,
            customPromptText: draft.customPromptText
        )
        
        // Clone sections
        for section in draft.sections {
            let newSection = StatementSection(
                source: section.source,
                content: section.content,
                order: section.order,
                sourceID: section.sourceID
            )
            newDraft.sections.append(newSection)
        }
        
        modelContext.insert(newDraft)
        persistDraftChanges("save a new draft version")
        // Navigate to new draft? Or just inform user?
        // For now, simpler to stay here or pop back.
    }
    
    private func saveSnapshot() {
        draft.isSnapshot = true
        draft.isLocked = false
        draft.dateModified = Date()
        persistDraftChanges("save this snapshot")
    }

    private var advisorSeedText: String {
        if let data = draft.richTextData,
           let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
           ) {
            let richText = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !richText.isEmpty {
                return richText
            }
        }

        return draft.sections
            .sorted(by: { $0.order < $1.order })
            .map(\.content)
            .joined(separator: "\n\n")
    }

    private var draftFingerprint: String {
        [
            draft.title,
            draft.version.description,
            draft.isSnapshot.description,
            draft.draftScopeRaw ?? "",
            draft.writingTargetID ?? "",
            draft.writingTargetCategoryRaw ?? "",
            draft.customPromptText ?? "",
            draft.sections
                .sorted(by: { $0.order < $1.order })
                .map { "\($0.id.uuidString)|\($0.order)|\($0.source.rawValue)|\($0.content)|\($0.sourceID?.uuidString ?? "")" }
                .joined(separator: "||")
        ].joined(separator: "|||")
    }

    private func persistDraftChangesIfNeeded(_ operation: String) {
        guard draftFingerprint != loadedDraftFingerprint else { return }
        persistDraftChanges(operation)
    }

    private func persistDraftChanges(_ operation: String) {
        draft.dateModified = Date()
        draft.isLocked = false

        do {
            try modelContext.persistIfNeeded(for: operation)
            loadedDraftFingerprint = draftFingerprint
        } catch let error as PersistenceOperationError {
            persistenceAlert = error.alertContext
        } catch {
            persistenceAlert = PersistenceAlertContext.saveFailure(
                for: operation,
                details: error.localizedDescription
            )
        }
    }
}
