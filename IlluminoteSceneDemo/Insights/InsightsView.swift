import SwiftUI
import SwiftData
import OSLog

enum InsightsViewSupport {
    enum CoreMode: String, CaseIterable, Identifiable {
        case patterns
        case experiences

        var id: String { rawValue }

        var title: String {
            switch self {
            case .patterns: return "Patterns"
            case .experiences: return "Experiences"
            }
        }
    }

    static let coreDefaultLens: InsightLens = .themes
    static let coreVisibleLenses: [InsightLens] = [.themes, .experiences]

    struct LensSummary {
        let nodesCount: Int
        let draftsCount: Int
        let latestActivity: Date?

        var hasActivity: Bool {
            nodesCount > 0 || draftsCount > 0
        }
    }

    struct LandingState {
        static let empty = LandingState(summariesByLens: [:], suggestedLens: nil)

        let summariesByLens: [InsightLens: LensSummary]
        let suggestedLens: InsightLens?

        func summary(for lens: InsightLens) -> LensSummary {
            summariesByLens[lens] ?? LensSummary(nodesCount: 0, draftsCount: 0, latestActivity: nil)
        }
    }

    static func inputFingerprint(for inputs: [InsightAnalysisInput]) -> Int {
        var hasher = Hasher()
        for input in inputs {
            hasher.combine(input.entryID)
            hasher.combine(input.date)
            hasher.combine(input.experienceType?.rawValue)
            hasher.combine(input.examenMode.rawValue)
            hasher.combine(input.text)
            hasher.combine(input.title)
            hasher.combine(input.secondaryDetail)
            hasher.combine(input.focusDetail)
        }
        return hasher.finalize()
    }

    static func linkedWorkspaceEntriesByNodeID(
        from entries: [InsightWorkspaceEntry]
    ) -> [UUID: [InsightWorkspaceEntry]] {
        let linkedPairs: [(UUID, InsightWorkspaceEntry)] = entries.compactMap { entry in
            guard let nodeID = entry.linkedInsightNode?.id else { return nil }
            return (nodeID, entry)
        }

        return Dictionary(grouping: linkedPairs, by: { pair in pair.0 }).mapValues { grouped in
            grouped
                .map(\.1)
                .sorted { lhs, rhs in
                    if lhs.updatedAt == rhs.updatedAt {
                        return lhs.createdAt > rhs.createdAt
                    }
                    return lhs.updatedAt > rhs.updatedAt
                }
        }
    }

    static func linkedExperiences(from entries: [ExamenSession]) -> [ApplicationExperience] {
        var seen = Set<UUID>()
        var experiences: [ApplicationExperience] = []

        for entry in entries {
            guard let experience = entry.applicationExperience else { continue }
            guard !seen.contains(experience.id) else { continue }
            seen.insert(experience.id)
            experiences.append(experience)
        }

        return experiences.sorted {
            $0.exportTitle.localizedCaseInsensitiveCompare($1.exportTitle) == .orderedAscending
        }
    }

    static func sourceSummary(
        reflectionCount: Int,
        linkedExperienceCount: Int,
        selected: Bool
    ) -> String {
        let reflectionNoun = reflectionCount == 1 ? "reflection" : "reflections"
        let prefix = selected ? "selected " : ""
        var parts = ["\(reflectionCount) \(prefix)\(reflectionNoun)"]

        if linkedExperienceCount > 0 {
            let experienceNoun = linkedExperienceCount == 1 ? "linked application record" : "linked application records"
            parts.append("\(linkedExperienceCount) \(experienceNoun)")
        }

        return parts.joined(separator: " + ")
    }

    static func publishedExperienceType(
        for lens: InsightLens,
        themeScope: ThemeClusterScope,
        selectedWithinExperience: ExperienceType
    ) -> ExperienceType? {
        guard lens == .themes, themeScope == .withinExperience else { return nil }
        return selectedWithinExperience
    }

    static func landingState(
        nodes: [InsightNode],
        drafts: [InsightWorkspaceEntry]
    ) -> LandingState {
        let summaries = Dictionary(uniqueKeysWithValues: InsightLens.allCases.map { lens in
            let lensNodes = nodes.filter { $0.kind.lens == lens && $0.status == .accepted && !$0.isHidden }
            let lensDrafts = drafts.filter { $0.lens == lens && $0.linkedInsightNode == nil }
            let latestNodeActivity = lensNodes.map(\.updatedAt).max()
            let latestDraftActivity = lensDrafts.map(\.updatedAt).max()
            let latestActivity = [latestNodeActivity, latestDraftActivity].compactMap { $0 }.max()

            return (
                lens,
                LensSummary(
                    nodesCount: lensNodes.count,
                    draftsCount: lensDrafts.count,
                    latestActivity: latestActivity
                )
            )
        })

        let suggestedLens = InsightLens.allCases
            .filter { summaries[$0]?.hasActivity == true }
            .max { lhs, rhs in
                let lhsSummary = summaries[lhs] ?? LensSummary(nodesCount: 0, draftsCount: 0, latestActivity: nil)
                let rhsSummary = summaries[rhs] ?? LensSummary(nodesCount: 0, draftsCount: 0, latestActivity: nil)

                let lhsScore = lhsSummary.nodesCount * 3 + lhsSummary.draftsCount * 2
                let rhsScore = rhsSummary.nodesCount * 3 + rhsSummary.draftsCount * 2

                if lhsScore == rhsScore {
                    return (lhsSummary.latestActivity ?? .distantPast) < (rhsSummary.latestActivity ?? .distantPast)
                }
                return lhsScore < rhsScore
            }

        return LandingState(summariesByLens: summaries, suggestedLens: suggestedLens)
    }

    static func promptContext(for suggestion: InsightSuggestion) -> InsightPromptContext {
        let signals = orderedUniqueTitles(
            from: [suggestion.title] + suggestion.keywordHighlights
        )
        return InsightPromptContext(
            lens: suggestion.lens,
            signalTitles: Array(signals.prefix(4)),
            entryCount: suggestion.entries.count
        )
    }

    static func orderedUniqueTitles(from titles: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for title in titles {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }

        return result
    }
}

enum InsightsWorkspacePublisher {
    @MainActor
    static func publish(
        entry: InsightWorkspaceEntry,
        defaultKind: InsightNodeKind,
        experienceType: ExperienceType?,
        sessionsByID: [UUID: ExamenSession],
        context: ModelContext
    ) -> InsightNode {
        let node = entry.linkedInsightNode ?? InsightNode(
            kind: defaultKind,
            title: entry.title,
            normalizedTitle: InsightNode.normalize(entry.title),
            status: .accepted,
            confidence: 0.92,
            source: .manual,
            experienceType: experienceType,
            isPinned: true
        )

        if entry.linkedInsightNode == nil {
            context.insert(node)
        }

        node.kind = defaultKind
        node.rename(to: entry.title)
        node.status = .accepted
        node.source = .manual
        node.experienceType = experienceType
        node.isHidden = false
        node.touch()

        let existingLinks = Dictionary(uniqueKeysWithValues: node.links.map { ($0.entryID, $0) })
        for entryID in Array(Set(entry.sourceEntryIDs)) {
            let evidenceSnippet = sessionsByID[entryID].map {
                InsightsAnalysisService.truncatedEvidenceSnippet(from: $0.themeAnalysisText())
            } ?? "Linked reflection"

            if let existingLink = existingLinks[entryID] {
                if existingLink.evidenceSnippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    existingLink.evidenceSnippet = evidenceSnippet
                }
                existingLink.confidence = max(existingLink.confidence, 0.82)
            } else {
                let link = InsightEntryLink(
                    entryID: entryID,
                    evidenceSnippet: evidenceSnippet,
                    confidence: 0.82,
                    insightNode: node
                )
                context.insert(link)
            }
        }

        entry.linkedInsightNode = node
        entry.touch()
        return node
    }
}

enum InsightsSuggestionAcceptance {
    @MainActor
    static func accept(
        _ suggestion: InsightSuggestion,
        existingNodes: [InsightNode],
        entriesByID: [UUID: ExamenSession],
        context: ModelContext
    ) -> InsightNode {
        let identityKey = InsightNode.identityKey(
            kind: suggestion.kind,
            normalizedTitle: suggestion.normalizedTitle,
            experienceType: suggestion.experienceType
        )

        let node = existingNodes.first {
            InsightNode.identityKey(
                kind: $0.kind,
                normalizedTitle: $0.normalizedTitle,
                experienceType: $0.experienceType
            ) == identityKey
        } ?? InsightNode(
            kind: suggestion.kind,
            title: suggestion.title,
            normalizedTitle: suggestion.normalizedTitle,
            status: .accepted,
            confidence: suggestion.confidence,
            source: suggestion.source,
            experienceType: suggestion.experienceType
        )

        if node.modelContext == nil {
            context.insert(node)
        }

        node.title = suggestion.title
        node.normalizedTitle = suggestion.normalizedTitle
        node.status = .accepted
        node.source = suggestion.source
        node.isHidden = false
        node.experienceType = suggestion.experienceType
        node.confidence = max(node.confidence, suggestion.confidence)

        let existingLinks = Dictionary(uniqueKeysWithValues: node.links.map { ($0.entryID, $0) })
        let evidenceByEntryID = Dictionary(uniqueKeysWithValues: suggestion.entries.map {
            ($0.entryID, (snippet: $0.evidenceSnippet, confidence: $0.confidence))
        })

        for entryID in Array(Set(evidenceByEntryID.keys)) {
            let suggestedEvidence = evidenceByEntryID[entryID]
            let evidenceSnippet = suggestedEvidence?.snippet
                ?? entriesByID[entryID].map { InsightsAnalysisService.truncatedEvidenceSnippet(from: $0.themeAnalysisText()) }
                ?? "Linked reflection"
            let confidence = suggestedEvidence?.confidence ?? 0.82

            if let existingLink = existingLinks[entryID] {
                if suggestedEvidence != nil || existingLink.evidenceSnippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    existingLink.evidenceSnippet = evidenceSnippet
                }
                existingLink.confidence = max(existingLink.confidence, confidence)
            } else {
                let link = InsightEntryLink(
                    entryID: entryID,
                    evidenceSnippet: evidenceSnippet,
                    confidence: confidence,
                    insightNode: node
                )
                context.insert(link)
            }
        }

        return node
    }
}

// MARK: - InsightsView (Bento Grid)
struct InsightsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var nodes: [InsightNode]
    @Query private var drafts: [InsightWorkspaceEntry]
    
    @State private var activeStudioLens: InsightLens?
    @State private var landingState = InsightsViewSupport.LandingState.empty
    
    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 0)]
        }

        return [
            GridItem(.flexible(), spacing: DSSpacing.sm),
            GridItem(.flexible(), spacing: DSSpacing.sm)
        ]
    }
    
    var body: some View {
        if AppSettings.featurePolicy.mode == .core {
            CoreInsightsView()
        } else {
            NavigationStack {
                ZStack {
                    InsightsSupportingBackground()

                    AppPageScrollView {
                        VStack(alignment: .leading, spacing: DSSpacing.lg) {
                            AppPageHeader(
                                title: "Insights",
                                eyebrow: "Workbench",
                                subtitle: "Explore patterns and build your perspective over time."
                            )

                            InsightsEntryGuide(suggestedLens: landingState.suggestedLens)

                            LazyVGrid(columns: columns, spacing: DSSpacing.sm) {
                                ForEach(InsightLens.allCases) { lens in
                                    Button(action: { activeStudioLens = lens }) {
                                        InsightBentoTile(
                                            lens: lens,
                                            nodesCount: landingState.summary(for: lens).nodesCount,
                                            draftsCount: landingState.summary(for: lens).draftsCount,
                                            isSuggestedStart: landingState.suggestedLens == lens
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("insights.lens.\(lens.rawValue)")
                                }
                            }
                        }
                    }
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .fullScreenCover(item: $activeStudioLens) { lens in
                    InsightStudioView(selectedLens: lens)
                }
                .task {
                    openPendingStudioIfNeeded()
                }
                .onChange(of: settings.selectedTab) { _, _ in
                    openPendingStudioIfNeeded()
                }
                .onChange(of: settings.pendingInsightsLensRaw) { _, _ in
                    openPendingStudioIfNeeded()
                }
                .task(id: landingMetricsRevision) {
                    landingState = InsightsViewSupport.landingState(nodes: nodes, drafts: drafts)
                }
            }
        }
    }

    private var landingMetricsRevision: Int {
        var hasher = Hasher()
        for node in nodes {
            hasher.combine(node.id)
            hasher.combine(node.kindRaw)
            hasher.combine(node.statusRaw)
            hasher.combine(node.isHidden)
            hasher.combine(node.updatedAt)
        }
        for draft in drafts {
            hasher.combine(draft.id)
            hasher.combine(draft.lensRaw)
            hasher.combine(draft.updatedAt)
            hasher.combine(draft.linkedInsightNode?.id)
        }
        return hasher.finalize()
    }

    private func openPendingStudioIfNeeded() {
        guard settings.selectedTab == .insights else { return }
        guard activeStudioLens == nil else { return }
        guard let pendingLens = settings.pendingInsightsLens else { return }
        activeStudioLens = pendingLens
    }
}

private struct CoreInsightsView: View {
    private enum SheetRoute: Identifiable {
        case brainstorm(InsightSuggestion)
        case addToDraft(UUID)

        var id: String {
            switch self {
            case .brainstorm(let suggestion):
                return "brainstorm-\(suggestion.id.uuidString)"
            case .addToDraft(let entryID):
                return "addToDraft-\(entryID.uuidString)"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @Query(sort: [SortDescriptor(\ExamenSession.date, order: .reverse)])
    private var allSessions: [ExamenSession]
    @Query(sort: [SortDescriptor(\InsightWorkspaceEntry.updatedAt, order: .reverse)])
    private var workspaceEntries: [InsightWorkspaceEntry]
    @Query private var practiceThemes: [PracticeTheme]

    @State private var selectedMode: InsightsViewSupport.CoreMode = .patterns
    @State private var patternSuggestions: [InsightSuggestion] = []
    @State private var experienceSuggestions: [InsightSuggestion] = []
    @State private var isAnalyzing = false
    @State private var activeSheet: SheetRoute?
    @State private var persistenceAlert: PersistenceAlertContext?
    @State private var refreshTask: Task<Void, Never>?
    @State private var activeAnalysisRevision: Int?

    private let analysisService = InsightsAnalysisService()

    private var journalEntries: [ExamenSession] {
        allSessions.filter { $0.sessionType != .statementDraft }
    }

    private var entriesByID: [UUID: ExamenSession] {
        Dictionary(uniqueKeysWithValues: journalEntries.map { ($0.id, $0) })
    }

    private var visibleSuggestions: [InsightSuggestion] {
        switch selectedMode {
        case .patterns:
            return patternSuggestions
        case .experiences:
            return experienceSuggestions
        }
    }

    private var experienceGroups: [(type: ExperienceType, suggestions: [InsightSuggestion])] {
        Dictionary(grouping: experienceSuggestions) { suggestion in
            suggestion.experienceType?.canonical ?? .other
        }
        .map { (type: $0.key, suggestions: $0.value.sorted { $0.score > $1.score }) }
        .sorted { lhs, rhs in
            if lhs.suggestions.count == rhs.suggestions.count {
                return lhs.type.displayName < rhs.type.displayName
            }
            return lhs.suggestions.count > rhs.suggestions.count
        }
    }

    private var contentRevision: Int {
        var hasher = Hasher()
        for entry in allSessions where entry.sessionType != .statementDraft {
            hasher.combine(entry.id)
            hasher.combine(entry.date)
            hasher.combine(entry.sessionType.rawValue)
            hasher.combine(entry.experienceType?.rawValue)
            hasher.combine(entry.examenModeRaw)
            hasher.combine(entry.personalStatement)
            hasher.combine(entry.title)
            hasher.combine(entry.physician)
            hasher.combine(entry.facility)
            hasher.combine(entry.specialty)
            hasher.combine(entry.location)
            hasher.combine(entry.mentorOrSupervisor)
            hasher.combine(entry.roleTitle)
            hasher.combine(entry.organizationName)
            hasher.combine(entry.focusArea)
            hasher.combine(entry.notes)
            hasher.combine(entry.tags)
        }
        for theme in practiceThemes {
            hasher.combine(theme.id)
            hasher.combine(theme.title)
            hasher.combine(theme.themeDescription)
        }
        return hasher.finalize()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                InsightsSupportingBackground()

                AppPageScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.lg) {
                        AppPageHeader(
                            title: "Insights",
                            eyebrow: nil,
                            subtitle: "What your reflections are showing you."
                        )

                        Picker("Insights view", selection: $selectedMode) {
                            ForEach(InsightsViewSupport.CoreMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("insights.core.modePicker")

                        if isAnalyzing {
                            CoreInsightsLoadingCard()
                        }

                        content
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $activeSheet) { route in
                sheetContent(for: route)
                    .presentationBackground(DSColor.backgroundPrimary)
            }
            .task(id: contentRevision) {
                refreshSuggestions(for: contentRevision)
            }
            .onDisappear {
                refreshTask?.cancel()
            }
            .persistenceFailureAlert($persistenceAlert)
        }
    }

    @ViewBuilder
    private var content: some View {
        if journalEntries.isEmpty {
            CoreInsightsEmptyCard(
                title: "No reflections yet",
                message: "Save a reflection first. Insights will look for patterns here."
            )
        } else {
            switch selectedMode {
            case .patterns:
                if patternSuggestions.isEmpty && !isAnalyzing {
                    CoreInsightsEmptyCard(
                        title: "Patterns need a little more material",
                        message: "A few more reflections will make recurring patterns easier to see."
                    )
                } else {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        ForEach(patternSuggestions) { suggestion in
                            CoreInsightSuggestionCard(
                                suggestion: suggestion,
                                entriesByID: entriesByID,
                                actionTitle: "Brainstorm",
                                onBrainstorm: { activeSheet = .brainstorm(suggestion) }
                            )
                        }
                    }
                    .accessibilityIdentifier("insights.core.patterns")
                }

            case .experiences:
                if experienceGroups.isEmpty && !isAnalyzing {
                    CoreInsightsEmptyCard(
                        title: "No experience patterns yet",
                        message: "Reflections will gather here by experience type."
                    )
                } else {
                    VStack(alignment: .leading, spacing: DSSpacing.lg) {
                        ForEach(experienceGroups, id: \.type) { group in
                            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                                Text(group.type.displayName)
                                    .font(DSFont.sectionTitle)
                                    .foregroundStyle(DSColor.textPrimary)

                                ForEach(group.suggestions) { suggestion in
                                    CoreInsightSuggestionCard(
                                        suggestion: suggestion,
                                        entriesByID: entriesByID,
                                        actionTitle: "Brainstorm",
                                        onBrainstorm: { activeSheet = .brainstorm(suggestion) }
                                    )
                                }
                            }
                        }
                    }
                    .accessibilityIdentifier("insights.core.experiences")
                }
            }
        }
    }

    @ViewBuilder
    private func sheetContent(for route: SheetRoute) -> some View {
        switch route {
        case .brainstorm(let suggestion):
            CoreInsightBrainstormSheet(
                suggestion: suggestion,
                entriesByID: entriesByID,
                onSave: { draft in
                    _ = saveBrainstorm(draft)
                    activeSheet = nil
                },
                onSendToWriting: { draft in
                    guard let entry = saveBrainstorm(draft) else { return }
                    activeSheet = .addToDraft(entry.id)
                }
            )
        case .addToDraft(let entryID):
            AddToStatementSheet(
                selectedEntries: [],
                selectedWorkspaceEntries: workspaceEntries.filter { $0.id == entryID },
                onComplete: { activeSheet = nil }
            )
        }
    }

    private func refreshSuggestions(for revision: Int) {
        let inputs = analysisService.makeInputs(from: journalEntries)
        let taxonomyTitles = practiceThemes.map { ($0.id, $0.title, $0.themeDescription) }
        guard !inputs.isEmpty else {
            refreshTask?.cancel()
            activeAnalysisRevision = revision
            patternSuggestions = []
            experienceSuggestions = []
            isAnalyzing = false
            return
        }

        activeAnalysisRevision = revision
        isAnalyzing = true
        refreshTask?.cancel()

        refreshTask = Task.detached(priority: .userInitiated) {
            let service = InsightsAnalysisService()
            let patterns = service.analyzeThemes(
                entries: inputs,
                taxonomyTitles: taxonomyTitles,
                scope: .acrossExperiences,
                selectedExperience: nil
            )
            let experiences = service.analyzeExperiences(entries: inputs)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard activeAnalysisRevision == revision else { return }
                patternSuggestions = patterns
                experienceSuggestions = experiences
                isAnalyzing = false
            }
        }
    }

    private func saveBrainstorm(_ draft: CoreInsightBrainstormDraft) -> InsightWorkspaceEntry? {
        let trimmed = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)

        let entry = InsightWorkspaceEntry(
            lens: draft.lens,
            title: trimmedTitle.isEmpty ? "Brainstorm" : trimmedTitle,
            promptKey: draft.promptKey,
            body: trimmed,
            sourceEntryIDs: draft.sourceEntryIDs
        )
        modelContext.insert(entry)

        do {
            _ = try modelContext.persistIfNeeded(for: "save your brainstorming")
            return entry
        } catch let error as PersistenceOperationError {
            persistenceAlert = error.alertContext
            return nil
        } catch {
            persistenceAlert = PersistenceAlertContext.saveFailure(
                for: "save your brainstorming",
                details: error.localizedDescription
            )
            return nil
        }
    }
}

private struct CoreInsightBrainstormDraft {
    let lens: InsightLens
    let title: String
    let promptKey: String?
    let body: String
    let sourceEntryIDs: [UUID]
}

private struct CoreInsightSuggestionCard: View {
    let suggestion: InsightSuggestion
    let entriesByID: [UUID: ExamenSession]
    let actionTitle: String
    let onBrainstorm: () -> Void

    private var evidenceSnippets: [String] {
        suggestion.entries
            .prefix(2)
            .map(\.evidenceSnippet)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(suggestion.title)
                    .font(DSFont.body.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(suggestion.entries.count) reflection\(suggestion.entries.count == 1 ? "" : "s")")
                    .font(DSFont.supporting)
                    .foregroundStyle(DSColor.quietText)
            }

            if !evidenceSnippets.isEmpty {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    ForEach(evidenceSnippets, id: \.self) { snippet in
                        Text(snippet)
                            .font(DSFont.supporting)
                            .foregroundStyle(DSColor.textSecondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Button(action: onBrainstorm) {
                Label(actionTitle, systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.appPrimary)
            .accessibilityIdentifier("insights.core.brainstorm.\(suggestion.id.uuidString)")
        }
        .padding(DSSpacing.md)
        .appSurfaceStyle(role: .interactive, highlighted: false)
        .accessibilityElement(children: .contain)
    }
}

private struct CoreInsightBrainstormSheet: View {
    @Environment(\.dismiss) private var dismiss

    let suggestion: InsightSuggestion
    let entriesByID: [UUID: ExamenSession]
    let onSave: (CoreInsightBrainstormDraft) -> Void
    let onSendToWriting: (CoreInsightBrainstormDraft) -> Void

    @State private var title: String
    @State private var bodyText: String = ""
    @State private var selectedPromptKey: String?

    private var context: InsightPromptContext {
        InsightsViewSupport.promptContext(for: suggestion)
    }

    private var templates: [InsightPromptTemplate] {
        Array(InsightPromptCatalog.templates(for: suggestion.lens).prefix(3))
    }

    private var selectedTemplate: InsightPromptTemplate? {
        templates.first { $0.promptKey == selectedPromptKey } ?? templates.first
    }

    private var canSave: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        suggestion: InsightSuggestion,
        entriesByID: [UUID: ExamenSession],
        onSave: @escaping (CoreInsightBrainstormDraft) -> Void,
        onSendToWriting: @escaping (CoreInsightBrainstormDraft) -> Void
    ) {
        self.suggestion = suggestion
        self.entriesByID = entriesByID
        self.onSave = onSave
        self.onSendToWriting = onSendToWriting
        let context = InsightsViewSupport.promptContext(for: suggestion)
        let firstTemplate = InsightPromptCatalog.templates(for: suggestion.lens).first
        self._title = State(initialValue: firstTemplate?.suggestedTitle(using: context) ?? suggestion.title)
        self._selectedPromptKey = State(initialValue: firstTemplate?.promptKey)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    AppPanel(
                        title: suggestion.title,
                        subtitle: "\(suggestion.entries.count) reflection\(suggestion.entries.count == 1 ? "" : "s")",
                        role: .reading,
                        highlighted: true
                    ) {
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            ForEach(suggestion.entries.prefix(2), id: \.entryID) { entry in
                                Text(entry.evidenceSnippet)
                                    .font(DSFont.supporting)
                                    .foregroundStyle(DSColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Choose a prompt")
                            .font(DSFont.body.weight(.semibold))
                            .foregroundStyle(DSColor.textPrimary)

                        ForEach(templates) { template in
                            Button {
                                selectedPromptKey = template.promptKey
                                title = template.suggestedTitle(using: context)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.title)
                                        .font(DSFont.body.weight(.semibold))
                                        .foregroundStyle(DSColor.textPrimary)
                                    Text(template.resolvedPrompt(using: context))
                                        .font(DSFont.supporting)
                                        .foregroundStyle(DSColor.quietText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(DSSpacing.md)
                                .appSurfaceStyle(
                                    role: .interactive,
                                    highlighted: selectedPromptKey == template.promptKey
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Brainstorm")
                            .font(DSFont.body.weight(.semibold))
                            .foregroundStyle(DSColor.textPrimary)

                        TextField("Title", text: $title)
                            .font(DSFont.body.weight(.semibold))
                            .padding(DSSpacing.md)
                            .background(DSColor.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityLabel("Brainstorm title")

                        TextEditor(text: $bodyText)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 260)
                            .padding(12)
                            .background(DSColor.readingSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(DSColor.dividerSoft, lineWidth: 1)
                            )
                            .accessibilityLabel("Brainstorming")
                            .accessibilityIdentifier("insights.core.brainstorm.editor")
                    }

                    HStack(spacing: DSSpacing.sm) {
                        Button("Save") {
                            onSave(draft)
                        }
                        .buttonStyle(.appSecondary)
                        .disabled(!canSave)

                        Button("Send to Writing") {
                            onSendToWriting(draft)
                        }
                        .buttonStyle(.appPrimary)
                        .disabled(!canSave)
                        .accessibilityIdentifier("insights.core.sendToWriting")
                    }
                }
                .padding(DSSpacing.lg)
            }
            .navigationTitle("Brainstorm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var draft: CoreInsightBrainstormDraft {
        CoreInsightBrainstormDraft(
            lens: suggestion.lens,
            title: title,
            promptKey: selectedTemplate?.promptKey,
            body: bodyText,
            sourceEntryIDs: suggestion.entries.map(\.entryID)
        )
    }
}

private struct CoreInsightsLoadingCard: View {
    var body: some View {
        HStack(spacing: DSSpacing.md) {
            ProgressView()
            Text("Looking for patterns...")
                .font(DSFont.supporting)
                .foregroundStyle(DSColor.quietText)
        }
        .padding(DSSpacing.md)
        .appSurfaceStyle(role: .quiet)
    }
}

private struct CoreInsightsEmptyCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(title)
                .font(DSFont.sectionTitle)
                .foregroundStyle(DSColor.textPrimary)
            Text(message)
                .font(DSFont.supporting)
                .foregroundStyle(DSColor.quietText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.md)
        .appSurfaceStyle(role: .quiet)
    }
}

struct InsightBentoTile: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let lens: InsightLens
    let nodesCount: Int
    let draftsCount: Int
    var isSuggestedStart: Bool = false

    private var isAccessibilityTextSize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack(alignment: .top) {
                Image(systemName: lens.systemImage)
                    .font(.title2)
                    .foregroundStyle(DSColor.brandAccent)
                Spacer()
                if isSuggestedStart {
                    AppInfoChip(text: "Suggested", icon: "sparkles", emphasized: true)
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(DSColor.quietText)
                }
            }
            
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(lens.title)
                    .font(.headline)
                    .foregroundStyle(DSColor.textPrimary)
                
                Text(lens.summary)
                    .font(DSFont.supporting.weight(.regular))
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(isAccessibilityTextSize ? 5 : 4)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: DSSpacing.sm)
            
            Divider()
                .background(DSColor.dividerSoft)
            
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "checklist")
                        .font(.caption)
                        .foregroundStyle(DSColor.success)
                    Text("\(nodesCount) saved")
                        .font(DSFont.supporting)
                        .foregroundStyle(DSColor.quietText)
                    
                    Text("•")
                        .font(DSFont.supporting)
                        .foregroundStyle(DSColor.dividerStrong)
                    
                    Text("\(draftsCount) drafted")
                        .font(DSFont.supporting)
                        .foregroundStyle(DSColor.quietText)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Label("\(nodesCount) saved", systemImage: "checklist")
                        .font(DSFont.supporting)
                        .foregroundStyle(DSColor.quietText)
                    Text("\(draftsCount) drafted")
                        .font(DSFont.supporting)
                        .foregroundStyle(DSColor.quietText)
                        .padding(.leading, 18)
                }
            }
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, minHeight: isAccessibilityTextSize ? 232 : 212, alignment: .leading)
        .appSurfaceStyle(role: .interactive, highlighted: isSuggestedStart)
    }
}

private struct InsightsEntryGuide: View {
    @AppStorage(AppCoachStorageKey.insights) private var isDismissed = false

    let suggestedLens: InsightLens?

    var body: some View {
        Group {
            if !isDismissed {
                AppCoachPanel(
                    title: AppSettings.featurePolicy.mode == .core
                        ? "Start with one pattern."
                        : "See patterns in what your reflections are teaching you.",
                    subtitle: AppSettings.featurePolicy.mode == .core
                        ? "Choose the lens that fits today."
                        : "Insights becomes more valuable after a few reflections. Begin anywhere when you're ready to name a different layer of meaning.",
                    role: .quiet,
                    onDismiss: dismiss
                ) {
                    if let suggestedLens {
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            AppInfoChip(text: "Suggested starting lens", icon: "sparkles", emphasized: true)
                            Text("\(suggestedLens.title) has the strongest recent activity.")
                                .font(DSFont.supporting)
                                .foregroundStyle(DSColor.quietText)
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
    }

    private func dismiss() {
        withAnimation(AnimationConfig.screenTransition) {
            isDismissed = true
        }
    }
}

// MARK: - InsightStudioView
struct InsightStudioView: View {
    @Environment(\.dismiss) private var dismiss
    
    struct DraftSheetPayload: Identifiable {
        let entryIDs: [UUID]
        let workspaceEntryIDs: [UUID]

        var id: String {
            let entryPart = entryIDs.map(\.uuidString).joined(separator: "-")
            let workspacePart = workspaceEntryIDs.map(\.uuidString).joined(separator: "-")
            return "entries=\(entryPart)|workspace=\(workspacePart)"
        }
    }

    struct AnalysisCacheKey: Hashable {
        let lens: InsightLens
        let themeScope: ThemeClusterScope?
        let selectedExperienceRaw: String?
        let selectedEntryIDs: [UUID]
        let inputFingerprint: Int
    }

    struct RefreshSignature: Equatable {
        let cacheKey: AnalysisCacheKey
        let nodeRevision: Int
    }

    struct WorkspaceDraftState {
        var existingID: UUID?
        var lens: InsightLens
        var title: String
        var promptKey: String?
        var body: String
        var linkedNodeID: UUID?
        var sourceEntryIDs: [UUID]
        var openedSnapshot: InsightWorkspaceEntrySyncSnapshot? = nil
        var observedUpdatedAt: Date? = nil
        var observedSyncRevision: Int? = nil
        var lastLocalSaveAt: Date? = nil
        var lastLocalSaveFingerprint: String? = nil

        var currentContentFingerprint: String {
            InsightWorkspaceEntrySyncSnapshot.contentFingerprint(
                lensRaw: lens.rawValue,
                title: title,
                promptKey: promptKey,
                body: body,
                sourceEntryIDs: sourceEntryIDs,
                linkedInsightNodeID: linkedNodeID
            )
        }

        static let empty = WorkspaceDraftState(
            existingID: nil,
            lens: .themes,
            title: "",
            promptKey: nil,
            body: "",
            linkedNodeID: nil,
            sourceEntryIDs: [],
            openedSnapshot: nil,
            observedUpdatedAt: nil,
            observedSyncRevision: nil,
            lastLocalSaveAt: nil,
            lastLocalSaveFingerprint: nil
        )
    }

    struct CreatedDraftConfirmation: Identifiable, Equatable {
        let draftID: UUID
        let title: String

        var id: UUID { draftID }

        init(draft: StatementDraft) {
            draftID = draft.id
            title = draft.title
        }
    }

    enum InsightsSheetRoute: Identifiable {
        case entryPicker
        case manualNode(InsightNodeKind)
        case renameNode(UUID)
        case addToDraft(DraftSheetPayload)
        case workspaceEditor

        var id: String {
            switch self {
            case .entryPicker: return "entryPicker"
            case .manualNode(let kind): return "manualNode-\(kind.rawValue)"
            case .renameNode(let nodeID): return "renameNode-\(nodeID.uuidString)"
            case .addToDraft(let payload): return "addToDraft-\(payload.id)"
            case .workspaceEditor: return "workspaceEditor"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @Query(sort: [SortDescriptor(\ExamenSession.date, order: .reverse)])
    private var allSessions: [ExamenSession]

    @Query private var semanticVectorCaches: [SemanticVectorCache]

    @Query(sort: [SortDescriptor(\InsightNode.updatedAt, order: .reverse)])
    private var allInsightNodes: [InsightNode]

    @Query(sort: [SortDescriptor(\InsightWorkspaceEntry.updatedAt, order: .reverse)])
    private var allWorkspaceEntries: [InsightWorkspaceEntry]

    @Query(sort: \UserProfile.id)
    private var profiles: [UserProfile]

    @Query private var practiceThemes: [PracticeTheme]

    @State var selectedLens: InsightLens
    @State private var selectedThemeScope: ThemeClusterScope = .acrossExperiences
    @State private var selectedWithinExperience: ExperienceType = .shadowing
    @State private var selectedEntryIDs: Set<UUID> = []
    @State private var suggestions: [InsightSuggestion] = []
    @State private var isAnalyzing = false
    @State private var analysisError: String?
    @State private var activeSheet: InsightsSheetRoute?
    @State private var manualNodeTitle = ""
    @State private var renameText = ""
    @State private var entriesByIDCache: [UUID: ExamenSession] = [:]
    @State private var selectedEntriesCache: [ExamenSession] = []
    @State private var acceptedNodesCache: [InsightNode] = []
    @State private var visibleSuggestionsCache: [InsightSuggestion] = []
    @State private var scopedJournalEntriesCache: [ExamenSession] = []
    @State private var activeWorkspaceEntriesCache: [InsightWorkspaceEntry] = []
    @State private var linkedWorkspaceEntriesByNodeIDCache: [UUID: [InsightWorkspaceEntry]] = [:]
    @State private var refreshTask: Task<Void, Never>?
    @State private var cachedSuggestions: [AnalysisCacheKey: [InsightSuggestion]] = [:]
    @State private var lastRefreshSignature: RefreshSignature?
    @State private var workspaceDraft = WorkspaceDraftState.empty
    @State private var activeWorkspaceConflict: InsightWorkspaceEntrySyncConflict?
    @State private var workspaceSyncStatusMessage: String?
    @State private var persistenceAlert: PersistenceAlertContext?
    @State private var createdDraftConfirmation: CreatedDraftConfirmation?

    private let analysisService = InsightsAnalysisService()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "IlluminoteSceneDemo", category: "Insights")

    private var journalEntries: [ExamenSession] {
        allSessions.filter { $0.sessionType != .statementDraft }
    }

    private var journalEntriesContentRevision: Int {
        InsightsViewSupport.inputFingerprint(for: analysisService.makeInputs(from: journalEntries))
    }

    private var entriesByID: [UUID: ExamenSession] { entriesByIDCache }
    private var selectedEntries: [ExamenSession] { selectedEntriesCache }
    private var currentProfile: UserProfile? { profiles.first }
    private var acceptedNodes: [InsightNode] { acceptedNodesCache }
    private var visibleSuggestions: [InsightSuggestion] { visibleSuggestionsCache }
    private var activeWorkspaceEntries: [InsightWorkspaceEntry] { activeWorkspaceEntriesCache }
    private var linkedWorkspaceEntriesByNodeID: [UUID: [InsightWorkspaceEntry]] { linkedWorkspaceEntriesByNodeIDCache }

    private var selectedLinkedExperiences: [ApplicationExperience] {
        InsightsViewSupport.linkedExperiences(from: selectedEntries)
    }

    private var scopedLinkedExperiences: [ApplicationExperience] {
        InsightsViewSupport.linkedExperiences(from: scopedJournalEntries)
    }

    private var activeSourceEntries: [ExamenSession] {
        selectedEntries.isEmpty ? scopedJournalEntries : selectedEntries
    }

    private var themeTaxonomyTitles: [(id: String, title: String, description: String)] {
        practiceThemes.map { ($0.id, $0.title, $0.themeDescription) }
    }

    private var sourceEntryCountText: String {
        if !selectedEntries.isEmpty {
            return InsightsViewSupport.sourceSummary(
                reflectionCount: selectedEntries.count,
                linkedExperienceCount: selectedLinkedExperiences.count,
                selected: true
            )
        }
        return studioScopeCountText
    }

    private var studioScopeCountText: String {
        let summary = InsightsViewSupport.sourceSummary(
            reflectionCount: scopedJournalEntries.count,
            linkedExperienceCount: scopedLinkedExperiences.count,
            selected: false
        )
        return "\(summary) in scope"
    }

    private var scopedJournalEntries: [ExamenSession] { scopedJournalEntriesCache }

    private var workspaceEntriesForSelectedLens: [InsightWorkspaceEntry] {
        activeWorkspaceEntries
    }

    private var workspaceContext: InsightPromptContext {
        let linkedExperienceTitles = InsightsViewSupport.linkedExperiences(from: activeSourceEntries).map(\.exportTitle)
        let signalTitles = orderedUniqueTitles(from: acceptedNodes.map(\.title) + visibleSuggestions.map(\.title) + linkedExperienceTitles)
        return InsightPromptContext(
            lens: selectedLens,
            signalTitles: Array(signalTitles.prefix(4)),
            entryCount: activeSourceEntries.count
        )
    }

    private var promptTemplates: [InsightPromptTemplate] {
        InsightPromptCatalog.templates(for: selectedLens)
    }

    private var activeWorkspaceEntrySnapshot: InsightWorkspaceEntrySyncSnapshot? {
        guard let id = workspaceDraft.existingID,
              let entry = allWorkspaceEntries.first(where: { $0.id == id }) else {
            return nil
        }
        return InsightWorkspaceEntrySyncSnapshot(entry: entry)
    }

    private var activeWorkspaceEntryChangeToken: String {
        activeWorkspaceEntrySnapshot?.changeToken ?? "workspace-entry-\(workspaceDraft.existingID?.uuidString ?? "new")"
    }

    private var workspaceEditorMonitorID: String {
        guard activeSheet?.id == InsightsSheetRoute.workspaceEditor.id else { return "workspace-editor-inactive" }
        return activeWorkspaceEntryChangeToken
    }

    var body: some View {
        NavigationStack {
            ZStack {
                InsightsSupportingBackground()

                VStack(spacing: DSSpacing.sm) {
                    topChrome
                        .padding(.horizontal, DSSpacing.lg)
                        .padding(.top, DSSpacing.md)

                    AppPageScrollView {
                        if isAnalyzing {
                            analysisLoadingCard
                        }

                        if let analysisError {
                            analysisErrorCard(message: analysisError)
                        }

                        surfacedInsightsSection
                        guidedWorkspaceSection
                    }
                }

                if let createdDraftConfirmation {
                    VStack {
                        Spacer()
                        DraftCreatedConfirmationBanner(
                            confirmation: createdDraftConfirmation,
                            onOpen: {
                                settings.routeToWriting(draftID: createdDraftConfirmation.draftID)
                                withAnimation(AnimationConfig.screenTransition) {
                                    self.createdDraftConfirmation = nil
                                }
                                dismiss()
                            },
                            onStay: {
                                withAnimation(AnimationConfig.screenTransition) {
                                    self.createdDraftConfirmation = nil
                                }
                            }
                        )
                        .padding(.horizontal, DSSpacing.lg)
                        .padding(.bottom, DSSpacing.lg)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(item: $activeSheet, onDismiss: clearSheetDraftState) { route in
                insightSheetContent(for: route)
                    .presentationBackground(DSColor.backgroundPrimary)
            }
            .task {
                consumePendingInsightSelectionIfNeeded()
                refreshPresentationState()
                requestSuggestionRefresh(force: true)
            }
            .onChange(of: selectedThemeScope) { _, _ in
                refreshPresentationState()
                requestSuggestionRefresh()
            }
            .onChange(of: selectedWithinExperience) { _, _ in
                refreshPresentationState()
                requestSuggestionRefresh()
            }
            .onChange(of: allSessions.count) { _, _ in
                consumePendingInsightSelectionIfNeeded()
                refreshPresentationState()
                requestSuggestionRefresh(force: true)
            }
            .onChange(of: journalEntriesContentRevision) { _, _ in
                refreshPresentationState()
                requestSuggestionRefresh(force: true)
            }
            .onChange(of: allWorkspaceEntries.count) { _, _ in
                refreshPresentationState()
            }
            .onChange(of: activeWorkspaceEntryChangeToken) { _, _ in
                checkForRemoteWorkspaceEntryUpdate()
            }
            .onChange(of: settings.pendingInsightEntryIDs) { _, _ in
                consumePendingInsightSelectionIfNeeded()
                refreshPresentationState()
                requestSuggestionRefresh()
            }
            .onChange(of: settings.pendingInsightsLensRaw) { _, _ in
                consumePendingInsightSelectionIfNeeded()
                refreshPresentationState()
                requestSuggestionRefresh(force: true)
            }
            .onChange(of: selectedEntryIDs) { _, _ in
                refreshPresentationState()
                requestSuggestionRefresh()
            }
            .task(id: workspaceEditorMonitorID) {
                await monitorWorkspaceEntryForRemoteChanges()
            }
            .onDisappear {
                refreshTask?.cancel()
            }
            .persistenceFailureAlert($persistenceAlert)
        }
    }

    private var topChrome: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            studioHeader
            sourceSelectionCard
            scopeContextCard
        }
    }

    private var studioHeader: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            AppSectionHeader(
                eyebrow: "Insights",
                title: "\(selectedLens.title) Studio",
                subtitle: selectedLens.summary
            )

            Spacer(minLength: DSSpacing.md)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(DSColor.quietText)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityIdentifier("insights.studio.close")
        }
    }

    private var sourceSelectionCard: some View {
        AppPanel(
            title: selectedEntries.isEmpty ? "Choose source notes" : "Selected reflections",
            subtitle: selectedEntries.isEmpty
                ? "Choose notes from Journal first. Studio patterns and drafts will stay grounded in those reflections. \(studioScopeCountText)."
                : "\(sourceEntryCountText) currently shaping this Studio session.",
            role: .reading,
            highlighted: true
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                if !selectedEntries.isEmpty {
                    selectedEntriesPreview
                }

                ViewThatFits(in: .horizontal) {
                    sourceActionRow
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        sourcePrimaryAction
                        sourceSecondaryActions
                    }
                }
            }
        }
    }

    private var selectedEntriesPreview: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                ForEach(selectedEntries.prefix(3)) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entryHeadline(for: entry))
                            .font(DSFont.body.weight(.semibold))
                            .foregroundStyle(DSColor.textPrimary)
                            .lineLimit(1)
                        if let preview = entryPreview(for: entry) {
                            Text(preview)
                                .font(DSFont.supporting)
                                .foregroundStyle(DSColor.quietText)
                                .lineLimit(1)
                        }
                        if let experience = entry.applicationExperience {
                            InsightLinkedExperienceChip(experience: experience)
                                .padding(.top, 2)
                        }
                    }
                }
            }
        }
    }

    private var sourcePrimaryAction: some View {
        Button(action: presentEntryPicker) {
            Label(selectedEntries.isEmpty ? "Choose Notes" : "Edit Selection", systemImage: selectedEntries.isEmpty ? "plus.circle" : "slider.horizontal.3")
        }
        .buttonStyle(.appPrimary)
        .accessibilityIdentifier("insights.chooseNotes")
    }

    @ViewBuilder
    private var sourceSecondaryActions: some View {
        HStack(spacing: DSSpacing.sm) {
            if selectedLens.nodeKind != nil && !selectedEntries.isEmpty {
                Button(action: beginManualNodeCreation) {
                    Label("Add \(selectedLens.nodeKind?.displayName ?? "Insight")", systemImage: "plus")
                }
                .buttonStyle(.appSecondary)
            }

            if !selectedEntries.isEmpty {
                Button("Clear") {
                    selectedEntryIDs.removeAll()
                }
                .buttonStyle(.appQuiet)
            }
        }
    }

    private var sourceActionRow: some View {
        HStack(alignment: .center, spacing: DSSpacing.sm) {
            sourcePrimaryAction
            Spacer(minLength: DSSpacing.sm)
            sourceSecondaryActions
        }
    }

    private var scopeContextCard: some View {
        AppPanel(role: .quiet) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text(studioScopeCountText)
                    .font(DSFont.supporting)
                    .foregroundStyle(DSColor.quietText)
                    .accessibilityIdentifier("insights.sourceCount")

                if selectedLens == .themes {
                    Picker("Theme Scope", selection: $selectedThemeScope) {
                        ForEach(ThemeClusterScope.allCases) { scope in
                            Text(scope.displayName).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedThemeScope == .withinExperience {
                        Picker("Experience", selection: $selectedWithinExperience) {
                            ForEach(ExperienceType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
        }
    }

    private var analysisLoadingCard: some View {
        HStack(spacing: DSSpacing.md) {
            ProgressView()
            Text("Looking for patterns...")
                .font(DSFont.supporting)
                .foregroundStyle(DSColor.quietText)
        }
        .padding()
    }

    private func analysisErrorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("Interrupted: \(message)")
                .font(DSFont.body)
                .foregroundStyle(DSColor.error)
            Button("Try Again") {
                requestSuggestionRefresh(force: true)
            }
            .buttonStyle(.appQuiet)
        }
    }

    private var emptyCard: some View {
        VStack(spacing: DSSpacing.md) {
            Text("Nothing to show yet")
                .font(DSFont.heading2)
                .foregroundStyle(DSColor.textPrimary)
            Text("Select notes from Journal or manually add an insight to begin.")
                .font(DSFont.supporting)
                .foregroundStyle(DSColor.quietText)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, DSSpacing.xl)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var surfacedInsightsSection: some View {
        if !visibleSuggestions.isEmpty {
            insightSection(
                title: "Suggested Patterns",
                subtitle: "Grounded in your notes. Nothing is saved until you pin it."
            ) {
                ForEach(visibleSuggestions) { suggestion in
                    InsightSuggestionCard(
                        suggestion: suggestion,
                        entriesByID: entriesByID,
                        onAccept: { acceptSuggestion($0) },
                        onHide: { hideSuggestion($0) },
                        onUseInDraft: { useSuggestionInDraft($0) }
                    )
                }
            }
        }

        if !acceptedNodes.isEmpty {
            insightSection(
                title: "Saved \(selectedLens.title)",
                subtitle: "Insights you are actively carrying forward."
            ) {
                ForEach(acceptedNodes) { node in
                    InsightNodeCard(
                        node: node,
                        entriesByID: entriesByID,
                        linkedWorkspaceEntries: linkedWorkspaceEntriesByNodeID[node.id] ?? [],
                        canAttachSelectedEntries: !selectedEntryIDs.isEmpty,
                        onRename: { beginRename(node) },
                        onTogglePin: { togglePin(node) },
                        onHide: { hideNode(node) },
                        onUseInDraft: { useNodeInDraft(node) },
                        onOpenReflection: { openLinkedWorkspaceEntry(for: node) },
                        onAttachSelectedEntries: { attachSelectedEntries(to: node) },
                        onDetachEntry: { detach(entryID: $0, from: node) }
                    )
                }
            }
        }

        if visibleSuggestions.isEmpty && acceptedNodes.isEmpty {
            emptyCard
        }
    }

    private var guidedWorkspaceSection: some View {
        insightSection(
            title: "Brainstorming",
            subtitle: "Turn patterns into your own written thinking. Draft use and publishing stay separate, and published reflections move into an editable archive."
        ) {
            InsightWorkspaceSection(
                lens: selectedLens,
                context: workspaceContext,
                templates: promptTemplates,
                entries: workspaceEntriesForSelectedLens,
                entriesByID: entriesByID,
                onStartPrompt: { beginWorkspaceEntry(prompt: $0) },
                onStartBlank: beginBlankWorkspaceEntry,
                onEdit: beginEditingWorkspaceEntry,
                onTogglePin: togglePin,
                onDelete: deleteWorkspaceEntry,
                onUseInDraft: useWorkspaceEntryInDraft,
                onPublish: publishWorkspaceEntry
            )
        }
    }

    @ViewBuilder
    private func insightSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DSFont.sectionTitle)
                    .foregroundStyle(DSColor.textPrimary)
                Text(subtitle)
                    .font(DSFont.supporting)
                    .foregroundStyle(DSColor.quietText)
            }

            VStack(spacing: DSSpacing.md) {
                content()
            }
        }
    }

    // MARK: - State Logic
    private func refreshPresentationState() {
        let currentJournalEntries = journalEntries
        entriesByIDCache = Dictionary(uniqueKeysWithValues: currentJournalEntries.map { ($0.id, $0) })
        selectedEntriesCache = currentJournalEntries
            .filter { selectedEntryIDs.contains($0.id) }
            .sorted(by: { $0.date > $1.date })

        let baseEntries = selectedEntriesCache.isEmpty ? currentJournalEntries : selectedEntriesCache

        switch selectedLens {
        case .themes:
            switch selectedThemeScope {
            case .acrossExperiences:
                scopedJournalEntriesCache = baseEntries
            case .withinExperience:
                scopedJournalEntriesCache = baseEntries.filter { $0.experienceType == selectedWithinExperience }
            }
        case .experiences, .values, .why:
            scopedJournalEntriesCache = baseEntries
        }

        acceptedNodesCache = allInsightNodes
            .filter { $0.status == .accepted && !$0.isHidden && $0.kind.lens == selectedLens }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhs.updatedAt > rhs.updatedAt
            }

        activeWorkspaceEntriesCache = allWorkspaceEntries
            .filter { $0.lens == selectedLens && $0.linkedInsightNode == nil }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                return lhs.updatedAt > rhs.updatedAt
            }
        linkedWorkspaceEntriesByNodeIDCache = InsightsViewSupport.linkedWorkspaceEntriesByNodeID(from: allWorkspaceEntries)

        visibleSuggestionsCache = suggestions.compactMap { suggestion in
            guard let persisted = existingNode(for: suggestion) else { return suggestion }
            guard !persisted.isHidden else { return nil }

            var hydrated = suggestion
            hydrated.persistedNodeID = persisted.id
            hydrated.isAccepted = persisted.status == .accepted
            hydrated.title = persisted.title
            hydrated.normalizedTitle = persisted.normalizedTitle
            return hydrated
        }
    }

    private func requestSuggestionRefresh(force: Bool = false) {
        let relevantEntries = scopedJournalEntries
        guard !relevantEntries.isEmpty else {
            refreshTask?.cancel()
            suggestions = []
            analysisError = nil
            isAnalyzing = false
            lastRefreshSignature = nil
            refreshPresentationState()
            return
        }

        let inputs = analysisService.makeInputs(from: relevantEntries)
        guard !inputs.isEmpty else { return }

        let cacheKey = AnalysisCacheKey(
            lens: selectedLens,
            themeScope: selectedLens == .themes ? selectedThemeScope : nil,
            selectedExperienceRaw: selectedLens == .themes && selectedThemeScope == .withinExperience ? selectedWithinExperience.rawValue : nil,
            selectedEntryIDs: selectedEntryIDs.sorted { $0.uuidString < $1.uuidString },
            inputFingerprint: fingerprint(for: inputs)
        )
        let signature = RefreshSignature(cacheKey: cacheKey, nodeRevision: nodeRevision(for: selectedLens))

        guard force || signature != lastRefreshSignature else { return }
        lastRefreshSignature = signature

        if let cached = cachedSuggestions[cacheKey] {
            suggestions = cached
            isAnalyzing = false
            refreshPresentationState()
            return
        }

        refreshTask?.cancel()
        refreshTask = Task { await refreshSuggestions(cacheKey: cacheKey, inputs: inputs) }
    }

    private func refreshSuggestions(cacheKey: AnalysisCacheKey, inputs: [InsightAnalysisInput]) async {
        await MainActor.run { isAnalyzing = true; analysisError = nil }

        let deterministic: [InsightSuggestion]
        switch cacheKey.lens {
        case .themes:
            deterministic = analysisService.analyzeThemes(
                entries: inputs,
                taxonomyTitles: themeTaxonomyTitles,
                scope: cacheKey.themeScope ?? .acrossExperiences,
                selectedExperience: cacheKey.selectedExperienceRaw.flatMap(ExperienceType.init(rawValue:))
            )
        case .experiences:
            deterministic = analysisService.analyzeExperiences(entries: inputs)
        case .values:
            deterministic = analysisService.analyzeValues(entries: inputs, profile: currentProfile)
        case .why:
            deterministic = analysisService.analyzeWhy(entries: inputs, profile: currentProfile)
        }

        guard !Task.isCancelled else { return }

        await MainActor.run {
            cachedSuggestions[cacheKey] = deterministic
            suggestions = deterministic
            isAnalyzing = false
            refreshPresentationState()
        }
    }

    private func consumePendingInsightSelectionIfNeeded() {
        if let pendingLens = settings.pendingInsightsLens {
            selectedLens = pendingLens
            settings.pendingInsightsLens = nil
        }
        guard !settings.pendingInsightEntryIDs.isEmpty else { return }
        selectedEntryIDs.formUnion(settings.pendingInsightEntryIDs)
        settings.pendingInsightEntryIDs = []
    }

    @ViewBuilder
    private func insightSheetContent(for route: InsightsSheetRoute) -> some View {
        switch route {
        case .entryPicker:
            InsightEntryPickerView(initialSelection: selectedEntryIDs) { entries in
                selectedEntryIDs = Set(entries.map(\.id))
            }
        case .manualNode(let kind):
            InsightNodeTitleSheet(
                navigationTitle: "Create \(kind.displayName)",
                prompt: "\(kind.displayName) title",
                guidance: "Use a concise, evidence-based label.",
                title: $manualNodeTitle,
                saveTitle: "Create",
                useImmersive: settings.appThemeMode == .core
            ) { createManualNode(kind: kind) }
        case .renameNode(let nodeID):
            InsightNodeTitleSheet(
                navigationTitle: "Rename Insight",
                prompt: "Insight title",
                guidance: "Keep the label grounded in evidence.",
                title: $renameText,
                saveTitle: "Save",
                useImmersive: settings.appThemeMode == .core
            ) { renameNode(nodeID) }
        case .addToDraft(let payload):
            AddToStatementSheet(
                selectedEntries: draftEntries(for: payload.entryIDs),
                selectedWorkspaceEntries: draftWorkspaceEntries(for: payload.workspaceEntryIDs),
                onDraftCreated: { draft in
                    withAnimation(AnimationConfig.screenTransition) {
                        createdDraftConfirmation = CreatedDraftConfirmation(draft: draft)
                    }
                }
            )
        case .workspaceEditor:
            InsightWorkspaceEditorSheet(
                lens: workspaceDraft.lens,
                title: $workspaceDraft.title,
                draftBody: $workspaceDraft.body,
                promptTitle: InsightPromptCatalog.template(for: workspaceDraft.promptKey)?.title,
                promptText: InsightPromptCatalog.template(for: workspaceDraft.promptKey)?.resolvedPrompt(using: workspaceContext),
                syncConflict: activeWorkspaceConflict,
                syncStatusMessage: workspaceSyncStatusMessage,
                onDismissSyncStatus: {
                    withAnimation(AnimationConfig.screenTransition) {
                        workspaceSyncStatusMessage = nil
                    }
                },
                onSave: saveWorkspaceEntry,
                onKeepLocalEdits: keepLocalWorkspaceEdits,
                onReloadRemoteVersion: reloadRemoteWorkspaceEntry,
                onSaveLocalCopy: saveLocalWorkspaceEntryAsCopy,
                onDeepSearch: { performDeepSearch(query: workspaceDraft.body) }
            )
        }
    }

    // MARK: - Actions
    private func presentEntryPicker() { activeSheet = .entryPicker }
    private func beginManualNodeCreation() { 
        guard let kind = selectedLens.nodeKind else { return }
        manualNodeTitle = ""; activeSheet = .manualNode(kind) 
    }
    private func beginBlankWorkspaceEntry() {
        workspaceDraft = WorkspaceDraftState(lens: selectedLens, title: "\(selectedLens.title) Brainstorm", body: "", sourceEntryIDs: defaultWorkspaceSourceEntryIDs())
        activeWorkspaceConflict = nil
        workspaceSyncStatusMessage = nil
        activeSheet = .workspaceEditor
    }
    private func beginWorkspaceEntry(prompt: InsightPromptTemplate) {
        workspaceDraft = WorkspaceDraftState(lens: selectedLens, title: prompt.suggestedTitle(using: workspaceContext), promptKey: prompt.promptKey, body: "", sourceEntryIDs: defaultWorkspaceSourceEntryIDs())
        activeWorkspaceConflict = nil
        workspaceSyncStatusMessage = nil
        activeSheet = .workspaceEditor
    }
    private func beginEditingWorkspaceEntry(_ entry: InsightWorkspaceEntry) {
        let snapshot = InsightWorkspaceEntrySyncSnapshot(entry: entry)
        workspaceDraft = WorkspaceDraftState(
            existingID: entry.id,
            lens: entry.lens,
            title: entry.title,
            promptKey: entry.promptKey,
            body: entry.body,
            linkedNodeID: entry.linkedInsightNode?.id,
            sourceEntryIDs: entry.sourceEntryIDs,
            openedSnapshot: snapshot,
            observedUpdatedAt: snapshot.updatedAt,
            observedSyncRevision: snapshot.syncRevision
        )
        activeWorkspaceConflict = nil
        workspaceSyncStatusMessage = nil
        activeSheet = .workspaceEditor
    }
    
    private func createManualNode(kind: InsightNodeKind) {
        let trimmed = manualNodeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let experienceType = currentScopedExperienceType()
        let node = existingNode(forKind: kind, normalizedTitle: InsightNode.normalize(trimmed), experienceType: experienceType) ?? InsightNode(kind: kind, title: trimmed, status: .accepted, confidence: 1, source: .manual, experienceType: experienceType, isPinned: true)
        if node.modelContext == nil {
            modelContext.insert(node)
        }
        node.rename(to: trimmed)
        node.status = .accepted
        node.source = .manual
        node.experienceType = experienceType
        node.isHidden = false
        node.isPinned = true
        attachSelectedEntries(to: node, saveAfterMutation: false)
        saveContext()
        manualNodeTitle = ""
        activeSheet = nil
    }

    private func acceptSuggestion(_ suggestion: InsightSuggestion) {
        _ = InsightsSuggestionAcceptance.accept(
            suggestion,
            existingNodes: allInsightNodes,
            entriesByID: entriesByID,
            context: modelContext
        )
        saveContext()
    }

    private func hideSuggestion(_ suggestion: InsightSuggestion) {
        let node = existingNode(for: suggestion) ?? InsightNode(
            kind: suggestion.kind,
            title: suggestion.title,
            normalizedTitle: suggestion.normalizedTitle,
            status: .suggested,
            confidence: suggestion.confidence,
            source: suggestion.source,
            experienceType: suggestion.experienceType
        )
        if node.modelContext == nil {
            modelContext.insert(node)
        }
        node.source = suggestion.source
        node.isHidden = true
        node.experienceType = suggestion.experienceType
        saveContext()
    }

    private func beginRename(_ node: InsightNode) {
        renameText = node.title
        activeSheet = .renameNode(node.id)
    }

    private func renameNode(_ nodeID: UUID) {
        guard let node = node(for: nodeID) else { return }
        node.rename(to: renameText)
        saveContext()
        activeSheet = nil
    }

    private func togglePin(_ node: InsightNode) {
        node.isPinned.toggle()
        saveContext()
    }

    private func togglePin(_ entry: InsightWorkspaceEntry) {
        entry.isPinned.toggle()
        saveContext()
    }

    private func hideNode(_ node: InsightNode) {
        node.isHidden = true
        saveContext()
    }

    private func attachSelectedEntries(to node: InsightNode, saveAfterMutation: Bool = true) {
        attachEntries(Array(selectedEntryIDs), to: node, saveAfterMutation: saveAfterMutation)
    }

    private func detach(entryID: UUID, from node: InsightNode) {
        node.links.removeAll { $0.entryID == entryID }
        saveContext()
    }

    private func saveWorkspaceEntry() {
        let trimmed = workspaceDraft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        checkForRemoteWorkspaceEntryUpdate()
        if activeWorkspaceConflict != nil {
            workspaceSyncStatusMessage = "Choose how to continue before saving this brainstorming entry."
            return
        }
        
        let entry: InsightWorkspaceEntry
        if let id = workspaceDraft.existingID, let existing = allWorkspaceEntries.first(where: { $0.id == id }) {
            entry = existing
        } else {
            entry = InsightWorkspaceEntry(lens: workspaceDraft.lens, title: workspaceDraft.title)
            modelContext.insert(entry)
        }
        
        let savedAt = Date()
        entry.applyEditorDraft(
            title: workspaceDraft.title,
            body: trimmed,
            promptKey: workspaceDraft.promptKey,
            sourceEntryIDs: workspaceDraft.sourceEntryIDs,
            at: savedAt
        )
        workspaceDraft.lastLocalSaveAt = savedAt
        workspaceDraft.lastLocalSaveFingerprint = InsightWorkspaceEntrySyncSnapshot(entry: entry).contentFingerprint
        saveContext()
        activeSheet = nil
    }

    private func monitorWorkspaceEntryForRemoteChanges() async {
        guard activeSheet?.id == InsightsSheetRoute.workspaceEditor.id else { return }

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                checkForRemoteWorkspaceEntryUpdate()
            }
        }
    }

    private func checkForRemoteWorkspaceEntryUpdate() {
        guard activeSheet?.id == InsightsSheetRoute.workspaceEditor.id,
              let openedSnapshot = workspaceDraft.openedSnapshot,
              let refreshedEntry = refreshedWorkspaceEntry(for: openedSnapshot.id) else {
            return
        }

        let remoteSnapshot = InsightWorkspaceEntrySyncSnapshot(entry: refreshedEntry)
        let localFingerprint = workspaceDraft.currentContentFingerprint
        let isLocalSaveEcho = workspaceDraft.lastLocalSaveAt.map {
            abs(remoteSnapshot.updatedAt.timeIntervalSince($0)) < 0.01
        } ?? false

        if isLocalSaveEcho,
           remoteSnapshot.contentFingerprint == workspaceDraft.lastLocalSaveFingerprint,
           localFingerprint == remoteSnapshot.contentFingerprint {
            markWorkspaceDraftLoaded(from: remoteSnapshot)
            return
        }

        if let conflict = remoteSnapshot.remoteConflictIfNeeded(
            openedSnapshot: openedSnapshot,
            currentLocalFingerprint: localFingerprint,
            observedUpdatedAt: workspaceDraft.observedUpdatedAt,
            observedSyncRevision: workspaceDraft.observedSyncRevision
        ) {
            workspaceDraft.observedUpdatedAt = remoteSnapshot.updatedAt
            workspaceDraft.observedSyncRevision = remoteSnapshot.syncRevision
            withAnimation(AnimationConfig.screenTransition) {
                activeWorkspaceConflict = conflict
                workspaceSyncStatusMessage = nil
            }
            return
        }

        guard activeWorkspaceConflict == nil else { return }
        guard remoteSnapshot.contentFingerprint != openedSnapshot.contentFingerprint else { return }
        guard workspaceDraft.currentContentFingerprint == openedSnapshot.contentFingerprint else { return }

        loadWorkspaceDraft(from: refreshedEntry)
        workspaceSyncStatusMessage = "The latest iCloud version is now open."
    }

    private func keepLocalWorkspaceEdits() {
        guard let id = workspaceDraft.existingID,
              let entry = refreshedWorkspaceEntry(for: id) else { return }

        let savedAt = Date()
        entry.applyEditorDraft(
            title: workspaceDraft.title,
            body: workspaceDraft.body,
            promptKey: workspaceDraft.promptKey,
            sourceEntryIDs: workspaceDraft.sourceEntryIDs,
            resolvingConflict: true,
            at: savedAt
        )
        workspaceDraft.lastLocalSaveAt = savedAt
        workspaceDraft.lastLocalSaveFingerprint = InsightWorkspaceEntrySyncSnapshot(entry: entry).contentFingerprint
        saveContext()
        markWorkspaceDraftLoaded(from: InsightWorkspaceEntrySyncSnapshot(entry: entry))
        activeWorkspaceConflict = nil
        workspaceSyncStatusMessage = "Your edits were kept in this entry."
    }

    private func reloadRemoteWorkspaceEntry() {
        guard let id = workspaceDraft.existingID,
              let entry = refreshedWorkspaceEntry(for: id) else { return }
        loadWorkspaceDraft(from: entry)
        activeWorkspaceConflict = nil
        workspaceSyncStatusMessage = "The latest iCloud version is now open."
    }

    private func saveLocalWorkspaceEntryAsCopy() {
        let trimmed = workspaceDraft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let baseTitle = workspaceDraft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let copy = InsightWorkspaceEntry(
            lens: workspaceDraft.lens,
            title: baseTitle.isEmpty ? "Brainstorm Copy" : "\(baseTitle) Copy",
            promptKey: workspaceDraft.promptKey,
            body: trimmed,
            sourceEntryIDs: workspaceDraft.sourceEntryIDs
        )
        copy.syncRevision = 0
        modelContext.insert(copy)
        saveContext()

        if let id = workspaceDraft.existingID,
           let remoteEntry = refreshedWorkspaceEntry(for: id) {
            loadWorkspaceDraft(from: remoteEntry)
        }

        activeWorkspaceConflict = nil
        workspaceSyncStatusMessage = "Saved your edits as \(copy.title). The iCloud version is open here."
    }

    private func refreshedWorkspaceEntry(for id: UUID) -> InsightWorkspaceEntry? {
        if let entry = allWorkspaceEntries.first(where: { $0.id == id }) {
            return entry
        }

        var descriptor = FetchDescriptor<InsightWorkspaceEntry>(
            predicate: #Predicate { candidate in
                candidate.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func loadWorkspaceDraft(from entry: InsightWorkspaceEntry) {
        let snapshot = InsightWorkspaceEntrySyncSnapshot(entry: entry)
        workspaceDraft.existingID = entry.id
        workspaceDraft.lens = entry.lens
        workspaceDraft.title = entry.title
        workspaceDraft.promptKey = entry.promptKey
        workspaceDraft.body = entry.body
        workspaceDraft.linkedNodeID = entry.linkedInsightNode?.id
        workspaceDraft.sourceEntryIDs = entry.sourceEntryIDs
        markWorkspaceDraftLoaded(from: snapshot)
    }

    private func markWorkspaceDraftLoaded(from snapshot: InsightWorkspaceEntrySyncSnapshot) {
        workspaceDraft.openedSnapshot = snapshot
        workspaceDraft.observedUpdatedAt = snapshot.updatedAt
        workspaceDraft.observedSyncRevision = snapshot.syncRevision
        workspaceDraft.lastLocalSaveAt = nil
        workspaceDraft.lastLocalSaveFingerprint = nil
    }

    private func performDeepSearch(query: String) {
        let service = InsightsAnalysisService()
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty, let queryVector = service.generateSemanticEmbedding(text: cleanQuery) else { return }
        
        let threshold = 0.55
        var matches: [(id: UUID, score: Double)] = []
        
        for session in allSessions {
            if let vector = semanticVector(for: session.id) {
                let score = service.cosineSimilarity(a: queryVector, b: vector)
                if score >= threshold {
                    matches.append((id: session.id, score: score))
                }
            } else {
                let text = session.notes ?? session.personalStatement
                let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanText.isEmpty, let vector = service.generateSemanticEmbedding(text: cleanText) {
                    cacheSemanticVector(vector, for: session.id)
                    let score = service.cosineSimilarity(a: queryVector, b: vector)
                    if score >= threshold {
                        matches.append((id: session.id, score: score))
                    }
                }
            }
        }
        
        saveContext()
        
        matches.sort { $0.score > $1.score }
        let topIDs = matches.prefix(5).map(\.id)
        
        let existingSet = Set(workspaceDraft.sourceEntryIDs)
        for id in topIDs {
            if !existingSet.contains(id) {
                workspaceDraft.sourceEntryIDs.append(id)
            }
        }
    }

    private func semanticVector(for entryID: UUID) -> [Double]? {
        semanticVectorCaches.first { $0.entryID == entryID }?.values
    }

    private func cacheSemanticVector(_ vector: [Double], for entryID: UUID) {
        if let existing = semanticVectorCaches.first(where: { $0.entryID == entryID }) {
            existing.values = vector
            existing.updatedAt = .now
        } else {
            modelContext.insert(SemanticVectorCache(entryID: entryID, values: vector))
        }
    }

    private func deleteWorkspaceEntry(_ entry: InsightWorkspaceEntry) {
        modelContext.delete(entry)
        saveContext()
    }

    private func publishWorkspaceEntry(_ entry: InsightWorkspaceEntry) {
        guard let kind = entry.lens.nodeKind else { return }
        _ = InsightsWorkspacePublisher.publish(
            entry: entry,
            defaultKind: kind,
            experienceType: currentPublishedExperienceType(for: entry),
            sessionsByID: entriesByID,
            context: modelContext
        )
        saveContext()
    }

    private func useSuggestionInDraft(_ suggestion: InsightSuggestion) {
        activeSheet = .addToDraft(DraftSheetPayload(entryIDs: suggestion.entries.map(\.entryID), workspaceEntryIDs: []))
    }
    private func useNodeInDraft(_ node: InsightNode) {
        let linkedWorkspaceIDs = linkedWorkspaceEntriesByNodeID[node.id, default: []].map(\.id)
        activeSheet = .addToDraft(DraftSheetPayload(entryIDs: node.links.map(\.entryID), workspaceEntryIDs: linkedWorkspaceIDs))
    }
    private func useWorkspaceEntryInDraft(_ entry: InsightWorkspaceEntry) {
        activeSheet = .addToDraft(DraftSheetPayload(entryIDs: [], workspaceEntryIDs: [entry.id]))
    }

    private func openLinkedWorkspaceEntry(for node: InsightNode) {
        guard let entry = linkedWorkspaceEntriesByNodeID[node.id]?.first else { return }
        beginEditingWorkspaceEntry(entry)
    }

    // MARK: - Helpers
    private func saveContext() {
        do {
            _ = try modelContext.persistIfNeeded(for: "save your insights")
            refreshPresentationState()
        } catch let error as PersistenceOperationError {
            persistenceAlert = error.alertContext
            logger.error("Failed to save insights: \(error.localizedDescription)")
        } catch {
            persistenceAlert = PersistenceAlertContext.saveFailure(
                for: "save your insights",
                details: error.localizedDescription
            )
            logger.error("Failed to save insights: \(error.localizedDescription)")
        }
    }

    private func clearSheetDraftState() {
        manualNodeTitle = ""; renameText = ""; workspaceDraft = .empty
        activeWorkspaceConflict = nil
        workspaceSyncStatusMessage = nil
    }

    private func defaultWorkspaceSourceEntryIDs() -> [UUID] {
        if !selectedEntryIDs.isEmpty { return Array(selectedEntryIDs) }
        return scopedJournalEntries.map(\.id)
    }

    private func existingNode(for suggestion: InsightSuggestion) -> InsightNode? {
        existingNode(
            forKind: suggestion.kind,
            normalizedTitle: suggestion.normalizedTitle,
            experienceType: suggestion.experienceType
        )
    }

    private func existingNode(forKind kind: InsightNodeKind, normalizedTitle: String, experienceType: ExperienceType?) -> InsightNode? {
        let key = InsightNode.identityKey(
            kind: kind,
            normalizedTitle: normalizedTitle,
            experienceType: experienceType
        )
        return allInsightNodes.first {
            InsightNode.identityKey(
                kind: $0.kind,
                normalizedTitle: $0.normalizedTitle,
                experienceType: $0.experienceType
            ) == key
        }
    }

    private func node(for id: UUID) -> InsightNode? { allInsightNodes.first { $0.id == id } }
    
    private func draftEntries(for ids: [UUID]) -> [ExamenSession] {
        allSessions.filter { ids.contains($0.id) }
    }
    private func draftWorkspaceEntries(for ids: [UUID]) -> [InsightWorkspaceEntry] {
        allWorkspaceEntries.filter { ids.contains($0.id) }
    }

    private func fingerprint(for inputs: [InsightAnalysisInput]) -> Int {
        InsightsViewSupport.inputFingerprint(for: inputs)
    }

    private func nodeRevision(for lens: InsightLens) -> Int {
        allInsightNodes.filter { $0.kind.lens == lens }.count
    }

    private func orderedUniqueTitles(from items: [String]) -> [String] {
        var seen = Set<String>(); var list = [String]()
        for item in items { if !seen.contains(item) { seen.insert(item); list.append(item) } }
        return list
    }

    private func entryHeadline(for entry: ExamenSession) -> String {
        if let role = entry.roleTitle, !role.isEmpty { return role }
        return entry.title.isEmpty ? "Reflection" : entry.title
    }

    private func entryPreview(for entry: ExamenSession) -> String? {
        entry.notes
    }

    private func currentScopedExperienceType() -> ExperienceType? {
        InsightsViewSupport.publishedExperienceType(
            for: selectedLens,
            themeScope: selectedThemeScope,
            selectedWithinExperience: selectedWithinExperience
        )
    }

    private func currentPublishedExperienceType(for entry: InsightWorkspaceEntry) -> ExperienceType? {
        InsightsViewSupport.publishedExperienceType(
            for: entry.lens,
            themeScope: selectedThemeScope,
            selectedWithinExperience: selectedWithinExperience
        )
    }

    private func attachEntries(
        _ entryIDs: [UUID],
        to node: InsightNode,
        evidenceByEntryID: [UUID: (snippet: String, confidence: Double)] = [:],
        saveAfterMutation: Bool = true
    ) {
        let existingLinks = Dictionary(uniqueKeysWithValues: node.links.map { ($0.entryID, $0) })
        for entryID in Array(Set(entryIDs)) {
            let suggestedEvidence = evidenceByEntryID[entryID]
            let evidenceSnippet = suggestedEvidence?.snippet
                ?? entriesByID[entryID].map { InsightsAnalysisService.truncatedEvidenceSnippet(from: $0.themeAnalysisText()) }
                ?? "Linked reflection"
            let confidence = suggestedEvidence?.confidence ?? 0.82

            if let existingLink = existingLinks[entryID] {
                if suggestedEvidence != nil || existingLink.evidenceSnippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    existingLink.evidenceSnippet = evidenceSnippet
                }
                existingLink.confidence = max(existingLink.confidence, confidence)
            } else {
                let link = InsightEntryLink(
                    entryID: entryID,
                    evidenceSnippet: evidenceSnippet,
                    confidence: confidence,
                    insightNode: node
                )
                modelContext.insert(link)
            }
        }

        if saveAfterMutation {
            saveContext()
        }
    }
}

// MARK: - Reconstructed Subviews
private struct InsightSuggestionCard: View {
    let suggestion: InsightSuggestion
    let entriesByID: [UUID: ExamenSession]
    let onAccept: (InsightSuggestion) -> Void
    let onHide: (InsightSuggestion) -> Void
    let onUseInDraft: (InsightSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Text(suggestion.title)
                    .font(DSFont.body.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                Menu {
                    Button("Hide", role: .destructive) { onHide(suggestion) }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(DSColor.quietText)
                }
            }
            Text("\(suggestion.entries.count) notes connected")
                .font(DSFont.supporting)
                .foregroundStyle(DSColor.quietText)
            HStack {
                Button("Save Pattern") { onAccept(suggestion) }.buttonStyle(.appPrimary)
                Button("Draft") { onUseInDraft(suggestion) }.buttonStyle(.appSecondary)
            }
        }
        .padding(DSSpacing.md)
        .background(DSColor.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct InsightNodeCard: View {
    let node: InsightNode
    let entriesByID: [UUID: ExamenSession]
    let linkedWorkspaceEntries: [InsightWorkspaceEntry]
    let canAttachSelectedEntries: Bool
    let onRename: () -> Void
    let onTogglePin: () -> Void
    let onHide: () -> Void
    let onUseInDraft: () -> Void
    let onOpenReflection: () -> Void
    let onAttachSelectedEntries: () -> Void
    let onDetachEntry: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Text(node.title)
                    .font(DSFont.body.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                Menu {
                    Button("Rename") { onRename() }
                    Button(node.isPinned ? "Unpin" : "Pin") { onTogglePin() }
                    if canAttachSelectedEntries { Button("Attach Selected Notes") { onAttachSelectedEntries() } }
                    Button("Remove", role: .destructive) { onHide() }
                } label: { Image(systemName: "ellipsis.circle").foregroundStyle(DSColor.quietText) }
            }
            Text("\(node.links.count) connected")
                .font(DSFont.supporting).foregroundStyle(DSColor.quietText)
            HStack {
                Button("Start Draft") { onUseInDraft() }.buttonStyle(.appPrimary)
                    .accessibilityIdentifier("insights.node.draft.\(node.id.uuidString)")
                if !linkedWorkspaceEntries.isEmpty {
                    Button("Open Reflection") { onOpenReflection() }
                        .buttonStyle(.appSecondary)
                        .accessibilityIdentifier("insights.node.openReflection.\(node.id.uuidString)")
                }
            }
        }
        .padding(DSSpacing.md)
        .background(DSColor.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct InsightWorkspaceSection: View {
    let lens: InsightLens
    let context: InsightPromptContext
    let templates: [InsightPromptTemplate]
    let entries: [InsightWorkspaceEntry]
    let entriesByID: [UUID: ExamenSession]
    let onStartPrompt: (InsightPromptTemplate) -> Void
    let onStartBlank: () -> Void
    let onEdit: (InsightWorkspaceEntry) -> Void
    let onTogglePin: (InsightWorkspaceEntry) -> Void
    let onDelete: (InsightWorkspaceEntry) -> Void
    let onUseInDraft: (InsightWorkspaceEntry) -> Void
    let onPublish: (InsightWorkspaceEntry) -> Void

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            ForEach(templates) { template in
                Button(action: { onStartPrompt(template) }) {
                    HStack {
                        Text(template.title).font(DSFont.body).foregroundStyle(DSColor.accentPrimary)
                        Spacer()
                        Image(systemName: "plus").foregroundStyle(DSColor.accentPrimary)
                    }
                    .padding(DSSpacing.md).background(DSColor.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("insights.prompt.\(template.promptKey)")
            }
            Button("Blank Draft", action: onStartBlank)
                .buttonStyle(.appSecondary)
                .accessibilityIdentifier("insights.workspace.blank")
            
            ForEach(entries) { entry in
                InsightWorkspaceEntryCard(
                    entry: entry,
                    onEdit: { onEdit(entry) },
                    onTogglePin: { onTogglePin(entry) },
                    onDelete: { onDelete(entry) },
                    onUseInDraft: { onUseInDraft(entry) },
                    onPublish: { onPublish(entry) }
                )
            }
        }
    }
}

private struct InsightWorkspaceEntryCard: View {
    let entry: InsightWorkspaceEntry
    let onEdit: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onUseInDraft: () -> Void
    let onPublish: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Text(entry.title).font(DSFont.body.weight(.semibold)).foregroundStyle(DSColor.textPrimary)
                Spacer()
                Menu {
                    Button(entry.isPinned ? "Unpin" : "Pin") { onTogglePin() }
                    Button("Delete", role: .destructive) { onDelete() }
                } label: { Image(systemName: "ellipsis.circle").foregroundStyle(DSColor.quietText) }
            }
            Text(entry.body).font(DSFont.supporting).foregroundStyle(DSColor.textSecondary).lineLimit(3)
            HStack {
                Button("Edit") { onEdit() }
                    .buttonStyle(.appSecondary)
                    .accessibilityIdentifier("insights.workspace.edit.\(entry.id.uuidString)")
                Button("Use in Draft") { onUseInDraft() }
                    .buttonStyle(.appSecondary)
                    .accessibilityIdentifier("insights.workspace.draft.\(entry.id.uuidString)")
                Button("Publish Insight") { onPublish() }
                    .buttonStyle(.appPrimary)
                    .accessibilityIdentifier("insights.workspace.publish.\(entry.id.uuidString)")
            }
        }
        .padding(DSSpacing.md).background(DSColor.surfaceElevated).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct InsightLinkedExperienceChip: View {
    let experience: ApplicationExperience

    var body: some View {
        Label(experience.exportTitle, systemImage: "briefcase")
            .font(DSFont.caption.weight(.semibold))
            .foregroundStyle(DSColor.goldLight)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(DSColor.goldLight.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityLabel("Linked application record, \(experience.exportTitle)")
    }
}

private struct DraftCreatedConfirmationBanner: View {
    let confirmation: InsightStudioView.CreatedDraftConfirmation
    let onOpen: () -> Void
    let onStay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(alignment: .top, spacing: DSSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(DSColor.success)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Draft created")
                        .font(DSFont.body.weight(.semibold))
                        .foregroundStyle(DSColor.textPrimary)
                    Text(confirmation.title)
                        .font(DSFont.supporting)
                        .foregroundStyle(DSColor.quietText)
                        .lineLimit(2)
                }

                Spacer(minLength: DSSpacing.sm)
            }

            HStack(spacing: DSSpacing.sm) {
                Button("Open Draft", action: onOpen)
                    .buttonStyle(.appPrimary)
                Button("Stay in Insights", action: onStay)
                    .buttonStyle(.appSecondary)
            }
        }
        .padding(DSSpacing.md)
        .appSurfaceStyle(role: .interactive, highlighted: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insights.draftCreated")
    }
}

private struct InsightNodeTitleSheet: View {
    let navigationTitle: String
    let prompt: String
    let guidance: String
    @Binding var title: String
    let saveTitle: String
    let useImmersive: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(prompt), footer: Text(guidance)) {
                    TextField(prompt, text: $title)
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(saveTitle) { onSave() } }
            }
        }
    }
}

private struct InsightWorkspaceEditorSheet: View {
    let lens: InsightLens
    @Binding var title: String
    @Binding var draftBody: String
    let promptTitle: String?
    let promptText: String?
    let syncConflict: InsightWorkspaceEntrySyncConflict?
    let syncStatusMessage: String?
    let onDismissSyncStatus: () -> Void
    let onSave: () -> Void
    let onKeepLocalEdits: () -> Void
    let onReloadRemoteVersion: () -> Void
    let onSaveLocalCopy: () -> Void
    var onDeepSearch: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var extractedConcepts: [String] = []
    
    // Phase 3 Generative State
    @State private var mlxManager = MLXManager.shared
    @State private var pendingAIResponse: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                if let pt = promptText { Text(pt).font(DSFont.supporting).padding() }

                workspaceSyncNotice
                
                if !extractedConcepts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(extractedConcepts, id: \.self) { concept in
                                Text(concept)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DSColor.accentPrimary.opacity(0.1))
                                    .foregroundStyle(DSColor.accentPrimary)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                TextEditor(text: $draftBody)
                    .onChange(of: draftBody) { old, new in
                        extractConceptsDebounced(from: new)
                    }
                    .padding()
                
                // Active Generative UI
                if mlxManager.isGenerating || !pendingAIResponse.isEmpty {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(DSColor.accentPrimary)
                            Text("AI Guidance")
                                .font(DSFont.caption.weight(.semibold))
                                .foregroundStyle(DSColor.accentPrimary)
                        }
                        
                        Text(pendingAIResponse)
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textSecondary)
                        
                        if mlxManager.isGenerating {
                            ProgressView()
                                .tint(DSColor.accentPrimary)
                                .padding(.top, DSSpacing.xs)
                        } else if !pendingAIResponse.isEmpty {
                            HStack {
                                Button("Append to Draft") {
                                    withAnimation {
                                        let prefix = draftBody.isEmpty ? "" : "\n\n"
                                        draftBody += prefix + pendingAIResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                                        pendingAIResponse = ""
                                    }
                                }
                                .buttonStyle(.appPrimary)
                                
                                Button("Discard") {
                                    withAnimation { pendingAIResponse = "" }
                                }
                                .buttonStyle(.appSecondary)
                            }
                            .padding(.top, DSSpacing.sm)
                        }
                    }
                    .padding()
                    .background(DSColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Brainstorm").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Discard") { dismiss() } }
                
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        if let onDeepSearch {
                            Button(action: onDeepSearch) { Label("Deep Search", systemImage: "magnifyingglass.circle") }
                        }
                        
                        Button {
                            performPonderAction()
                        } label: { 
                            Label(mlxManager.isModelLoaded ? "Ponder with AI" : "Deepen Reflection", systemImage: mlxManager.isModelLoaded ? "sparkles" : "ellipsis.bubble")
                        }
                        .disabled(mlxManager.isGenerating)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                        .accessibilityIdentifier("insights.workspace.save")
                }
            }
            .onAppear { extractConceptsDebounced(from: draftBody) }
            .onChange(of: mlxManager.currentResponse) { old, new in
                self.pendingAIResponse = new
            }
        }
    }

    @ViewBuilder
    private var workspaceSyncNotice: some View {
        if let syncConflict {
            WorkspaceSyncConflictCard(
                conflict: syncConflict,
                onKeepLocalEdits: onKeepLocalEdits,
                onReloadRemoteVersion: onReloadRemoteVersion,
                onSaveLocalCopy: onSaveLocalCopy
            )
            .padding(.horizontal)
            .padding(.top, DSSpacing.sm)
        } else if let syncStatusMessage {
            HStack(alignment: .top, spacing: DSSpacing.sm) {
                Image(systemName: "checkmark.icloud")
                    .foregroundStyle(DSColor.accentPrimary)
                Text(syncStatusMessage)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Dismiss", action: onDismissSyncStatus)
                    .font(DSFont.caption.weight(.semibold))
            }
            .padding(DSSpacing.sm)
            .appSurfaceStyle(role: .quiet, highlighted: false)
            .padding(.horizontal)
            .padding(.top, DSSpacing.sm)
        }
    }
    
    private func performPonderAction() {
        if mlxManager.isModelLoaded {
            let system = "You are an introspective advisor. Synthesize the user's reflection on their \(lens.rawValue) calmly and briefly. Do not use generic AI language. Expand gently without rewriting their work."
            let user = draftBody.isEmpty ? "I am struggling to find words." : draftBody
            
            Task {
                await mlxManager.generate(
                    systemPrompt: system,
                    userPrompt: user,
                    requestedProfile: AIModelRuntimePolicy.requestedProfile
                )
            }
        } else {
            // Deterministic Fallback if AI disabled or missing
            let fallbackPrompt = InsightPromptCatalog.deterministicFallback(for: lens, concept: extractedConcepts.first)
            withAnimation {
                draftBody += fallbackPrompt
            }
        }
    }
    
    private func extractConceptsDebounced(from text: String) {
        Task.detached {
            let service = InsightsAnalysisService()
            let concepts = Array(service.extractConcepts(from: text).prefix(5))
            await MainActor.run {

                withAnimation { self.extractedConcepts = concepts }
            }
        }
    }
}

private struct WorkspaceSyncConflictCard: View {
    let conflict: InsightWorkspaceEntrySyncConflict
    let onKeepLocalEdits: () -> Void
    let onReloadRemoteVersion: () -> Void
    let onSaveLocalCopy: () -> Void

    private var timestampText: String {
        conflict.remoteModifiedAt.formatted(.dateTime.month().day().hour().minute())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(alignment: .top, spacing: DSSpacing.sm) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.headline)
                    .foregroundStyle(DSColor.warning)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Newer iCloud version available")
                        .font(DSFont.body.weight(.semibold))
                        .foregroundStyle(DSColor.textPrimary)
                    Text("This brainstorming entry changed on another device at \(timestampText). Choose how to continue before you save.")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !conflict.remotePreview.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("iCloud version")
                        .font(DSFont.caption.weight(.semibold))
                        .foregroundStyle(DSColor.textSecondary)
                    Text(conflict.remotePreview)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.quietText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: DSSpacing.xs) {
                Button("Save These Edits as a Copy", action: onSaveLocalCopy)
                    .buttonStyle(.appPrimary)
                Button("Keep My Edits Here", action: onKeepLocalEdits)
                    .buttonStyle(.appSecondary)
                Button("Open iCloud Version", role: .destructive, action: onReloadRemoteVersion)
                    .buttonStyle(.appQuiet)
            }
            .padding(.top, DSSpacing.xs)
        }
        .padding(DSSpacing.md)
        .appSurfaceStyle(role: .interactive, highlighted: true)
        .accessibilityElement(children: .contain)
    }
}

private struct InsightEntryPickerView: View {
    let initialSelection: Set<UUID>
    let onComplete: ([ExamenSession]) -> Void
    @Query(sort: [SortDescriptor(\ExamenSession.date, order: .reverse)]) private var allSessions: [ExamenSession]
    @State private var selection: Set<UUID>
    @Environment(\.dismiss) private var dismiss

    private var journalEntries: [ExamenSession] {
        allSessions.filter { $0.sessionType != .statementDraft }
    }
    
    init(initialSelection: Set<UUID>, onComplete: @escaping ([ExamenSession]) -> Void) {
        self.initialSelection = initialSelection
        self.onComplete = onComplete
        self._selection = State(initialValue: initialSelection)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                InsightsSupportingBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        AppPageHeader(
                            title: "Select Notes",
                            eyebrow: "Source Material",
                            subtitle: "Choose the reflections this Studio session should listen to."
                        )

                        if journalEntries.isEmpty {
                            AppPanel(role: .quiet) {
                                Text("No journal reflections are available yet.")
                                    .font(DSFont.supporting)
                                    .foregroundStyle(DSColor.quietText)
                            }
                        } else {
                            VStack(spacing: DSSpacing.sm) {
                                ForEach(journalEntries) { session in
                                    Button {
                                        toggle(session)
                                    } label: {
                                        HStack(alignment: .top, spacing: DSSpacing.sm) {
                                            Image(systemName: selection.contains(session.id) ? "checkmark.circle.fill" : "circle")
                                                .font(.title3)
                                                .foregroundStyle(selection.contains(session.id) ? DSColor.goldLight : DSColor.quietText)
                                                .frame(width: 28, height: 28)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(headline(for: session))
                                                    .font(DSFont.body.weight(.semibold))
                                                    .foregroundStyle(DSColor.textPrimary)
                                                    .lineLimit(2)

                                                Text(preview(for: session))
                                                    .font(DSFont.supporting)
                                                    .foregroundStyle(DSColor.quietText)
                                                    .lineLimit(2)

                                                HStack(spacing: DSSpacing.xs) {
                                                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                                        .font(DSFont.caption)
                                                        .foregroundStyle(DSColor.quietTextMuted)

                                                    if let experience = session.applicationExperience {
                                                        InsightLinkedExperienceChip(experience: experience)
                                                    }
                                                }
                                            }

                                            Spacer(minLength: 0)
                                        }
                                        .padding(DSSpacing.md)
                                        .appSurfaceStyle(role: .interactive, highlighted: selection.contains(session.id))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("\(headline(for: session)), \(selection.contains(session.id) ? "selected" : "not selected")")
                                }
                            }
                        }
                    }
                    .padding(DSSpacing.lg)
                    .padding(.bottom, DSSpacing.xl)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { 
                    Button("Done") { 
                        onComplete(journalEntries.filter { selection.contains($0.id) })
                        dismiss() 
                    }
                    .disabled(journalEntries.isEmpty)
                }
            }
        }
    }

    private func toggle(_ session: ExamenSession) {
        if selection.contains(session.id) {
            selection.remove(session.id)
        } else {
            selection.insert(session.id)
        }
    }

    private func headline(for session: ExamenSession) -> String {
        if let role = session.roleTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !role.isEmpty {
            return role
        }
        let title = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Reflection" : title
    }

    private func preview(for session: ExamenSession) -> String {
        let candidates: [String?] = [
            session.notes,
            session.personalStatement,
            session.resolvedSecondaryDetail,
            session.experienceType?.displayName
        ]

        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "No preview text yet."
    }
}

struct InsightsSupportingBackground: View {
    var body: some View {
        LinearGradient(colors: [DSColor.backgroundPrimary, DSColor.backgroundSecondary], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}
