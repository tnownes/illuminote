import SwiftUI
import SwiftData
import NaturalLanguage

enum JournalDetailsEditorSource: String, Hashable {
    case postExamenHandoff
    case journalEdit

    var navigationTitle: String {
        switch self {
        case .postExamenHandoff: return "Add Details"
        case .journalEdit: return "Edit Details"
        }
    }

    var headerTitle: String {
        switch self {
        case .postExamenHandoff: return "Add details to this reflection"
        case .journalEdit: return "Edit Details"
        }
    }

    var headerSubtitle: String {
        switch self {
        case .postExamenHandoff:
            return "You can keep this simple. These details help Journal stay searchable later."
        case .journalEdit:
            return "Update the context that helps this reflection stay findable."
        }
    }

    var secondaryActionTitle: String {
        switch self {
        case .postExamenHandoff: return "Skip"
        case .journalEdit: return "Cancel"
        }
    }
}

struct JournalDetailsDraft: Equatable {
    var experience: ExperienceType?
    var primaryValue = ""
    var secondaryValue = ""
    var focusValue = ""
    var location = ""
    var notes = ""
    var hoursString = ""
    var tags: [String] = []
    var newTagText = ""

    init() {
        self.experience = nil
    }

    init(entry: ExamenSession) {
        let type = entry.experienceType?.canonical
        let config = (type ?? .other).detailFieldConfig

        self.experience = type
        self.primaryValue = config.showsPrimary ? (entry.resolvedPrimaryDetail ?? "") : ""
        self.secondaryValue = config.showsFacility ? (entry.resolvedSecondaryDetail ?? "") : ""
        self.focusValue = config.showsFocus ? (entry.resolvedFocusDetail ?? "") : ""
        self.location = config.showsLocation ? (entry.location ?? "") : ""
        self.notes = entry.notes ?? ""
        self.hoursString = config.showsHours && entry.hours > 0 ? String(format: "%g", entry.hours) : ""
        self.tags = entry.tags
        self.newTagText = ""
    }

    var canonicalExperience: ExperienceType? {
        experience?.canonical
    }

    var detailConfig: ExperienceDetailFieldConfig {
        (canonicalExperience ?? .other).detailFieldConfig
    }

    mutating func changeExperience(to newExperience: ExperienceType?) {
        let previousType = canonicalExperience
        let newType = newExperience?.canonical
        let newConfig = (newType ?? .other).detailFieldConfig

        experience = newType

        if !newConfig.showsPrimary {
            primaryValue = ""
        }

        if !newConfig.showsFacility {
            secondaryValue = ""
        }

        if !newConfig.showsLocation {
            location = ""
        }

        if !newConfig.showsHours {
            hoursString = ""
        }

        if !newConfig.showsFocus || focusFamily(for: previousType) != focusFamily(for: newType) {
            focusValue = ""
        }
    }

    mutating func addTag() {
        let tag = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        if !tags.contains(tag) {
            tags.append(tag)
        }
        newTagText = ""
    }

    mutating func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    func apply(to entry: ExamenSession) {
        entry.experienceType = canonicalExperience
        entry.notes = Self.normalized(notes)
        entry.tags = tags

        guard let type = canonicalExperience else {
            clearReflectionDetails(on: entry)
            return
        }

        let config = type.detailFieldConfig
        let primary = Self.normalized(primaryValue)
        let secondary = Self.normalized(secondaryValue)
        let focus = Self.normalized(focusValue)
        let place = Self.normalized(location)

        entry.location = config.showsLocation ? place : nil
        entry.organizationName = config.showsFacility ? secondary : nil
        entry.facility = config.showsFacility ? secondary : nil
        entry.focusArea = config.showsFocus ? focus : nil
        entry.specialty = config.showsFocus ? focus : nil
        entry.hours = config.showsHours ? (Double(hoursString) ?? 0) : 0

        switch type {
        case .shadowing, .clinical, .research:
            entry.mentorOrSupervisor = config.showsPrimary ? primary : nil
            entry.physician = config.showsPrimary ? primary : nil
            entry.roleTitle = nil
        case .leadership, .service, .work:
            entry.roleTitle = config.showsPrimary ? primary : nil
            entry.mentorOrSupervisor = nil
            entry.physician = nil
        case .other, .volunteer, .discernment:
            entry.roleTitle = nil
            entry.mentorOrSupervisor = nil
            entry.physician = nil
        }
    }

    private func focusFamily(for type: ExperienceType?) -> JournalDetailsFocusFamily? {
        switch type {
        case .shadowing, .clinical, .research:
            return .professional
        case .discernment:
            return .discernment
        case .leadership, .work, .service, .volunteer, .other, .none:
            return nil
        }
    }

    private func clearReflectionDetails(on entry: ExamenSession) {
        entry.hours = 0
        entry.physician = nil
        entry.facility = nil
        entry.specialty = nil
        entry.location = nil
        entry.mentorOrSupervisor = nil
        entry.roleTitle = nil
        entry.organizationName = nil
        entry.focusArea = nil
    }

    private static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum JournalDetailsFocusFamily {
    case professional
    case discernment
}

private enum JournalDetailsField: Hashable {
    case hours
    case primary
    case secondary
    case location
    case focus
    case notes
    case tag
}

struct JournalView: View {
    private let journalDateStyle = Date.FormatStyle(date: .abbreviated, time: .shortened)
    private static let monthHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    private static let customRangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings // reserved if you later style rows by theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

    private var isCoreMode: Bool {
        AppSettings.featurePolicy.mode == .core
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

    private enum JournalSheetRoute: Identifiable {
        case editDetails(UUID, JournalDetailsEditorSource)
        case viewEntry(UUID)
        case editText(UUID)
        case bulkTagging
        case dateRange
        case addToStatement([UUID])

        var id: String {
            switch self {
            case .editDetails(let entryID, let source):
                return "editDetails-\(source.rawValue)-\(entryID.uuidString)"
            case .viewEntry(let entryID):
                return "viewEntry-\(entryID.uuidString)"
            case .editText(let entryID):
                return "editText-\(entryID.uuidString)"
            case .bulkTagging:
                return "bulkTagging"
            case .dateRange:
                return "dateRange"
            case .addToStatement(let entryIDs):
                return "addToStatement-" + entryIDs.map(\.uuidString).joined(separator: "-")
            }
        }
    }

    private enum JournalCoverRoute: Identifiable {
        case quickNote(ExperienceType)

        var id: String {
            switch self {
            case .quickNote(let type):
                return "quickNote-\(type.rawValue)"
            }
        }
    }
    @State private var datePreset: DatePreset = .all
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var customEnd: Date = .now
    @State private var activeSheet: JournalSheetRoute?
    @State private var activeCover: JournalCoverRoute?

    @State private var detailsDraft = JournalDetailsDraft()

    @State private var bulkTags: [String] = []
    @State private var bulkNewTagText: String = ""
    
    // Quick Note
    @State private var showQuickNoteTypePicker = false

    // File Export State
    @State private var showFileExporter = false
    @State private var exportDocument: RTFDocument?
    @State private var showFilterControls = false
    @State private var persistenceAlert: PersistenceAlertContext?

    // Cached presentation data so large lists are only regrouped when inputs change.
    @State private var availableTags: [String] = []
    @State private var filteredSessionsCache: [ExamenSession] = []
    @State private var groupedSessionsByMonth: [(month: Date, items: [ExamenSession])] = []
    @State private var favoriteSessionCountCache = 0

    private var allTags: [String] {
        availableTags
    }

    private var filtersAreClear: Bool {
        query.isEmpty && selectedExperience == nil && selectedTag == nil && datePreset == .all && !onlyFavorites
    }

    private var filteredSessions: [ExamenSession] {
        filteredSessionsCache
    }

    private func refilter() {
        let filtered = sessions.filter { entry in
            passesExperienceAndTagFilters(entry: entry, experience: selectedExperience, tag: selectedTag)
            && passesSearchFilter(entry: entry, query: query)
            && isWithinDateRange(entry: entry, preset: datePreset)
            && (!onlyFavorites || entry.isFavorite)
        }

        filteredSessionsCache = filtered
        groupedSessionsByMonth = groupedSessions(filtered)
        availableTags = Array(Set(sessions.flatMap(\.tags))).sorted()
        favoriteSessionCountCache = sessions.filter(\.isFavorite).count
    }

    // Grouping helpers
    private var monthFormatter: DateFormatter {
        Self.monthHeaderFormatter
    }

    private func monthStart(for date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }

    private var groupedByMonth: [(month: Date, items: [ExamenSession])] {
        groupedSessionsByMonth
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
            return "Date: \(Self.customRangeFormatter.string(from: min(s,e)))–\(Self.customRangeFormatter.string(from: max(s,e)))"
        }
    }

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }

    private var favoriteSessionCount: Int {
        favoriteSessionCountCache
    }

    private var hasActiveSelection: Bool {
        editMode == .active && !selectedIDs.isEmpty
    }

    private var headerSummaryText: String {
        if filtersAreClear {
            return "\(sessions.count) reflection\(sessions.count == 1 ? "" : "s")"
        }
        return "\(filteredSessions.count) of \(sessions.count) shown"
    }

    private var journalCanvasMaxWidth: CGFloat {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize ? 1280 : .infinity
    }

    private var usesJournalSidebar: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize && !sessions.isEmpty
    }

    private var selectionModeCaption: String? {
        guard editMode == .active else { return nil }
        return "Selection mode is on. Choose reflections, then use the menu for available actions."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if useImmersive {
                    SacredScreenBackground(settings: settings)
                }
                VStack(spacing: DSSpacing.xs) {
                    AppPageHeader(title: "Journal")
                        .padding(.horizontal, DSSpacing.lg)
                        .padding(.top, DSSpacing.md)
                        .padding(.bottom, DSSpacing.xs)

                    if sessions.isEmpty {
                        JournalFirstUseState(
                            useImmersive: useImmersive,
                            onCaptureQuickNote: { showQuickNoteTypePicker = true },
                            onGoHome: { settings.routeHome() }
                        )
                    } else if usesJournalSidebar {
                        HStack(alignment: .top, spacing: 0) {
                            journalFilterSidebar
                                .frame(width: 310)
                                .padding(.leading, DSSpacing.lg)
                                .padding(.trailing, DSSpacing.md)
                                .padding(.bottom, DSSpacing.md)

                            Rectangle()
                                .fill(DSColor.dividerSoft)
                                .frame(width: 1)
                                .padding(.bottom, DSSpacing.sm)

                            journalResultsContent
                            .padding(.leading, DSSpacing.md)
                            .padding(.trailing, DSSpacing.lg)
                        }
                    } else {
                        compactJournalControls
                        journalResultsContent
                    }
                }
                .frame(maxWidth: journalCanvasMaxWidth, maxHeight: .infinity)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
            .onChange(of: query) { _, _ in refilter() }
            .onChange(of: selectedExperience) { _, _ in refilter() }
            .onChange(of: selectedTag) { _, _ in refilter() }
            .onChange(of: datePreset) { _, _ in refilter() }
            .onChange(of: onlyFavorites) { _, _ in refilter() }
            .onChange(of: customStart) { _, _ in
                guard datePreset == .custom else { return }
                refilter()
            }
            .onChange(of: customEnd) { _, _ in
                guard datePreset == .custom else { return }
                refilter()
            }
            .onChange(of: allSessions.count) { _, _ in
                refilter()
                presentPendingJournalEntryIfNeeded()
                presentPendingJournalDetailsIfNeeded()
            }
            .onChange(of: settings.pendingJournalEntryID) { _, _ in
                presentPendingJournalEntryIfNeeded()
            }
            .onChange(of: settings.pendingJournalDetailsEntryID) { _, _ in
                presentPendingJournalDetailsIfNeeded()
            }
            .onAppear {
                refilter()
                presentPendingJournalEntryIfNeeded()
                presentPendingJournalDetailsIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(editMode == .active ? "Cancel" : "Select") {
                        withAnimation { toggleEditMode() }
                    }
                    .accessibilityIdentifier("journal.selection.toggle")
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showQuickNoteTypePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .tint(useImmersive ? DSColor.goldLight : .accentColor)

                    Menu {
                        Button {
                            clearFilters()
                        } label: {
                            Label("Clear Filters", systemImage: "xmark.circle")
                        }
                        .disabled(filtersAreClear)

                        if !isCoreMode {
                            Divider()

                            Button {
                                seedBulkTagsFromSelection()
                                activeSheet = .bulkTagging
                            } label: {
                                Label("Tag Selected", systemImage: "tag")
                            }
                            .disabled(!(editMode == .active && !selectedIDs.isEmpty))
                        } else {
                            Divider()
                        }

                        Button {
                            exportSelectedNotes()
                        } label: {
                            Label("Export Selected", systemImage: "square.and.arrow.up")
                        }
                        .disabled(!(editMode == .active && !selectedIDs.isEmpty))

                        if !isCoreMode {
                            Button {
                                let chosen = filteredSessions.filter { selectedIDs.contains($0.id) }
                                presentAddToStatement(with: chosen)
                            } label: {
                                Label("Use in Writing", systemImage: "square.and.pencil")
                            }
                            .disabled(!(editMode == .active && !selectedIDs.isEmpty))
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .tint(useImmersive ? DSColor.goldLight : .accentColor)
                    .accessibilityIdentifier("journal.bulkMenu")
                }
            }
            .if(!usesJournalSidebar) { view in
                view.searchable(text: $query, placement: .toolbar, prompt: "Search journal entries")
            }
            .persistenceFailureAlert($persistenceAlert)
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
                persistenceAlert = PersistenceAlertContext(
                    title: "Couldn't Export Notes",
                    message: "Illuminote couldn't export those notes. \(error.localizedDescription)"
                )
            }
        }
        .confirmationDialog(
            "Quick Note",
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
            Text("Choose the kind of experience you want to capture. You can add the details right away.")
        }
        .fullScreenCover(item: $activeCover, onDismiss: {
            settings.routeDeferredJournalDetailsIfNeeded(presentAfterDelay: 500_000_000)
        }) { route in
            coverContent(for: route)
        }
        .sheet(item: $activeSheet, onDismiss: clearSheetScratchState) { route in
            sheetContent(for: route)
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
        let combinedAnswers = entry.normalizedResponseTexts().joined(separator: "\n\n")

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

    private func groupedSessions(_ sessions: [ExamenSession]) -> [(month: Date, items: [ExamenSession])] {
        let groups = Dictionary(grouping: sessions) { monthStart(for: $0.date) }
        return groups
            .map { key, value in
                (month: key, items: value.sorted { $0.date > $1.date })
            }
            .sorted { $0.month > $1.month }
    }

    private func presentPendingJournalEntryIfNeeded() {
        guard let targetID = settings.pendingJournalEntryID else { return }
        guard let entry = sessions.first(where: { $0.id == targetID }) else { return }
        settings.pendingJournalEntryID = nil
        activeSheet = .viewEntry(entry.id)
    }

    private func presentPendingJournalDetailsIfNeeded() {
        guard let targetID = settings.pendingJournalDetailsEntryID else { return }
        guard let entry = sessions.first(where: { $0.id == targetID }) else { return }
        settings.pendingJournalDetailsEntryID = nil
        beginEditDetails(entry, source: .postExamenHandoff)
    }

    @MainActor
    private func refreshJournalList() async {
        // CloudKit sync is system-driven; fetching refreshes the local SwiftData snapshot
        // after incoming changes have landed.
        _ = try? modelContext.fetch(FetchDescriptor<ExamenSession>())
        _ = try? modelContext.fetch(FetchDescriptor<StatementDraft>())
        refilter()
        presentPendingJournalEntryIfNeeded()
        presentPendingJournalDetailsIfNeeded()
        try? await Task.sleep(nanoseconds: 350_000_000)
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
        onlyFavorites = false
        showFilterControls = false
    }

    private func delete(_ entries: [ExamenSession]) {
        for entry in entries {
            modelContext.delete(entry)
        }
        if persistChanges("delete those reflections") {
            refilter()
        }
    }

    private func clearSelectionAndExitEditMode() {
        selectedIDs.removeAll()
        editMode = .inactive
    }

    private func toggleSelection(for entryID: UUID) {
        if selectedIDs.contains(entryID) {
            selectedIDs.remove(entryID)
        } else {
            selectedIDs.insert(entryID)
        }
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

    private var isDateRangeSheetPresented: Binding<Bool> {
        Binding(
            get: {
                if case .dateRange = activeSheet {
                    return true
                }
                return false
            },
            set: { isPresented in
                if isPresented {
                    activeSheet = .dateRange
                } else if case .dateRange = activeSheet {
                    activeSheet = nil
                }
            }
        )
    }

    private func journalEntry(for entryID: UUID) -> ExamenSession? {
        sessions.first { $0.id == entryID }
    }

    private func journalEntries(for entryIDs: [UUID]) -> [ExamenSession] {
        let lookup = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        return entryIDs.compactMap { lookup[$0] }
    }

    private func presentViewer(for entry: ExamenSession) {
        activeSheet = .viewEntry(entry.id)
    }

    private func beginEditDetails(
        _ entry: ExamenSession,
        source: JournalDetailsEditorSource = .journalEdit
    ) {
        detailsDraft = JournalDetailsDraft(entry: entry)
        activeSheet = .editDetails(entry.id, source)
    }

    private func beginEditingEntry(_ entry: ExamenSession) {
        activeSheet = .editText(entry.id)
    }

    private func presentAddToStatement(with entries: [ExamenSession]) {
        let entryIDs = entries.map(\.id)
        guard !entryIDs.isEmpty else { return }
        activeSheet = .addToStatement(entryIDs)
    }

    private func clearSheetScratchState() {
        detailsDraft = JournalDetailsDraft()
        bulkTags = []
        bulkNewTagText = ""
    }

    @ViewBuilder
    private func sheetContent(for route: JournalSheetRoute) -> some View {
        switch route {
        case .editDetails(let entryID, let source):
            if let entry = journalEntry(for: entryID) {
                editDetailsSheet(for: entry, source: source)
            } else {
                unavailableEntrySheet
            }
        case .viewEntry(let entryID):
            if let entry = journalEntry(for: entryID) {
                JournalEntryViewer(
                    entry: entry,
                    onClose: { activeSheet = nil },
                    onEdit: { beginEditingEntry(entry) },
                    onEditDetails: { beginEditDetails(entry) },
                    onAddToStatement: { presentAddToStatement(with: [entry]) }
                )
            } else {
                unavailableEntrySheet
            }
        case .editText(let entryID):
            if let entry = journalEntry(for: entryID) {
                editTextSheet(for: entry)
            } else {
                unavailableEntrySheet
            }
        case .bulkTagging:
            bulkTagSheet
        case .dateRange:
            dateRangeSheet
        case .addToStatement(let entryIDs):
            addToStatementSheetContent(for: journalEntries(for: entryIDs))
        }
    }

    @ViewBuilder
    private func coverContent(for route: JournalCoverRoute) -> some View {
        switch route {
        case .quickNote(let type):
            quickNoteFlow(for: type)
        }
    }

    private var unavailableEntrySheet: some View {
        NavigationStack {
            ContentUnavailableView(
                "Reflection Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("That reflection is no longer available.")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        activeSheet = nil
                    }
                }
            }
        }
    }

    // MARK: - UI Builders

    @ViewBuilder
    private func journalRow(for session: ExamenSession) -> some View {
        // Strict branching to ensure no gesture interference in Edit Mode
        if editMode == .active {
            Button {
                withAnimation(AnimationConfig.screenTransition) {
                    toggleSelection(for: session.id)
                }
            } label: {
                JournalRow(
                    session: session,
                    references: referencingDrafts(for: session.id),
                    onToggleFavorite: { toggleFavorite(session) },
                    isHighlighted: selectedIDs.contains(session.id)
                )
                .allowsHitTesting(false)
            }
            .buttonStyle(.plain)
            .tag(session.id)
            .accessibilityIdentifier("journal.entryButton")
            .accessibilityValue(selectedIDs.contains(session.id) ? "selected" : "not selected")
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
                presentViewer(for: session)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("journal.entryRow")
            .accessibilityAddTraits(.isButton)
            .contextMenu {
                Button { beginEditDetails(session) } label: {
                    Label("Details", systemImage: "slider.horizontal.3")
                }
                Button { presentViewer(for: session) } label: {
                    Label("View & Edit", systemImage: "doc.text.magnifyingglass")
                }
            }
            .swipeActions(edge: .trailing) {
                Button { presentViewer(for: session) } label: {
                    Label("View & Edit", systemImage: "doc.text.magnifyingglass")
                }.tint(.indigo)
                
                if !isCoreMode {
                    Button {
                        presentAddToStatement(with: [session])
                    } label: {
                        Label("Use in Writing", systemImage: "square.and.pencil")
                    }.tint(useImmersive ? DSColor.goldLight : .accentColor)
                }
                
                Button(role: .destructive) { delete([session]) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button { beginEditDetails(session) } label: {
                    Label("Details", systemImage: "slider.horizontal.3")
                }.tint(useImmersive ? DSColor.goldLight : .blue)
                
                Button { presentViewer(for: session) } label: {
                    Label("View & Edit", systemImage: "doc.text.magnifyingglass")
                }.tint(.indigo)
            }
            .tag(session.id)
        }
    }

    // Toolbar items moved inline to Body for better layout control
    
    private func quickNoteFlow(for type: ExperienceType) -> some View {
        ExamenSessionContainer(
            draft: ExamenSessionDraft(type: type),
            initialStage: .finalReflection
        )
    }

    private func launchQuickNote(for type: ExperienceType) {
        activeCover = .quickNote(type)
    }

    private func editDetailsSheet(
        for entry: ExamenSession,
        source: JournalDetailsEditorSource
    ) -> some View {
        JournalDetailsEditorSheet(
            draft: $detailsDraft,
            source: source,
            useImmersive: useImmersive,
            onSave: {
                saveEditDetails(for: entry)
            },
            onSecondaryAction: {
                activeSheet = nil
            }
        )
    }

    private func editTextSheet(for entry: ExamenSession) -> some View {
        JournalEntryTextEditSheet(
            entry: entry,
            useImmersive: useImmersive,
            onCancel: {
                activeSheet = nil
            },
            onSave: { text in
                if saveEditedText(text, for: entry) {
                    activeSheet = nil
                }
            },
            onDetails: { text in
                if saveEditedText(text, for: entry) {
                    beginEditDetails(entry)
                }
            }
        )
    }

    private struct JournalEntryTextEditSheet: View {
        let entry: ExamenSession
        let useImmersive: Bool
        let onCancel: () -> Void
        let onSave: (String) -> Void
        let onDetails: (String) -> Void

        @State private var draftText: String

        init(
            entry: ExamenSession,
            useImmersive: Bool,
            onCancel: @escaping () -> Void,
            onSave: @escaping (String) -> Void,
            onDetails: @escaping (String) -> Void
        ) {
            self.entry = entry
            self.useImmersive = useImmersive
            self.onCancel = onCancel
            self.onSave = onSave
            self.onDetails = onDetails
            self._draftText = State(initialValue: entry.personalStatement)
        }

        var body: some View {
            NavigationStack {
                Form {
                    Section("Edit Notes") {
                        TextEditor(text: $draftText)
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
                        Button("Cancel", action: onCancel)
                            .accessibilityIdentifier("journal.editText.cancel")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(draftText)
                        }
                        .accessibilityIdentifier("journal.editText.save")
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button("Details") {
                            onDetails(draftText)
                        }
                        .accessibilityIdentifier("journal.editText.details")
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        activeSheet = nil
                    }
                }
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        activeSheet = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        datePreset = .custom
                        activeSheet = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func addToStatementSheetContent(for entries: [ExamenSession]) -> some View {
        Group {
            if !entries.isEmpty {
                AddToStatementSheet(
                    selectedEntries: entries,
                    onComplete: {
                        withAnimation {
                            clearSelectionAndExitEditMode()
                        }
                    }
                )
                    .onDisappear {
                        withAnimation { clearSelectionAndExitEditMode() }
                    }
            } else {
                unavailableEntrySheet
            }
        }
    }
    
    // Favorite toggle handler
    private func toggleFavorite(_ entry: ExamenSession) {
        entry.isFavorite.toggle()
        if persistChanges("update that reflection") {
            refilter()
        }
    }
    
    @discardableResult
    private func saveEditedText(_ text: String, for entry: ExamenSession) -> Bool {
        entry.personalStatement = text
        if persistChanges("save that reflection text") {
            refilter()
            return true
        }
        return false
    }


    
    private func saveEditDetails(for entry: ExamenSession) {
        detailsDraft.apply(to: entry)
        if persistChanges("save those journal details") {
            refilter()
            activeSheet = nil
        }
    }

    @discardableResult
    private func persistChanges(_ operation: String) -> Bool {
        if !modelContext.hasChanges {
            return true
        }

        do {
            try modelContext.persistIfNeeded(for: operation)
            return true
        } catch let error as PersistenceOperationError {
            persistenceAlert = error.alertContext
        } catch {
            persistenceAlert = PersistenceAlertContext.saveFailure(
                for: operation,
                details: error.localizedDescription
            )
        }

        return false
    }

    private var compactJournalControls: some View {
        VStack(spacing: DSSpacing.xs) {
            JournalBrowseBar(
                summaryText: headerSummaryText,
                summaryIcon: filtersAreClear ? "book.closed" : "line.3.horizontal.decrease.circle",
                emphasizeSummary: !filtersAreClear,
                favoriteCount: favoriteSessionCount,
                showFavoritesAsActive: onlyFavorites,
                selectionCount: editMode == .active ? selectedIDs.count : nil,
                emphasizeSelection: hasActiveSelection,
                selectionCaption: selectionModeCaption,
                showFilterControls: showFilterControls,
                hasActiveFilters: !filtersAreClear,
                onToggleFilters: {
                    withAnimation(AnimationConfig.screenTransition) {
                        showFilterControls.toggle()
                    }
                },
                onClearFilters: clearFilters
            )
            .padding(.horizontal)
            .padding(.bottom, DSSpacing.xs)
            if showFilterControls || !filtersAreClear {
                JournalFilterTray {
                    FiltersRow(selectedExperience: $selectedExperience,
                               selectedTag: $selectedTag,
                               datePreset: $datePreset,
                               showDateRangeSheet: isDateRangeSheetPresented,
                               onlyFavorites: $onlyFavorites,
                               allTags: allTags,
                               datePresetLabel: datePresetLabel)
                }
                .padding(.horizontal)
                .padding(.bottom, DSSpacing.xs)
            }

            if !filtersAreClear {
                activeFilterPills
            }
        }
    }

    private var journalResultsContent: some View {
        Group {
            if filteredSessions.isEmpty {
                JournalResultsEmptyState(
                    useImmersive: useImmersive,
                    clearFilters: clearFilters
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.md)
            } else {
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
                                    .listRowInsets(
                                        EdgeInsets(
                                            top: DSSpacing.xs,
                                            leading: DSSpacing.md,
                                            bottom: DSSpacing.xs,
                                            trailing: DSSpacing.md
                                        )
                                    )
                                    .listRowBackground(useImmersive ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                            }
                        }
                    }
                }
                .environment(\.editMode, $editMode)
                .listRowSeparatorTint(useImmersive ? .clear : Color(uiColor: .separator))
                .darkListStyle(enabled: useImmersive, baseBackground: nil)
                .refreshable {
                    await refreshJournalList()
                }
            }
        }
    }

    private var activeFilterPills: some View {
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

    private var journalFilterSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Find reflections")
                        .font(DSFont.sectionTitle)
                        .foregroundStyle(DSColor.textPrimary)

                    Text(headerSummaryText)
                        .font(DSFont.supporting)
                        .foregroundStyle(DSColor.quietText)
                }

                JournalSidebarSearchField(query: $query)

                if favoriteSessionCount > 0 || editMode == .active {
                    HStack(spacing: DSSpacing.sm) {
                        if favoriteSessionCount > 0 {
                            AppInfoChip(
                                text: "\(favoriteSessionCount) favorite\(favoriteSessionCount == 1 ? "" : "s")",
                                icon: onlyFavorites ? "star.fill" : "star",
                                emphasized: onlyFavorites
                            )
                        }

                        if editMode == .active {
                            AppInfoChip(
                                text: "\(selectedIDs.count) selected",
                                icon: "checkmark.circle",
                                emphasized: hasActiveSelection
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Filters")
                        .font(DSFont.eyebrow)
                        .foregroundStyle(DSColor.quietTextMuted)
                        .textCase(.uppercase)

                    Menu {
                        Button("All Experiences") { selectedExperience = nil }
                        Divider()
                        ForEach(ExperienceType.allCases, id: \.self) { kind in
                            Button(kind.displayName) { selectedExperience = kind }
                        }
                    } label: {
                        JournalSidebarFilterLabel(
                            title: selectedExperience?.displayName ?? "Experience",
                            icon: "line.3.horizontal.decrease.circle",
                            isActive: selectedExperience != nil
                        )
                    }

                    Menu {
                        Button("All Tags") { selectedTag = nil }
                        Divider()
                        ForEach(allTags, id: \.self) { tag in
                            Button(tag) { selectedTag = tag }
                        }
                    } label: {
                        JournalSidebarFilterLabel(
                            title: selectedTag ?? "Tags",
                            icon: "tag",
                            isActive: selectedTag != nil
                        )
                    }

                    Menu {
                        Picker("Date Range", selection: $datePreset) {
                            Text("All Time").tag(DatePreset.all)
                            Text("Last 7 Days").tag(DatePreset.last7)
                            Text("Last 30 Days").tag(DatePreset.last30)
                            Text("Last Year").tag(DatePreset.last365)
                            Text("Custom...").tag(DatePreset.custom)
                        }
                        if datePreset == .custom {
                            Button("Choose Dates...") { activeSheet = .dateRange }
                        }
                    } label: {
                        JournalSidebarFilterLabel(
                            title: datePreset == .all ? "Date" : datePresetLabel.replacingOccurrences(of: "Date: ", with: ""),
                            icon: "calendar",
                            isActive: datePreset != .all
                        )
                    }

                    Button {
                        onlyFavorites.toggle()
                    } label: {
                        JournalSidebarFilterLabel(
                            title: "Favorites",
                            icon: onlyFavorites ? "star.fill" : "star",
                            isActive: onlyFavorites
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !filtersAreClear {
                    Button("Clear Filters", action: clearFilters)
                        .buttonStyle(.appQuiet)
                }

                if let selectionModeCaption {
                    Text(selectionModeCaption)
                        .font(DSFont.meta)
                        .foregroundStyle(DSColor.quietText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .appSurfaceStyle(role: .quiet, highlighted: false)
    }
}

private struct JournalDetailsEditorSheet: View {
    @Binding var draft: JournalDetailsDraft
    @FocusState private var focusedField: JournalDetailsField?

    let source: JournalDetailsEditorSource
    let useImmersive: Bool
    let onSave: () -> Void
    let onSecondaryAction: () -> Void

    private var detailConfig: ExperienceDetailFieldConfig {
        draft.detailConfig
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DSColor.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.lg) {
                        AppSectionHeader(
                            eyebrow: source == .postExamenHandoff ? "Saved to Journal" : "Journal",
                            title: source.headerTitle,
                            subtitle: source.headerSubtitle
                        )

                        experiencePanel

                        if draft.experience != nil {
                            detailsPanel
                        }

                        notesPanel
                        tagsPanel
                    }
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.top, DSSpacing.lg)
                    .padding(.bottom, 112)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(source.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
        }
        .interactiveDismissDisabled(source == .postExamenHandoff)
    }

    private var experiencePanel: some View {
        AppPanel(
            title: "Experience type",
            subtitle: "Choose the closest fit, or leave this as a general reflection.",
            role: .reading,
            highlighted: source == .postExamenHandoff
        ) {
            Menu {
                Button("None") {
                    changeExperience(to: nil)
                }
                Divider()
                ForEach(ExperienceType.allCases, id: \.self) { kind in
                    Button(kind.displayName) {
                        changeExperience(to: kind)
                    }
                }
            } label: {
                JournalDetailsPickerLabel(
                    title: draft.experience?.displayName ?? "General reflection",
                    subtitle: draft.experience == nil ? "No structured type" : "Tap to change",
                    icon: "line.3.horizontal.decrease.circle"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("journal.details.typePicker")
        }
    }

    @ViewBuilder
    private var detailsPanel: some View {
        AppPanel(
            title: "Experience details",
            subtitle: "Add only what helps you recognize this reflection later.",
            role: .interactive
        ) {
            VStack(spacing: DSSpacing.md) {
                if detailConfig.showsHours {
                    JournalDetailsTextField(
                        title: "Hours",
                        prompt: "0",
                        systemImage: "clock",
                        text: $draft.hoursString,
                        field: .hours,
                        focusedField: $focusedField,
                        keyboardType: .decimalPad,
                        capitalization: .never,
                        accessibilityIdentifier: "journal.details.hours"
                    )
                }

                if detailConfig.showsPrimary {
                    JournalDetailsTextField(
                        title: detailConfig.primaryLabel,
                        prompt: detailConfig.primaryLabel,
                        systemImage: "person",
                        text: $draft.primaryValue,
                        field: .primary,
                        focusedField: $focusedField,
                        capitalization: .words,
                        accessibilityIdentifier: "journal.details.primary"
                    )
                }

                if detailConfig.showsFacility {
                    JournalDetailsTextField(
                        title: detailConfig.facilityLabel,
                        prompt: detailConfig.facilityLabel,
                        systemImage: "building.2",
                        text: $draft.secondaryValue,
                        field: .secondary,
                        focusedField: $focusedField,
                        capitalization: .words,
                        accessibilityIdentifier: "journal.details.secondary"
                    )
                }

                if detailConfig.showsLocation {
                    JournalDetailsTextField(
                        title: "Location",
                        prompt: "City or place",
                        systemImage: "mappin.and.ellipse",
                        text: $draft.location,
                        field: .location,
                        focusedField: $focusedField,
                        capitalization: .words,
                        accessibilityIdentifier: "journal.details.location"
                    )
                }

                if detailConfig.showsFocus {
                    JournalDetailsTextField(
                        title: detailConfig.focusLabel,
                        prompt: detailConfig.focusLabel,
                        systemImage: "scope",
                        text: $draft.focusValue,
                        field: .focus,
                        focusedField: $focusedField,
                        capitalization: .sentences,
                        accessibilityIdentifier: "journal.details.focus"
                    )
                }

                if !detailConfig.showsHours
                    && !detailConfig.showsPrimary
                    && !detailConfig.showsFacility
                    && !detailConfig.showsLocation
                    && !detailConfig.showsFocus {
                    Text("No extra structured details are needed for this type.")
                        .font(DSFont.supporting)
                        .foregroundStyle(DSColor.quietText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var notesPanel: some View {
        AppPanel(
            title: "Private notes",
            subtitle: "Optional context for your future self.",
            role: .quiet
        ) {
            JournalDetailsTextField(
                title: "Notes",
                prompt: "Anything else to remember",
                systemImage: "note.text",
                text: $draft.notes,
                field: .notes,
                focusedField: $focusedField,
                isMultiline: true,
                accessibilityIdentifier: "journal.details.notes"
            )
        }
    }

    private var tagsPanel: some View {
        AppPanel(
            title: "Tags",
            subtitle: "Use a few simple words if they help you find this later.",
            role: .quiet
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                HStack(spacing: DSSpacing.sm) {
                    JournalDetailsTextField(
                        title: "New tag",
                        prompt: "Add a tag",
                        systemImage: "tag",
                        text: $draft.newTagText,
                        field: .tag,
                        focusedField: $focusedField,
                        capitalization: .never,
                        accessibilityIdentifier: "journal.details.tagInput"
                    )
                    .onSubmit(addTag)

                    Button(action: addTag) {
                        Image(systemName: "plus")
                            .font(.headline.weight(.semibold))
                            .appCircleControl(emphasized: canAddTag)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAddTag)
                    .accessibilityLabel("Add tag")
                    .accessibilityIdentifier("journal.details.addTag")
                }

                if draft.tags.isEmpty {
                    Text("No tags yet")
                        .font(DSFont.supporting)
                        .foregroundStyle(DSColor.quietText)
                } else {
                    TagCloud(tags: draft.tags) { tag in
                        var updated = draft
                        updated.removeTag(tag)
                        draft = updated
                    }
                }
            }
        }
    }

    private var actionBar: some View {
        VStack(spacing: DSSpacing.sm) {
            Button(action: onSave) {
                Label("Save Details", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.appPrimary)
            .accessibilityIdentifier("journal.details.save")

            Button(source.secondaryActionTitle, action: onSecondaryAction)
                .buttonStyle(.appQuiet)
                .accessibilityIdentifier("journal.details.skip")
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.top, DSSpacing.md)
        .padding(.bottom, DSSpacing.md)
        .background(
            Rectangle()
                .fill(DSColor.backgroundPrimary.opacity(0.96))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(DSColor.dividerSoft)
                        .frame(height: 1)
                }
        )
    }

    private var canAddTag: Bool {
        !draft.newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func changeExperience(to experience: ExperienceType?) {
        var updated = draft
        updated.changeExperience(to: experience)
        withAnimation(AnimationConfig.screenTransition) {
            draft = updated
        }
    }

    private func addTag() {
        var updated = draft
        updated.addTag()
        draft = updated
    }
}

private struct JournalDetailsPickerLabel: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(DSColor.brandAccent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DSFont.body.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(DSFont.meta)
                    .foregroundStyle(DSColor.quietText)
            }

            Spacer(minLength: DSSpacing.sm)

            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DSColor.quietTextMuted)
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(DSColor.interactiveSurface.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DSColor.dividerSoft, lineWidth: 1)
        )
    }
}

private struct JournalDetailsTextField: View {
    let title: String
    let prompt: String
    let systemImage: String
    @Binding var text: String
    let field: JournalDetailsField
    var focusedField: FocusState<JournalDetailsField?>.Binding
    var keyboardType: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    var isMultiline = false
    let accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Label(title, systemImage: systemImage)
                .font(DSFont.caption.weight(.semibold))
                .foregroundStyle(DSColor.quietText)

            if isMultiline {
                styledInput(
                    TextField(prompt, text: $text, axis: .vertical)
                        .lineLimit(3...6)
                )
            } else {
                styledInput(
                    TextField(prompt, text: $text)
                        .lineLimit(1)
                )
            }
        }
    }

    private func styledInput<Input: View>(_ input: Input) -> some View {
        input
            .font(DSFont.body)
            .foregroundStyle(DSColor.textPrimary)
            .textInputAutocapitalization(capitalization)
            .keyboardType(keyboardType)
            .focused(focusedField, equals: field)
            .textFieldStyle(.plain)
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(DSColor.readingSurface.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DSColor.dividerSoft, lineWidth: 1)
            )
            .accessibilityLabel(title)
            .accessibilityIdentifier(accessibilityIdentifier)
            .onTapGesture {
                focusedField.wrappedValue = field
            }
    }
}

private struct JournalBrowseBar: View {
    let summaryText: String
    let summaryIcon: String
    let emphasizeSummary: Bool
    let favoriteCount: Int
    let showFavoritesAsActive: Bool
    let selectionCount: Int?
    let emphasizeSelection: Bool
    let selectionCaption: String?
    let showFilterControls: Bool
    let hasActiveFilters: Bool
    let onToggleFilters: () -> Void
    let onClearFilters: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: DSSpacing.sm) {
                    summaryView
                    Spacer(minLength: DSSpacing.sm)
                    actionRow
                }

                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    summaryView
                    actionRow
                }
            }

            if favoriteCount > 0 || selectionCount != nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DSSpacing.sm) {
                        if favoriteCount > 0 {
                            AppInfoChip(
                                text: "\(favoriteCount) favorite\(favoriteCount == 1 ? "" : "s")",
                                icon: showFavoritesAsActive ? "star.fill" : "star",
                                emphasized: showFavoritesAsActive
                            )
                        }

                        if let selectionCount {
                            AppInfoChip(
                                text: "\(selectionCount) selected",
                                icon: "checkmark.circle",
                                emphasized: emphasizeSelection
                            )
                        }
                    }
                }
            }

            if let selectionCaption {
                Text(selectionCaption)
                    .font(DSFont.meta)
                    .foregroundStyle(DSColor.quietText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DSColor.quietSurface.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DSColor.dividerSoft, lineWidth: 1)
        )
    }

    private var summaryView: some View {
        HStack(spacing: 8) {
            Image(systemName: summaryIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(emphasizeSummary ? DSColor.brandAccent : DSColor.quietTextMuted)

            Text(summaryText)
                .font(DSFont.supporting.weight(.semibold))
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var actionRow: some View {
        HStack(spacing: DSSpacing.sm) {
            Button(action: onToggleFilters) {
                Label(
                    "Filters",
                    systemImage: showFilterControls ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
                )
            }
            .buttonStyle(.appQuiet)
            .accessibilityLabel(showFilterControls ? "Hide filters" : "Show filters")

            if hasActiveFilters {
                Button("Clear", action: onClearFilters)
                    .buttonStyle(.appQuiet)
            }
        }
    }
}

private struct JournalFilterTray<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.vertical, DSSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DSColor.interactiveSurface.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DSColor.dividerSoft, lineWidth: 1)
            )
    }
}

private struct JournalSidebarSearchField: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(DSFont.meta.weight(.semibold))
                .foregroundStyle(DSColor.quietTextMuted)

            TextField("Search journal entries", text: $query)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DSColor.quietTextMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DSColor.interactiveSurface.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DSColor.dividerSoft, lineWidth: 1)
        )
        .accessibilityLabel("Search journal entries")
    }
}

private struct JournalSidebarFilterLabel: View {
    let title: String
    let icon: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: icon)
                .font(DSFont.meta.weight(.semibold))
                .foregroundStyle(isActive ? DSColor.brandAccent : DSColor.quietTextMuted)
                .frame(width: 18)

            Text(title)
                .font(DSFont.body.weight(isActive ? .semibold : .regular))
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)

            Spacer(minLength: DSSpacing.sm)

            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DSColor.quietTextMuted)
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isActive ? DSColor.brandAccentSoft : DSColor.interactiveSurface.opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isActive ? DSColor.brandAccent.opacity(0.38) : DSColor.dividerSoft, lineWidth: 1)
        )
        .accessibilityValue(isActive ? "Active" : "")
    }
}

private struct JournalFirstUseState: View {
    @AppStorage(AppCoachStorageKey.journal) private var isDismissed = false

    let useImmersive: Bool
    let onCaptureQuickNote: () -> Void
    let onGoHome: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            if useImmersive {
                Image(systemName: "book")
                    .font(.system(size: 48))
                    .foregroundStyle(DSColor.quietTextMuted)
            }

            if !isDismissed {
                AppCoachPanel(
                    title: "No reflections yet",
                    subtitle: "Your journal fills after your first Examen or quick note. Once you begin, this is where the details stay searchable and close at hand.",
                    role: .quiet,
                    highlighted: useImmersive,
                    onDismiss: dismiss
                ) {
                    EmptyView()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            AppPanel(role: .quiet, highlighted: useImmersive) {
                VStack(spacing: DSSpacing.sm) {
                    AppButton(title: "Enter a Note", style: .primary, action: onCaptureQuickNote)
                    AppButton(title: "Go to Home", style: .quiet, action: onGoHome)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, DSSpacing.lg)
        .padding(.top, DSSpacing.lg)
    }

    private func dismiss() {
        withAnimation(AnimationConfig.screenTransition) {
            isDismissed = true
        }
    }
}

private struct JournalResultsEmptyState: View {
    let useImmersive: Bool
    let clearFilters: () -> Void

    var body: some View {
        Group {
            if useImmersive {
                DarkEmptyState(
                    title: "No reflections match these filters",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: "Try widening the date range, removing a tag, or clearing favorites to bring more of your journal back into view.",
                    actionTitle: "Clear Filters",
                    action: clearFilters,
                    fillBackground: false
                )
            } else {
                ContentUnavailableView(
                    "No Matches",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Try widening the date range, removing a tag, or clearing favorites.")
                )
            }
        }
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
        if persistChanges("apply those tags") {
            refilter()
            activeSheet = nil
            withAnimation { clearSelectionAndExitEditMode() }
        }
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
        formattedJournalEntryText(for: entry, dateStyle: journalDateStyle)
    }
}
import SwiftUI
import SwiftData

private func formattedJournalEntryText(
    for entry: ExamenSession,
    dateStyle: Date.FormatStyle
) -> String {
    var sections: [String] = []

    sections.append("— Journal \(entry.date.formatted(dateStyle)) —")

    var metadata: [String] = []
    if let type = entry.experienceType {
        metadata.append("Experience: \(type.displayName)")
    }
    metadata.append(contentsOf: entry.detailMetadataLines())

    if !metadata.isEmpty {
        sections.append(metadata.joined(separator: "\n"))
    }

    let responsesText = entry.normalizedResponseTexts().joined(separator: "\n\n")
    if !responsesText.isEmpty {
        sections.append("— Prompt Responses —\n\(responsesText)")
    }

    let finalReflection = entry.personalStatement.trimmingCharacters(in: .whitespacesAndNewlines)
    if !finalReflection.isEmpty {
        sections.append("— Final Reflection —\n\(finalReflection)")
    }

    let privateNotes = entry.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !privateNotes.isEmpty {
        sections.append("— Private Notes —\n\(privateNotes)")
    }

    return sections.joined(separator: "\n\n")
}

struct JournalEntryViewer: View {
    @Environment(AppSettings.self) private var settings
    let entry: ExamenSession
    var onClose: () -> Void
    var onEdit: () -> Void
    var onEditDetails: () -> Void
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

                if AppSettings.featurePolicy.allowsExamenApplicationRecordDuringReflection,
                   let applicationRecord = entry.applicationExperience {
                    Section("Application Record") {
                        NavigationLink {
                            ApplicationExperienceDetailView(experience: applicationRecord)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(applicationRecord.exportTitle)
                                    .font(DSFont.body.weight(.semibold))
                                Text(applicationRecord.organizationName ?? applicationRecord.category.displayName)
                                    .font(DSFont.caption)
                                    .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                            }
                        }
                        .accessibilityIdentifier("journal.viewer.openApplicationRecord")
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
                        .accessibilityIdentifier("journal.viewer.close")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: DSSpacing.sm) {
                        Button("Details", action: onEditDetails)
                            .accessibilityIdentifier("journal.viewer.details")
                        Button("Edit", action: onEdit)
                            .accessibilityIdentifier("journal.viewer.edit")
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    Button(action: onAddToStatement) {
                        Label("Use in Writing", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("journal.viewer.useInDraft")
                }
            }
        }
    }
    
    // Helper to build combined text for viewer
    private func computedViewerText(for entry: ExamenSession) -> String {
        formattedJournalEntryText(for: entry, dateStyle: journalDateStyle)
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
        do {
            try modelContext.persistIfNeeded(for: "delete that saved theme bundle")
        } catch {
            print("Failed to delete theme bundle: \(error)")
        }
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
                Button("Use in Writing", action: onSendToStatement)
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
