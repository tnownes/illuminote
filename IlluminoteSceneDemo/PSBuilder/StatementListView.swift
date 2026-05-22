import SwiftUI
import SwiftData

struct StatementListView: View {
    private enum WritingSheetRoute: Identifiable {
        case addWriting(String?)
        case journalPicker(String)
        case experienceLog
        case knowledgeBase
        case assignDraft(UUID)

        var id: String {
            switch self {
            case .addWriting(let targetID):
                return "addWriting-\(targetID ?? "none")"
            case .journalPicker(let targetID):
                return "journalPicker-\(targetID)"
            case .experienceLog:
                return "experienceLog"
            case .knowledgeBase:
                return "knowledgeBase"
            case .assignDraft(let draftID):
                return "assignDraft-\(draftID.uuidString)"
            }
        }
    }

    private enum WritingSidebarSelection: Hashable {
        case overview
        case target(String)
        case draft(UUID)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: [SortDescriptor(\StatementDraft.dateModified, order: .reverse)])
    private var drafts: [StatementDraft]
    @Query(sort: \UserProfile.id)
    private var profiles: [UserProfile]

    @State private var requirements: [StatementRequirement] = []
    @State private var targets: [WritingTargetDefinition] = []
    @State private var applicationEntries: [ApplicationEntryDefinition] = []
    @State private var activeSheet: WritingSheetRoute?
    @State private var navigationPath = NavigationPath()
    @State private var writingColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedWritingItem: WritingSidebarSelection? = .overview
    @State private var expandedWritingTargetID: String?
    @State private var isImporting = false
    @State private var persistenceAlert: PersistenceAlertContext?
    @AppStorage(AppCoachStorageKey.writing) private var isWritingCoachDismissed = false

    private let requirementsService = LocalStatementRequirementsService()
    private let targetCatalogService = LocalWritingTargetCatalogService()
    private let applicationEntryCatalogService = LocalApplicationEntryCatalogService()

    private var currentProfile: UserProfile? {
        profiles.first
    }

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }

    private var canShowKnowledgeBaseVerification: Bool {
        AppSettings.knowledgeBaseVerificationAllowedInThisBuild
    }

    private var usesWideWritingLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var writingCanvasMaxWidth: CGFloat {
        usesWideWritingLayout ? 1120 : .infinity
    }

    private var profileSignature: String {
        guard let profile = currentProfile else { return "no-profile" }
        return [
            profile.id.uuidString,
            profile.preProfessionalTrack?.canonical.rawValue ?? "general",
            profile.degreeIntent.rawValue,
            profile.isTexasApplicant.description,
            profile.isMDPhDApplicant.description
        ].joined(separator: "|")
    }

    private var coreTargets: [WritingTargetDefinition] {
        targets.filter { $0.category == .coreStatement }
    }

    private var supplementalTargets: [WritingTargetDefinition] {
        targets.filter { $0.category == .supplementalEssay }
    }

    private var schoolSpecificTargets: [WritingTargetDefinition] {
        targets.filter { $0.category == .schoolSpecificEssay }
    }

    private var unassignedDrafts: [StatementDraft] {
        drafts.filter { $0.writingTargetID == nil }
    }

    private var selectedDraftID: UUID? {
        if case .draft(let draftID) = selectedWritingItem {
            return draftID
        }
        return nil
    }

    var body: some View {
        Group {
            if usesWideWritingLayout {
                wideWritingBody
            } else {
                compactWritingBody
            }
        }
        .sheet(item: $activeSheet) { route in
            sheetContent(for: route)
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.illuminoteDraft]
        ) { result in
            switch result {
            case .success(let url):
                importDraft(from: url)
            case .failure(let error):
                persistenceAlert = PersistenceAlertContext.saveFailure(
                    for: "import that draft",
                    details: error.localizedDescription
                )
            }
        }
        .background(Color.clear)
        .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
        .persistenceFailureAlert($persistenceAlert)
        .task(id: profileSignature) {
            await loadWritingTargets()
            consumePendingWritingDraftIfNeeded()
        }
        .task {
            consumePendingWritingDraftIfNeeded()
        }
        .onChange(of: settings.pendingWritingDraftID) { _, _ in
            consumePendingWritingDraftIfNeeded()
        }
        .onChange(of: drafts.count) { _, _ in
            consumePendingWritingDraftIfNeeded()
        }
        .onChange(of: usesWideWritingLayout) { _, isWide in
            if isWide, selectedWritingItem == nil {
                selectedWritingItem = .overview
            }
        }
    }

    private var compactWritingBody: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                if useImmersive {
                    SacredScreenBackground(settings: settings)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.lg) {
                        AppPageHeader(
                            title: "Writing",
                            eyebrow: "Application",
                            subtitle: "Draft and revise application essays."
                        ) {
                            HStack(spacing: DSSpacing.sm) {
                                Button {
                                    activeSheet = .addWriting(nil)
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.headline)
                                        .appCircleControl(emphasized: true)
                                }
                                .accessibilityLabel("New Writing Draft")
                                .accessibilityIdentifier("writing.new")

                                if canShowKnowledgeBaseVerification {
                                    Button {
                                        activeSheet = .knowledgeBase
                                    } label: {
                                        Image(systemName: "books.vertical")
                                            .font(.headline)
                                            .appCircleControl()
                                    }
                                    .accessibilityLabel("Knowledge Base Tools")
                                }
                            }
                        }
                        .accessibilityIdentifier("writing.pageHeader")

                        if !isWritingCoachDismissed {
                            AppCoachPanel(
                                title: "Use reflections when helpful.",
                                subtitle: "Bring in Journal or Insights material when a draft needs evidence.",
                                role: .quiet,
                                onDismiss: dismissWritingCoach
                            ) {
                                EmptyView()
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }

                        WritingTargetSectionView(
                            title: "Core Statements",
                            targets: coreTargets,
                            drafts: drafts,
                            requirements: requirements,
                            catalog: targetCatalogService,
                            usesWideLayout: usesWideWritingLayout
                        )

                        WritingTargetSectionView(
                            title: "Supplemental Essays",
                            targets: supplementalTargets,
                            drafts: drafts,
                            requirements: requirements,
                            catalog: targetCatalogService,
                            usesWideLayout: usesWideWritingLayout
                        )

                        WritingTargetSectionView(
                            title: "School-Specific Essays",
                            targets: schoolSpecificTargets,
                            drafts: drafts,
                            requirements: requirements,
                            catalog: targetCatalogService,
                            usesWideLayout: usesWideWritingLayout
                        )

                        if !applicationEntries.isEmpty {
                            ApplicationEntriesSection(
                                entries: applicationEntries,
                                usesWideLayout: usesWideWritingLayout,
                                onOpenExperienceLog: {
                                    activeSheet = .experienceLog
                                }
                            )
                        }

                        if !unassignedDrafts.isEmpty {
                            WritingAssignmentSection(
                                drafts: unassignedDrafts,
                                usesWideLayout: usesWideWritingLayout,
                                onAssign: { draft in
                                    activeSheet = .assignDraft(draft.id)
                                }
                            )
                        }
                    }
                    .frame(maxWidth: writingCanvasMaxWidth, alignment: .leading)
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.top, DSSpacing.md)
                    .padding(.bottom, DSSpacing.xxl)
                    .frame(maxWidth: .infinity)
                }
                .refreshable {
                    await refreshWritingList()
                }
            }
            .navigationDestination(for: WritingTargetDefinition.self) { target in
                WritingTargetDetailView(
                    target: target,
                    onCreateDraft: {
                        activeSheet = .addWriting(target.id)
                    },
                    onAddFromJournal: {
                        activeSheet = .journalPicker(target.id)
                    }
                )
            }
            .navigationDestination(for: UUID.self) { draftID in
                if let draft = drafts.first(where: { $0.id == draftID }) {
                    PSRichTextEditorView(draft: draft)
                } else {
                    WritingEmptySectionCard(message: "That draft is no longer available.")
                        .padding(DSSpacing.lg)
                }
            }
            .toolbar(navigationPath.isEmpty ? .hidden : .visible, for: .navigationBar)
            .background(Color.clear)
            .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
        }
    }

    private var wideWritingBody: some View {
        ZStack {
            if useImmersive {
                SacredScreenBackground(settings: settings)
            } else {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
            }

            NavigationSplitView(columnVisibility: $writingColumnVisibility) {
                writingSidebar
            } detail: {
                writingSplitDetail
            }
            .navigationSplitViewStyle(.balanced)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
    }

    private var writingSidebar: some View {
        ZStack {
            writingSidebarBackground
                .ignoresSafeArea(.container, edges: .vertical)

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    HStack(alignment: .center, spacing: DSSpacing.sm) {
                        Text("Writing")
                            .font(DSFont.sectionTitle)
                            .foregroundStyle(DSColor.textPrimary)

                        Spacer()

                        Button {
                            activeSheet = .addWriting(nil)
                        } label: {
                            Image(systemName: "plus")
                                .appCircleControl(emphasized: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("New Writing Draft")
                        .accessibilityIdentifier("writing.sidebar.new")

                        if canShowKnowledgeBaseVerification {
                            Button {
                                activeSheet = .knowledgeBase
                            } label: {
                                Image(systemName: "books.vertical")
                                    .appCircleControl()
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Knowledge Base Tools")
                        }
                    }
                    .padding(.top, DSSpacing.sm)

                    WritingSidebarRow(
                        title: "Writing Overview",
                        subtitle: nil,
                        icon: "doc.text.magnifyingglass",
                        isSelected: selectedWritingItem == .overview
                    ) {
                        selectWritingOverview()
                    }
                    .accessibilityIdentifier("writing.sidebar.overview")

                    writingTargetSidebarSection(title: "Core Statements", targets: coreTargets)
                    writingTargetSidebarSection(title: "Supplemental Essays", targets: supplementalTargets)
                    writingTargetSidebarSection(title: "School-Specific Essays", targets: schoolSpecificTargets)

                    if !unassignedDrafts.isEmpty {
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            WritingSidebarSectionTitle("Needs Assignment")
                            ForEach(unassignedDrafts) { draft in
                                WritingSidebarRow(
                                    title: draft.title.isEmpty ? "Untitled Draft" : draft.title,
                                    subtitle: "Updated \(relativeDate(for: draft.dateModified))",
                                    icon: "doc.text",
                                    isSelected: selectedWritingItem == .draft(draft.id)
                                ) {
                                    selectWritingDraft(draft.id)
                                }
                                .accessibilityIdentifier("writing.sidebar.draft.\(draft.id.uuidString)")
                            }
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.sm)
                .padding(.bottom, DSSpacing.lg)
            }
            .contentMargins(.top, 0, for: .scrollContent)
            .refreshable {
                await refreshWritingList()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var writingSidebarBackground: some View {
        if useImmersive {
            DSColor.quietSurface.opacity(0.82)
        } else {
            Color(uiColor: .secondarySystemGroupedBackground)
        }
    }

    @ViewBuilder
    private func writingTargetSidebarSection(
        title: String,
        targets: [WritingTargetDefinition]
    ) -> some View {
        if !targets.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                WritingSidebarSectionTitle(title)
                ForEach(targets) { target in
                    let isSelected = selectedWritingItem == .target(target.id)
                    let isExpanded = expandedWritingTargetID == target.id
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        WritingSidebarRow(
                            title: target.writingDisplayTitle,
                            subtitle: latestStatus(for: target),
                            icon: "doc.text",
                            isSelected: isSelected,
                            isExpanded: isExpanded
                        ) {
                            selectWritingTarget(target.id)
                        }
                        .accessibilityIdentifier("writing.sidebar.target.\(target.id)")

                        if isExpanded {
                            WritingSidebarExpandedTargetContent(
                                target: target,
                                drafts: matchedDrafts(for: target),
                                selectedDraftID: selectedDraftID,
                                onCreateDraft: {
                                    activeSheet = .addWriting(target.id)
                                },
                                onAddFromJournal: {
                                    activeSheet = .journalPicker(target.id)
                                },
                                onAddFromInsights: {
                                    settings.pendingWritingTargetID = target.id
                                    settings.selectedTab = .insights
                                },
                                onOpenDraft: { draft in
                                    selectWritingDraft(draft.id)
                                }
                            )
                            .transition(.opacity)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var writingSplitDetail: some View {
        switch selectedWritingItem ?? .overview {
        case .overview:
            WritingSplitWelcomeView(
                settings: settings,
                useImmersive: useImmersive,
                isWritingCoachDismissed: isWritingCoachDismissed,
                drafts: drafts,
                draftCount: drafts.count,
                targetCount: targets.count,
                targetTitleForDraft: targetTitle(for:),
                onDismissCoach: dismissWritingCoach,
                onCreateDraft: { activeSheet = .addWriting(nil) },
                onOpenDraft: { draft in
                    selectWritingDraft(draft.id)
                }
            )
        case .target(let targetID):
            if let target = targets.first(where: { $0.id == targetID }) {
                WritingTargetDetailView(
                    target: target,
                    onCreateDraft: {
                        activeSheet = .addWriting(target.id)
                    },
                    onAddFromJournal: {
                        activeSheet = .journalPicker(target.id)
                    },
                    onOpenDraft: { draft in
                        selectWritingDraft(draft.id)
                    }
                )
            } else {
                WritingEmptyDetailView(
                    message: "That writing target is no longer available.",
                    settings: settings,
                    useImmersive: useImmersive
                )
            }
        case .draft(let draftID):
            if let draft = drafts.first(where: { $0.id == draftID }) {
                PSRichTextEditorView(
                    draft: draft,
                    onClose: closeSplitDraft,
                    isWritingMapVisible: isWritingMapVisible,
                    onToggleWritingMap: toggleWritingMap,
                    onAdvisorPresentationChange: handleAdvisorPresentationChange
                )
            } else {
                WritingEmptyDetailView(
                    message: "That draft is no longer available.",
                    settings: settings,
                    useImmersive: useImmersive
                )
            }
        }
    }

    @ViewBuilder
    private func sheetContent(for route: WritingSheetRoute) -> some View {
        switch route {
        case .addWriting(let targetID):
            AddToStatementSheet(
                selectedEntries: [],
                selectedWorkspaceEntries: [],
                preselectedTargetID: targetID
            )
            .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
        case .journalPicker(let targetID):
            JournalEntrySelectionView(
                initialWritingTargetID: targetID
            )
            .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
        case .experienceLog:
            NavigationStack {
                ExperienceLogView()
            }
        case .knowledgeBase:
            if canShowKnowledgeBaseVerification {
                ToolsVerificationSheet()
            } else {
                EmptyView()
            }
        case .assignDraft(let draftID):
            if let draft = drafts.first(where: { $0.id == draftID }) {
                WritingDraftAssignmentSheet(
                    draft: draft,
                    targets: targets
                )
            } else {
                EmptyView()
            }
        }
    }

    private func dismissWritingCoach() {
        withAnimation(AnimationConfig.screenTransition) {
            isWritingCoachDismissed = true
        }
    }

    private func loadWritingTargets() async {
        let loadedRequirements: [StatementRequirement]
        if let currentProfile {
            loadedRequirements = await requirementsService.requirements(for: currentProfile)
        } else {
            loadedRequirements = []
        }

        requirements = loadedRequirements
        targets = targetCatalogService.targets(for: currentProfile, requirements: loadedRequirements)
        applicationEntries = applicationEntryCatalogService.entries(for: currentProfile)
    }

    private func consumePendingWritingDraftIfNeeded() {
        guard let draftID = settings.pendingWritingDraftID else { return }
        guard drafts.contains(where: { $0.id == draftID }) else { return }
        if usesWideWritingLayout {
            selectWritingDraft(draftID)
        } else {
            navigationPath.append(draftID)
        }
        settings.pendingWritingDraftID = nil
    }

    private func selectWritingOverview() {
        selectedWritingItem = .overview
        expandedWritingTargetID = nil
        writingColumnVisibility = .all
    }

    private func selectWritingTarget(_ targetID: String) {
        let shouldCollapseTarget = selectedWritingItem == .target(targetID)
            && expandedWritingTargetID == targetID

        withAnimation(AnimationConfig.screenTransition) {
            selectedWritingItem = .target(targetID)
            expandedWritingTargetID = shouldCollapseTarget ? nil : targetID
            writingColumnVisibility = .all
        }
    }

    private func selectWritingDraft(_ draftID: UUID) {
        selectedWritingItem = .draft(draftID)
        expandedWritingTargetID = drafts.first(where: { $0.id == draftID })?.writingTargetID
        writingColumnVisibility = .detailOnly
    }

    private var isWritingMapVisible: Bool {
        switch writingColumnVisibility {
        case .detailOnly:
            return false
        default:
            return true
        }
    }

    private func toggleWritingMap() {
        writingColumnVisibility = isWritingMapVisible ? .detailOnly : .all
    }

    private func handleAdvisorPresentationChange(_ isPresented: Bool) {
        if isPresented {
            writingColumnVisibility = .detailOnly
        }
    }

    private func closeSplitDraft() {
        selectWritingOverview()
    }

    private func latestStatus(for target: WritingTargetDefinition) -> String {
        guard let latest = drafts
            .filter({ $0.writingTargetID == target.id })
            .sorted(by: { $0.dateModified > $1.dateModified })
            .first else {
            return "No drafts yet"
        }

        let stamp = relativeDate(for: latest.dateModified)
        if latest.isSnapshot {
            return "Snapshot updated \(stamp)"
        }
        return "Updated \(stamp)"
    }

    private func matchedDrafts(for target: WritingTargetDefinition) -> [StatementDraft] {
        drafts.filter { $0.writingTargetID == target.id }
    }

    private func targetTitle(for draft: StatementDraft) -> String {
        guard let writingTargetID = draft.writingTargetID,
              let target = targets.first(where: { $0.id == writingTargetID }) else {
            return "Needs Assignment"
        }
        return target.writingDisplayTitle
    }

    private func relativeDate(for date: Date) -> String {
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }

    @MainActor
    private func refreshWritingList() async {
        // CloudKit sync is system-driven; fetching refreshes the local SwiftData snapshot
        // after incoming draft changes have landed.
        _ = try? modelContext.fetch(FetchDescriptor<StatementDraft>())
        consumePendingWritingDraftIfNeeded()
        try? await Task.sleep(nanoseconds: 350_000_000)
    }

    private func importDraft(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(StatementDraftFilePayload.self, from: data) else {
            return
        }

        _ = StatementDraft.fromPayload(payload, context: modelContext, asCopy: true)
        _ = persistChanges("import that draft")
    }

    @discardableResult
    private func persistChanges(_ operation: String) -> Bool {
        do {
            return try modelContext.persistIfNeeded(for: operation)
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
}

private struct WritingTargetSectionView: View {
    let title: String
    var subtitle: String? = nil
    let targets: [WritingTargetDefinition]
    let drafts: [StatementDraft]
    let requirements: [StatementRequirement]
    let catalog: LocalWritingTargetCatalogService
    let usesWideLayout: Bool

    private var columns: [GridItem] {
        [
            GridItem(
                usesWideLayout ? .adaptive(minimum: 260, maximum: 360) : .flexible(),
                spacing: DSSpacing.sm,
                alignment: .top
            )
        ]
    }

    var body: some View {
        AppPanel(title: title, subtitle: subtitle, role: .interactive) {
            if targets.isEmpty {
                WritingEmptySectionCard(message: "No essay types are active for your current profile yet.")
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: DSSpacing.sm) {
                    ForEach(targets) { target in
                        NavigationLink(value: target) {
                            WritingTargetCard(
                                target: target,
                                draftCount: draftCount(for: target),
                                latestStatus: latestStatus(for: target)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("writing.target.\(target.id)")
                    }
                }
            }
        }
    }

    private func draftCount(for target: WritingTargetDefinition) -> Int {
        drafts.filter { $0.writingTargetID == target.id }.count
    }

    private func latestStatus(for target: WritingTargetDefinition) -> String {
        guard let latest = drafts
            .filter({ $0.writingTargetID == target.id })
            .sorted(by: { $0.dateModified > $1.dateModified })
            .first else {
            return "No drafts yet"
        }

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        let stamp = relative.localizedString(for: latest.dateModified, relativeTo: Date())
        if latest.isSnapshot {
            return "Snapshot updated \(stamp)"
        }
        return "Updated \(stamp)"
    }
}

private struct ApplicationEntriesSection: View {
    let entries: [ApplicationEntryDefinition]
    let usesWideLayout: Bool
    let onOpenExperienceLog: () -> Void

    private var columns: [GridItem] {
        [
            GridItem(
                usesWideLayout ? .adaptive(minimum: 300, maximum: 420) : .flexible(),
                spacing: DSSpacing.sm,
                alignment: .top
            )
        ]
    }

    var body: some View {
        AppPanel(
            title: "Application Entries",
            subtitle: "Structured application fields stay anchored in Application Records, with the official CAS names surfaced here for clarity.",
            role: .interactive
        ) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: DSSpacing.sm) {
                ForEach(entries) { entry in
                    Button(action: onOpenExperienceLog) {
                        HStack(spacing: DSSpacing.sm) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title)
                                    .font(DSFont.sectionTitle)
                                    .foregroundStyle(DSColor.textPrimary)
                                    .lineLimit(2)
                                Text(entry.summary)
                                    .font(DSFont.supporting)
                                    .foregroundStyle(DSColor.quietText)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 6) {
                                    Text(entry.serviceLabel)
                                        .font(DSFont.caption)
                                        .foregroundStyle(DSColor.brandAccent)
                                    if !entry.metadataSummary.isEmpty {
                                        Text("•")
                                            .font(DSFont.caption)
                                            .foregroundStyle(DSColor.textSecondary)
                                        Text(entry.metadataSummary)
                                            .font(DSFont.caption)
                                            .foregroundStyle(DSColor.textSecondary)
                                    }
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(DSColor.brandAccent)
                        }
                        .padding(DSSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appSurfaceStyle(role: .interactive, highlighted: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("writing.applicationEntry.\(entry.id)")
                }
            }
        }
    }
}

private struct WritingAssignmentSection: View {
    let drafts: [StatementDraft]
    let usesWideLayout: Bool
    let onAssign: (StatementDraft) -> Void

    private var columns: [GridItem] {
        [
            GridItem(
                usesWideLayout ? .adaptive(minimum: 300, maximum: 420) : .flexible(),
                spacing: DSSpacing.sm,
                alignment: .top
            )
        ]
    }

    var body: some View {
        AppPanel(
            title: "Needs Assignment",
            subtitle: "Older drafts stay editable. Assign them to an essay type when you know where they belong.",
            role: .interactive
        ) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: DSSpacing.sm) {
                ForEach(drafts) { draft in
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        NavigationLink(value: draft.id) {
                            WritingDraftRow(draft: draft, targetTitle: "Needs Assignment")
                        }
                        .buttonStyle(.plain)

                        Button("Assign Essay Type") {
                            onAssign(draft)
                        }
                        .buttonStyle(.appSecondary)
                        .accessibilityIdentifier("writing.assign.\(draft.id.uuidString)")
                    }
                }
            }
        }
    }
}

private struct WritingTargetCard: View {
    let target: WritingTargetDefinition
    let draftCount: Int
    let latestStatus: String

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(target.writingDisplayTitle)
                    .font(DSFont.sectionTitle)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: DSSpacing.sm) {
                Text("\(draftCount) draft\(draftCount == 1 ? "" : "s")")
                    .font(DSFont.meta.weight(.semibold))
                    .foregroundStyle(DSColor.textSecondary)
            }

            HStack(alignment: .center, spacing: DSSpacing.sm) {
                Text(latestStatus)
                    .font(DSFont.meta)
                    .foregroundStyle(DSColor.quietText)
                    .lineLimit(2)
                Spacer(minLength: DSSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSColor.brandAccent)
                    .accessibilityHidden(true)
            }
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurfaceStyle(role: .reading, highlighted: true)
        .accessibilityLabel("\(target.writingDisplayTitle), \(draftCount) drafts, \(latestStatus)")
    }
}

private struct WritingDraftRow: View {
    let draft: StatementDraft
    let targetTitle: String

    private var displayTitle: String {
        draft.title.isEmpty ? "Untitled Draft" : draft.title
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: draft.dateModified, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(targetTitle)
                .font(DSFont.eyebrow)
                .foregroundStyle(DSColor.quietTextMuted)
                .textCase(.uppercase)

            HStack {
                Text(displayTitle)
                    .font(DSFont.heading2)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(2)
                Spacer()
                if draft.isSnapshot {
                    Text("Snapshot")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.goldLight)
                }
            }

            Text("\(draft.draftScope.displayName) • Updated \(relativeDate)")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.md)
        .appSurfaceStyle(role: .interactive, highlighted: false)
    }
}

private struct WritingEmptySectionCard: View {
    let message: String

    var body: some View {
        Text(message)
            .font(DSFont.supporting)
            .foregroundStyle(DSColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSSpacing.md)
            .appSurfaceStyle(role: .quiet, highlighted: false)
    }
}

private struct WritingSidebarSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(DSFont.eyebrow)
            .foregroundStyle(DSColor.quietTextMuted)
            .textCase(.uppercase)
            .tracking(0.8)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.top, DSSpacing.xs)
    }
}

private struct WritingSidebarRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let isSelected: Bool
    var isExpanded: Bool? = nil
    let action: () -> Void

    private var accessibilityText: String {
        [title, subtitle].compactMap { $0 }.joined(separator: ", ")
    }

    private var stateValue: String {
        var values: [String] = []
        if isSelected {
            values.append("Selected")
        }
        if let isExpanded {
            values.append(isExpanded ? "Expanded" : "Collapsed")
        }
        return values.joined(separator: ", ")
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DSSpacing.sm) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isSelected ? DSColor.brandAccent : Color.clear)
                    .frame(width: 3)
                    .padding(.vertical, 3)
                    .accessibilityHidden(true)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? DSColor.brandAccent : DSColor.quietTextMuted)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DSFont.body.weight(.semibold))
                        .foregroundStyle(isSelected ? DSColor.brandAccent : DSColor.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle {
                        Text(subtitle)
                            .font(DSFont.meta)
                            .foregroundStyle(DSColor.quietText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: DSSpacing.xs)

                if let isExpanded {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? DSColor.brandAccent : DSColor.quietTextMuted)
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? DSColor.brandAccentSoft : DSColor.quietSurface.opacity(0.38))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? DSColor.brandAccent.opacity(0.34) : DSColor.dividerSoft, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityValue(stateValue)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct WritingSidebarExpandedTargetContent: View {
    let target: WritingTargetDefinition
    let drafts: [StatementDraft]
    let selectedDraftID: UUID?
    let onCreateDraft: () -> Void
    let onAddFromJournal: () -> Void
    let onAddFromInsights: () -> Void
    let onOpenDraft: (StatementDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            VStack(spacing: DSSpacing.xs) {
                WritingSidebarTargetActionButton(
                    title: "Create Draft",
                    systemImage: "plus",
                    emphasized: true,
                    action: onCreateDraft
                )
                WritingSidebarTargetActionButton(
                    title: "Add from Journal",
                    systemImage: "book",
                    emphasized: false,
                    action: onAddFromJournal
                )
                WritingSidebarTargetActionButton(
                    title: "Add from Insights",
                    systemImage: "sparkles",
                    emphasized: false,
                    action: onAddFromInsights
                )
            }

            if drafts.isEmpty {
                Text("No drafts yet")
                    .font(DSFont.meta)
                    .foregroundStyle(DSColor.quietText)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, DSSpacing.md)
                    .accessibilityLabel("\(target.writingDisplayTitle), no drafts yet")
            } else {
                VStack(spacing: DSSpacing.xs) {
                    ForEach(drafts) { draft in
                        WritingSidebarDraftChildRow(
                            draft: draft,
                            isSelected: selectedDraftID == draft.id,
                            action: {
                                onOpenDraft(draft)
                            }
                        )
                        .accessibilityIdentifier("writing.sidebar.target.\(target.id).draft.\(draft.id.uuidString)")
                    }
                }
            }
        }
        .padding(.leading, DSSpacing.lg)
        .padding(.trailing, DSSpacing.xs)
        .accessibilityElement(children: .contain)
    }
}

private struct WritingSidebarTargetActionButton: View {
    let title: String
    let systemImage: String
    let emphasized: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 20)
                    .accessibilityHidden(true)

                Text(title)
                    .font(DSFont.meta.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: DSSpacing.xs)
            }
            .foregroundStyle(emphasized ? DSColor.backgroundPrimary : DSColor.textPrimary)
            .padding(.horizontal, DSSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(emphasized ? DSColor.brandAccent : DSColor.quietSurface.opacity(0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(emphasized ? Color.clear : DSColor.dividerSoft, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct WritingSidebarDraftChildRow: View {
    let draft: StatementDraft
    let isSelected: Bool
    let action: () -> Void

    private var title: String {
        draft.title.isEmpty ? "Untitled Draft" : draft.title
    }

    private var updatedText: String {
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return "Updated \(relative.localizedString(for: draft.dateModified, relativeTo: Date()))"
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DSSpacing.sm) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? DSColor.brandAccent : DSColor.quietTextMuted)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(DSFont.meta.weight(.semibold))
                        .foregroundStyle(isSelected ? DSColor.brandAccent : DSColor.textPrimary)
                        .lineLimit(2)
                    Text(updatedText)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.quietText)
                        .lineLimit(1)
                }

                Spacer(minLength: DSSpacing.xs)
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? DSColor.brandAccentSoft : DSColor.quietSurface.opacity(0.28))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? DSColor.brandAccent.opacity(0.28) : DSColor.dividerSoft, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(updatedText)")
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct WritingSplitWelcomeView: View {
    let settings: AppSettings
    let useImmersive: Bool
    let isWritingCoachDismissed: Bool
    let drafts: [StatementDraft]
    let draftCount: Int
    let targetCount: Int
    let targetTitleForDraft: (StatementDraft) -> String
    let onDismissCoach: () -> Void
    let onCreateDraft: () -> Void
    let onOpenDraft: (StatementDraft) -> Void

    var body: some View {
        ZStack {
            if useImmersive {
                SacredScreenBackground(settings: settings)
            } else {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
            }

            AppPageScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    AppPageHeader(
                        title: "Writing Desk",
                        eyebrow: "iPad Workspace",
                        subtitle: "Choose an essay type or draft from the sidebar, then keep your prompt and writing space open together."
                    ) {
                        Button {
                            onCreateDraft()
                        } label: {
                            Label("New Draft", systemImage: "plus")
                                .font(DSFont.body.weight(.semibold))
                        }
                        .buttonStyle(.appPrimary)
                    }

                    if !isWritingCoachDismissed {
                        AppCoachPanel(
                            title: "Use the sidebar as your writing map.",
                            subtitle: "Landscape gives you a stable index of essay types and drafts while the detail pane stays focused on the current prompt or draft.",
                            role: .quiet,
                            highlighted: useImmersive,
                            onDismiss: onDismissCoach
                        ) {
                            EmptyView()
                        }
                    }

                    AppPanel(
                        title: "Current Drafts",
                        subtitle: drafts.isEmpty
                            ? "Start a draft from the sidebar or create one here when you are ready."
                            : "Open a draft and continue shaping it without leaving the writing desk.",
                        role: .interactive
                    ) {
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            HStack(spacing: DSSpacing.sm) {
                                AppInfoChip(
                                    text: "\(targetCount) essay type\(targetCount == 1 ? "" : "s")",
                                    icon: "list.bullet.rectangle"
                                )
                                AppInfoChip(
                                    text: "\(draftCount) draft\(draftCount == 1 ? "" : "s")",
                                    icon: "doc.text"
                                )
                            }

                            if drafts.isEmpty {
                                WritingEmptySectionCard(message: "No drafts yet. Create one when you are ready to begin.")
                            } else {
                                VStack(spacing: DSSpacing.sm) {
                                    ForEach(drafts) { draft in
                                        Button {
                                            onOpenDraft(draft)
                                        } label: {
                                            WritingDraftRow(
                                                draft: draft,
                                                targetTitle: targetTitleForDraft(draft)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("writing.overview.draft.\(draft.id.uuidString)")
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct WritingEmptyDetailView: View {
    let message: String
    let settings: AppSettings
    let useImmersive: Bool

    var body: some View {
        ZStack {
            if useImmersive {
                SacredScreenBackground(settings: settings)
            } else {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
            }
            WritingEmptySectionCard(message: message)
                .frame(maxWidth: 520)
                .padding(DSSpacing.lg)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct WritingTargetDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let target: WritingTargetDefinition
    let onCreateDraft: () -> Void
    let onAddFromJournal: () -> Void
    var onOpenDraft: ((StatementDraft) -> Void)? = nil

    @Query(sort: [SortDescriptor(\StatementDraft.dateModified, order: .reverse)])
    private var drafts: [StatementDraft]

    private var matchedDrafts: [StatementDraft] {
        drafts.filter { $0.writingTargetID == target.id }
    }

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }

    private var usesWideLayout: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var detailCanvasMaxWidth: CGFloat {
        usesWideLayout ? 920 : .infinity
    }

    private var actionColumns: [GridItem] {
        [
            GridItem(
                usesWideLayout ? .adaptive(minimum: 220, maximum: 280) : .flexible(),
                spacing: DSSpacing.sm,
                alignment: .top
            )
        ]
    }

    var body: some View {
        ZStack {
            if useImmersive {
                SacredScreenBackground(settings: settings)
            } else {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    AppPanel(
                        title: target.writingDisplayTitle,
                        subtitle: target.summary,
                        role: .reading,
                        highlighted: true
                    ) {
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            Text(target.promptText)
                                .font(DSFont.body)
                                .foregroundStyle(DSColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("writing.target.prompt")

                            HStack(spacing: DSSpacing.sm) {
                                Text(target.limitSummary)
                                    .font(DSFont.caption)
                                    .foregroundStyle(DSColor.textSecondary)
                                if let service = target.serviceCode {
                                    Text("•")
                                        .font(DSFont.caption)
                                        .foregroundStyle(DSColor.textSecondary)
                                    Text(service.displayName)
                                        .font(DSFont.caption)
                                        .foregroundStyle(DSColor.textSecondary)
                                }
                            }

                            if let officialTitleSupportingText = target.officialTitleSupportingText {
                                Text(officialTitleSupportingText)
                                    .font(DSFont.caption)
                                    .foregroundStyle(DSColor.quietText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if let officialLink = target.officialLink,
                               let url = URL(string: officialLink) {
                                Link("Official guidance", destination: url)
                                    .font(DSFont.caption.weight(.semibold))
                            }
                        }
                    }

                    if !usesWideLayout {
                        AppPanel(
                            title: "Actions",
                            subtitle: "Stay grounded in the prompt while deciding how to start this draft.",
                            role: .interactive
                        ) {
                            LazyVGrid(columns: actionColumns, alignment: .leading, spacing: DSSpacing.sm) {
                                Button("Create Draft") {
                                    onCreateDraft()
                                }
                                .buttonStyle(.appPrimary)
                                .accessibilityIdentifier("writing.target.create")

                                Button("Add from Journal") {
                                    onAddFromJournal()
                                }
                                .buttonStyle(.appSecondary)
                                .accessibilityIdentifier("writing.target.addJournal")

                                Button("Add from Insights") {
                                    settings.pendingWritingTargetID = target.id
                                    settings.selectedTab = .insights
                                    dismiss()
                                }
                                .buttonStyle(.appSecondary)
                                .accessibilityIdentifier("writing.target.addInsights")
                            }
                        }
                    }

                    AppPanel(
                        title: "Drafts",
                        subtitle: matchedDrafts.isEmpty ? "No drafts are assigned here yet." : "Open and continue shaping any draft already tied to this target.",
                        role: .interactive
                    ) {
                        if matchedDrafts.isEmpty {
                            WritingEmptySectionCard(message: "Start a draft here when you are ready.")
                        } else {
                            VStack(spacing: DSSpacing.sm) {
                                ForEach(matchedDrafts) { draft in
                                    if let onOpenDraft {
                                        Button {
                                            onOpenDraft(draft)
                                        } label: {
                                            WritingDraftRow(draft: draft, targetTitle: target.writingDisplayTitle)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("writing.target.draft.\(draft.id.uuidString)")
                                    } else {
                                        NavigationLink(value: draft.id) {
                                            WritingDraftRow(draft: draft, targetTitle: target.writingDisplayTitle)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("writing.target.draft.\(draft.id.uuidString)")
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: detailCanvasMaxWidth, alignment: .leading)
                .padding(.horizontal, DSSpacing.lg)
                .padding(.vertical, DSSpacing.lg)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(target.writingDisplayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
    }
}

struct WritingDraftAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var draft: StatementDraft
    let targets: [WritingTargetDefinition]
    @State private var persistenceAlert: PersistenceAlertContext?

    private var showsProfileGuidance: Bool {
        targets.contains(where: { $0.serviceCode == nil })
            && !targets.contains(where: { $0.serviceCode != nil })
    }

    var body: some View {
        WritingTargetPickerSheet(
            targets: targets,
            selectedTargetID: Binding(
                get: { draft.writingTargetID },
                set: { newValue in
                    guard let newValue, let target = targets.first(where: { $0.id == newValue }) else { return }
                    draft.assignWritingTarget(target)
                    draft.dateModified = Date()
                    draft.isLocked = false
                    persist()
                    dismiss()
                }
            ),
            isLoading: false,
            showsProfileGuidance: showsProfileGuidance
        )
        .persistenceFailureAlert($persistenceAlert)
    }

    private func persist() {
        do {
            try modelContext.persistIfNeeded(for: "assign that essay type")
        } catch let error as PersistenceOperationError {
            persistenceAlert = error.alertContext
        } catch {
            persistenceAlert = PersistenceAlertContext.saveFailure(
                for: "assign that essay type",
                details: error.localizedDescription
            )
        }
    }
}
