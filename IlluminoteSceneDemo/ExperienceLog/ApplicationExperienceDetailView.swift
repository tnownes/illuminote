import SwiftUI
import SwiftData
import UIKit

struct ApplicationExperienceDetailView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \UserProfile.id) private var profiles: [UserProfile]

    let experience: ApplicationExperience

    @State private var copyMessage: String?
    @State private var persistenceAlert: PersistenceAlertContext?

    private let requirementsService = LocalExperienceEntryRequirementsService.shared

    private var relevantRequirements: [ExperienceEntryRequirement] {
        requirementsService.requirements(for: profiles.first)
    }

    private var evaluations: [ExperienceReadinessEvaluation] {
        ExperienceReadinessEvaluator.evaluations(for: experience, requirements: relevantRequirements)
    }

    var body: some View {
        @Bindable var bindableExperience = experience

        ZStack {
            SacredScreenBackground(settings: settings)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCard

                    CardView(backgroundColor: DSColor.backgroundSecondary) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Application Record Details")
                                .font(DSFont.heading2)
                                .foregroundStyle(.white)

                            TextField("Record title", text: $bindableExperience.title)
                                .textFieldStyle(.roundedBorder)
                            Picker("Category", selection: Binding(
                                get: { bindableExperience.category },
                                set: {
                                    bindableExperience.category = $0
                                    bindableExperience.touch()
                                }
                            )) {
                                ForEach(ApplicationExperienceCategory.allCases) { category in
                                    Text(category.displayName).tag(category)
                                }
                            }
                            .pickerStyle(.menu)

                            DetailTextField(label: "Organization / Site", text: Binding(
                                get: { bindableExperience.organizationName ?? "" },
                                set: {
                                    bindableExperience.organizationName = emptyAsNil($0)
                                    bindableExperience.touch()
                                }
                            ))

                            DetailTextField(label: "Role / Title", text: Binding(
                                get: { bindableExperience.roleTitle ?? "" },
                                set: {
                                    bindableExperience.roleTitle = emptyAsNil($0)
                                    bindableExperience.touch()
                                }
                            ))

                            DetailTextField(label: "Location", text: Binding(
                                get: { bindableExperience.location ?? "" },
                                set: {
                                    bindableExperience.location = emptyAsNil($0)
                                    bindableExperience.touch()
                                }
                            ))
                        }
                    }

                    CardView(backgroundColor: DSColor.backgroundSecondary) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Contact & Verification")
                                .font(DSFont.heading2)
                                .foregroundStyle(.white)

                            DetailTextField(label: "Contact Name", text: Binding(
                                get: { bindableExperience.contactName ?? "" },
                                set: {
                                    bindableExperience.contactName = emptyAsNil($0)
                                    bindableExperience.touch()
                                }
                            ))

                            DetailTextField(label: "Contact Title", text: Binding(
                                get: { bindableExperience.contactTitle ?? "" },
                                set: {
                                    bindableExperience.contactTitle = emptyAsNil($0)
                                    bindableExperience.touch()
                                }
                            ))

                            DetailTextField(label: "Contact Email", text: Binding(
                                get: { bindableExperience.contactEmail ?? "" },
                                set: {
                                    bindableExperience.contactEmail = emptyAsNil($0)
                                    bindableExperience.touch()
                                }
                            ))
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)

                            DetailTextField(label: "Contact Phone", text: Binding(
                                get: { bindableExperience.contactPhone ?? "" },
                                set: {
                                    bindableExperience.contactPhone = emptyAsNil($0)
                                    bindableExperience.touch()
                                }
                            ))
                            .keyboardType(.phonePad)

                            Picker("Permission to Contact", selection: Binding(
                                get: { bindableExperience.contactPermissionAuthorized },
                                set: {
                                    bindableExperience.contactPermissionAuthorized = $0
                                    bindableExperience.touch()
                                }
                            )) {
                                Text("Not set").tag(Optional<Bool>.none)
                                Text("Yes").tag(Optional(true))
                                Text("No").tag(Optional(false))
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    CardView(backgroundColor: DSColor.backgroundSecondary) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Date Ranges & Hours")
                                    .font(DSFont.heading2)
                                    .foregroundStyle(.white)
                                Spacer()
                                Button {
                                    addPeriod()
                                } label: {
                                    Label("Add Period", systemImage: "plus")
                                }
                                .buttonStyle(.bordered)
                                .tint(DSColor.goldLight)
                            }

                            if experience.periods.isEmpty {
                                Text("Add at least one date range so the experience is ready for export.")
                                    .font(DSFont.body)
                                    .foregroundStyle(DSColor.textSecondary)
                            }

                            ForEach(experience.periods.sorted { lhs, rhs in
                                if lhs.startDate == rhs.startDate {
                                    return lhs.id.uuidString < rhs.id.uuidString
                                }
                                return lhs.startDate < rhs.startDate
                            }) { period in
                                ExperiencePeriodEditorCard(period: period) {
                                    deletePeriod(period)
                                }
                            }
                        }
                    }

                    CardView(backgroundColor: DSColor.backgroundSecondary) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Application Description")
                                .font(DSFont.heading2)
                                .foregroundStyle(.white)
                            TextEditor(text: Binding(
                                get: { bindableExperience.applicationDescription },
                                set: {
                                    bindableExperience.applicationDescription = $0
                                    bindableExperience.touch()
                                }
                            ))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 160)
                            .padding(8)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text("Use the description for concise facts and outcomes; let the linked notes preserve your deeper reflection.")
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textSecondary)
                        }
                    }

                    if !relevantRequirements.isEmpty {
                        CardView(backgroundColor: DSColor.backgroundSecondary) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Service Readiness")
                                    .font(DSFont.heading2)
                                    .foregroundStyle(.white)

                                ForEach(evaluations, id: \.service.id) { evaluation in
                                    ServiceReadinessCard(experience: experience, evaluation: evaluation)
                                }
                            }
                        }
                    }

                    CardView(backgroundColor: DSColor.backgroundSecondary) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Linked Notes")
                                .font(DSFont.heading2)
                                .foregroundStyle(.white)

                            if experience.linkedSessions.isEmpty {
                                Text("No journal notes are linked yet. Link them from the final Examen form or import from note suggestions.")
                                    .font(DSFont.body)
                                    .foregroundStyle(DSColor.textSecondary)
                            } else {
                                ForEach(experience.linkedSessions.sorted { $0.date > $1.date }) { session in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Text(session.experienceType?.displayName ?? "Reflection Note")
                                            .font(DSFont.caption)
                                            .foregroundStyle(DSColor.textSecondary)
                                        if session.hours > 0 {
                                            Text("Logged note hours: \(session.hours.formattedOneDecimal)")
                                                .font(DSFont.caption)
                                                .foregroundStyle(DSColor.goldLight)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(DSColor.surfaceElevated.opacity(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }

                    CardView(backgroundColor: DSColor.backgroundSecondary) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Export & Copy")
                                .font(DSFont.heading2)
                                .foregroundStyle(.white)

                            ShareLink(item: experience.plainTextSummary) {
                                Label("Share Plain-Text Summary", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .tint(DSColor.goldLight)

                            Button {
                                UIPasteboard.general.string = experience.copyReadyBreakdown(for: relevantRequirements)
                                copyMessage = "Copied readiness breakdown."
                            } label: {
                                Label("Copy Readiness Breakdown", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .tint(DSColor.goldLight)

                            if let copyMessage {
                                Text(copyMessage)
                                    .font(DSFont.caption)
                                    .foregroundStyle(DSColor.textSecondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(experience.exportTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveContext()
                }
            }
        }
        .onDisappear {
            saveContext()
        }
        .persistenceFailureAlert($persistenceAlert)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(experience.exportTitle)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(experience.category.displayName)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                summaryPill(title: "Completed", value: experience.totalCompletedHours.formattedOneDecimal)
                summaryPill(title: "Planned", value: experience.totalPlannedHours.formattedOneDecimal)
                summaryPill(title: "Linked Note Hours", value: experience.totalLoggedSessionHours.formattedOneDecimal)
            }

            if !experience.relevantTagSummary.isEmpty {
                Text("Themes from linked notes: \(experience.relevantTagSummary.joined(separator: ", "))")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
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

    private func addPeriod() {
        let period = ExperiencePeriod(
            startDate: .now,
            endDate: .now,
            isOngoing: false,
            isPlanned: false,
            totalHours: 0,
            averageHoursPerWeek: nil,
            experience: experience
        )
        modelContext.insert(period)
        experience.periods.append(period)
        experience.touch()
        saveContext()
    }

    private func deletePeriod(_ period: ExperiencePeriod) {
        experience.periods.removeAll { $0.id == period.id }
        modelContext.delete(period)
        experience.touch()
        saveContext()
    }

    private func saveContext() {
        experience.touch()
        do {
            try modelContext.persistIfNeeded(for: "save that experience")
        } catch let error as PersistenceOperationError {
            persistenceAlert = error.alertContext
        } catch {
            persistenceAlert = PersistenceAlertContext.saveFailure(
                for: "save that experience",
                details: error.localizedDescription
            )
        }
    }

    private func emptyAsNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct DetailTextField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(label)
        }
    }
}

private struct ExperiencePeriodEditorCard: View {
    let period: ExperiencePeriod
    let onDelete: () -> Void

    var body: some View {
        @Bindable var bindablePeriod = period

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Activity Period")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete period")
                .accessibilityHint("Removes this date range and its hours from the experience.")
            }

            DatePicker("Start", selection: $bindablePeriod.startDate, displayedComponents: .date)
                .tint(DSColor.goldLight)
            Toggle("Ongoing", isOn: $bindablePeriod.isOngoing)
                .tint(DSColor.goldLight)
            Toggle("Planned", isOn: $bindablePeriod.isPlanned)
                .tint(DSColor.goldLight)

            if !bindablePeriod.isOngoing {
                DatePicker(
                    "End",
                    selection: Binding(
                        get: { bindablePeriod.endDate ?? bindablePeriod.startDate },
                        set: { bindablePeriod.endDate = $0 }
                    ),
                    in: bindablePeriod.startDate...,
                    displayedComponents: .date
                )
                .tint(DSColor.goldLight)
            }

            TextField("Total hours", value: $bindablePeriod.totalHours, format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
            TextField(
                "Average hours per week (optional)",
                value: Binding(
                    get: { bindablePeriod.averageHoursPerWeek ?? 0 },
                    set: { bindablePeriod.averageHoursPerWeek = $0 == 0 ? nil : $0 }
                ),
                format: .number
            )
            .textFieldStyle(.roundedBorder)
            .keyboardType(.decimalPad)
        }
        .padding(12)
        .background(DSColor.surfaceElevated.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
    }
}

private struct ServiceReadinessCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let experience: ApplicationExperience
    let evaluation: ExperienceReadinessEvaluation
    @State private var persistenceAlert: PersistenceAlertContext?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                VStack(alignment: .leading, spacing: 2) {
                    Text(evaluation.service.serviceCode.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let highlightLabel = evaluation.service.highlightLabel,
                       let maxHighlights = evaluation.service.maxHighlights {
                        Text("Up to \(maxHighlights) \(highlightLabel.lowercased())")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
                Spacer()
                if evaluation.service.maxHighlights != nil {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { experience.isHighlighted(for: evaluation.service.serviceCode) },
                            set: {
                                experience.setHighlighted($0, for: evaluation.service.serviceCode)
                                do {
                                    try modelContext.persistIfNeeded(for: "update that experience highlight")
                                } catch let error as PersistenceOperationError {
                                    persistenceAlert = error.alertContext
                                } catch {
                                    persistenceAlert = PersistenceAlertContext.saveFailure(
                                        for: "update that experience highlight",
                                        details: error.localizedDescription
                                    )
                                }
                            }
                        )
                    )
                    .labelsHidden()
                    .tint(DSColor.goldLight)
                    .accessibilityLabel(highlightAccessibilityLabel)
                    .accessibilityHint("Marks this experience as a highlighted entry for \(evaluation.service.serviceCode.displayName).")
                }
            }
            .modifier(ServiceHeaderLayoutModifier(useVerticalLayout: dynamicTypeSize.isAccessibilitySize))

            if evaluation.issues.isEmpty {
                Text("This experience covers the core fields for \(evaluation.service.serviceCode.displayName).")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)
            } else {
                ForEach(evaluation.issues) { issue in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: icon(for: issue.severity))
                            .foregroundStyle(color(for: issue.severity))
                            .padding(.top, 2)
                        Text(issue.message)
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
            }

            if !evaluation.service.guidanceNotes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(evaluation.service.guidanceNotes, id: \.self) { note in
                        Text("• \(note)")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
            }
        }
        .padding(12)
        .background(DSColor.surfaceElevated.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
    }

    private var highlightAccessibilityLabel: String {
        if let highlightLabel = evaluation.service.highlightLabel {
            return "Mark as \(highlightLabel.lowercased())"
        }
        return "Highlight experience"
    }

    private func color(for severity: ExperienceReadinessIssue.Severity) -> Color {
        switch severity {
        case .info: return DSColor.accentPrimary
        case .warning: return DSColor.warning
        case .critical: return DSColor.error
        }
    }

    private func icon(for severity: ExperienceReadinessIssue.Severity) -> String {
        switch severity {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "xmark.octagon"
        }
    }
}

private struct ServiceHeaderLayoutModifier: ViewModifier {
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
