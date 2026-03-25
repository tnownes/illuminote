import Foundation

struct ExperienceEntryRequirement: Identifiable, Codable {
    let id: String
    let serviceCode: RequirementApplicationService
    let title: String
    let maxExperiences: Int?
    let maxHighlights: Int?
    let highlightLabel: String?
    let requiresTotalHours: Bool
    let requiresAverageWeeklyHours: Bool
    let requiresContactDetails: Bool
    let requiresContactPermission: Bool
    let supportsRepeatedDateRanges: Bool
    let supportsCurrentPlannedSplit: Bool
    let descriptionCharacterLimit: Int?
    let guidanceNotes: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case serviceCode = "service_code"
        case title
        case maxExperiences = "max_experiences"
        case maxHighlights = "max_highlights"
        case highlightLabel = "highlight_label"
        case requiresTotalHours = "requires_total_hours"
        case requiresAverageWeeklyHours = "requires_average_weekly_hours"
        case requiresContactDetails = "requires_contact_details"
        case requiresContactPermission = "requires_contact_permission"
        case supportsRepeatedDateRanges = "supports_repeated_date_ranges"
        case supportsCurrentPlannedSplit = "supports_current_planned_split"
        case descriptionCharacterLimit = "description_character_limit"
        case guidanceNotes = "guidance_notes"
    }
}

protocol ExperienceEntryRequirementsService {
    func requirements(for profile: UserProfile?) -> [ExperienceEntryRequirement]
}

final class LocalExperienceEntryRequirementsService: ExperienceEntryRequirementsService {
    static let shared = LocalExperienceEntryRequirementsService()

    private let decoder = JSONDecoder()
    private var cached: [ExperienceEntryRequirement]?

    func requirements(for profile: UserProfile?) -> [ExperienceEntryRequirement] {
        let all = loadAll()
        guard let profile else { return all }
        let services = profile.relevantExperienceServices
        guard !services.isEmpty else { return [] }
        return all.filter { services.contains($0.serviceCode) }
    }

    private func loadAll() -> [ExperienceEntryRequirement] {
        if let cached {
            return cached
        }

        guard let url = Bundle.main.url(forResource: "experience_requirements", withExtension: "json") else {
            print("⚠️ experience_requirements.json not found in bundle")
            cached = []
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try decoder.decode([ExperienceEntryRequirement].self, from: data)
            cached = decoded
            return decoded
        } catch {
            print("⚠️ Failed to load experience entry requirements: \(error)")
            cached = []
            return []
        }
    }
}

extension UserProfile {
    var relevantExperienceServices: Set<RequirementApplicationService> {
        if let track = preProfessionalTrack?.canonical {
            switch track {
            case .preMedicine:
                if isTexasApplicant {
                    switch degreeIntent {
                    case .md:
                        return [.tmdsas, .amcas]
                    case .doDetail:
                        return [.tmdsas, .aacomas]
                    case .both:
                        return [.tmdsas, .amcas, .aacomas]
                    }
                }
                switch degreeIntent {
                case .md:
                    return [.amcas]
                case .doDetail:
                    return [.aacomas]
                case .both:
                    return [.amcas, .aacomas]
                }
            case .preDentistry:
                return isTexasApplicant ? [.tmdsas, .aadsas] : [.aadsas]
            case .prePharmacy:
                return [.pharmcas]
            case .preOccupationalTherapy:
                return [.otcas]
            case .prePhysicalTherapy:
                return [.ptcas]
            case .prePhysicianAssistant:
                return [.caspa]
            case .preVeterinaryMedicine:
                return isTexasApplicant ? [.tmdsas, .vmcas] : [.vmcas]
            case .preOptometry:
                return [.optomcas]
            case .preLaw, .medicalOrDentalResidency, .general, .other:
                return []
            }
        }
        return []
    }
}

struct ExperienceReadinessIssue: Identifiable, Hashable {
    enum Severity: String, Hashable {
        case info
        case warning
        case critical
    }

    let id: String
    let severity: Severity
    let message: String
}

struct ExperienceReadinessEvaluation {
    let service: ExperienceEntryRequirement
    let issues: [ExperienceReadinessIssue]
}

enum ExperienceReadinessEvaluator {
    static func evaluations(
        for experience: ApplicationExperience,
        requirements: [ExperienceEntryRequirement]
    ) -> [ExperienceReadinessEvaluation] {
        requirements.map { requirement in
            ExperienceReadinessEvaluation(
                service: requirement,
                issues: issues(for: experience, requirement: requirement)
            )
        }
    }

    static func listIssues(
        for experiences: [ApplicationExperience],
        requirements: [ExperienceEntryRequirement]
    ) -> [ExperienceReadinessIssue] {
        var results: [ExperienceReadinessIssue] = []

        for requirement in requirements {
            if let maxExperiences = requirement.maxExperiences, experiences.count > maxExperiences {
                results.append(
                    ExperienceReadinessIssue(
                        id: "\(requirement.serviceCode.rawValue)-count",
                        severity: .warning,
                        message: "\(requirement.serviceCode.displayName) supports up to \(maxExperiences) drafted experiences. You currently have \(experiences.count)."
                    )
                )
            }

            if let maxHighlights = requirement.maxHighlights {
                let selected = experiences.filter { $0.isHighlighted(for: requirement.serviceCode) }.count
                if selected == 0 {
                    let label = requirement.highlightLabel ?? "highlighted experiences"
                    results.append(
                        ExperienceReadinessIssue(
                            id: "\(requirement.serviceCode.rawValue)-missing-highlight",
                            severity: .info,
                            message: "Choose up to \(maxHighlights) \(label.lowercased()) for \(requirement.serviceCode.displayName)."
                        )
                    )
                } else if selected > maxHighlights {
                    let label = requirement.highlightLabel ?? "highlighted experiences"
                    results.append(
                        ExperienceReadinessIssue(
                            id: "\(requirement.serviceCode.rawValue)-too-many-highlight",
                            severity: .warning,
                            message: "\(requirement.serviceCode.displayName) allows up to \(maxHighlights) \(label.lowercased()); you currently marked \(selected)."
                        )
                    )
                }
            }
        }

        return results
    }

    private static func issues(
        for experience: ApplicationExperience,
        requirement: ExperienceEntryRequirement
    ) -> [ExperienceReadinessIssue] {
        var issues: [ExperienceReadinessIssue] = []

        if experience.exportTitle == "Untitled Experience" {
            issues.append(.init(id: "title", severity: .critical, message: "Add a clear experience title."))
        }

        if requirement.requiresTotalHours && experience.totalCompletedHours + experience.totalPlannedHours <= 0 {
            issues.append(.init(id: "hours", severity: .critical, message: "Add completed or planned hours for this experience."))
        }

        if requirement.requiresAverageWeeklyHours && experience.periods.contains(where: { ($0.averageHoursPerWeek ?? 0) <= 0 }) {
            issues.append(.init(id: "avg-hours", severity: .warning, message: "Add average weekly hours for each period before exporting to \(requirement.serviceCode.displayName)."))
        }

        if requirement.requiresContactDetails {
            let hasContact = !(experience.contactName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            if !hasContact {
                issues.append(.init(id: "contact-name", severity: .warning, message: "Add a supervisor or contact name for \(requirement.serviceCode.displayName)."))
            }
        }

        if requirement.requiresContactPermission && experience.contactPermissionAuthorized == nil {
            issues.append(.init(id: "contact-permission", severity: .warning, message: "Record whether programs may contact this experience reference."))
        }

        if requirement.supportsCurrentPlannedSplit,
           experience.periods.contains(where: { $0.isOngoing && !$0.isPlanned }) {
            issues.append(.init(id: "current-planned", severity: .info, message: "If this activity continues into the application year, consider splitting current and planned hours."))
        }

        if let characterLimit = requirement.descriptionCharacterLimit,
           experience.applicationDescription.count > characterLimit {
            issues.append(.init(id: "description-limit", severity: .warning, message: "Your activity description is \(experience.applicationDescription.count) characters; \(requirement.serviceCode.displayName) guidance is \(characterLimit)."))
        } else if experience.applicationDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(id: "description-empty", severity: .info, message: "Draft a concise activity description so this experience is ready to export."))
        }

        if requirement.serviceCode == .amcas && experience.periods.count > 4 {
            issues.append(.init(id: "amcas-repeats", severity: .warning, message: "AMCAS repeated activities support up to four date ranges; consolidate if needed."))
        }

        return issues
    }
}
