//
//  StatementListView.swift
//  IlluminoteSceneDemo
//
//  Created by AntiGravity on 12/20/25.
//

import SwiftUI
import SwiftData

/// Lists all Personal Statement drafts designated by StatementDraft model.
struct StatementListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    // Fetch StatementDrafts
    @Query(sort: [SortDescriptor(\StatementDraft.dateModified, order: .reverse)])
    private var drafts: [StatementDraft]
    
    // Fetch UserProfile for requirements
    @Query(sort: \UserProfile.id) private var profiles: [UserProfile]
    
    @State private var requirements: [StatementRequirement] = []
    private let requirementsService = LocalStatementRequirementsService()

    @State private var showingRenameSheet = false
    @State private var renameTarget: StatementDraft?
    @State private var renameTitle = ""
    @State private var renameScope: StatementDraftScope = .full
    
    @State private var showingJournalPicker = false
    @State private var isImporting = false
    @State private var draftCreationTrigger = 0
    @State private var draftTypeChangeTrigger = 0

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }

    private var canShowKnowledgeBaseVerification: Bool {
        AppSettings.knowledgeBaseVerificationAllowedInThisBuild
    }


    var body: some View {
        NavigationStack {
            ZStack {
                if useImmersive {
                    SacredScreenBackground(settings: settings)
                }
                VStack(spacing: 0) {
                    StatementListContent(
                        requirements: requirements,
                        drafts: drafts,
                        onDelete: { draft in
                            AdvisorFeedbackStore.removeLatest(for: draft.id)
                            DraftRevisionStore.remove(for: draft.id)
                            modelContext.delete(draft)
                            try? modelContext.save()
                        },
                        onRename: { draft in
                            beginRename(draft)
                        },
                        onChangeScope: { draft, scope in
                            guard draft.draftScope != scope else { return }
                            draft.draftScope = scope
                            draft.dateModified = Date()
                            try? modelContext.save()
                            draftTypeChangeTrigger += 1
                        },
                        onCreate: createEmptyDraft,
                        useImmersive: useImmersive
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Menu {
                            Menu {
                                ForEach(StatementDraftScope.allCases) { scope in
                                    Button {
                                        createEmptyDraft(scope: scope)
                                    } label: {
                                        Text(scope.displayName)
                                    }
                                }
                            } label: {
                                Label("New Empty Draft", systemImage: "doc.badge.plus")
                            }
                            
                            Button {
                                showingJournalPicker = true
                            } label: {
                                Label("New from Journal", systemImage: "book")
                            }
                            
                            Divider()
                            
                            Button {
                                isImporting = true
                            } label: {
                                Label("Import Draft", systemImage: "arrow.down.doc")
                            }
                        } label: {
                            Label("Add Draft", systemImage: "plus")
                        }
                        
                        if canShowKnowledgeBaseVerification {
                            Button {
                                showingKnowledgeBase = true
                            } label: {
                                Image(systemName: "books.vertical")
                            }
                        }
                    }
                }
            }
            .sheet(item: $renameTarget) { draft in
                RenameSheetView(
                    draft: draft,
                    title: $renameTitle,
                    scope: $renameScope,
                    useImmersive: useImmersive,
                    onSave: {
                        draft.title = renameTitle
                        draft.draftScope = renameScope
                        try? modelContext.save()
                        renameTarget = nil
                    },
                    onCancel: {
                        renameTarget = nil
                    }
                )
                .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
            }
            .sheet(isPresented: $showingJournalPicker) {
                JournalEntrySelectionView(onDraftCreated: { _ in
                    // Draft created and inserted, List will update automatically
                })
                .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
            }
            .sheet(isPresented: Binding(
                get: { canShowKnowledgeBaseVerification && showingKnowledgeBase },
                set: { showingKnowledgeBase = $0 }
            )) {
                ToolsVerificationSheet()
                    .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.illuminoteDraft]
            ) { result in
                switch result {
                case .success(let url):
                    importDraft(from: url)
                case .failure(let error):
                    print("Import failed: \(error.localizedDescription)")
                }
            }
            .navigationTitle(useImmersive ? "" : "Statement Drafts")
            .navigationBarTitleDisplayMode(useImmersive ? .inline : .large)
            .background(Color.clear)
            .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
            .sensoryFeedback(.success, trigger: draftCreationTrigger)
            .sensoryFeedback(.selection, trigger: draftTypeChangeTrigger)
        }
        .task(id: profiles.first?.id) {
            await loadRequirements()
        }
        .onAppear {
            if !canShowKnowledgeBaseVerification {
                showingKnowledgeBase = false
            }
        }
        .onChange(of: profiles.first?.degreeIntent) { Task { await loadRequirements() } }
        .onChange(of: profiles.first?.isTexasApplicant) { Task { await loadRequirements() } }
    }
    
    @State private var showingKnowledgeBase = false
    
    private func loadRequirements() async {
        guard let profile = profiles.first else { return }
        requirements = await requirementsService.requirements(for: profile)
    }
    
    private func createEmptyDraft() {
        createEmptyDraft(scope: .full)
    }

    private func createEmptyDraft(scope: StatementDraftScope) {
        let draft = StatementDraft(title: "New Draft", draftScope: scope)
        modelContext.insert(draft)
        try? modelContext.save()
        draftCreationTrigger += 1
    }
    
    private func beginRename(_ draft: StatementDraft) {
        renameTarget = draft
        renameTitle = draft.title
        renameScope = draft.draftScope
    }
    
    private func importDraft(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder()
                .decode(StatementDraftFilePayload.self, from: data)
        else { return }

        let _ = StatementDraft.fromPayload(
            payload,
            context: modelContext,
            asCopy: true
        )
        try? modelContext.save()
    }
}

// Breakdown of main list content to reduce body complexity
private struct StatementListContent: View {
    let requirements: [StatementRequirement]
    let drafts: [StatementDraft]
    let onDelete: (StatementDraft) -> Void
    let onRename: (StatementDraft) -> Void
    let onChangeScope: (StatementDraft, StatementDraftScope) -> Void
    let onCreate: () -> Void
    let useImmersive: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if useImmersive {
                HStack {
                    Text("Statement Drafts")
                        .font(DSFont.heading1)
                        .foregroundStyle(DSColor.textPrimary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, DSSpacing.md)
                .padding(.bottom, DSSpacing.sm)
            }

            if !requirements.isEmpty {
                StatementRequirementsCard(requirements: requirements)
                    .padding(.horizontal)
                    .padding(.top, useImmersive ? 0 : DSSpacing.md)
            }
            
            if drafts.isEmpty {
                if useImmersive {
                    DarkEmptyState(
                        title: "No Drafts Yet",
                        systemImage: "square.and.pencil",
                        description: "Start a new personal statement draft to begin writing.",
                        actionTitle: "Create Your First Draft",
                        action: onCreate,
                        fillBackground: false
                    )
                } else {
                    ContentUnavailableView(
                        "No Drafts Yet",
                        systemImage: "square.and.pencil",
                        description: Text("Start a new personal statement draft to begin writing.")
                    )
                }
            } else {
                List {
                    ForEach(drafts) { draft in
                        StatementDraftRow(
                            draft: draft,
                            requirements: requirements,
                            onDelete: { onDelete(draft) },
                            onRename: { onRename(draft) },
                            onChangeScope: { scope in
                                onChangeScope(draft, scope)
                            },
                            useImmersive: useImmersive
                        )
                        .listRowBackground(useImmersive ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                    }
                }
                .listRowSeparatorTint(useImmersive ? DSColor.divider : Color(uiColor: .separator))
                .darkListStyle(enabled: useImmersive, baseBackground: nil)
            }
        }
        .background(Color.clear)
    }
}

private struct RenameSheetView: View {
    let draft: StatementDraft
    @Binding var title: String
    @Binding var scope: StatementDraftScope
    let useImmersive: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                    .onSubmit(onSave)
                    .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)

                Picker("Draft Type", selection: $scope) {
                    ForEach(StatementDraftScope.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(useImmersive ? DSColor.goldLight : .accentColor)
            }
            .darkListStyle(enabled: useImmersive)
            .navigationTitle("Edit Draft")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct StatementDraftRow: View {
    let draft: StatementDraft
    let requirements: [StatementRequirement]
    let onDelete: () -> Void
    let onRename: () -> Void
    let onChangeScope: (StatementDraftScope) -> Void
    let useImmersive: Bool

    private enum ReviewState {
        case notReviewed
        case reviewed
        case needsReReview
    }
    
    private var totalCharacterCount: Int {
        if let richTextData = draft.richTextData,
           let attributed = try? NSAttributedString(
                data: richTextData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
           ) {
            let richTextCount = attributed.string.count
            if richTextCount > 0 {
                return richTextCount
            }
        }
        return draft.sections.reduce(0) { $0 + $1.content.count }
    }

    private var draftPlainText: String {
        if let richTextData = draft.richTextData,
           let attributed = try? NSAttributedString(
                data: richTextData,
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
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var draftTextHash: String? {
        guard !draftPlainText.isEmpty else { return nil }
        return AdvisorFeedbackStore.hash(for: draftPlainText)
    }

    private var revisionCount: Int {
        DraftRevisionStore.revisionCount(for: draft.id, currentHash: draftTextHash)
    }

    private var reviewState: ReviewState {
        guard let snapshot = AdvisorFeedbackStore.loadLatest(for: draft.id) else {
            return .notReviewed
        }
        guard let hash = draftTextHash else {
            return .notReviewed
        }
        return snapshot.analyzedTextHash == hash ? .reviewed : .needsReReview
    }

    @ViewBuilder
    private var reviewStateBadge: some View {
        switch reviewState {
        case .notReviewed:
            statusBadge(
                text: "Not Reviewed",
                foreground: useImmersive ? DSColor.textSecondary : .secondary,
                background: useImmersive ? DSColor.surfaceElevated : Color(uiColor: .tertiarySystemFill)
            )
        case .reviewed:
            statusBadge(
                text: "Reviewed",
                foreground: useImmersive ? DSColor.success : .green,
                background: useImmersive ? DSColor.success.opacity(0.18) : Color.green.opacity(0.14)
            )
        case .needsReReview:
            statusBadge(
                text: "Needs Re-Review",
                foreground: useImmersive ? DSColor.warning : .orange,
                background: useImmersive ? DSColor.warning.opacity(0.18) : Color.orange.opacity(0.14)
            )
        }
    }

    private func statusBadge(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(DSFont.caption)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(background))
    }

    private var baseRowContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(draft.title.isEmpty ? "Untitled Draft" : draft.title)
                    .font(DSFont.heading2)
                    .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                if draft.isFinal {
                    Image(systemName: "lock.fill")
                        .font(DSFont.caption)
                        .foregroundStyle(useImmersive ? DSColor.textTertiary : .secondary)
                    }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    statusBadge(
                        text: "v\(draft.version)",
                        foreground: useImmersive ? DSColor.textPrimary : .primary,
                        background: useImmersive ? DSColor.surfaceElevated : Color(uiColor: .tertiarySystemFill)
                    )
                    .contentTransition(.numericText())

                    statusBadge(
                        text: draft.draftScope.shortLabel,
                        foreground: useImmersive ? DSColor.textPrimary : .primary,
                        background: useImmersive ? DSColor.surfaceElevated : Color(uiColor: .tertiarySystemFill)
                    )

                    statusBadge(
                        text: "r\(revisionCount)",
                        foreground: useImmersive ? DSColor.goldLight : .accentColor,
                        background: useImmersive ? DSColor.goldLight.opacity(0.18) : Color.accentColor.opacity(0.14)
                    )
                    .contentTransition(.numericText())

                    reviewStateBadge
                }
            }

            HStack {
                Text(draft.dateModified.formatted(date: .abbreviated, time: .shortened))
                    .font(DSFont.subtext)
                    .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                
                Spacer()
                
                if let req = requirements.first {
                    Text("\(totalCharacterCount) / \(req.characterLimitMax) chars")
                        .font(DSFont.caption)
                        .foregroundStyle(useImmersive ? DSColor.textTertiary : .secondary)
                } else {
                    Text("\(totalCharacterCount) chars")
                        .font(DSFont.caption)
                        .foregroundStyle(useImmersive ? DSColor.textTertiary : .secondary)
                }
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.md)
    }

    @ViewBuilder
    private var rowContent: some View {
        if useImmersive {
            baseRowContent
                .sacredCardStyle(highlighted: draft.isFinal)
        } else {
            baseRowContent
        }
    }
    
    var body: some View {
        NavigationLink(destination: PSRichTextEditorView(draft: draft)) {
            rowContent
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            .tint(useImmersive ? DSColor.goldLight : .blue)
        }
        .contextMenu {
            Menu {
                ForEach(StatementDraftScope.allCases) { scope in
                    Button {
                        onChangeScope(scope)
                    } label: {
                        if draft.draftScope == scope {
                            Label(scope.displayName, systemImage: "checkmark")
                        } else {
                            Text(scope.displayName)
                        }
                    }
                    .disabled(draft.draftScope == scope)
                }
            } label: {
                Label("Draft Type", systemImage: "tag")
            }

            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct DraftRevisionSnapshot: Codable {
    var revisionCount: Int
    var lastTextHash: String?
}

private enum DraftRevisionStore {
    private static let keyPrefix = "statementDraft.revision."

    static func revisionCount(for draftID: UUID, currentHash: String?) -> Int {
        let existingSnapshot = load(for: draftID)
        var snapshot = existingSnapshot ?? DraftRevisionSnapshot(revisionCount: 1, lastTextHash: currentHash)

        if snapshot.lastTextHash != currentHash {
            snapshot.revisionCount += 1
            snapshot.lastTextHash = currentHash
            save(snapshot, for: draftID)
        } else if existingSnapshot == nil {
            save(snapshot, for: draftID)
        }

        return max(snapshot.revisionCount, 1)
    }

    static func remove(for draftID: UUID) {
        UserDefaults.standard.removeObject(forKey: keyPrefix + draftID.uuidString)
    }

    private static func load(for draftID: UUID) -> DraftRevisionSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: keyPrefix + draftID.uuidString) else {
            return nil
        }
        return try? JSONDecoder().decode(DraftRevisionSnapshot.self, from: data)
    }

    private static func save(_ snapshot: DraftRevisionSnapshot, for draftID: UUID) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: keyPrefix + draftID.uuidString)
    }
}

#if DEBUG
struct StatementListView_Previews: PreviewProvider {
    static var previews: some View {
        StatementListView()
            .modelContainer(for: [StatementDraft.self, StatementSection.self, ExamenSession.self], inMemory: true)
    }
}
#endif

private struct JournalImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    // Fetch all sessions, filter for non-draft journal entries
    @Query(sort: [SortDescriptor(\ExamenSession.date, order: .reverse)])
    private var allSessions: [ExamenSession]

    private var entries: [ExamenSession] {
        allSessions.filter { $0.sessionType != ExamenType.statementDraft }
    }

    @State private var selection = Set<ExamenSession.ID>()
    var onCancel: () -> Void
    var onImport: ([ExamenSession]) -> Void

    @State private var query: String = ""
    @State private var selectedExperience: ExperienceType? = nil
    @State private var selectedTag: String? = nil

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }

    private var allTags: [String] {
        let set = Set(entries.flatMap { $0.tags })
        return Array(set).sorted()
    }

    private var filtersAreClear: Bool {
        query.isEmpty && selectedExperience == nil && selectedTag == nil
    }

    private var filteredEntries: [ExamenSession] {
        entries.filter { entry in
            // Experience filter
            let experienceOK = selectedExperience == nil || entry.experienceType == selectedExperience
            // Tag filter (single tag for MVP)
            let tagOK = selectedTag == nil || entry.tags.contains(selectedTag!)
            // Text search across first answer + all answers (simple contains)
            let haystack: String = {
                let answers = entry.responses.sorted(by: { $0.stepIndex < $1.stepIndex }).map { $0.answerText }.joined(separator: "\n")
                return answers + "\n" + entry.date.formatted(date: .abbreviated, time: .shortened)
            }()
            let searchOK = query.isEmpty || haystack.localizedCaseInsensitiveContains(query)
            return experienceOK && tagOK && searchOK
        }
    }

    private func clearFilters() {
        query = ""
        selectedExperience = nil
        selectedTag = nil
        selection.removeAll()
    }

    private struct FilterPill: View {
        let text: String
        let onClear: () -> Void

        var body: some View {
            HStack(spacing: 6) {
                Text(text)
                    .font(.footnote)
                    .lineLimit(1)
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(DSColor.goldLight.opacity(0.5), lineWidth: 1)
            )
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if useImmersive {
                    SacredScreenBackground(settings: settings)
                }
                VStack(spacing: 8) {
                // Filters row
                HStack {
                    Menu {
                        // Experience picker
                        Button("All Experiences") { selectedExperience = nil }
                        Divider()
                        ForEach(ExperienceType.allCases, id: \.self) { kind in
                            Button(kind.displayName) { selectedExperience = kind }
                        }
                    } label: {
                        Label(selectedExperience == nil ? "Experience: All" : "Experience: \(selectedExperience!.displayName)", systemImage: "line.3.horizontal.decrease.circle")
                            .labelStyle(.titleAndIcon)
                    }

                    Menu {
                        Button("All Tags") { selectedTag = nil }
                        Divider()
                        ForEach(allTags, id: \.self) { tag in
                            Button(tag) { selectedTag = tag }
                        }
                    } label: {
                        Label(selectedTag == nil ? "Tag: All" : "Tag: \(selectedTag!)", systemImage: "tag")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .padding(.horizontal)

                if !filtersAreClear {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if let kind = selectedExperience {
                                FilterPill(text: "Experience: \(kind.displayName)") {
                                    selectedExperience = nil
                                }
                            }
                            if let tag = selectedTag {
                                FilterPill(text: "Tag: \(tag)") {
                                    selectedTag = nil
                                }
                            }
                            if !query.isEmpty {
                                FilterPill(text: "Search: \(query)") {
                                    query = ""
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Results list
                Group {
                    if filteredEntries.isEmpty {
                        if useImmersive {
                            DarkEmptyState(
                                title: "No Matches",
                                systemImage: "magnifyingglass",
                                description: "Adjust your filters or search.",
                                fillBackground: false
                            )
                        } else {
                            ContentUnavailableView("No Matches", systemImage: "magnifyingglass", description: Text("Adjust your filters or search."))
                        }
                    } else {
                        List(selection: $selection) {
                            ForEach(filteredEntries) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(DSFont.heading2)
                                            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                                        if let first = entry.responses.sorted(by: { $0.stepIndex < $1.stepIndex }).first {
                                            Text(first.answerText)
                                                .lineLimit(1)
                                                .font(DSFont.subtext)
                                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, DSSpacing.md)
                                .padding(.vertical, DSSpacing.sm)
                                .overlay {
                                    if useImmersive {
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(selection.contains(entry.id) ? DSColor.goldLight : Color.white.opacity(0.12), lineWidth: selection.contains(entry.id) ? 2 : 1)
                                    }
                                }
                                .background {
                                    if useImmersive {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.ultraThinMaterial)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: useImmersive && selection.contains(entry.id) ? DSColor.goldLight.opacity(0.25) : .clear, radius: 10, x: 0, y: 3)
                                .tag(entry.id)
                                .listRowBackground(useImmersive ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                            }
                        }
                        .listRowSeparatorTint(useImmersive ? DSColor.divider : Color(uiColor: .separator))
                        .darkListStyle(enabled: useImmersive, baseBackground: nil)
                    }
                }
            }
            .background(Color.clear)
            .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
            .navigationTitle("Import from Journal")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { onCancel() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear Filters") { clearFilters() }
                        .disabled(filtersAreClear)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import") {
                        let chosen = entries.filter { selection.contains($0.id) }
                        onImport(chosen)
                    }
                    .disabled(selection.isEmpty)
                }
            }
            .searchable(text: $query, placement: .toolbar, prompt: "Search journal entries")
            // Apple docs: Lists require edit mode for multi-select on iOS; enabling it here mirrors the Photos app style. (List selection guidance)
            .environment(\.editMode, .constant(.active)) // enable multi-select like Photos on iOS. See Apple docs. 
            }
        }
    }
}
