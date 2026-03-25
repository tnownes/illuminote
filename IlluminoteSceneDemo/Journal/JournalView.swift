import SwiftUI
import SwiftData
import NaturalLanguage

struct JournalView: View {
    private let journalDateStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings // reserved if you later style rows by theme

    // Environment editMode removed in favor of local state management

    // Fetch all, then filter in-memory to avoid predicate enum issues
    @Query(sort: [SortDescriptor(\ExamenSession.date, order: .reverse)])
    private var allSessions: [ExamenSession]

    // Fetch drafts for reference resolution
    @Query(sort: \StatementDraft.dateModified, order: .reverse)
    private var statementDrafts: [StatementDraft]

    // JOURNAL ONLY: exclude statement drafts
    private var sessions: [ExamenSession] {
        allSessions.filter { $0.sessionType != ExamenType.statementDraft }
    }

    // All drafts for reference marking and default-draft use
    private var drafts: [ExamenSession] {
        allSessions.filter { $0.sessionType == ExamenType.statementDraft }
    }

    // Multi-selection like Photos app
    @State private var selectedIDs: Set<UUID> = []
    
    // Manage EditMode locally to ensure List selection works reliably
    @State private var editMode: EditMode = .inactive

    // Filters/search state
    @State private var query: String = ""
    @State private var selectedExperience: ExperienceType? = nil
    @State private var selectedTag: String? = nil
    @State private var onlyFavorites: Bool = false
    
    // Date filter state
    enum DatePreset: String, CaseIterable { case all, last7, last30, last365, custom }
    @State private var datePreset: DatePreset = .all
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var customEnd: Date = .now
    @State private var showDateRangeSheet = false
    
    @State private var showEditDetails = false
    @State private var editingEntry: ExamenSession? = nil
    @State private var tempExperience: ExperienceType? = nil
    @State private var tempTags: [String] = []
    @State private var newTagText: String = ""

    @State private var showBulkTagSheet = false
    @State private var bulkTags: [String] = []
    @State private var bulkNewTagText: String = ""

    // Entry viewer/editor state
    @State private var viewingEntry: ExamenSession? = nil
    
    // Edit Mode State (Notes only)
    @State private var showEditTextSheet = false
    @State private var editStatementText: String = ""
    @State private var editingTextEntry: ExamenSession? = nil
    
    // Quick Note
    @State private var showQuickNoteTypePicker = false
    @State private var showQuickNoteFlow = false
    @State private var quickNoteType: ExperienceType = .other
    
    // Add to Statement Sheet
    @State private var showAddToStatementSheet = false
    @State private var entriesToAdd: [ExamenSession] = []

    // Theme Finder
    @State private var showThemeFinder = false
    
    // File Export State
    @State private var showFileExporter = false
    @State private var exportDocument: RTFDocument?

    // Cached filter results to avoid recomputation on every body evaluation
    @State private var cachedFilteredSessions: [ExamenSession] = []
    @State private var needsFilterUpdate = true

    private var allTags: [String] {
        let set = Set(sessions.flatMap { $0.tags })
        return Array(set).sorted()
    }

    private var filtersAreClear: Bool {
        query.isEmpty && selectedExperience == nil && selectedTag == nil && datePreset == .all
    }

    private var filteredSessions: [ExamenSession] {
        cachedFilteredSessions
    }

    private func refilter() {
        cachedFilteredSessions = sessions.filter { entry in
            passesExperienceAndTagFilters(entry: entry, experience: selectedExperience, tag: selectedTag)
            && passesSearchFilter(entry: entry, query: query)
            && isWithinDateRange(entry: entry, preset: datePreset)
            && (!onlyFavorites || entry.isFavorite)
        }
    }

    // Grouping helpers
    private var monthFormatter: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale.current
        f.dateFormat = "LLLL yyyy" // e.g., September 2025
        return f
    }

    private func monthStart(for date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }

    private var groupedByMonth: [(month: Date, items: [ExamenSession])] {
        let groups = Dictionary(grouping: filteredSessions) { monthStart(for: $0.date) }
        // Sort months descending (newest first), and items descending by date
        return groups
            .map { (key, value) in
                (month: key, items: value.sorted { $0.date > $1.date })
            }
            .sorted { $0.month > $1.month }
    }

    private var datePresetLabel: String {
        switch datePreset {
        case .all: return "Date: All"
        case .last7: return "Date: 7d"
        case .last30: return "Date: 30d"
        case .last365: return "Date: 1y"
        case .custom:
            let s = customStart
            let e = customEnd
            let fmt = DateFormatter()
            fmt.dateStyle = .short
            return "Date: \(fmt.string(from: min(s,e)))–\(fmt.string(from: max(s,e)))"
        }
    }

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if useImmersive {
                    SacredScreenBackground(settings: settings)
                }
                Group {
                    if sessions.isEmpty {
                        if useImmersive {
                            DarkEmptyState(
                                title: "No Sessions Yet",
                                systemImage: "book",
                                description: "Your reflections will appear here once you complete an Examen. Tap the Home tab to start.",
                                actionTitle: "Start Your First Examen",
                                action: {},
                                fillBackground: false
                            )
                        } else {
                            ContentUnavailableView {
                                Label("No Sessions Yet", systemImage: "book")
                            } description: {
                                Text("Your reflections will appear here once you complete an Examen. Tap the Home tab to start.")
                            }
                        }
                    } else {
                        VStack(spacing: 8) {
                            // Filters row
                            FiltersRow(selectedExperience: $selectedExperience,
                                       selectedTag: $selectedTag,
                                       datePreset: $datePreset,
                                       showDateRangeSheet: $showDateRangeSheet,
                                       onlyFavorites: $onlyFavorites,
                                       allTags: allTags,
                                       datePresetLabel: datePresetLabel)
                                .padding(.horizontal)

                            // Active filter pills
                            if !filtersAreClear {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        if let kind = selectedExperience {
                                            FilterPill(text: "Experience: \(kind.displayName)") { selectedExperience = nil }
                                        }
                                        if let tag = selectedTag {
                                            FilterPill(text: "Tag: \(tag)") { selectedTag = nil }
                                        }
                                        if !query.isEmpty {
                                            FilterPill(text: "Search: \(query)") { query = "" }
                                        }
                                        if datePreset != .all {
                                            FilterPill(text: datePresetLabel) {
                                                datePreset = .all
                                            }
                                        }
                                        if onlyFavorites {
                                            FilterPill(text: "Favorites") { onlyFavorites = false }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }

                            // Results list (multi-select)
                            List(selection: $selectedIDs) {
                                ForEach(groupedByMonth, id: \.month) { section in
                                    Section(
                                        header: Group {
                                            if useImmersive {
                                                DarkSectionHeader(title: monthFormatter.string(from: section.month))
                                            } else {
                                                Text(monthFormatter.string(from: section.month))
                                            }
                                        }
                                    ) {
                                        ForEach(section.items) { session in
                                            journalRow(for: session)
                                                .listRowBackground(useImmersive ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                                        }
                                    }
                                }
                            }
                            .environment(\.editMode, $editMode) // Inject local state
                            .listRowSeparatorTint(useImmersive ? .clear : Color(uiColor: .separator))
                            .darkListStyle(enabled: useImmersive, baseBackground: nil)
                        }
                    }
                }
            }
            .navigationTitle("Journal")
            .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
            .onChange(of: query) { _, _ in refilter() }
            .onChange(of: selectedExperience) { _, _ in refilter() }
            .onChange(of: selectedTag) { _, _ in refilter() }
            .onChange(of: datePreset) { _, _ in refilter() }
            .onChange(of: onlyFavorites) { _, _ in refilter() }
            .onChange(of: allSessions.count) { _, _ in refilter() }
            .onAppear { refilter() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(editMode == .active ? "Cancel" : "Select") {
                        withAnimation { toggleEditMode() }
                    }
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showQuickNoteTypePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .tint(useImmersive ? DSColor.goldLight : .accentColor)

                    Button {
                        showThemeFinder = true
                    } label: {
                        Label("Theme Finder", systemImage: "sparkles.rectangle.stack")
                    }
                    .tint(useImmersive ? DSColor.goldLight : .accentColor)
                    
                    Button {
                        clearFilters()
                    } label: {
                        Label("Clear Filters", systemImage: "xmark.circle")
                    }
                    .disabled(filtersAreClear)
                    .tint(useImmersive ? DSColor.goldLight : .accentColor)
                    
                    Button {
                        seedBulkTagsFromSelection()
                        showBulkTagSheet = true
                    } label: {
                        Label("Tag Selected", systemImage: "tag")
                    }
                    .disabled(!(editMode == .active && !selectedIDs.isEmpty))
                    .tint(useImmersive ? DSColor.goldLight : .accentColor)
                    
                    Button {
                        exportSelectedNotes()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(!(editMode == .active && !selectedIDs.isEmpty))
                    .tint(useImmersive ? DSColor.goldLight : .accentColor)
                    
                    Button {
                        let chosen = filteredSessions.filter { selectedIDs.contains($0.id) }
                        entriesToAdd = chosen
                        showAddToStatementSheet = true
                    } label: {
                        Label("Add to Statement", systemImage: "square.and.pencil")
                    }
                    .disabled(!(editMode == .active && !selectedIDs.isEmpty))
                    .tint(useImmersive ? DSColor.goldLight : .accentColor)
                }
            }
            .searchable(text: $query, placement: .toolbar, prompt: "Search journal entries")
        }
        .fileExporter(
            isPresented: $showFileExporter,
            document: exportDocument,
            contentType: .rtf,
            defaultFilename: "ExportedNotes"
        ) { result in
            if case .success(let url) = result {
                print("Exported to: \(url)")
            } else if case .failure(let error) = result {
                print("Export failed: \(error.localizedDescription)")
            }
        }
        .confirmationDialog(
            "New Note: Choose Experience Type",
            isPresented: $showQuickNoteTypePicker,
            titleVisibility: .visible
        ) {
            ForEach(ExperienceType.allCases, id: \.self) { type in
                Button(type.displayName) {
                    launchQuickNote(for: type)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This opens the Session Details form directly without running a full Examen.")
        }
        .fullScreenCover(isPresented: $showQuickNoteFlow) {
            quickNoteFlow
        }
        .sheet(isPresented: $showEditDetails) {
            editDetailsSheet
                .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
        }
        .sheet(item: $viewingEntry) { entry in
            JournalEntryViewer(
                entry: entry,
                onClose: { viewingEntry = nil },
                onEdit: {
                    // Slight delay to allow sheet to dismiss if we want smoother transition,
                    // but usually we can swap.
                    // Original logic: "View & Edit" meant View, then click Edit button.
                    // Here we are inside the viewer.
                    // To edit, we dismiss viewer and show edit sheet?
                    // The original 'beginEditingEntry' sets 'showEditTextSheet = true'.
                    // If we do that while this sheet is presented, we need unrelated sheets.
                    // JournalView has them as siblings.
                    viewingEntry = nil
                    // Defer slightly to allow dismiss?
                    // Or rely on SwiftUI handling sibling sheet swap.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                         beginEditingEntry(entry)
                    }
                },
                onAddToStatement: {
                    viewingEntry = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        entriesToAdd = [entry]
                        showAddToStatementSheet = true
                    }
                }
            )
            .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
        }
        .sheet(isPresented: $showEditTextSheet) {
            editTextSheet
                .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
        }
        .sheet(isPresented: $showBulkTagSheet) {
            bulkTagSheet
                .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
        }
        .sheet(isPresented: $showDateRangeSheet) {
            dateRangeSheet
                .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
        }
        .sheet(isPresented: $showAddToStatementSheet) {
            addToStatementSheetContent
                .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
        }
        .sheet(isPresented: $showThemeFinder) {
            ThemeFinderView(
                defaultScope: .acrossExperiences,
                onSendToStatement: { entries in
                    showThemeFinder = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        entriesToAdd = entries
                        showAddToStatementSheet = !entries.isEmpty
                    }
                }
            )
            .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
        }
    }


    // MARK: - Logic Helpers

    private func passesExperienceAndTagFilters(
        entry: ExamenSession,
        experience: ExperienceType?,
        tag: String?
    ) -> Bool {
        let expOK = experience == nil || entry.experienceType == experience
        let tagOK = tag == nil || entry.tags.contains(tag!)
        return expOK && tagOK
    }

    private func passesSearchFilter(entry: ExamenSession, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let haystack = searchHaystack(for: entry)
        return haystack.localizedCaseInsensitiveContains(query)
    }

    private func isWithinDateRange(entry: ExamenSession, preset: DatePreset) -> Bool {
        switch preset {
        case .all: return true
        case .last7:
            return entry.date >= Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        case .last30:
            return entry.date >= Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        case .last365:
            return entry.date >= Calendar.current.date(byAdding: .day, value: -365, to: .now)!
        case .custom:
            let start = min(customStart, customEnd)
            let end = max(customStart, customEnd)
            return (start...end).contains(entry.date)
        }
    }
    
    private func searchHaystack(for entry: ExamenSession) -> String {
        let sortedResponses = entry.responses
            .sorted { $0.stepIndex < $1.stepIndex }
        let answerTexts = sortedResponses.map { $0.answerText }
        let combinedAnswers = answerTexts.joined(separator: "\n\n")

        let metadataFields: [String] = [
            entry.resolvedPrimaryDetail,
            entry.resolvedSecondaryDetail,
            entry.resolvedFocusDetail,
            entry.location,
            entry.notes
        ].compactMap { $0 }
        let combinedMetadata = metadataFields.joined(separator: " ")

        let dateString = entry.date.formatted(journalDateStyle)
        let personalStatementText = entry.personalStatement

        return """
        \(combinedAnswers)
        \(dateString)
        \(personalStatementText)
        \(combinedMetadata)
        """
    }

    // MARK: - Helpers

    private func toggleEditMode() {
        print("Toggle Edit Mode tapped. Current: \(editMode)")
        if editMode == .active {
            clearSelectionAndExitEditMode()
        } else {
            editMode = .active
        }
    }

    private func clearFilters() {
        query = ""
        selectedExperience = nil
        selectedTag = nil
        selectedIDs.removeAll()
        datePreset = .all
    }
    
    private func delete(_ entries: [ExamenSession]) {
        for entry in entries {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }

    private func clearSelectionAndExitEditMode() {
        selectedIDs.removeAll()
        editMode = .inactive
    }

    private func referencingDrafts(
        for entryID: UUID
    ) -> [(draft: StatementDraft, sectionDate: Date)] {
        statementDrafts.compactMap { draft in
            draft.sections
                .first { $0.sourceID == entryID }
                .map { (draft, $0.date) }
        }
    }
    
    private func presentViewer(for entry: ExamenSession) {
        viewingEntry = entry
    }
    
    private func beginEditDetails(_ entry: ExamenSession) {
        editingEntry = entry
        tempExperience = entry.experienceType
        tempTags = entry.tags
        newTagText = ""
        showEditDetails = true
    }

    // MARK: - UI Builders

    @ViewBuilder
    private func journalRow(for session: ExamenSession) -> some View {
        // Strict branching to ensure no gesture interference in Edit Mode
        if editMode == .active {
            // Edit Mode: Pure Content.
            // We disable the row content so internal buttons (like Favorite) don't eat the selection tap.
            // The List cell handles the selection touch.
            JournalRow(
                session: session,
                references: referencingDrafts(for: session.id),
                onToggleFavorite: { toggleFavorite(session) },
                isHighlighted: selectedIDs.contains(session.id)
            )
            .disabled(true) 
            .tag(session.id)
        } else {
            // View Mode: Interactive
            JournalRow(
                session: session,
                references: referencingDrafts(for: session.id),
                onToggleFavorite: { toggleFavorite(session) },
                isHighlighted: selectedIDs.contains(session.id)
            )
            .sensoryFeedback(.impact(weight: .light), trigger: session.isFavorite)
            .contentShape(Rectangle()) // Ensure tap hits spacers
            .onTapGesture {
                print("DEBUG: Row tapped in View Mode: \(session.id)")
                presentViewer(for: session)
            }
            .contextMenu {
                Button { beginEditDetails(session) } label: {
                    Label("Edit Details", systemImage: "slider.horizontal.3")
                }
                Button { presentViewer(for: session) } label: {
                    Label("View & Edit", systemImage: "doc.text.magnifyingglass")
                }
            }
            .swipeActions(edge: .trailing) {
                Button { presentViewer(for: session) } label: {
                    Label("View & Edit", systemImage: "doc.text.magnifyingglass")
                }.tint(.indigo)
                
                Button {
                    entriesToAdd = [session]
                    showAddToStatementSheet = true
                } label: {
                    Label("Add to Statement", systemImage: "square.and.pencil")
                }.tint(useImmersive ? DSColor.goldLight : .accentColor)
                
                Button(role: .destructive) { delete([session]) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button { beginEditDetails(session) } label: {
                    Label("Edit Details", systemImage: "slider.horizontal.3")
                }.tint(useImmersive ? DSColor.goldLight : .blue)
                
                Button { presentViewer(for: session) } label: {
                    Label("View & Edit", systemImage: "doc.text.magnifyingglass")
                }.tint(.indigo)
            }
            .tag(session.id)
        }
    }

    // Toolbar items moved inline to Body for better layout control
    
    private var quickNoteFlow: some View {
        ExamenSessionContainer(
            draft: ExamenSessionDraft(type: quickNoteType),
            initialStage: .details
        )
    }

    private func launchQuickNote(for type: ExperienceType) {
        quickNoteType = type
        showQuickNoteFlow = true
    }

    private var editDetailsSheet: some View {
        NavigationStack {
            Form {
                Section("Experience Type") {
                    Picker("Type", selection: $tempExperience) {
                        Text("None").tag(ExperienceType?.none)
                        ForEach(ExperienceType.allCases, id: \.self) { kind in
                            Text(kind.displayName).tag(ExperienceType?.some(kind))
                        }
                    }
                }

                Section("Tags") {
                    HStack {
                        TextField("Add a tag", text: $newTagText)
                            .submitLabel(.done)
                            .onSubmit(addNewTag)
                        Button("Add", action: addNewTag)
                            .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    // Tag chips with remove buttons
                    if tempTags.isEmpty {
                        Text("No tags yet").foregroundStyle(.secondary)
                    } else {
                        TagCloud(tags: tempTags) { tag in
                            removeTag(tag)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .darkListStyle(enabled: useImmersive)
            .navigationTitle("Edit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showEditDetails = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { saveEditDetails() } }
            }
        }
    }



    private var editTextSheet: some View {
        NavigationStack {
            Form {
                Section("Edit Notes") {
                    TextEditor(text: $editStatementText)
                        .frame(minHeight: 200)
                        .scrollContentBackground(.hidden)
                        .background(useImmersive ? DSColor.backgroundSecondary : Color.clear)
                        .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                }
            }
            .darkListStyle(enabled: useImmersive)
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        editingTextEntry = nil
                        showEditTextSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEditedText()
                        showEditTextSheet = false
                    }
                }
            }
        }
    }

    private var bulkTagSheet: some View {
        NavigationStack {
            Form {
                Section("Tags to Apply") {
                    HStack {
                        TextField("Add a tag", text: $bulkNewTagText)
                            .submitLabel(.done)
                            .onSubmit(addBulkNewTag)
                        Button("Add", action: addBulkNewTag)
                            .disabled(bulkNewTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if bulkTags.isEmpty {
                        Text("No tags yet").foregroundStyle(.secondary)
                    } else {
                        TagCloud(tags: bulkTags) { tag in
                            removeBulkTag(tag)
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section(footer: Text("Tags will be added to all selected entries. Existing tags won’t be removed.")) {
                    EmptyView()
                }
            }
            .darkListStyle(enabled: useImmersive)
            .navigationTitle("Tag Selected")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showBulkTagSheet = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Apply") { applyBulkTags() } .disabled(bulkTags.isEmpty) }
            }
        }
    }

    private var dateRangeSheet: some View {
        NavigationStack {
            Form {
                Section("Start") {
                    DatePicker("From", selection: $customStart, displayedComponents: .date)
                }
                Section("End") {
                    DatePicker("To", selection: $customEnd, in: customStart...Date.distantFuture, displayedComponents: .date)
                }
            }
            .darkListStyle(enabled: useImmersive)
            .navigationTitle("Choose Dates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showDateRangeSheet = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        datePreset = .custom
                        showDateRangeSheet = false
                    }
                }
            }
        }
    }

    private var addToStatementSheetContent: some View {
        Group {
            if !entriesToAdd.isEmpty {
                AddToStatementSheet(selectedEntries: entriesToAdd)
                    .onDisappear {
                        withAnimation { clearSelectionAndExitEditMode() }
                        entriesToAdd = []
                    }
            }
        }
    }
    
    private func addNewTag() {
        let t = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if !tempTags.contains(t) { tempTags.append(t) }
        newTagText = ""
    }

    private func removeTag(_ tag: String) {
        tempTags.removeAll { $0 == tag }
    }

    // Favorite toggle handler
    private func toggleFavorite(_ entry: ExamenSession) {
        entry.isFavorite.toggle()
        if modelContext.hasChanges { try? modelContext.save() }
    }
    
    private func beginEditingEntry(_ entry: ExamenSession) {
        editingTextEntry = entry
        editStatementText = entry.personalStatement
        showEditTextSheet = true
    }
    
    private func saveEditedText() {
        guard let entry = editingTextEntry else { return }
        entry.personalStatement = editStatementText
        if modelContext.hasChanges { try? modelContext.save() }
        editingTextEntry = nil
    }


    
    private func saveEditDetails() {
        guard let entry = editingEntry else { return }
        entry.experienceType = tempExperience
        entry.tags = tempTags
        if modelContext.hasChanges {
            try? modelContext.save()
        }
        showEditDetails = false
    }
}

#if DEBUG
struct JournalView_Previews: PreviewProvider {
    static var previews: some View {
        JournalView()
            .modelContainer(for: [
                UserProfile.self,
                ExamenSession.self,
                StepResponse.self,
                ThemeCluster.self,
                ThemeEntryLink.self,
                ThemeBundle.self,
                PracticeTheme.self
            ])
    }
}
#endif

// Bulk tag helpers
extension JournalView {
    private func seedBulkTagsFromSelection() {
        // Optionally prefill with tags common to all selected entries
        let selected = sessions.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { bulkTags = []; return }
        let sets = selected.map { Set($0.tags) }
        if let first = sets.first {
            let common = sets.dropFirst().reduce(first) { $0.intersection($1) }
            bulkTags = Array(common).sorted()
        } else {
            bulkTags = []
        }
        bulkNewTagText = ""
    }

    private func addBulkNewTag() {
        let t = bulkNewTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if !bulkTags.contains(t) { bulkTags.append(t) }
        bulkNewTagText = ""
    }

    private func removeBulkTag(_ tag: String) {
        bulkTags.removeAll { $0 == tag }
    }

    private func applyBulkTags() {
        guard !bulkTags.isEmpty else { return }
        let selected = sessions.filter { selectedIDs.contains($0.id) }
        for entry in selected {
            var set = Set(entry.tags)
            for t in bulkTags { set.insert(t) }
            entry.tags = Array(set).sorted()
        }
        if modelContext.hasChanges { try? modelContext.save() }
        showBulkTagSheet = false
        withAnimation { clearSelectionAndExitEditMode() }
    }
    
    private func exportSelectedNotes() {
        let selected = sessions.filter { selectedIDs.contains($0.id) }
            .sorted { $0.date < $1.date }
        
        guard !selected.isEmpty else { return }
        
        var fullText = ""
        
        for entry in selected {
            fullText += computedViewerText(for: entry)
            fullText += "\n\n------------------------------------------------\n\n"
        }
        
        exportDocument = RTFDocument(text: fullText)
        showFileExporter = true
    }
    
    // Copy of helper for export access
    private func computedViewerText(for entry: ExamenSession) -> String {
        let header = "— Journal \(entry.date.formatted(journalDateStyle)) —\n"
        
        var contentParts: [String] = [header]
        
        // Add Metadata
        var metadata: [String] = []
        if let type = entry.experienceType { metadata.append("Experience: \(type.displayName)") }
        metadata.append(contentsOf: entry.detailMetadataLines())
        
        if !metadata.isEmpty {
            contentParts.append(metadata.joined(separator: "\n"))
        }
        
        // Add Q&A responses
        let responsesText = entry.responses
            .sorted(by: { $0.stepIndex < $1.stepIndex })
            .map { $0.answerText }
            .joined(separator: "\n\n")
        if !responsesText.isEmpty {
            contentParts.append(responsesText)
        }
        
        // Add Personal Statement / Notes
        if !entry.personalStatement.isEmpty {
            contentParts.append(entry.personalStatement)
        }
        
        return contentParts.joined(separator: "\n\n")
    }
}
import SwiftUI
import SwiftData

struct JournalEntryViewer: View {
    @Environment(AppSettings.self) private var settings
    let entry: ExamenSession
    var onClose: () -> Void
    var onEdit: () -> Void
    var onAddToStatement: () -> Void
    
    private let journalDateStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label(entry.date.formatted(journalDateStyle), systemImage: "calendar")
                        Spacer()
                        if let kind = entry.experienceType {
                            Text(kind.displayName)
                                .font(.footnote)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(useImmersive ? DSColor.backgroundSecondary : Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }
                    }
                    if !entry.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(entry.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(DSFont.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(useImmersive ? DSColor.divider : Color(uiColor: .separator), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section("Entry Text") {
                    ScrollView {
                        Text(computedViewerText(for: entry))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listRowSeparatorTint(useImmersive ? DSColor.divider : Color(uiColor: .separator))
            .darkListStyle(enabled: useImmersive)
            .navigationTitle("Journal Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit", action: onEdit)
                }
                
                ToolbarItem(placement: .bottomBar) {
                    Button(action: onAddToStatement) {
                        Label("Add to Statement", systemImage: "square.and.pencil")
                    }
                }
            }
        }
    }
    
    // Helper to build combined text for viewer
    private func computedViewerText(for entry: ExamenSession) -> String {
        let header = "— Journal \(entry.date.formatted(journalDateStyle)) —\n"
        
        var contentParts: [String] = []
        
        // Add Metadata
        var metadata: [String] = []
        metadata.append(contentsOf: entry.detailMetadataLines())
        
        if !metadata.isEmpty {
            contentParts.append(metadata.joined(separator: "\n"))
        }
        
        // Add Q&A responses
        let responsesText = entry.responses
            .sorted(by: { $0.stepIndex < $1.stepIndex })
            .map { $0.answerText }
            .joined(separator: "\n\n")
        if !responsesText.isEmpty {
            contentParts.append(responsesText)
        }
        
        // Add Personal Statement / Notes
        if !entry.personalStatement.isEmpty {
            if !contentParts.isEmpty {
                contentParts.append("\n— Notes —\n")
            }
            contentParts.append(entry.personalStatement)
        }
        
        return header + contentParts.joined(separator: "\n\n")
    }
}

// MARK: - RTF Document Helper
import UniformTypeIdentifiers

struct RTFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.rtf] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            if let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                text = attributed.string
            } else {
                text = ""
            }
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let attributedString = NSAttributedString(string: text)
        let data = try attributedString.data(from: NSRange(location: 0, length: attributedString.length),
                                             documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        return FileWrapper(regularFileWithContents: data)
    }
}

private struct ThemeAnalysisInput {
    let entryID: UUID
    let date: Date
    let experienceType: ExperienceType?
    let text: String
}

private struct ThemeTaxonomyInput {
    let id: String
    let title: String
    let description: String
}

private struct ThemeEntrySuggestion: Identifiable {
    var id: UUID { entryID }
    let entryID: UUID
    let evidenceSnippet: String
    let confidence: Double
}

private struct ThemeSuggestion: Identifiable {
    let id: UUID
    var label: String
    var normalizedLabel: String
    var source: ThemeLabelSource
    let scope: ThemeClusterScope
    let experienceType: ExperienceType?
    let score: Double
    let confidence: Double
    let keywordHighlights: [String]
    let entries: [ThemeEntrySuggestion]
    let taxonomyMatchScore: Double
    var persistedClusterID: UUID?
    var isAccepted: Bool
}

struct ThemeFinderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\ExamenSession.date, order: .reverse)])
    private var allSessions: [ExamenSession]

    @Query(sort: [SortDescriptor(\ThemeCluster.updatedAt, order: .reverse)])
    private var clusters: [ThemeCluster]

    @Query(sort: [SortDescriptor(\ThemeBundle.updatedAt, order: .reverse)])
    private var bundles: [ThemeBundle]

    @Query private var practiceThemes: [PracticeTheme]

    let defaultScope: ThemeClusterScope
    let onSendToStatement: ([ExamenSession]) -> Void

    @State private var selectedScope: ThemeClusterScope
    @State private var selectedWithinExperience: ExperienceType = .shadowing
    @State private var suggestions: [ThemeSuggestion] = []
    @State private var isAnalyzing = false
    @State private var analysisError: String?

    @State private var showRenameAlert = false
    @State private var renameTarget: ThemeSuggestion?
    @State private var renameText = ""

    private let analyzer = ThemeAnalysisService(
        similarityThreshold: 0.72,
        taxonomyMatchThreshold: 0.62,
        minClusterSize: 2,
        maxThemes: 8
    )

    init(
        defaultScope: ThemeClusterScope = .acrossExperiences,
        onSendToStatement: @escaping ([ExamenSession]) -> Void
    ) {
        self.defaultScope = defaultScope
        self.onSendToStatement = onSendToStatement
        _selectedScope = State(initialValue: defaultScope)
    }

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }

    private var journalEntries: [ExamenSession] {
        allSessions.filter { $0.sessionType != .statementDraft }
    }

    private var entriesByID: [UUID: ExamenSession] {
        Dictionary(uniqueKeysWithValues: journalEntries.map { ($0.id, $0) })
    }

    private var filteredEntryCount: Int {
        let input = journalEntries.filter {
            switch selectedScope {
            case .acrossExperiences:
                return true
            case .withinExperience:
                return $0.experienceType == selectedWithinExperience
            }
        }
        return input.count
    }

    private func clusterKey(normalizedLabel: String, scope: ThemeClusterScope, experienceType: ExperienceType?) -> String {
        "\(scope.rawValue)|\(experienceType?.rawValue ?? "all")|\(normalizedLabel)"
    }

    private var clusterByKey: [String: ThemeCluster] {
        var map: [String: ThemeCluster] = [:]
        for cluster in clusters {
            let key = clusterKey(
                normalizedLabel: cluster.normalizedLabel,
                scope: cluster.scope,
                experienceType: cluster.experienceType
            )
            if let existing = map[key] {
                map[key] = cluster.updatedAt > existing.updatedAt ? cluster : existing
            } else {
                map[key] = cluster
            }
        }
        return map
    }

    private var visibleSuggestions: [ThemeSuggestion] {
        suggestions.compactMap { suggestion in
            let key = clusterKey(
                normalizedLabel: suggestion.normalizedLabel,
                scope: suggestion.scope,
                experienceType: suggestion.experienceType
            )

            if let persisted = clusterByKey[key] {
                if persisted.isHidden {
                    return nil
                }
                var hydrated = suggestion
                hydrated.label = persisted.label
                hydrated.normalizedLabel = persisted.normalizedLabel
                hydrated.persistedClusterID = persisted.id
                hydrated.isAccepted = persisted.isAccepted
                return hydrated
            }
            return suggestion
        }
    }

    private var savedBundles: [ThemeBundle] {
        bundles.filter { bundle in
            !bundle.entryIDs.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if useImmersive {
                    SacredScreenBackground(settings: settings)
                }

                VStack(spacing: DSSpacing.sm) {
                    controlsCard
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.top, DSSpacing.sm)

                    if isAnalyzing {
                        VStack(spacing: DSSpacing.sm) {
                            ProgressView()
                            Text("Analyzing journal patterns...")
                                .font(DSFont.subtext)
                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                        }
                        .frame(maxHeight: .infinity)
                    } else if let analysisError {
                        DarkEmptyState(
                            title: "Theme Analysis Failed",
                            systemImage: "exclamationmark.triangle",
                            description: analysisError,
                            actionTitle: "Try Again",
                            action: analyzeThemes,
                            fillBackground: false
                        )
                    } else if filteredEntryCount < 2 {
                        DarkEmptyState(
                            title: "Need More Notes",
                            systemImage: "text.badge.plus",
                            description: "At least two journal notes are required for pattern detection in the selected scope.",
                            fillBackground: false
                        )
                    } else if visibleSuggestions.isEmpty && savedBundles.isEmpty {
                        DarkEmptyState(
                            title: "No Themes Yet",
                            systemImage: "sparkles",
                            description: "Try again after adding more reflections or widening your scope.",
                            actionTitle: "Reanalyze",
                            action: analyzeThemes,
                            fillBackground: false
                        )
                    } else {
                        List {
                            if !visibleSuggestions.isEmpty {
                                Section(
                                    header: Group {
                                        if useImmersive {
                                            DarkSectionHeader(title: "Suggested Themes")
                                        } else {
                                            Text("Suggested Themes")
                                        }
                                    }
                                ) {
                                    ForEach(visibleSuggestions) { suggestion in
                                        ThemeSuggestionCard(
                                            suggestion: suggestion,
                                            entriesByID: entriesByID,
                                            useImmersive: useImmersive,
                                            onAccept: { acceptSuggestion($0) },
                                            onHide: { hideSuggestion($0) },
                                            onRename: { beginRename($0) },
                                            onCreateBundle: { createBundle(from: $0) },
                                            onSendToStatement: { sendSuggestionToStatement($0) }
                                        )
                                        .listRowInsets(EdgeInsets())
                                        .listRowBackground(useImmersive ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                                        .padding(.vertical, DSSpacing.xs)
                                    }
                                }
                            }

                            if !savedBundles.isEmpty {
                                Section(
                                    header: Group {
                                        if useImmersive {
                                            DarkSectionHeader(title: "Saved Bundles")
                                        } else {
                                            Text("Saved Bundles")
                                        }
                                    }
                                ) {
                                    ForEach(savedBundles) { bundle in
                                        ThemeBundleRow(
                                            bundle: bundle,
                                            useImmersive: useImmersive,
                                            onSendToStatement: { sendBundleToStatement(bundle) },
                                            onDelete: { deleteBundle(bundle) }
                                        )
                                        .listRowInsets(EdgeInsets())
                                        .listRowBackground(useImmersive ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                                        .padding(.vertical, DSSpacing.xs)
                                    }
                                }
                            }
                        }
                        .listRowSeparatorTint(useImmersive ? .clear : Color(uiColor: .separator))
                        .darkListStyle(enabled: useImmersive, baseBackground: nil)
                    }
                }
            }
            .navigationTitle("Theme Finder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Refresh", action: analyzeThemes)
                        .disabled(isAnalyzing || filteredEntryCount < 2)
                }
            }
            .task {
                analyzeThemes()
            }
            .onChange(of: selectedScope) { _, _ in analyzeThemes() }
            .onChange(of: selectedWithinExperience) { _, _ in
                if selectedScope == .withinExperience {
                    analyzeThemes()
                }
            }
            .onChange(of: journalEntries.count) { _, _ in analyzeThemes() }
            .alert("Rename Theme", isPresented: $showRenameAlert) {
                TextField("Theme Name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    renameTarget = nil
                }
                Button("Save") {
                    renameAndAcceptSuggestion()
                }
                .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Use a concise, evidence-based label for this bundle.")
            }
        }
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Picker("Scope", selection: $selectedScope) {
                ForEach(ThemeClusterScope.allCases) { scope in
                    Text(scope.displayName).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            if selectedScope == .withinExperience {
                Picker("Experience", selection: $selectedWithinExperience) {
                    ForEach(ExperienceType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }

            HStack(spacing: DSSpacing.sm) {
                Label("\(filteredEntryCount) notes in scope", systemImage: "doc.text")
                    .font(DSFont.caption)
                    .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                Spacer()
                Button("Analyze", action: analyzeThemes)
                    .disabled(isAnalyzing || filteredEntryCount < 2)
                    .font(DSFont.caption.weight(.semibold))
                    .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(useImmersive ? DSColor.goldLight : Color(uiColor: .separator), lineWidth: 1)
                    )
            }
        }
        .padding(DSSpacing.md)
        .if(useImmersive) { view in
            view.sacredCardStyle(highlighted: false)
        }
    }

    private func analyzeThemes() {
        let sourceEntries: [ExamenSession]
        switch selectedScope {
        case .acrossExperiences:
            sourceEntries = journalEntries
        case .withinExperience:
            sourceEntries = journalEntries.filter { $0.experienceType == selectedWithinExperience }
        }

        guard sourceEntries.count >= 2 else {
            suggestions = []
            analysisError = nil
            return
        }

        let inputs = sourceEntries.map {
            ThemeAnalysisInput(
                entryID: $0.id,
                date: $0.date,
                experienceType: $0.experienceType,
                text: $0.themeAnalysisText()
            )
        }

        let taxonomy = practiceThemes.map {
            ThemeTaxonomyInput(id: $0.id, title: $0.title, description: $0.themeDescription)
        }

        isAnalyzing = true
        analysisError = nil

        Task(priority: .userInitiated) {
            let nextSuggestions = analyzer.analyze(
                entries: inputs,
                taxonomy: taxonomy,
                scope: selectedScope,
                selectedExperience: selectedScope == .withinExperience ? selectedWithinExperience : nil
            )

            await MainActor.run {
                suggestions = nextSuggestions
                isAnalyzing = false
            }
        }
    }

    private func beginRename(_ suggestion: ThemeSuggestion) {
        renameTarget = suggestion
        renameText = suggestion.label
        showRenameAlert = true
    }

    private func renameAndAcceptSuggestion() {
        guard let target = renameTarget else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = upsertCluster(from: target, labelOverride: trimmed, accepted: true, hidden: false)
        renameTarget = nil
        analyzeThemes()
    }

    private func acceptSuggestion(_ suggestion: ThemeSuggestion) {
        _ = upsertCluster(from: suggestion, labelOverride: nil, accepted: true, hidden: false)
        analyzeThemes()
    }

    private func hideSuggestion(_ suggestion: ThemeSuggestion) {
        _ = upsertCluster(from: suggestion, labelOverride: nil, accepted: false, hidden: true)
        analyzeThemes()
    }

    private func existingCluster(for suggestion: ThemeSuggestion) -> ThemeCluster? {
        if let persistedClusterID = suggestion.persistedClusterID {
            return clusters.first { $0.id == persistedClusterID }
        }

        return clusters.first {
            $0.normalizedLabel == suggestion.normalizedLabel
                && $0.scope == suggestion.scope
                && $0.experienceType == suggestion.experienceType
        }
    }

    @discardableResult
    private func upsertCluster(
        from suggestion: ThemeSuggestion,
        labelOverride: String?,
        accepted: Bool,
        hidden: Bool
    ) -> ThemeCluster? {
        let trimmedOverride = labelOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextLabel = (trimmedOverride?.isEmpty == false) ? (trimmedOverride ?? suggestion.label) : suggestion.label

        let cluster = existingCluster(for: suggestion) ?? ThemeCluster(
            label: nextLabel,
            normalizedLabel: ThemeCluster.normalize(nextLabel),
            scope: suggestion.scope,
            labelSource: suggestion.source,
            experienceType: suggestion.experienceType,
            score: suggestion.score,
            confidence: suggestion.confidence,
            isAccepted: accepted,
            isHidden: hidden
        )

        if existingCluster(for: suggestion) == nil {
            modelContext.insert(cluster)
        }

        cluster.label = nextLabel
        cluster.normalizedLabel = ThemeCluster.normalize(nextLabel)
        cluster.scope = suggestion.scope
        cluster.labelSource = suggestion.source
        cluster.experienceType = suggestion.experienceType
        cluster.score = suggestion.score
        cluster.confidence = suggestion.confidence
        cluster.isAccepted = accepted
        cluster.isHidden = hidden
        cluster.updatedAt = .now

        for link in cluster.links {
            modelContext.delete(link)
        }

        if accepted && !hidden {
            for entry in suggestion.entries {
                let link = ThemeEntryLink(
                    entryID: entry.entryID,
                    evidenceSnippet: entry.evidenceSnippet,
                    confidence: entry.confidence,
                    cluster: cluster
                )
                modelContext.insert(link)
            }
        }

        do {
            try modelContext.save()
            return cluster
        } catch {
            print("Failed to save theme cluster: \(error)")
            return nil
        }
    }

    private func resolvedEntries(for suggestion: ThemeSuggestion) -> [ExamenSession] {
        suggestion.entries
            .compactMap { entriesByID[$0.entryID] }
            .sorted(by: { $0.date < $1.date })
    }

    private func sendSuggestionToStatement(_ suggestion: ThemeSuggestion) {
        let selected = resolvedEntries(for: suggestion)
        guard !selected.isEmpty else { return }
        onSendToStatement(selected)
    }

    private func createBundle(from suggestion: ThemeSuggestion) {
        let selected = resolvedEntries(for: suggestion)
        guard !selected.isEmpty else { return }

        let cluster = upsertCluster(from: suggestion, labelOverride: nil, accepted: true, hidden: false)
        let existing = bundles.first {
            $0.title == "\(suggestion.label) Bundle"
                && $0.themeLabel == suggestion.label
                && $0.sourceClusterID == cluster?.id
        }

        if let existing {
            existing.entryIDs = selected.map(\.id)
            existing.updatedAt = .now
        } else {
            let bundle = ThemeBundle(
                title: "\(suggestion.label) Bundle",
                themeLabel: suggestion.label,
                sourceClusterID: cluster?.id,
                entryIDs: selected.map(\.id)
            )
            modelContext.insert(bundle)
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save theme bundle: \(error)")
        }
    }

    private func sendBundleToStatement(_ bundle: ThemeBundle) {
        let selected = bundle.entryIDs
            .compactMap { entriesByID[$0] }
            .sorted(by: { $0.date < $1.date })

        guard !selected.isEmpty else { return }
        onSendToStatement(selected)
    }

    private func deleteBundle(_ bundle: ThemeBundle) {
        modelContext.delete(bundle)
        try? modelContext.save()
    }
}

private struct ThemeSuggestionCard: View {
    let suggestion: ThemeSuggestion
    let entriesByID: [UUID: ExamenSession]
    let useImmersive: Bool
    let onAccept: (ThemeSuggestion) -> Void
    let onHide: (ThemeSuggestion) -> Void
    let onRename: (ThemeSuggestion) -> Void
    let onCreateBundle: (ThemeSuggestion) -> Void
    let onSendToStatement: (ThemeSuggestion) -> Void

    private let dateStyle = Date.FormatStyle(date: .abbreviated, time: .omitted)

    private var resolvedEntries: [ExamenSession] {
        suggestion.entries
            .compactMap { entriesByID[$0.entryID] }
            .sorted(by: { $0.date > $1.date })
    }

    private var experienceCoverageText: String {
        let set = Set(resolvedEntries.compactMap(\.experienceType?.displayName))
        return set.isEmpty ? "Personal" : "\(set.count) experience type\(set.count == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.label)
                        .font(DSFont.heading2)
                        .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                    Text(suggestion.source == .taxonomy ? "Taxonomy Matched" : "Emergent Pattern")
                        .font(DSFont.caption)
                        .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                }
                Spacer()
                if suggestion.isAccepted {
                    Label("Accepted", systemImage: "checkmark.seal.fill")
                        .font(DSFont.caption)
                        .foregroundStyle(useImmersive ? DSColor.goldLight : .green)
                }
            }

            HStack(spacing: DSSpacing.sm) {
                ThemeMetricPill(title: "Strength", value: Int((suggestion.score * 100).rounded()), suffix: "%", useImmersive: useImmersive)
                ThemeMetricPill(title: "Confidence", value: Int((suggestion.confidence * 100).rounded()), suffix: "%", useImmersive: useImmersive)
                ThemeMetricPill(title: "Notes", value: suggestion.entries.count, suffix: "", useImmersive: useImmersive)
            }

            HStack(spacing: DSSpacing.sm) {
                Text(experienceCoverageText)
                    .font(DSFont.caption)
                    .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                if !suggestion.keywordHighlights.isEmpty {
                    Text("• \(suggestion.keywordHighlights.joined(separator: ", "))")
                        .font(DSFont.caption)
                        .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(suggestion.entries.prefix(3)) { match in
                    if let entry = entriesByID[match.entryID] {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(entry.date.formatted(dateStyle))
                                    .font(DSFont.caption)
                                    .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                if let type = entry.experienceType {
                                    Text(type.displayName)
                                        .font(DSFont.caption)
                                        .foregroundStyle(useImmersive ? DSColor.textTertiary : .secondary)
                                }
                            }
                            Text(match.evidenceSnippet)
                                .font(DSFont.subtext)
                                .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                                .lineLimit(2)
                        }
                    }
                }
            }

            HStack(spacing: DSSpacing.sm) {
                Button(suggestion.isAccepted ? "Refresh" : "Accept") {
                    onAccept(suggestion)
                }
                .buttonStyle(.borderedProminent)
                .tint(useImmersive ? DSColor.goldLight : .accentColor)

                Button("Rename") {
                    onRename(suggestion)
                }
                .buttonStyle(.bordered)

                Button("Hide", role: .destructive) {
                    onHide(suggestion)
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: DSSpacing.sm) {
                Button("Create Bundle") {
                    onCreateBundle(suggestion)
                }
                .buttonStyle(.bordered)

                Button("Send to PSBuilder") {
                    onSendToStatement(suggestion)
                }
                .buttonStyle(.borderedProminent)
                .tint(useImmersive ? DSColor.goldLight : .accentColor)
            }
        }
        .padding(DSSpacing.md)
        .if(useImmersive) { view in
            view.sacredCardStyle(highlighted: suggestion.isAccepted)
        }
    }
}

private struct ThemeBundleRow: View {
    let bundle: ThemeBundle
    let useImmersive: Bool
    let onSendToStatement: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bundle.title)
                        .font(DSFont.heading2)
                        .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                    Text("\(bundle.entryIDs.count) linked notes")
                        .font(DSFont.caption)
                        .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                }
                Spacer()
                Text(bundle.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(DSFont.caption)
                    .foregroundStyle(useImmersive ? DSColor.textTertiary : .secondary)
            }

            HStack(spacing: DSSpacing.sm) {
                Button("Send to PSBuilder", action: onSendToStatement)
                    .buttonStyle(.borderedProminent)
                    .tint(useImmersive ? DSColor.goldLight : .accentColor)
                Button("Delete", role: .destructive, action: onDelete)
                    .buttonStyle(.bordered)
            }
        }
        .padding(DSSpacing.md)
        .if(useImmersive) { view in
            view.sacredCardStyle(highlighted: false)
        }
    }
}

private struct ThemeMetricPill: View {
    let title: String
    let value: Int
    let suffix: String
    let useImmersive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(DSFont.caption)
                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
            Text("\(value)\(suffix)")
                .font(DSFont.caption.weight(.semibold))
                .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(useImmersive ? DSColor.divider : Color(uiColor: .separator), lineWidth: 1)
        )
    }
}

private struct ThemeAnalysisService {
    let similarityThreshold: Double
    let taxonomyMatchThreshold: Double
    let minClusterSize: Int
    let maxThemes: Int

    func analyze(
        entries: [ThemeAnalysisInput],
        taxonomy: [ThemeTaxonomyInput],
        scope: ThemeClusterScope,
        selectedExperience: ExperienceType?
    ) -> [ThemeSuggestion] {
        let embedding = NLEmbedding.sentenceEmbedding(for: .english)
        let docs = entries.compactMap { buildDocument(input: $0, embedding: embedding) }
        guard docs.count >= minClusterSize else { return [] }

        let taxonomyCandidates = taxonomy.map { makeTaxonomyCandidate(from: $0, embedding: embedding) }
        let components = connectedComponents(for: docs)

        let suggestions = components.compactMap { component -> ThemeSuggestion? in
            let componentDocs = component.map { docs[$0] }
            guard componentDocs.count >= minClusterSize else { return nil }

            let sharedTokens = commonTokens(for: componentDocs)
            let keywords = Array(sharedTokens.prefix(3))
            let centroid = centroidVector(for: componentDocs)

            let taxonomyMatch = bestTaxonomyMatch(
                for: componentDocs,
                centroid: centroid,
                sharedTokens: Set(sharedTokens),
                taxonomy: taxonomyCandidates
            )

            let label: String
            let source: ThemeLabelSource
            if taxonomyMatch.score >= taxonomyMatchThreshold {
                label = taxonomyMatch.title
                source = .taxonomy
            } else {
                label = emergentLabel(from: sharedTokens, fallbackText: componentDocs.first?.text ?? "Theme")
                source = .emergent
            }

            let score = clusterScore(componentDocs: componentDocs, scope: scope, sharedTokens: sharedTokens)
            let confidence = clusterConfidence(componentDocs: componentDocs, sharedTokens: sharedTokens)

            let entrySuggestions = componentDocs.map { doc in
                ThemeEntrySuggestion(
                    entryID: doc.entryID,
                    evidenceSnippet: evidenceSnippet(from: doc.text, preferredTokens: keywords),
                    confidence: entryConfidence(for: doc, in: componentDocs, centroid: centroid)
                )
            }

            return ThemeSuggestion(
                id: UUID(),
                label: label,
                normalizedLabel: ThemeCluster.normalize(label),
                source: source,
                scope: scope,
                experienceType: selectedExperience,
                score: score,
                confidence: confidence,
                keywordHighlights: keywords,
                entries: entrySuggestions.sorted(by: { $0.confidence > $1.confidence }),
                taxonomyMatchScore: taxonomyMatch.score,
                persistedClusterID: nil,
                isAccepted: false
            )
        }

        return suggestions
            .sorted {
                if $0.score == $1.score {
                    return $0.confidence > $1.confidence
                }
                return $0.score > $1.score
            }
            .prefix(maxThemes)
            .map { $0 }
    }

    private struct Document {
        let entryID: UUID
        let date: Date
        let experienceType: ExperienceType?
        let text: String
        let tokens: [String]
        let tokenSet: Set<String>
        let vector: [Double]?
    }

    private struct TaxonomyCandidate {
        let title: String
        let tokenSet: Set<String>
        let vector: [Double]?
    }

    private func buildDocument(input: ThemeAnalysisInput, embedding: NLEmbedding?) -> Document? {
        let text = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let tokens = extractTokens(from: text)
        guard !tokens.isEmpty else { return nil }
        let vector = embedding?.vector(for: text)
        return Document(
            entryID: input.entryID,
            date: input.date,
            experienceType: input.experienceType,
            text: text,
            tokens: tokens,
            tokenSet: Set(tokens),
            vector: vector
        )
    }

    private func makeTaxonomyCandidate(from input: ThemeTaxonomyInput, embedding: NLEmbedding?) -> TaxonomyCandidate {
        let composite = "\(input.title). \(input.description)"
        return TaxonomyCandidate(
            title: input.title,
            tokenSet: Set(extractTokens(from: composite)),
            vector: embedding?.vector(for: composite)
        )
    }

    private func connectedComponents(for docs: [Document]) -> [[Int]] {
        guard docs.count >= 2 else { return [] }
        var adjacency = Array(repeating: [Int](), count: docs.count)

        for i in docs.indices {
            for j in docs.indices where j > i {
                let similarity = similarityBetween(docs[i], docs[j])
                if similarity >= similarityThreshold {
                    adjacency[i].append(j)
                    adjacency[j].append(i)
                }
            }
        }

        var visited = Set<Int>()
        var result: [[Int]] = []

        for start in docs.indices where !visited.contains(start) {
            var stack = [start]
            var component: [Int] = []
            visited.insert(start)

            while let node = stack.popLast() {
                component.append(node)
                for neighbor in adjacency[node] where !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    stack.append(neighbor)
                }
            }

            if component.count >= minClusterSize {
                result.append(component)
            }
        }

        return result
    }

    private func similarityBetween(_ lhs: Document, _ rhs: Document) -> Double {
        if let left = lhs.vector, let right = rhs.vector {
            return cosine(left, right)
        }
        return jaccard(lhs.tokenSet, rhs.tokenSet)
    }

    private func commonTokens(for docs: [Document]) -> [String] {
        guard !docs.isEmpty else { return [] }
        let minimumFrequency = max(2, Int(ceil(Double(docs.count) * 0.4)))
        var counts: [String: Int] = [:]

        for doc in docs {
            for token in doc.tokenSet {
                counts[token, default: 0] += 1
            }
        }

        let ranked = counts
            .filter { $0.value >= minimumFrequency }
            .sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }
                return $0.value > $1.value
            }
            .map(\.key)

        return ranked
    }

    private func bestTaxonomyMatch(
        for docs: [Document],
        centroid: [Double]?,
        sharedTokens: Set<String>,
        taxonomy: [TaxonomyCandidate]
    ) -> (title: String, score: Double) {
        var winner = (title: "", score: 0.0)

        for candidate in taxonomy {
            let lexical = jaccard(sharedTokens, candidate.tokenSet)
            let semantic: Double
            if let centroid, let vector = candidate.vector {
                semantic = cosine(centroid, vector)
            } else {
                semantic = 0
            }

            let combined = (semantic * 0.65) + (lexical * 0.35)
            if combined > winner.score {
                winner = (candidate.title, combined)
            }
        }

        return winner
    }

    private func emergentLabel(from tokens: [String], fallbackText: String) -> String {
        if tokens.count >= 2 {
            return "\(tokens[0].capitalized) & \(tokens[1].capitalized)"
        }
        if let first = tokens.first {
            return first.capitalized
        }

        let words = fallbackText
            .split(separator: " ")
            .prefix(2)
            .map(String.init)
        if words.isEmpty {
            return "Emergent Theme"
        }
        return words.joined(separator: " ").capitalized
    }

    private func centroidVector(for docs: [Document]) -> [Double]? {
        let vectors = docs.compactMap(\.vector)
        guard let first = vectors.first else { return nil }
        var sum = Array(repeating: 0.0, count: first.count)
        for vector in vectors {
            guard vector.count == first.count else { continue }
            for i in vector.indices {
                sum[i] += vector[i]
            }
        }
        return sum.map { $0 / Double(vectors.count) }
    }

    private func clusterScore(componentDocs: [Document], scope: ThemeClusterScope, sharedTokens: [String]) -> Double {
        let cohesion = averagePairwiseSimilarity(componentDocs)
        let lexicalStrength = min(1.0, Double(sharedTokens.count) / 5.0)

        let spread: Double
        if scope == .withinExperience {
            spread = 1.0
        } else {
            let uniqueExperienceCount = Set(componentDocs.compactMap(\.experienceType)).count
            spread = min(1.0, Double(uniqueExperienceCount) / Double(max(1, ExperienceType.allCases.count)))
        }

        let latestDate = componentDocs.map(\.date).max() ?? .now
        let daysAgo = max(0, Calendar.current.dateComponents([.day], from: latestDate, to: .now).day ?? 0)
        let recency = max(0, 1 - (Double(daysAgo) / 180.0))

        let total = (cohesion * 0.40) + (lexicalStrength * 0.25) + (spread * 0.20) + (recency * 0.15)
        return min(max(total, 0), 1)
    }

    private func clusterConfidence(componentDocs: [Document], sharedTokens: [String]) -> Double {
        let cohesion = averagePairwiseSimilarity(componentDocs)
        let lexical = min(1.0, Double(sharedTokens.count) / 4.0)
        let confidence = (cohesion * 0.65) + (lexical * 0.35)
        return min(max(confidence, 0), 1)
    }

    private func entryConfidence(for doc: Document, in componentDocs: [Document], centroid: [Double]?) -> Double {
        if let centroid, let vector = doc.vector {
            return min(max(cosine(vector, centroid), 0), 1)
        }

        let peers = componentDocs.filter { $0.entryID != doc.entryID }
        guard !peers.isEmpty else { return 0.5 }
        let mean = peers
            .map { similarityBetween(doc, $0) }
            .reduce(0, +) / Double(peers.count)
        return min(max(mean, 0), 1)
    }

    private func evidenceSnippet(from text: String, preferredTokens: [String]) -> String {
        let tokenSet = Set(preferredTokens.map { $0.lowercased() })
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text

        var fallback = ""
        var winner = ""

        sentenceTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { return true }
            if fallback.isEmpty {
                fallback = String(sentence)
            }
            let lowered = sentence.lowercased()
            if tokenSet.contains(where: { lowered.contains($0) }) {
                winner = String(sentence)
                return false
            }
            return true
        }

        let chosen = winner.isEmpty ? fallback : winner
        if chosen.count <= 180 {
            return chosen
        }
        let endIndex = chosen.index(chosen.startIndex, offsetBy: 180)
        return "\(chosen[..<endIndex])…"
    }

    private func extractTokens(from text: String) -> [String] {
        let lowered = text.lowercased()
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = lowered

        let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
        tagger.string = lowered

        var tokens: [String] = []
        let range = lowered.startIndex..<lowered.endIndex
        tokenizer.enumerateTokens(in: range) { tokenRange, _ in
            let rawToken = String(lowered[tokenRange]).trimmingCharacters(in: .punctuationCharacters)
            guard rawToken.count >= 3 else { return true }

            let lexicalClass = tagger.tag(
                at: tokenRange.lowerBound,
                unit: .word,
                scheme: .lexicalClass
            ).0

            guard lexicalClass == .noun || lexicalClass == .verb || lexicalClass == .adjective else {
                return true
            }

            let lemma = tagger.tag(
                at: tokenRange.lowerBound,
                unit: .word,
                scheme: .lemma
            ).0?.rawValue ?? rawToken

            guard !ThemeAnalysisService.stopWords.contains(lemma) else {
                return true
            }

            tokens.append(lemma)
            return true
        }

        return tokens
    }

    private func averagePairwiseSimilarity(_ docs: [Document]) -> Double {
        guard docs.count >= 2 else { return 0.5 }
        var total = 0.0
        var pairCount = 0

        for i in docs.indices {
            for j in docs.indices where j > i {
                total += similarityBetween(docs[i], docs[j])
                pairCount += 1
            }
        }

        guard pairCount > 0 else { return 0.5 }
        return total / Double(pairCount)
    }

    private func cosine(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }

        var dot = 0.0
        var lhsNorm = 0.0
        var rhsNorm = 0.0

        for i in lhs.indices {
            dot += lhs[i] * rhs[i]
            lhsNorm += lhs[i] * lhs[i]
            rhsNorm += rhs[i] * rhs[i]
        }

        guard lhsNorm > 0, rhsNorm > 0 else { return 0 }
        return dot / (sqrt(lhsNorm) * sqrt(rhsNorm))
    }

    private func jaccard(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty || !rhs.isEmpty else { return 0 }
        let intersection = lhs.intersection(rhs).count
        let union = lhs.union(rhs).count
        guard union > 0 else { return 0 }
        return Double(intersection) / Double(union)
    }

    private static let stopWords: Set<String> = [
        "about", "after", "again", "against", "almost", "also", "always", "among", "because",
        "before", "being", "between", "both", "could", "during", "every", "from", "have",
        "having", "into", "just", "like", "made", "more", "much", "must", "need", "only",
        "other", "over", "really", "same", "should", "some", "such", "than", "that", "their",
        "them", "then", "there", "these", "they", "this", "those", "through", "today", "very",
        "what", "when", "where", "which", "while", "with", "would", "your", "ours", "ourselves",
        "myself", "itself", "herself", "himself", "themselves", "patient", "patients"
    ]
}
