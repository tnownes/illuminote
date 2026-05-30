import SwiftUI
import SwiftData

enum ExamenPostSaveIntent {
    case completion
    case journalDetails
}

struct ExamenDetailsView: View {
    @Query(sort: \ApplicationExperience.dateModified, order: .reverse) private var applicationExperiences: [ApplicationExperience]

    var draft: ExamenSessionDraft
    var onSave: (ExamenSessionDraft, ExamenPostSaveIntent) -> Void
    var onCancel: () -> Void
    

    @State private var primaryValue: String = ""
    @State private var secondaryValue: String = ""
    @State private var focusValue: String = ""
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var extraTags: String = "" // comma-separated
    @State private var personalStatement: String = ""
    @State private var hoursString: String = ""
    @State private var isUsingApplicationRecord = false
    @State private var applicationRecordDestination: ApplicationRecordDestination = .createNew
    @State private var selectedApplicationRecordID: UUID?
    @State private var showCopiedDetailOverrides = false
    @State private var newExperienceSeed = ApplicationExperienceSeed()
    @State private var manuallyEditedExperienceFields: Set<ApplicationExperienceSeedField> = []
    @State private var isApplyingExperienceSuggestion = false

    private var detailFieldConfig: ExperienceDetailFieldConfig { draft.type.detailFieldConfig }
    private var canSave: Bool {
        !isUsingApplicationRecord
            || applicationRecordDestination == .createNew
            || selectedApplicationRecordID != nil
    }
    
    @ViewBuilder
    var body: some View {
        if AppSettings.featurePolicy.allowsExamenApplicationRecordDuringReflection {
            fullDetailsBody
        } else {
            coreSaveBody
        }
    }

    private var fullDetailsBody: some View {
        ZStack {
            DSColor.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: DSSpacing.md) {
                // Header
                HStack {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(DSColor.textSecondary)
                    Spacer()
                    ThemedText(text: "Session Details", style: .heading2)
                    Spacer()
                    Button("Save") { saveSession() }
                        .fontWeight(.semibold)
                        .foregroundStyle(DSColor.accentPrimary)
                        .disabled(!canSave)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: DSSpacing.lg) {
                        
                        // Reflection Notes Section
                        CardView(backgroundColor: DSColor.backgroundSecondary) {
                            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                                ThemedText(text: "Reflection Notes", style: .heading2)

                                ZStack(alignment: .topLeading) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white)

                                    if personalStatement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text("Personal Statement / Notes")
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 12)
                                    }

                                    TextEditor(text: $personalStatement)
                                        .scrollContentBackground(.hidden)
                                        .padding(8)
                                        .foregroundStyle(.black)
                                        .textInputAutocapitalization(.sentences)
                                        .accessibilityLabel("Reflection notes")
                                }
                                .frame(minHeight: 150)
                            }
                        }
                        
                        // Optional Details Section
                        CardView(backgroundColor: DSColor.backgroundSecondary) {
                            VStack(alignment: .leading, spacing: DSSpacing.md) {
                                ThemedText(text: "Optional Details", style: .heading2)
                                ThemedText(text: draft.type.displayName, style: .caption)
                                    .foregroundStyle(DSColor.textSecondary)
                                
                                Divider()
                                
                                if detailFieldConfig.showsHours {
                                    DetailField(label: "Hours represented by this note", text: $hoursString)
                                        .keyboardType(.decimalPad)
                                }
                                
                                if detailFieldConfig.showsPrimary {
                                    DetailField(label: detailFieldConfig.primaryLabel, text: $primaryValue)
                                }
                                if detailFieldConfig.showsFacility {
                                    DetailField(label: detailFieldConfig.facilityLabel, text: $secondaryValue)
                                }
                                if detailFieldConfig.showsLocation {
                                    DetailField(label: "Location", text: $location)
                                }
                                if detailFieldConfig.showsFocus {
                                    DetailField(label: detailFieldConfig.focusLabel, text: $focusValue)
                                }
                                DetailField(label: "Private Notes", text: $notes)
                                DetailField(label: "Tags (comma-separated)", text: $extraTags)
                                    .textInputAutocapitalization(.never)
                            }
                        }

                        CardView(backgroundColor: DSColor.backgroundSecondary) {
                            VStack(alignment: .leading, spacing: DSSpacing.md) {
                                ThemedText(text: "Application Record", style: .heading2)
                                Text("Keep this off for a journal-only reflection. Turn it on when this note should also support an application record.")
                                    .font(DSFont.caption)
                                    .foregroundStyle(DSColor.textSecondary)

                                Toggle("Use this note for an Application Record", isOn: $isUsingApplicationRecord)
                                    .tint(DSColor.goldLight)
                                    .accessibilityIdentifier("examen.details.applicationRecord.toggle")

                                if !isUsingApplicationRecord {
                                    Text("This will save to Journal only.")
                                        .font(DSFont.caption)
                                        .foregroundStyle(DSColor.textSecondary)
                                } else {
                                    if applicationExperiences.isEmpty {
                                        Text("Illuminote will create a new Application Record from the details below.")
                                            .font(DSFont.caption)
                                            .foregroundStyle(DSColor.textSecondary)
                                    } else {
                                        Picker("Application Record destination", selection: $applicationRecordDestination) {
                                            ForEach(ApplicationRecordDestination.allCases) { destination in
                                                Text(destination.title).tag(destination)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                    }

                                    switch applicationRecordDestination {
                                    case .connectExisting:
                                        Picker("Existing Application Record", selection: $selectedApplicationRecordID) {
                                            Text("Select a record").tag(UUID?.none)
                                            ForEach(applicationExperiences) { experience in
                                                Text(experience.exportTitle).tag(UUID?.some(experience.id))
                                            }
                                        }
                                        .pickerStyle(.menu)

                                        if let selectedRecord = applicationExperiences.first(where: { $0.id == selectedApplicationRecordID }) {
                                            Text("This reflection will stay in Journal and connect to \(selectedRecord.exportTitle).")
                                                .font(DSFont.caption)
                                                .foregroundStyle(DSColor.textSecondary)
                                        } else {
                                            Text("Choose an Application Record before saving.")
                                                .font(DSFont.caption)
                                                .foregroundStyle(DSColor.warning)
                                        }
                                    case .createNew:
                                        ApplicationRecordCopiedDetailsPreview(seed: newExperienceSeed)

                                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                                            Text("Additional details")
                                                .font(DSFont.caption.weight(.semibold))
                                                .foregroundStyle(DSColor.textSecondary)

                                            Picker("Category", selection: seedCategoryBinding()) {
                                                ForEach(ApplicationExperienceCategory.allCases) { category in
                                                    Text(category.displayName).tag(category)
                                                }
                                            }
                                            .pickerStyle(.menu)

                                            DatePicker("Start Date", selection: seedStartDateBinding(), displayedComponents: .date)
                                                .tint(DSColor.goldLight)
                                            Toggle("Ongoing", isOn: seedBoolBinding(\.isOngoing, field: .isOngoing))
                                                .tint(DSColor.goldLight)
                                            Toggle("Planned", isOn: seedBoolBinding(\.isPlanned, field: .isPlanned))
                                                .tint(DSColor.goldLight)
                                            if !newExperienceSeed.initialPeriod.isOngoing {
                                                DatePicker(
                                                    "End Date",
                                                    selection: Binding(
                                                        get: { newExperienceSeed.initialPeriod.endDate ?? newExperienceSeed.initialPeriod.startDate },
                                                        set: { newValue in
                                                            setExperienceField(.endDate) { seed in
                                                                seed.initialPeriod.endDate = newValue
                                                            }
                                                        }
                                                    ),
                                                    in: newExperienceSeed.initialPeriod.startDate...,
                                                    displayedComponents: .date
                                                )
                                                .tint(DSColor.goldLight)
                                            }

                                            if newExperienceSeed.contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                DetailField(label: "Supervisor / Contact", text: seedTextBinding(\.contactName, field: .contactName))
                                            }

                                            TextField(
                                                "Average hours per week (optional)",
                                                value: seedAverageHoursBinding(),
                                                format: .number
                                            )
                                            .textFieldStyle(.roundedBorder)
                                            .keyboardType(.decimalPad)
                                        }

                                        DisclosureGroup("Adjust copied details", isExpanded: $showCopiedDetailOverrides) {
                                            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                                                DetailField(label: "Record Title", text: seedTextBinding(\.title, field: .title))
                                                DetailField(label: "Organization / Site", text: seedTextBinding(\.organizationName, field: .organizationName))
                                                    .textContentType(.organizationName)
                                                DetailField(label: "Role / Title", text: seedTextBinding(\.roleTitle, field: .roleTitle))
                                                DetailField(label: "Location", text: seedTextBinding(\.location, field: .location))
                                                if !newExperienceSeed.contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                    DetailField(label: "Supervisor / Contact", text: seedTextBinding(\.contactName, field: .contactName))
                                                }
                                                TextField(
                                                    "Total hours",
                                                    value: seedHoursBinding(),
                                                    format: .number
                                                )
                                                .textFieldStyle(.roundedBorder)
                                                .keyboardType(.decimalPad)
                                                    }
                                        }
                                        .tint(DSColor.goldLight)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .toolbar(.hidden, for: .navigationBar) // We built a custom header
        .onAppear {
            primaryValue = draft.resolvedPrimaryDetail
            secondaryValue = draft.resolvedSecondaryDetail
            focusValue = draft.resolvedFocusDetail
            location = draft.location ?? ""
            notes = draft.notes ?? ""
            extraTags = draft.tags.joined(separator: ", ")
            personalStatement = draft.personalStatement
            if draft.hours > 0 {
                hoursString = String(draft.hours)
            }
            if let linkedID = draft.linkedApplicationExperienceID {
                isUsingApplicationRecord = true
                applicationRecordDestination = .connectExisting
                selectedApplicationRecordID = linkedID
                manuallyEditedExperienceFields.removeAll()
            } else if let pending = draft.pendingApplicationExperience {
                isUsingApplicationRecord = true
                applicationRecordDestination = .createNew
                newExperienceSeed = pending
                manuallyEditedExperienceFields = Set(ApplicationExperienceSeedField.allCases)
            } else {
                isUsingApplicationRecord = false
                applicationRecordDestination = .createNew
                newExperienceSeed = ApplicationExperienceSeed.suggested(from: draft)
                selectedApplicationRecordID = nil
                manuallyEditedExperienceFields.removeAll()
            }
        }
        .onChange(of: isUsingApplicationRecord) { _, isUsing in
            guard isUsing else { return }
            if applicationRecordDestination == .connectExisting, selectedApplicationRecordID == nil {
                selectedApplicationRecordID = applicationExperiences.first?.id
            }
            if applicationRecordDestination == .createNew {
                refreshExperienceSeedFromNoteDetails(force: manuallyEditedExperienceFields.isEmpty)
            }
        }
        .onChange(of: applicationRecordDestination) { _, newValue in
            switch newValue {
            case .connectExisting:
                if selectedApplicationRecordID == nil {
                    selectedApplicationRecordID = applicationExperiences.first?.id
                }
            case .createNew:
                refreshExperienceSeedFromNoteDetails(force: manuallyEditedExperienceFields.isEmpty)
            }
        }
        .onChange(of: personalStatement) { _, _ in refreshExperienceSeedFromNoteDetails() }
        .onChange(of: primaryValue) { _, _ in refreshExperienceSeedFromNoteDetails() }
        .onChange(of: secondaryValue) { _, _ in refreshExperienceSeedFromNoteDetails() }
        .onChange(of: location) { _, _ in refreshExperienceSeedFromNoteDetails() }
        .onChange(of: hoursString) { _, _ in refreshExperienceSeedFromNoteDetails() }
    }

    private var coreSaveBody: some View {
        ZStack {
            // Keep the active choice's dynamic scene backdrop running quietly behind the save card
            ExamenBackgroundHost(presentation: .flow)

            // High-contrast immersive overlay to ensure high accessibility readability
            DSColor.immersiveOverlay.ignoresSafeArea()

            VStack(spacing: DSSpacing.xl) {
                Spacer()

                AppPanel(
                    title: "Reflection Complete",
                    subtitle: "Your insights are safe and private on this device.",
                    role: .reading,
                    highlighted: true
                ) {
                    VStack(spacing: DSSpacing.xl) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 64, weight: .semibold))
                            .foregroundStyle(DSColor.brandAccent)
                            .luminous() // Smooth contemplative gold pulse animation
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)

                        VStack(spacing: 8) {
                            Text("EXAMEN REVIEW")
                                .font(DSFont.eyebrow)
                                .foregroundStyle(DSColor.quietTextMuted)
                                .tracking(0.7)

                            Text(draft.type.displayName)
                                .font(DSFont.heading1)
                                .foregroundStyle(DSColor.textPrimary)

                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Private Journal")
                                    .font(DSFont.meta.weight(.semibold))
                            }
                            .foregroundStyle(DSColor.brandAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(DSColor.brandAccentSoft)
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        VStack(spacing: DSSpacing.sm) {
                            Button {
                                saveCoreReflection(intent: .completion)
                            } label: {
                                Label("Add to Journal", systemImage: "checkmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SacredButtonStyle())
                            .accessibilityIdentifier("examen.details.saveToJournal")

                            Button {
                                saveCoreReflection(intent: .journalDetails)
                            } label: {
                                Label("Add Details", systemImage: "square.and.pencil")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.appSecondary)
                            .accessibilityIdentifier("examen.details.saveAndAddDetails")
                        }
                    }
                    .padding(.vertical, DSSpacing.xs)
                }
                .padding(.horizontal, DSSpacing.lg)

                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.appQuiet)
                .padding(.bottom, DSSpacing.xl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func seedTextBinding(
        _ keyPath: WritableKeyPath<ApplicationExperienceSeed, String>,
        field: ApplicationExperienceSeedField
    ) -> Binding<String> {
        Binding(
            get: { newExperienceSeed[keyPath: keyPath] },
            set: { newValue in
                setExperienceField(field) { seed in
                    seed[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func seedCategoryBinding() -> Binding<ApplicationExperienceCategory> {
        Binding(
            get: { newExperienceSeed.category },
            set: { newValue in
                setExperienceField(.category) { seed in
                    seed.category = newValue
                }
            }
        )
    }

    private func seedStartDateBinding() -> Binding<Date> {
        Binding(
            get: { newExperienceSeed.initialPeriod.startDate },
            set: { newValue in
                setExperienceField(.startDate) { seed in
                    seed.initialPeriod.startDate = newValue
                    if let endDate = seed.initialPeriod.endDate, endDate < newValue {
                        seed.initialPeriod.endDate = newValue
                    }
                }
            }
        )
    }

    private func seedBoolBinding(
        _ keyPath: WritableKeyPath<ExperiencePeriodDraft, Bool>,
        field: ApplicationExperienceSeedField
    ) -> Binding<Bool> {
        Binding(
            get: { newExperienceSeed.initialPeriod[keyPath: keyPath] },
            set: { newValue in
                setExperienceField(field) { seed in
                    seed.initialPeriod[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func seedHoursBinding() -> Binding<Double> {
        Binding(
            get: { newExperienceSeed.initialPeriod.totalHours },
            set: { newValue in
                setExperienceField(.totalHours) { seed in
                    seed.initialPeriod.totalHours = max(0, newValue)
                }
            }
        )
    }

    private func seedAverageHoursBinding() -> Binding<Double> {
        Binding(
            get: { newExperienceSeed.initialPeriod.averageHoursPerWeek ?? 0 },
            set: { newValue in
                setExperienceField(.averageHoursPerWeek) { seed in
                    if newValue > 0 {
                        seed.initialPeriod.averageHoursPerWeek = newValue
                    } else {
                        seed.initialPeriod.averageHoursPerWeek = nil
                    }
                }
            }
        )
    }

    private func setExperienceField(
        _ field: ApplicationExperienceSeedField,
        update: (inout ApplicationExperienceSeed) -> Void
    ) {
        if !isApplyingExperienceSuggestion {
            manuallyEditedExperienceFields.insert(field)
        }
        var seed = newExperienceSeed
        update(&seed)
        newExperienceSeed = seed
    }

    private func refreshExperienceSeedFromNoteDetails(force: Bool = false) {
        guard isUsingApplicationRecord, applicationRecordDestination == .createNew else { return }
        let suggestion = ApplicationExperienceSeed.suggested(from: currentDraftSnapshot())

        isApplyingExperienceSuggestion = true
        defer { isApplyingExperienceSuggestion = false }

        if force || !manuallyEditedExperienceFields.contains(.title) {
            newExperienceSeed.title = suggestion.title
        }
        if force || !manuallyEditedExperienceFields.contains(.category) {
            newExperienceSeed.category = suggestion.category
        }
        if force || !manuallyEditedExperienceFields.contains(.organizationName) {
            newExperienceSeed.organizationName = suggestion.organizationName
        }
        if force || !manuallyEditedExperienceFields.contains(.roleTitle) {
            newExperienceSeed.roleTitle = suggestion.roleTitle
        }
        if force || !manuallyEditedExperienceFields.contains(.location) {
            newExperienceSeed.location = suggestion.location
        }
        if force || !manuallyEditedExperienceFields.contains(.contactName) {
            newExperienceSeed.contactName = suggestion.contactName
        }
        if force || !manuallyEditedExperienceFields.contains(.totalHours) {
            newExperienceSeed.initialPeriod.totalHours = suggestion.initialPeriod.totalHours
        }

        if force {
            newExperienceSeed.initialPeriod.startDate = suggestion.initialPeriod.startDate
            newExperienceSeed.initialPeriod.endDate = suggestion.initialPeriod.endDate
            newExperienceSeed.initialPeriod.isOngoing = suggestion.initialPeriod.isOngoing
            newExperienceSeed.initialPeriod.isPlanned = suggestion.initialPeriod.isPlanned
            newExperienceSeed.initialPeriod.averageHoursPerWeek = suggestion.initialPeriod.averageHoursPerWeek
        }
    }

    private func currentDraftSnapshot() -> ExamenSessionDraft {
        var snapshot = draft
        snapshot.applyDetails(
            primary: primaryValue,
            secondary: secondaryValue,
            focus: focusValue,
            location: location,
            hours: Double(hoursString)
        )
        snapshot.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.tags = extraTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        snapshot.personalStatement = personalStatement
        return snapshot
    }
    
    private func saveSession() {
        // Update the draft structure with new metadata
        var updatedDraft = draft
        updatedDraft.applyDetails(
            primary: primaryValue,
            secondary: secondaryValue,
            focus: focusValue,
            location: location,
            hours: Double(hoursString)
        )
        updatedDraft.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedDraft.tags = extraTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        updatedDraft.personalStatement = personalStatement
        updatedDraft.linkedApplicationExperienceID = nil
        updatedDraft.pendingApplicationExperience = nil

        guard isUsingApplicationRecord else {
            onSave(updatedDraft, .completion)
            return
        }

        switch applicationRecordDestination {
        case .connectExisting:
            updatedDraft.linkedApplicationExperienceID = selectedApplicationRecordID
        case .createNew:
            var seed = newExperienceSeed
            if seed.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                seed.title = updatedDraft.personalStatementTitleFallback
            }
            if seed.initialPeriod.totalHours == 0, let noteHours = Double(hoursString), noteHours > 0 {
                seed.initialPeriod.totalHours = noteHours
            }
            updatedDraft.pendingApplicationExperience = seed
        }
        
        // Pass back to parent to handle persistence via VM
        onSave(updatedDraft, .completion)
    }

    private func saveCoreReflection(intent: ExamenPostSaveIntent) {
        var updatedDraft = draft
        updatedDraft.linkedApplicationExperienceID = nil
        updatedDraft.pendingApplicationExperience = nil
        onSave(updatedDraft, intent)
    }
}

private enum ApplicationRecordDestination: String, CaseIterable, Identifiable {
    case createNew
    case connectExisting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .createNew: return "Create New"
        case .connectExisting: return "Connect Existing"
        }
    }
}

private enum ApplicationExperienceSeedField: Hashable, CaseIterable {
    case title
    case category
    case organizationName
    case roleTitle
    case location
    case contactName
    case startDate
    case endDate
    case isOngoing
    case isPlanned
    case totalHours
    case averageHoursPerWeek
}

private struct DetailField: View {
    let label: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ThemedText(text: label, style: .caption)
                .foregroundStyle(DSColor.textSecondary)
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(label)
        }
    }
}

private struct ApplicationRecordCopiedDetailsPreview: View {
    let seed: ApplicationExperienceSeed

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("Copied from this note")
                .font(DSFont.caption.weight(.semibold))
                .foregroundStyle(DSColor.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                previewRow("Title", value: seed.title)
                previewRow("Role", value: seed.roleTitle)
                previewRow("Organization / Site", value: seed.organizationName)
                previewRow("Location", value: seed.location)
                previewRow("Supervisor / Contact", value: seed.contactName)
                if seed.initialPeriod.totalHours > 0 {
                    previewRow("Hours", value: seed.initialPeriod.totalHours.formatted(.number.precision(.fractionLength(0...1))))
                }
            }
            .padding(DSSpacing.sm)
            .background(DSColor.surfaceElevated.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func previewRow(_ label: String, value: String) -> some View {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: DSSpacing.sm) {
                Text(label)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .frame(width: 112, alignment: .leading)
                Text(trimmed)
                    .font(DSFont.caption.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ExamenDetailsView(
        draft: ExamenSessionDraft(type: .clinical),
        onSave: { _, _ in },
        onCancel: {}
    )
    .modelContainer(for: [ExamenSession.self, ApplicationExperience.self, ExperiencePeriod.self], inMemory: true)
}
