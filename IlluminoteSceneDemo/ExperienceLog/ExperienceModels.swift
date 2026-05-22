import Foundation
import SwiftData

enum ApplicationExperienceCategory: String, Codable, CaseIterable, Identifiable {
    case shadowing
    case clinical
    case research
    case service
    case leadership
    case employment
    case teachingTutoring
    case extracurricular
    case awardHonor
    case manualDexterityArtistic
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shadowing: return "Shadowing"
        case .clinical: return "Clinical"
        case .research: return "Research"
        case .service: return "Service"
        case .leadership: return "Leadership"
        case .employment: return "Employment"
        case .teachingTutoring: return "Teaching / Tutoring"
        case .extracurricular: return "Extracurricular"
        case .awardHonor: return "Award / Honor"
        case .manualDexterityArtistic: return "Manual Dexterity / Artistic"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .shadowing: return "stethoscope"
        case .clinical: return "cross.case"
        case .research: return "microscope"
        case .service: return "heart.text.square"
        case .leadership: return "person.3"
        case .employment: return "briefcase"
        case .teachingTutoring: return "graduationcap"
        case .extracurricular: return "figure.run"
        case .awardHonor: return "rosette"
        case .manualDexterityArtistic: return "paintpalette"
        case .other: return "square.grid.2x2"
        }
    }

    static func suggested(for experienceType: ExperienceType) -> ApplicationExperienceCategory {
        switch experienceType.canonical {
        case .shadowing:
            return .shadowing
        case .clinical:
            return .clinical
        case .leadership:
            return .leadership
        case .research:
            return .research
        case .work:
            return .employment
        case .service, .volunteer:
            return .service
        case .discernment, .other:
            return .other
        }
    }
}

@Model
final class ApplicationExperience {
    var id: UUID = UUID()
    var title: String = ""
    var categoryRaw: String = ApplicationExperienceCategory.other.rawValue
    var organizationName: String?
    var roleTitle: String?
    var location: String?
    var contactName: String?
    var contactTitle: String?
    var contactEmail: String?
    var contactPhone: String?
    var contactPermissionAuthorized: Bool?
    var applicationDescription: String = ""
    var highlightServiceCodes: [String] = []
    var dateCreated: Date = Date.now
    var dateModified: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \ExperiencePeriod.experience)
    private var periodStorage: [ExperiencePeriod]?

    @Relationship(inverse: \ExamenSession.applicationExperience)
    private var linkedSessionStorage: [ExamenSession]?

    var periods: [ExperiencePeriod] {
        get { periodStorage ?? [] }
        set { periodStorage = newValue }
    }

    var linkedSessions: [ExamenSession] {
        get { linkedSessionStorage ?? [] }
        set { linkedSessionStorage = newValue }
    }

    var category: ApplicationExperienceCategory {
        get { ApplicationExperienceCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        category: ApplicationExperienceCategory,
        organizationName: String? = nil,
        roleTitle: String? = nil,
        location: String? = nil,
        contactName: String? = nil,
        contactTitle: String? = nil,
        contactEmail: String? = nil,
        contactPhone: String? = nil,
        contactPermissionAuthorized: Bool? = nil,
        applicationDescription: String = "",
        highlightServiceCodes: [String] = [],
        dateCreated: Date = .now,
        dateModified: Date = .now,
        periods: [ExperiencePeriod] = [],
        linkedSessions: [ExamenSession] = []
    ) {
        self.id = id
        self.title = title
        self.categoryRaw = category.rawValue
        self.organizationName = organizationName
        self.roleTitle = roleTitle
        self.location = location
        self.contactName = contactName
        self.contactTitle = contactTitle
        self.contactEmail = contactEmail
        self.contactPhone = contactPhone
        self.contactPermissionAuthorized = contactPermissionAuthorized
        self.applicationDescription = applicationDescription
        self.highlightServiceCodes = highlightServiceCodes
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.periodStorage = periods
        self.linkedSessionStorage = linkedSessions
    }
}

@Model
final class ExperiencePeriod {
    var id: UUID = UUID()
    var startDate: Date = Date.now
    var endDate: Date?
    var isOngoing: Bool = false
    var isPlanned: Bool = false
    var totalHours: Double = 0
    var averageHoursPerWeek: Double?

    var experience: ApplicationExperience?

    init(
        id: UUID = UUID(),
        startDate: Date = .now,
        endDate: Date? = nil,
        isOngoing: Bool = false,
        isPlanned: Bool = false,
        totalHours: Double = 0,
        averageHoursPerWeek: Double? = nil,
        experience: ApplicationExperience? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.isOngoing = isOngoing
        self.isPlanned = isPlanned
        self.totalHours = totalHours
        self.averageHoursPerWeek = averageHoursPerWeek
        self.experience = experience
    }
}

struct ExperiencePeriodDraft: Codable, Hashable {
    var startDate: Date = .now
    var endDate: Date? = nil
    var isOngoing: Bool = false
    var isPlanned: Bool = false
    var totalHours: Double = 0
    var averageHoursPerWeek: Double? = nil

    func buildModel() -> ExperiencePeriod {
        ExperiencePeriod(
            startDate: startDate,
            endDate: endDate,
            isOngoing: isOngoing,
            isPlanned: isPlanned,
            totalHours: totalHours,
            averageHoursPerWeek: averageHoursPerWeek
        )
    }
}

struct ApplicationExperienceSeed: Codable, Hashable {
    var title: String = ""
    var category: ApplicationExperienceCategory = .other
    var organizationName: String = ""
    var roleTitle: String = ""
    var location: String = ""
    var contactName: String = ""
    var initialPeriod: ExperiencePeriodDraft = .init()

    static func suggested(from draft: ExamenSessionDraft) -> ApplicationExperienceSeed {
        ApplicationExperienceSeed(
            title: draft.personalStatement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? suggestedTitleFallback(for: draft.type) : draft.personalStatementTitleFallback,
            category: .suggested(for: draft.type),
            organizationName: draft.resolvedSecondaryDetail,
            roleTitle: draft.resolvedPrimaryDetail,
            location: draft.location ?? "",
            contactName: draft.type == .shadowing ? draft.resolvedPrimaryDetail : (draft.mentorOrSupervisor ?? draft.physician ?? ""),
            initialPeriod: ExperiencePeriodDraft(totalHours: draft.hours)
        )
    }

    static func suggestedTitleFallback(for type: ExperienceType) -> String {
        switch type.canonical {
        case .shadowing: return "Shadowing Experience"
        case .clinical: return "Clinical Experience"
        case .leadership: return "Leadership Experience"
        case .research: return "Research Experience"
        case .work: return "Work Experience"
        case .service, .volunteer: return "Service Experience"
        case .discernment: return "Discernment Experience"
        case .other: return "Personal Experience"
        }
    }

    func buildModel() -> ApplicationExperience {
        let experience = ApplicationExperience(
            title: trimmed(title) ?? "Untitled Experience",
            category: category,
            organizationName: trimmed(organizationName),
            roleTitle: trimmed(roleTitle),
            location: trimmed(location),
            contactName: trimmed(contactName)
        )
        let period = initialPeriod.buildModel()
        period.experience = experience
        experience.periods = [period]
        return experience
    }

    private func trimmed(_ value: String) -> String? {
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}

struct ExperienceSuggestionCandidate: Identifiable, Hashable {
    let id: String
    let title: String
    let category: ApplicationExperienceCategory
    let organizationName: String?
    let roleTitle: String?
    let location: String?
    let contactName: String?
    let linkedSessionIDs: [UUID]
    let totalSessionHours: Double
    let suggestedPeriod: ExperiencePeriodDraft

    func makeSeed() -> ApplicationExperienceSeed {
        ApplicationExperienceSeed(
            title: title,
            category: category,
            organizationName: organizationName ?? "",
            roleTitle: roleTitle ?? "",
            location: location ?? "",
            contactName: contactName ?? "",
            initialPeriod: suggestedPeriod
        )
    }
}

extension ApplicationExperience {
    var totalPlannedHours: Double {
        periods.filter(\.isPlanned).reduce(0) { $0 + max(0, $1.totalHours) }
    }

    var totalCompletedHours: Double {
        periods.filter { !$0.isPlanned }.reduce(0) { $0 + max(0, $1.totalHours) }
    }

    var totalLoggedSessionHours: Double {
        linkedSessions.reduce(0) { $0 + max(0, $1.hours) }
    }

    var relevantTagSummary: [String] {
        let counts = linkedSessions
            .flatMap(\.tags)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String: Int]()) { partialResult, tag in
                partialResult[tag, default: 0] += 1
            }

        return counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
                }
                return lhs.value > rhs.value
            }
            .map(\.key)
            .prefix(5)
            .map { $0 }
    }

    var highlightServices: Set<RequirementApplicationService> {
        Set(highlightServiceCodes.compactMap(RequirementApplicationService.init(rawValue:)))
    }

    func isHighlighted(for service: RequirementApplicationService) -> Bool {
        highlightServices.contains(service)
    }

    func setHighlighted(_ highlighted: Bool, for service: RequirementApplicationService) {
        var updated = highlightServiceCodes.filter { $0 != service.rawValue }
        if highlighted {
            updated.append(service.rawValue)
        }
        highlightServiceCodes = updated.sorted()
        touch()
    }

    func touch() {
        dateModified = .now
    }

    var exportTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Experience" : trimmed
    }
}

extension ExamenSessionDraft {
    var personalStatementTitleFallback: String {
        let separators = CharacterSet.whitespacesAndNewlines
        let trimmed = personalStatement
            .split { character in
                character.unicodeScalars.allSatisfy(separators.contains)
            }
            .prefix(6)
            .joined(separator: " ")
        if trimmed.isEmpty {
            return ApplicationExperienceSeed.suggestedTitleFallback(for: type)
        }
        return trimmed
    }
}

extension ExperienceSuggestionCandidate {
    static func suggestions(from sessions: [ExamenSession], existingExperiences: [ApplicationExperience]) -> [ExperienceSuggestionCandidate] {
        let linkedSessionIDs = Set(existingExperiences.flatMap(\.linkedSessions).map(\.id))
        let eligible = sessions.filter { session in
            guard !linkedSessionIDs.contains(session.id) else { return false }
            guard let type = session.experienceType?.canonical else { return false }
            return type != .other && type != .discernment
        }

        let grouped = Dictionary(grouping: eligible) { session in
            let type = session.experienceType?.canonical ?? .other
            let organization = normalized(session.resolvedSecondaryDetail)
            let role = normalized(session.resolvedPrimaryDetail)
            let location = normalized(session.location)
            return [type.rawValue, organization, role, location].joined(separator: "|")
        }

        return grouped.compactMap { key, groupedSessions in
            guard let first = groupedSessions.first,
                  let type = first.experienceType?.canonical else { return nil }

            let totalHours = groupedSessions.reduce(0) { $0 + max(0, $1.hours) }
            let sortedDates = groupedSessions.map(\.date).sorted()
            let title = suggestedTitle(for: first, count: groupedSessions.count)
            let category = ApplicationExperienceCategory.suggested(for: type)
            let avgWeeklyHours: Double? = totalHours > 0 ? max(totalHours / max(1, Double(groupedSessions.count)), 0.5) : nil

            return ExperienceSuggestionCandidate(
                id: key,
                title: title,
                category: category,
                organizationName: first.resolvedSecondaryDetail,
                roleTitle: first.resolvedPrimaryDetail,
                location: first.location,
                contactName: first.resolvedPrimaryDetail,
                linkedSessionIDs: groupedSessions.map(\.id).sorted { $0.uuidString < $1.uuidString },
                totalSessionHours: totalHours,
                suggestedPeriod: ExperiencePeriodDraft(
                    startDate: sortedDates.first ?? .now,
                    endDate: sortedDates.last,
                    isOngoing: false,
                    isPlanned: false,
                    totalHours: totalHours,
                    averageHoursPerWeek: avgWeeklyHours
                )
            )
        }
        .sorted { lhs, rhs in
            if lhs.totalSessionHours == rhs.totalSessionHours {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.totalSessionHours > rhs.totalSessionHours
        }
    }

    private static func normalized(_ value: String?) -> String {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) ?? ""
    }

    private static func suggestedTitle(for session: ExamenSession, count: Int) -> String {
        let role = session.resolvedPrimaryDetail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let organization = session.resolvedSecondaryDetail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let typeName = session.experienceType?.canonical.displayName ?? "Experience"

        if let role, !role.isEmpty, let organization, !organization.isEmpty {
            return "\(role) — \(organization)"
        }
        if let organization, !organization.isEmpty {
            return "\(typeName) — \(organization)"
        }
        if let role, !role.isEmpty {
            return role
        }
        return count > 1 ? "\(typeName) Cluster" : typeName
    }
}
