import SwiftUI
import SwiftData

struct AddToStatementSheet: View {
    @Environment(\.dismiss) private var dismiss

    var selectedEntries: [ExamenSession]
    var selectedWorkspaceEntries: [InsightWorkspaceEntry] = []
    var preselectedTargetID: String? = nil
    var onDraftCreated: ((StatementDraft) -> Void)? = nil
    var onComplete: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            AddToDraftDestinationView(
                selectedEntries: selectedEntries,
                selectedWorkspaceEntries: selectedWorkspaceEntries,
                preselectedTargetID: preselectedTargetID,
                onDraftCreated: onDraftCreated,
                onCancel: { dismiss() },
                onComplete: {
                    onComplete?()
                    dismiss()
                }
            )
        }
    }
}

struct AddToDraftDestinationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    let selectedEntries: [ExamenSession]
    let selectedWorkspaceEntries: [InsightWorkspaceEntry]
    let preselectedTargetID: String?
    var onDraftCreated: ((StatementDraft) -> Void)? = nil
    let onCancel: () -> Void
    let onComplete: () -> Void

    @Query(sort: \StatementDraft.dateModified, order: .reverse)
    private var drafts: [StatementDraft]
    @Query(sort: \ExamenSession.date, order: .reverse)
    private var allSessions: [ExamenSession]
    @Query(sort: \UserProfile.id)
    private var profiles: [UserProfile]

    @State private var requirements: [StatementRequirement] = []
    @State private var availableTargets: [WritingTargetDefinition] = []
    @State private var selectedTargetID: String?
    @State private var workingTitle = ""
    @State private var customPromptText = ""
    @State private var showingTargetPicker = false
    @State private var isLoadingTargets = true
    @State private var persistenceAlert: PersistenceAlertContext?

    private let requirementsService = LocalStatementRequirementsService()
    private let targetCatalogService = LocalWritingTargetCatalogService()

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }

    private var currentProfile: UserProfile? {
        profiles.first
    }

    private var selectedTarget: WritingTargetDefinition? {
        availableTargets.first(where: { $0.id == selectedTargetID })
    }

    private var selectedTargetLabel: String {
        selectedTarget?.title ?? "Select essay type"
    }

    private var canCreateDraft: Bool {
        guard !isLoadingTargets else { return false }
        guard let selectedTarget else { return false }
        if selectedTarget.category == .schoolSpecificEssay {
            return !resolvedDraftTitle(for: selectedTarget).isEmpty
        }
        return true
    }

    private var hasSourceMaterial: Bool {
        !selectedEntries.isEmpty || !selectedWorkspaceEntries.isEmpty
    }

    private var isShowingFallbackEssayTypes: Bool {
        !isLoadingTargets && requirements.isEmpty && !availableTargets.isEmpty
    }

    private var selectionCountText: String {
        switch (selectedEntries.count, selectedWorkspaceEntries.count) {
        case (0, 0):
            return "No source material selected"
        case (let entryCount, 0):
            return "\(entryCount) reflection\(entryCount == 1 ? "" : "s") selected"
        case (0, let workspaceCount):
            return "\(workspaceCount) brainstorming note\(workspaceCount == 1 ? "" : "s") selected"
        case (let entryCount, let workspaceCount):
            return "\(entryCount) reflection\(entryCount == 1 ? "" : "s") + \(workspaceCount) brainstorming note\(workspaceCount == 1 ? "" : "s")"
        }
    }

    private var createButtonTitle: String {
        "New Draft"
    }

    private var eligibleDrafts: [StatementDraft] {
        guard let selectedTargetID else { return drafts }
        return drafts.filter {
            $0.writingTargetID == nil || $0.writingTargetID == selectedTargetID
        }
    }

    private var groupedDrafts: [(label: String, drafts: [StatementDraft])] {
        let grouped = Dictionary(grouping: eligibleDrafts) { draft in
            targetLabel(for: draft)
        }

        return grouped.keys.sorted().map { key in
            let items = grouped[key, default: []].sorted { $0.dateModified > $1.dateModified }
            return (label: key, drafts: items)
        }
    }

    var body: some View {
        ZStack {
            if useImmersive {
                SacredScreenBackground(settings: settings)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                        VStack(alignment: .leading, spacing: DSSpacing.md) {
                            Text("New Draft")
                                .font(DSFont.sectionTitle)
                                .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)

                        AppInfoChip(text: selectionCountText, icon: "square.and.pencil")

                        if let selectedTarget {
                            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                                Text("Draft name")
                                    .font(DSFont.body.weight(.semibold))
                                    .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)

                                TextField(
                                    draftNamePlaceholder(for: selectedTarget),
                                    text: $workingTitle
                                )
                                .font(DSFont.body.weight(.semibold))
                                .textInputAutocapitalization(.words)
                                .submitLabel(.done)
                                .padding(DSSpacing.md)
                                .frame(minHeight: 58)
                                .background(useImmersive ? DSColor.surfaceElevated : Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(useImmersive ? DSColor.brandAccent.opacity(0.36) : DSColor.dividerSoft, lineWidth: 1)
                                )
                                .accessibilityLabel("Draft name")
                            }
                        }

                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            Text("Essay type")
                                .font(DSFont.meta)
                                .foregroundStyle(useImmersive ? DSColor.quietTextMuted : .secondary)

                            Button {
                                showingTargetPicker = true
                            } label: {
                                HStack(spacing: DSSpacing.sm) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(selectedTargetLabel)
                                            .font(DSFont.body.weight(.semibold))
                                            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                                        if let selectedTarget {
                                            Text(selectedTarget.limitSummary)
                                                .font(DSFont.caption)
                                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                        } else if isLoadingTargets {
                                            Text("Loading essay types...")
                                                .font(DSFont.caption)
                                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                        } else {
                                            Text("Choose the prompt this will support.")
                                                .font(DSFont.caption)
                                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundStyle(useImmersive ? DSColor.goldLight : DSColor.brandAccent)
                                }
                                .padding(DSSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .appSurfaceStyle(role: .interactive, highlighted: selectedTarget != nil)
                            .accessibilityIdentifier("writing.destination.target")
                        }

                        if isShowingFallbackEssayTypes {
                            Text("General essay types are available now. Profile details can refine this later.")
                                .font(DSFont.caption)
                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                .accessibilityIdentifier("writing.destination.guidance")
                        }

                        if let selectedTarget {
                            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                                if selectedTarget.category == .schoolSpecificEssay || selectedTarget.allowsCustomPrompt {
                                    Text("Prompt")
                                        .font(DSFont.meta)
                                        .foregroundStyle(useImmersive ? DSColor.quietTextMuted : .secondary)

                                    TextEditor(text: $customPromptText)
                                        .frame(minHeight: 120)
                                        .padding(8)
                                        .background(useImmersive ? DSColor.surfaceElevated : Color(uiColor: .secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .accessibilityLabel("Custom prompt text")

                                    Text(customPromptHelpText(for: selectedTarget))
                                        .font(DSFont.caption)
                                        .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                }
                            }
                        }

                        Button {
                            createNewDraft(scope: .full)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.pencil")
                                Text(createButtonTitle)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.appPrimary)
                        .disabled(!canCreateDraft)
                        .accessibilityIdentifier("writing.destination.create")
                    }
                    .padding(DSSpacing.lg)
                    .appSurfaceStyle(role: .interactive, highlighted: true)

                    if hasSourceMaterial && !groupedDrafts.isEmpty {
                        VStack(alignment: .leading, spacing: DSSpacing.md) {
                            Text("Add to Existing Draft")
                                .font(DSFont.sectionTitle)
                                .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)

                            ForEach(groupedDrafts, id: \.label) { group in
                                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                                    Text(group.label)
                                        .font(DSFont.caption)
                                        .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)

                                    ForEach(group.drafts) { draft in
                                        Button {
                                            addToDraft(draft)
                                        } label: {
                                            HStack(alignment: .top, spacing: DSSpacing.sm) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(draft.title)
                                                        .font(DSFont.body.weight(.semibold))
                                                        .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                                                    Text(existingDraftMetadata(for: draft))
                                                        .font(DSFont.caption)
                                                        .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                                }
                                                Spacer()
                                                if draft.isSnapshot {
                                                    Text("Snapshot")
                                                        .font(DSFont.caption)
                                                        .foregroundStyle(useImmersive ? DSColor.goldLight : .orange)
                                                }
                                            }
                                            .padding(.horizontal, DSSpacing.md)
                                            .padding(.vertical, DSSpacing.md)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
                                        .appSurfaceStyle(role: .interactive, highlighted: false)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.vertical, DSSpacing.lg)
            }
            .scrollIndicators(.hidden)
            .background(Color.clear)
            .navigationTitle("Use in Writing")
            .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .sheet(isPresented: $showingTargetPicker) {
                WritingTargetPickerSheet(
                    targets: availableTargets,
                    selectedTargetID: $selectedTargetID,
                    isLoading: isLoadingTargets,
                    showsProfileGuidance: isShowingFallbackEssayTypes
                )
                .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
            }
            .persistenceFailureAlert($persistenceAlert)
        }
        .task(id: profileSignature) {
            await loadTargets()
            consumePendingTargetIfNeeded()
        }
        .onAppear {
            consumePendingTargetIfNeeded()
        }
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

    private func consumePendingTargetIfNeeded() {
        if selectedTargetID == nil {
            selectedTargetID = preselectedTargetID ?? settings.pendingWritingTargetID
        }
        settings.pendingWritingTargetID = nil
    }

    private func loadTargets() async {
        isLoadingTargets = true
        let loadedRequirements: [StatementRequirement]
        if let currentProfile {
            loadedRequirements = await requirementsService.requirements(for: currentProfile)
        } else {
            loadedRequirements = []
        }

        requirements = loadedRequirements
        availableTargets = targetCatalogService.targets(for: currentProfile, requirements: loadedRequirements)
        if selectedTargetID == nil || !availableTargets.contains(where: { $0.id == selectedTargetID }) {
            selectedTargetID = preselectedTargetID ?? settings.pendingWritingTargetID
        }
        isLoadingTargets = false
    }

    private func resolvedDraftTitle(for target: WritingTargetDefinition) -> String {
        let trimmedTitle = workingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        return target.writingDisplayTitle
    }

    private func draftNamePlaceholder(for target: WritingTargetDefinition) -> String {
        "\(target.writingDisplayTitle) draft"
    }

    private func customPromptHelpText(for target: WritingTargetDefinition) -> String {
        if target.category == .schoolSpecificEssay {
            return "Paste the school prompt so the draft keeps its context."
        }
        return "Optional: keep the specific prompt with the draft when this target needs more detail."
    }

    private func createNewDraft(scope: StatementDraftScope = .full) {
        guard let selectedTarget else { return }

        let newDraft = StatementDraft(
            title: resolvedDraftTitle(for: selectedTarget),
            draftScope: scope,
            writingTargetID: selectedTarget.id,
            writingTargetCategory: selectedTarget.category,
            customPromptText: cleanedCustomPrompt(for: selectedTarget)
        )

        let appendedSections = appendSources(to: newDraft)
        modelContext.insert(newDraft)

        guard persistChanges("create that draft") else {
            newDraft.sections.removeAll { section in
                appendedSections.contains(where: { $0.id == section.id })
            }
            modelContext.delete(newDraft)
            return
        }

        onDraftCreated?(newDraft)
        onComplete()
    }

    private func addToDraft(_ draft: StatementDraft) {
        let originalModifiedDate = draft.dateModified
        let originalTargetID = draft.writingTargetID
        let originalCategory = draft.writingTargetCategoryRaw
        let originalCustomPrompt = draft.customPromptText

        if let selectedTarget, draft.writingTargetID == nil {
            draft.assignWritingTarget(selectedTarget)
            draft.customPromptText = cleanedCustomPrompt(for: selectedTarget)
        }

        let appendedSections = appendSources(to: draft)
        draft.dateModified = Date()
        draft.isLocked = false

        guard persistChanges("add that writing source") else {
            draft.sections.removeAll { section in
                appendedSections.contains(where: { $0.id == section.id })
            }
            draft.dateModified = originalModifiedDate
            draft.writingTargetID = originalTargetID
            draft.writingTargetCategoryRaw = originalCategory
            draft.customPromptText = originalCustomPrompt
            return
        }

        onComplete()
    }

    private func cleanedCustomPrompt(for target: WritingTargetDefinition) -> String? {
        let trimmed = customPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard target.category == .schoolSpecificEssay || target.allowsCustomPrompt else { return nil }
        return trimmed
    }

    private func appendSources(to draft: StatementDraft) -> [StatementSection] {
        let startOrder = (draft.sections.map { $0.order }.max() ?? -1) + 1

        let sortedEntries = selectedEntries.sorted(by: { $0.date < $1.date })
        let sortedWorkspaceEntries = selectedWorkspaceEntries.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.updatedAt < rhs.updatedAt
        }

        var appendedSections: [StatementSection] = []
        var nextOrder = startOrder

        for entry in sortedEntries {
            let section = StatementSection(
                source: .journalEntry,
                content: entry.mergedDraftContent(),
                order: nextOrder,
                sourceID: entry.id
            )
            draft.sections.append(section)
            appendedSections.append(section)
            nextOrder += 1
        }

        for workspaceEntry in sortedWorkspaceEntries {
            let linkedEntries = allSessions.filter { workspaceEntry.sourceEntryIDs.contains($0.id) }
            let section = StatementSection(
                source: .insightWorkspace,
                content: workspaceEntry.draftSourceContent(linkedSourceEntries: linkedEntries),
                order: nextOrder,
                sourceID: workspaceEntry.id
            )
            draft.sections.append(section)
            appendedSections.append(section)
            nextOrder += 1
        }

        return appendedSections
    }

    private func existingDraftMetadata(for draft: StatementDraft) -> String {
        let modifiedDate = draft.dateModified.formatted(date: .abbreviated, time: .omitted)
        return "\(draft.draftScope.shortLabel) • v\(draft.version) • Updated \(modifiedDate)"
    }

    private func targetLabel(for draft: StatementDraft) -> String {
        if let target = targetCatalogService.target(
            withID: draft.writingTargetID,
            for: currentProfile,
            requirements: requirements
        ) {
            return target.writingDisplayTitle
        }
        return "Needs Assignment"
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

struct WritingTargetPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let targets: [WritingTargetDefinition]
    @Binding var selectedTargetID: String?
    let isLoading: Bool
    let showsProfileGuidance: Bool

    private var groupedTargets: [(category: WritingTargetCategory, items: [WritingTargetDefinition])] {
        WritingTargetCategory.allCases.compactMap { category in
            let items = targets.filter { $0.category == category }
            guard !items.isEmpty else { return nil }
            return (category: category, items: items)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: DSSpacing.md) {
                        ProgressView()
                        Text("Loading essay types...")
                            .font(DSFont.body.weight(.semibold))
                        Text("Illuminote is preparing the options that fit your current profile and writing flow.")
                            .font(DSFont.supporting)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(DSSpacing.xl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if groupedTargets.isEmpty {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        Text("No essay types available")
                            .font(DSFont.sectionTitle)
                        Text("Illuminote couldn't load any essay types right now. Try again, or update your profile if you expected service-specific prompts and limits.")
                            .font(DSFont.supporting)
                            .foregroundStyle(.secondary)
                    }
                    .padding(DSSpacing.xl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    List {
                        if showsProfileGuidance {
                            Section {
                                Text("Showing general essay types for now. Update your profile to unlock service-specific prompts and limits.")
                                    .font(DSFont.supporting)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("writing.picker.guidance")
                            }
                        }
                        ForEach(groupedTargets, id: \.category) { group in
                            Section(group.category.displayName) {
                                ForEach(group.items) { target in
                                    Button {
                                        selectedTargetID = target.id
                                        dismiss()
                                    } label: {
                                        HStack(spacing: DSSpacing.sm) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(target.writingDisplayTitle)
                                                    .font(DSFont.body.weight(.semibold))
                                                if let officialTitleSupportingText = target.officialTitleSupportingText {
                                                    Text(officialTitleSupportingText)
                                                        .font(DSFont.meta)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Text(target.summary)
                                                    .font(DSFont.caption)
                                                    .foregroundStyle(.secondary)
                                                    .multilineTextAlignment(.leading)
                                            }
                                            Spacer()
                                            if selectedTargetID == target.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(DSColor.brandAccent)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(target.writingDisplayTitle), \(target.limitSummary)")
                                    .accessibilityIdentifier("writing.picker.target.\(target.id)")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Essay Type")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
