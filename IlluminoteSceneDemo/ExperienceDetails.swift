/// A lightweight, non-persisted value type used to collect optional metadata
/// about a user's experience before starting an Examen. This is intentionally
/// separate from SwiftData models so it can be freely created/edited in forms
/// and then applied to an `ExamenSession` when the flow begins.
struct ExperienceDetails: Equatable, Codable, Sendable {
    var physician: String?
    var specialty: String?
    var facility: String?
    var location: String?
    var role: String?
    var organization: String?
    var isClinicalService: Bool?
    var facultyOrLab: String?
    var otherNotes: String?
    var hours: Double?

    /// Returns true if all user-entered fields are empty or whitespace.
    var isEmpty: Bool {
        return fields.allSatisfy { value in
             guard let s = value else { return true }
             return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } && isClinicalService == nil && hours == nil
    }

    /// A trimmed version of this value, where all string properties are
    /// whitespace-trimmed and empty strings are converted to nil.
    func trimmed() -> ExperienceDetails {
        ExperienceDetails(
            physician: physician?.trimmedOrNil,
            specialty: specialty?.trimmedOrNil,
            facility: facility?.trimmedOrNil,
            location: location?.trimmedOrNil,
            role: role?.trimmedOrNil,
            organization: organization?.trimmedOrNil,
            isClinicalService: isClinicalService,
            facultyOrLab: facultyOrLab?.trimmedOrNil,
            otherNotes: otherNotes?.trimmedOrNil,
            hours: hours
        )
    }

    /// Merge non-nil values from `other`, preferring values in `other` when present.
    func merging(prefer other: ExperienceDetails) -> ExperienceDetails {
        ExperienceDetails(
            physician: other.physician ?? physician,
            specialty: other.specialty ?? specialty,
            facility: other.facility ?? facility,
            location: other.location ?? location,
            role: other.role ?? role,
            organization: other.organization ?? organization,
            isClinicalService: other.isClinicalService ?? isClinicalService,
            facultyOrLab: other.facultyOrLab ?? facultyOrLab,
            otherNotes: other.otherNotes ?? otherNotes,
            hours: other.hours ?? hours
        )
    }

    // MARK: - Private

    private var fields: [String?] {
        [physician, specialty, facility, location, role, organization, facultyOrLab, otherNotes]
    }
}

private extension String {
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
