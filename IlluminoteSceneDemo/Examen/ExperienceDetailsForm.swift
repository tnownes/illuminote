import SwiftUI

private extension String {
    var nonEmpty: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}

struct ExperienceDetailsForm: View {
    let type: ExperienceType
    var onCancel: () -> Void
    var onContinue: (ExperienceDetails) -> Void

    @State private var physician: String = ""
    @State private var specialty: String = ""
    @State private var facility: String = ""
    @State private var location: String = ""
    @State private var role: String = ""
    @State private var organization: String = ""
    @State private var isClinicalService: Bool = true
    @State private var facultyOrLab: String = ""
    @State private var otherNotes: String = ""
    @State private var notes: String = ""
    @State private var hoursString: String = ""

    private var typeTitle: String { type.displayName }

    private var isFormValid: Bool {
        if type == .other || type == .discernment { return true }
        // Attempt to convert hoursString to Double
        return Double(hoursString) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if type != .other && type != .discernment {
                    Section {
                        TextField("Number of Hours", text: $hoursString)
                            .keyboardType(.decimalPad)
                    }
                }

                if type == .shadowing {
                    TextField("Physician", text: $physician)
                        .textContentType(.name)
                    TextField("Specialty", text: $specialty)
                        .textContentType(.jobTitle)
                    TextField("Location", text: $location)
                        .textContentType(.location)
                }
                else if type == .clinical {
                    TextField("Facility", text: $facility)
                        .textContentType(.organizationName)
                    TextField("Role", text: $role)
                        .textContentType(.jobTitle)
                    TextField("Location", text: $location)
                        .textContentType(.location)
                }
                else if type == .leadership {
                    TextField("Organization", text: $organization)
                        .textContentType(.organizationName)
                    TextField("Role", text: $role)
                        .textContentType(.jobTitle)
                    TextField("Location", text: $location)
                        .textContentType(.location)
                }
                else if type == .research {
                    TextField("Role", text: $role)
                        .textContentType(.jobTitle)
                    TextField("Faculty or Lab", text: $facultyOrLab)
                        .textContentType(.organizationName)
                    TextField("Location", text: $location)
                        .textContentType(.location)
                }
                else if type == .service {
                    Toggle("Clinical Service", isOn: $isClinicalService)
                    TextField("Organization", text: $organization)
                        .textContentType(.organizationName)
                    TextField("Role", text: $role)
                        .textContentType(.jobTitle)
                    TextField("Location", text: $location)
                        .textContentType(.location)
                }
                else if type == .other {
                    TextField("Describe today's experience", text: $otherNotes, axis: .vertical).lineLimit(3...6)
                } else if type == .discernment {
                    TextField("What are you discerning right now?", text: $otherNotes, axis: .vertical).lineLimit(3...6)
                } else {
                    TextField("Describe the experience", text: $otherNotes, axis: .vertical).lineLimit(3...6)
                }

                Section {
                    TextField("Additional Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(typeTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        let freeText = (type == .other || type == .discernment ? otherNotes : notes).nonEmpty
                        let details = ExperienceDetails(
                            physician: physician.nonEmpty,
                            specialty: specialty.nonEmpty,
                            facility: facility.nonEmpty,
                            location: location.nonEmpty,
                            role: role.nonEmpty,
                            organization: organization.nonEmpty,
                            isClinicalService: (type == .service) ? isClinicalService : nil,
                            facultyOrLab: facultyOrLab.nonEmpty,
                            otherNotes: freeText,
                            hours: Double(hoursString)
                        ).trimmed()
                        onContinue(details)
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .foregroundStyle(Color.primary) // Fix for Dark Mode: override potential inherited styles
    }

}
