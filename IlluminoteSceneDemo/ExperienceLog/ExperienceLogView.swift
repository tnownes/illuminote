import SwiftUI
import SwiftData

struct ExperienceLogView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \ApplicationExperience.dateModified, order: .reverse) private var experiences: [ApplicationExperience]
    @Query(sort: \ExamenSession.date, order: .reverse) private var sessions: [ExamenSession]
    @Query(sort: \UserProfile.id) private var profiles: [UserProfile]

    @State private var showNewExperienceSheet = false
    @State private var showSuggestionsSheet = false
    @State private var exportDocument: ApplicationExperienceCSVDocument?
    @State private var showExporter = false

    private let requirementsService = LocalExperienceEntryRequirementsService.shared

    private var relevantRequirements: [ExperienceEntryRequirement] {
        requirementsService.requirements(for: profiles.first)
    }

    private var listIssues: [ExperienceReadinessIssue] {
        ExperienceReadinessEvaluator.listIssues(for: experiences, requirements: relevantRequirements)
    }

    private var suggestionCandidates: [ExperienceSuggestionCandidate] {
        ExperienceSuggestionCandidate.suggestions(from: sessions, existingExperiences: experiences)
    }

    private var prefersStackedActions: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        ZStack {
            SacredScreenBackground(settings: settings)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard

                    if experiences.isEmpty {
                        emptyStateCard
                    } else {
                        readinessCard
                        experienceList
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Experience Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !suggestionCandidates.isEmpty {
                    Button {
                        showSuggestionsSheet = true
                    } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    .accessibilityLabel("Review suggested experience groupings")
                }

                Button {
                    showNewExperienceSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add application experience")
            }
        }
        .sheet(isPresented: $showNewExperienceSheet) {
            NavigationStack {
                ApplicationExperienceSeedEditor(
                    title: "New Application Experience",
                    seed: .init(),
                    includeCancel: true
                ) { seed in
                    let experience = seed.buildModel()
                    modelContext.insert(experience)
                    saveContext()
                }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showSuggestionsSheet) {
            NavigationStack {
                ExperienceSuggestionReviewView(candidates: suggestionCandidates) { candidate in
                    let experience = candidate.makeSeed().buildModel()
                    modelContext.insert(experience)

                    let idSet = Set(candidate.linkedSessionIDs)
                    sessions.filter { idSet.contains($0.id) }.forEach { session in
                        session.applicationExperience = experience
                    }
                    saveContext()
                }
            }
            .presentationDetents([.large])
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "Illuminote-Experience-Log"
        ) { result in
            if case .failure(let error) = result {
                print("⚠️ Failed to export experience CSV: \(error)")
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Application-ready experiences")
                .font(DSFont.heading2)
                .foregroundStyle(DSColor.textPrimary)

            Text("Keep application records separate from reflection notes. Link journal entries to experiences so you can preserve insight while building clean AMCAS, TMDSAS, AADSAS, CASPA, and other pre-health entries.")
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)

            if relevantRequirements.isEmpty {
                Text("Set a pre-health track in Profile to see service-specific readiness guidance.")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(relevantRequirements) { requirement in
                            Label(requirement.serviceCode.displayName, systemImage: "checklist")
                                .font(DSFont.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(DSColor.surfaceElevated.opacity(0.9))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(DSColor.goldLight.opacity(0.4), lineWidth: 1)
                                )
                        }
                    }
                }
            }

            VStack(spacing: 10) {
                Button {
                    showNewExperienceSheet = true
                } label: {
                    Label("Create Experience", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SacredButtonStyle())

                Group {
                    if !suggestionCandidates.isEmpty {
                        Button {
                            showSuggestionsSheet = true
                        } label: {
                            Label("Review Suggestions", systemImage: "wand.and.stars")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(DSColor.goldLight)
                    }

                    if !experiences.isEmpty {
                        Button {
                            exportDocument = ApplicationExperienceCSVDocument(csvText: ApplicationExperience.csvExport(for: experiences))
                            showExporter = true
                        } label: {
                            Label("Export CSV", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(DSColor.goldLight)
                    }
                }
                .modifier(ActionStackLayoutModifier(useVerticalLayout: prefersStackedActions))
            }
        }
        .padding()
        .sacredCardStyle(highlighted: false)
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No application experiences yet")
                .font(DSFont.heading2)
                .foregroundStyle(.white)

            Text("Create a reusable experience record for the activities you expect to enter into application services. Your linked notes stay reflective; the experience log stays structured.")
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)

            Group {
                Button("Create Experience") {
                    showNewExperienceSheet = true
                }
                .buttonStyle(SacredButtonStyle())

                if !suggestionCandidates.isEmpty {
                    Button("Suggest from Notes") {
                        showSuggestionsSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DSColor.goldLight)
                }
            }
            .modifier(ActionStackLayoutModifier(useVerticalLayout: prefersStackedActions))
        }
        .padding()
        .sacredCardStyle(highlighted: true)
    }

    private var readinessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Readiness Snapshot")
                        .font(DSFont.heading2)
                        .foregroundStyle(.white)
                    Text("Hours and service guidance are local to this device.")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
                Spacer()
                Button {
                    exportDocument = ApplicationExperienceCSVDocument(csvText: ApplicationExperience.csvExport(for: experiences))
                    showExporter = true
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .tint(DSColor.goldLight)
            }
            .modifier(HeaderExportLayoutModifier(useVerticalLayout: prefersStackedActions))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                summaryPill(title: "Experiences", value: "\(experiences.count)")
                summaryPill(title: "Logged Note Hours", value: experiences.reduce(0) { $0 + $1.totalLoggedSessionHours }.formattedOneDecimal)
                summaryPill(title: "Planned Hours", value: experiences.reduce(0) { $0 + $1.totalPlannedHours }.formattedOneDecimal)
            }

            if listIssues.isEmpty {
                Text("No immediate readiness flags. Review each experience to add service-specific detail before export.")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(listIssues.prefix(4)) { issue in
                        readinessIssueRow(issue)
                    }
                }
            }
        }
        .padding()
        .sacredCardStyle(highlighted: true)
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
            Text(title)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DSColor.surfaceElevated.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }

    private func readinessIssueRow(_ issue: ExperienceReadinessIssue) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: issueIcon(for: issue.severity))
                .foregroundStyle(issueColor(for: issue.severity))
                .padding(.top, 2)
            Text(issue.message)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var experienceList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Experience Log")
                .font(DSFont.heading2)
                .foregroundStyle(.white)

            ForEach(experiences) { experience in
                NavigationLink {
                    ApplicationExperienceDetailView(experience: experience)
                } label: {
                    ApplicationExperienceRow(experience: experience, requirements: relevantRequirements)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func issueColor(for severity: ExperienceReadinessIssue.Severity) -> Color {
        switch severity {
        case .info: return DSColor.accentPrimary
        case .warning: return DSColor.warning
        case .critical: return DSColor.error
        }
    }

    private func issueIcon(for severity: ExperienceReadinessIssue.Severity) -> String {
        switch severity {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "xmark.octagon"
        }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("⚠️ Failed to save application experiences: \(error)")
        }
    }
}

private struct ApplicationExperienceRow: View {
    let experience: ApplicationExperience
    let requirements: [ExperienceEntryRequirement]

    private var issues: [ExperienceReadinessIssue] {
        ExperienceReadinessEvaluator.evaluations(for: experience, requirements: requirements)
            .flatMap(\.issues)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(experience.exportTitle, systemImage: experience.category.systemImage)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(experience.organizationName ?? experience.category.displayName)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textSecondary)
                }
                Spacer()
                if !issues.isEmpty {
                    Text("\(issues.count) flag\(issues.count == 1 ? "" : "s")")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.goldLight)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 12)], spacing: 12) {
                rowMetric(title: "Completed", value: experience.totalCompletedHours.formattedOneDecimal)
                rowMetric(title: "Logged", value: experience.totalLoggedSessionHours.formattedOneDecimal)
                rowMetric(title: "Periods", value: "\(experience.periods.count)")
                rowMetric(title: "Notes", value: "\(experience.linkedSessions.count)")
            }

            if !experience.relevantTagSummary.isEmpty {
                Text(experience.relevantTagSummary.joined(separator: " • "))
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .sacredCardStyle(highlighted: !issues.isEmpty)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Opens this experience for editing and export.")
    }

    private func rowMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(title)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilitySummary: String {
        let organization = experience.organizationName ?? experience.category.displayName
        let flags = issues.isEmpty ? "No readiness flags." : "\(issues.count) readiness flag\(issues.count == 1 ? "" : "s")."
        return "\(experience.exportTitle). \(organization). Completed \(experience.totalCompletedHours.formattedOneDecimal) hours. Logged note hours \(experience.totalLoggedSessionHours.formattedOneDecimal). \(experience.periods.count) periods. \(experience.linkedSessions.count) linked notes. \(flags)"
    }
}

struct ApplicationExperienceSeedEditor: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let includeCancel: Bool
    let onSave: (ApplicationExperienceSeed) -> Void

    @State var seed: ApplicationExperienceSeed

    init(
        title: String,
        seed: ApplicationExperienceSeed,
        includeCancel: Bool = true,
        onSave: @escaping (ApplicationExperienceSeed) -> Void
    ) {
        self.title = title
        self.includeCancel = includeCancel
        self.onSave = onSave
        _seed = State(initialValue: seed)
    }

    var body: some View {
        Form {
            Section("Basic Information") {
                TextField("Experience title", text: $seed.title)
                Picker("Category", selection: $seed.category) {
                    ForEach(ApplicationExperienceCategory.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                TextField("Organization / Site", text: $seed.organizationName)
                    .textContentType(.organizationName)
                TextField("Role / Title", text: $seed.roleTitle)
                TextField("Location", text: $seed.location)
                TextField("Supervisor / Contact", text: $seed.contactName)
            }

            Section("Initial Date Range & Hours") {
                DatePicker("Start", selection: $seed.initialPeriod.startDate, displayedComponents: .date)
                Toggle("Ongoing", isOn: $seed.initialPeriod.isOngoing)
                Toggle("Planned", isOn: $seed.initialPeriod.isPlanned)
                if !seed.initialPeriod.isOngoing {
                    DatePicker(
                        "End",
                        selection: Binding(
                            get: { seed.initialPeriod.endDate ?? seed.initialPeriod.startDate },
                            set: { seed.initialPeriod.endDate = $0 }
                        ),
                        in: seed.initialPeriod.startDate...,
                        displayedComponents: .date
                    )
                }
                TextField(
                    "Total hours",
                    value: $seed.initialPeriod.totalHours,
                    format: .number
                )
                .keyboardType(.decimalPad)
                TextField(
                    "Average hours per week (optional)",
                    value: Binding(
                        get: { seed.initialPeriod.averageHoursPerWeek ?? 0 },
                        set: { seed.initialPeriod.averageHoursPerWeek = $0 == 0 ? nil : $0 }
                    ),
                    format: .number
                )
                .keyboardType(.decimalPad)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if includeCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(seed)
                    dismiss()
                }
                .disabled(seed.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct ActionStackLayoutModifier: ViewModifier {
    let useVerticalLayout: Bool

    func body(content: Content) -> some View {
        Group {
            if useVerticalLayout {
                VStack(spacing: 10) { content }
            } else {
                HStack(spacing: 10) { content }
            }
        }
    }
}

private struct HeaderExportLayoutModifier: ViewModifier {
    let useVerticalLayout: Bool

    func body(content: Content) -> some View {
        Group {
            if useVerticalLayout {
                VStack(alignment: .leading, spacing: 10) { content }
            } else {
                HStack { content }
            }
        }
    }
}

private extension Double {
    var formattedOneDecimal: String {
        String(format: "%.1f", self)
    }
}
