import SwiftUI
import SwiftData

struct ExamenDetailsView: View {
    @Query(sort: \ApplicationExperience.dateModified, order: .reverse) private var applicationExperiences: [ApplicationExperience]

    var draft: ExamenSessionDraft
    var onSave: (ExamenSessionDraft) -> Void
    var onCancel: () -> Void
    

    @State private var primaryValue: String = ""
    @State private var secondaryValue: String = ""
    @State private var focusValue: String = ""
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var extraTags: String = "" // comma-separated
    @State private var personalStatement: String = ""
    @State private var hoursString: String = ""
    @State private var attachmentMode: ApplicationExperienceAttachmentMode = .none
    @State private var selectedExperienceID: UUID?
    @State private var newExperienceSeed = ApplicationExperienceSeed()

    private var detailFieldConfig: ExperienceDetailFieldConfig { draft.type.detailFieldConfig }
    private var canSave: Bool {
        attachmentMode != .existing || selectedExperienceID != nil
    }
    
    var body: some View {
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
                                ThemedText(text: "Application Experience (Optional)", style: .heading2)
                                Text("Daily reflections stay separate by default. Attach this note only if it should support a structured application experience.")
                                    .font(DSFont.caption)
                                    .foregroundStyle(DSColor.textSecondary)

                                AttachmentModeSelector(
                                    selection: $attachmentMode,
                                    canLinkExisting: !applicationExperiences.isEmpty
                                )

                                switch attachmentMode {
                                case .none:
                                    Text("This note will save as a reflection only.")
                                        .font(DSFont.caption)
                                        .foregroundStyle(DSColor.textSecondary)
                                case .existing:
                                    Picker("Existing Experience", selection: $selectedExperienceID) {
                                        Text("Select an experience").tag(UUID?.none)
                                        ForEach(applicationExperiences) { experience in
                                            Text(experience.exportTitle).tag(UUID?.some(experience.id))
                                        }
                                    }
                                    .pickerStyle(.menu)

                                    if let selectedExperience = applicationExperiences.first(where: { $0.id == selectedExperienceID }) {
                                        Text("Linking to \(selectedExperience.exportTitle) keeps the structured experience record separate from this note.")
                                            .font(DSFont.caption)
                                            .foregroundStyle(DSColor.textSecondary)
                                    } else {
                                        Text("Choose one existing experience before saving.")
                                            .font(DSFont.caption)
                                            .foregroundStyle(DSColor.warning)
                                    }
                                case .createNew:
                                    DetailField(label: "Experience Title", text: $newExperienceSeed.title)
                                    Picker("Category", selection: $newExperienceSeed.category) {
                                        ForEach(ApplicationExperienceCategory.allCases) { category in
                                            Text(category.displayName).tag(category)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    DetailField(label: "Organization / Site", text: $newExperienceSeed.organizationName)
                                        .textContentType(.organizationName)
                                    DetailField(label: "Role / Title", text: $newExperienceSeed.roleTitle)
                                    DetailField(label: "Location", text: $newExperienceSeed.location)
                                    DetailField(label: "Supervisor / Contact", text: $newExperienceSeed.contactName)
                                    DatePicker("Start Date", selection: $newExperienceSeed.initialPeriod.startDate, displayedComponents: .date)
                                        .tint(DSColor.goldLight)
                                    Toggle("Ongoing", isOn: $newExperienceSeed.initialPeriod.isOngoing)
                                        .tint(DSColor.goldLight)
                                    Toggle("Planned", isOn: $newExperienceSeed.initialPeriod.isPlanned)
                                        .tint(DSColor.goldLight)
                                    if !newExperienceSeed.initialPeriod.isOngoing {
                                        DatePicker(
                                            "End Date",
                                            selection: Binding(
                                                get: { newExperienceSeed.initialPeriod.endDate ?? newExperienceSeed.initialPeriod.startDate },
                                                set: { newExperienceSeed.initialPeriod.endDate = $0 }
                                            ),
                                            in: newExperienceSeed.initialPeriod.startDate...,
                                            displayedComponents: .date
                                        )
                                        .tint(DSColor.goldLight)
                                    }
                                    TextField(
                                        "Experience hours",
                                        value: $newExperienceSeed.initialPeriod.totalHours,
                                        format: .number
                                    )
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.decimalPad)
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
                attachmentMode = .existing
                selectedExperienceID = linkedID
            } else if let pending = draft.pendingApplicationExperience {
                attachmentMode = .createNew
                newExperienceSeed = pending
            } else {
                attachmentMode = .none
                newExperienceSeed = ApplicationExperienceSeed.suggested(from: draft)
                selectedExperienceID = nil
            }
        }
        .onChange(of: attachmentMode) { _, newValue in
            switch newValue {
            case .existing:
                if selectedExperienceID == nil {
                    selectedExperienceID = applicationExperiences.first?.id
                }
            case .createNew:
                if newExperienceSeed.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    newExperienceSeed = ApplicationExperienceSeed.suggested(from: draft)
                }
            case .none:
                break
            }
        }
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

        switch attachmentMode {
        case .none:
            break
        case .existing:
            updatedDraft.linkedApplicationExperienceID = selectedExperienceID
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
        onSave(updatedDraft)
    }
}

private enum ApplicationExperienceAttachmentMode: String, CaseIterable, Identifiable {
    case none
    case existing
    case createNew

    var id: String { rawValue }
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

private struct AttachmentModeSelector: View {
    @Binding var selection: ApplicationExperienceAttachmentMode
    let canLinkExisting: Bool

    var body: some View {
        VStack(spacing: 10) {
            AttachmentModeButton(
                title: "Reflection Only",
                subtitle: "Save this as a private journal note.",
                isSelected: selection == .none
            ) {
                selection = .none
            }

            if canLinkExisting {
                AttachmentModeButton(
                    title: "Link Existing Experience",
                    subtitle: "Attach this note to a record already in your Experience Log.",
                    isSelected: selection == .existing
                ) {
                    selection = .existing
                }
            }

            AttachmentModeButton(
                title: "Create New Experience",
                subtitle: "Make a new application-ready record from this note.",
                isSelected: selection == .createNew
            ) {
                selection = .createNew
            }
        }
    }
}

private struct AttachmentModeButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? DSColor.goldLight : DSColor.textSecondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(DSColor.surfaceElevated.opacity(isSelected ? 0.9 : 0.7))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? DSColor.goldLight : DSColor.textSecondary.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(subtitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    ExamenDetailsView(
        draft: ExamenSessionDraft(type: .clinical),
        onSave: {_ in },
        onCancel: {}
    )
    .modelContainer(for: [ExamenSession.self, ApplicationExperience.self, ExperiencePeriod.self], inMemory: true)
}
