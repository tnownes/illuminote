//
//  ExamenModel.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 5/24/25.
//

import Foundation
import SwiftUI
import SwiftData
// ExamenModel.swift
@Model
final class UserProfile {
    var id: UUID = UUID()
    @Attribute(originalName: "preProfessionalInterest") var preProfessionalTrack: PreProfessionalTrack?
    var recentPromptIDs: [UUID] = []

    // Preferences
    var examenFrequency: ExamenFrequency = ExamenFrequency.daily
    var preferredTimeOfDay: PreferredTimeOfDay = PreferredTimeOfDay.evening
    var sessionLength: SessionLength = SessionLength.medium
    var defaultMode: ExamenMode = ExamenMode.deep
    var notificationsEnabled: Bool = false
    var notificationTime: Date = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date.now
    var hasSeenOnboarding: Bool = false

    init(id: UUID = UUID(),
         preProfessionalTrack: PreProfessionalTrack? = nil,
         recentPromptIDs: [UUID] = [],
         examenFrequency: ExamenFrequency = .daily,
         preferredTimeOfDay: PreferredTimeOfDay = .evening,
         sessionLength: SessionLength = .medium,
         defaultMode: ExamenMode = .deep,
         notificationsEnabled: Bool = false,
         notificationTime: Date? = nil,
         hasSeenOnboarding: Bool = false,
         degreeIntent: DegreeIntent = DegreeIntent.md,
         isTexasApplicant: Bool = false,
         isMDPhDApplicant: Bool = false)
    {
        self.id = id
        self.preProfessionalTrack = preProfessionalTrack
        self.recentPromptIDs = recentPromptIDs
        self.examenFrequency = examenFrequency
        self.preferredTimeOfDay = preferredTimeOfDay
        self.sessionLength = sessionLength
        self.defaultMode = defaultMode
        self.notificationsEnabled = notificationsEnabled
        self.notificationTime = notificationTime ?? (Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date.now)
        self.hasSeenOnboarding = hasSeenOnboarding
        self.degreeIntent = degreeIntent
        self.isTexasApplicant = isTexasApplicant
        self.isMDPhDApplicant = isMDPhDApplicant
    }

    // New fields for Phase 1 Knowledge Base
    var degreeIntent: DegreeIntent = DegreeIntent.md
    var isTexasApplicant: Bool = false
    var isMDPhDApplicant: Bool = false
}





enum ExamenFrequency: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, asNeeded
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .asNeeded: return "As Needed"
        }
    }
}

enum PreferredTimeOfDay: String, Codable, CaseIterable, Identifiable {
    case morning, afternoon, evening, noPreference
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .noPreference: return "No Preference"
        }
    }
}

enum SessionLength: String, Codable, CaseIterable, Identifiable {
    case short, medium, long
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .short: return "Short"
        case .medium: return "Medium"
        case .long: return "Long"
        }
    }
}

enum PreProfessionalTrack: String, CaseIterable, Codable {
    // Legacy raw values for backward compatibility
    case preMedicine = "preMedicine"
    case preDentistry = "preDentistry"
    case preLaw = "preLaw"
    case other = "other" // Legacy alias retained for existing records.
    
    // New cases (using camelCase raw values for consistency)
    case prePharmacy = "prePharmacy"
    case preOccupationalTherapy = "preOccupationalTherapy"
    case prePhysicalTherapy = "prePhysicalTherapy"
    case prePhysicianAssistant = "prePhysicianAssistant"
    case preVeterinaryMedicine = "preVeterinaryMedicine"
    case preOptometry = "preOptometry"
    case medicalOrDentalResidency = "medicalOrDentalResidency"
    case general = "general"

    /// Canonical form used by new UI/logic.
    var canonical: PreProfessionalTrack {
        switch self {
        case .other:
            return .general
        default:
            return self
        }
    }

    /// User-selectable cases (hides legacy aliases from pickers).
    static var selectableCases: [PreProfessionalTrack] {
        [
            .preMedicine,
            .preDentistry,
            .prePharmacy,
            .preOccupationalTherapy,
            .prePhysicalTherapy,
            .prePhysicianAssistant,
            .preLaw,
            .preVeterinaryMedicine,
            .preOptometry,
            .medicalOrDentalResidency,
            .general
        ]
    }
    
    var displayName: String {
        switch self {
        case .preMedicine: return "Pre-Medicine"
        case .preDentistry: return "Pre-Dentistry"
        case .prePharmacy: return "Pre-Pharmacy"
        case .preOccupationalTherapy: return "Pre-Occupational Therapy"
        case .prePhysicalTherapy: return "Pre-Physical Therapy"
        case .prePhysicianAssistant: return "Pre-Physician Assistant"
        case .preLaw: return "Pre-Law"
        case .preVeterinaryMedicine: return "Pre-Veterinary Medicine"
        case .preOptometry: return "Pre-Optometry"
        case .medicalOrDentalResidency: return "Medical or Dental Residency"
        case .general: return "Personal"
        case .other: return "Personal"
        }
    }
}

enum ExperienceType: String, Codable {
    case shadowing, clinical, leadership, research, work, service, discernment, other
    /// Deprecated: maps to `.service`. Kept for backward compatibility with existing SwiftData records.
    case volunteer

    /// All active cases (excludes deprecated `.volunteer`)
    static var allCases: [ExperienceType] {
        [.shadowing, .clinical, .leadership, .research, .work, .service, .discernment, .other]
    }

    /// Canonical form: maps deprecated cases to their replacement
    var canonical: ExperienceType {
        switch self {
        case .volunteer: return .service
        default: return self
        }
    }
}

extension ExperienceType {
    var displayName: String {
        switch self {
        case .shadowing: return "Shadowing"
        case .volunteer: return "Service"  // Deprecated, maps to service
        case .clinical: return "Clinical"
        case .leadership: return "Leadership"
        case .research: return "Research"
        case .work: return "Work"
        case .service: return "Service / Volunteer"
        case .discernment: return "Discernment"
        case .other: return "Daily"
        }
    }
    
    var paleColor: Color {
        switch self {
        case .shadowing: return Color(hex: "#E3F2FD") // Pale Blue
        case .clinical:  return Color(hex: "#E8F5E9") // Pale Green
        case .leadership: return Color(hex: "#F3E5F5") // Pale Purple
        case .research:  return Color(hex: "#FFF3E0") // Pale Orange
        case .service:   return Color(hex: "#FFEBEE") // Pale Red (fixed below, type-o in plan, using actual pale red) -> #FFEBEE
        case .volunteer: return Color(hex: "#FFEBEE") // Deprecated, same as service
        case .work:      return Color(hex: "#F5F5F5") // Pale Gray
        case .discernment: return Color(hex: "#FFF8E1") // Pale Gold
        case .other:     return Color(hex: "#E0F2F1") // Pale Teal
        }
    }
}

struct ExperienceDetailFieldConfig: Sendable {
    let primaryLabel: String
    let facilityLabel: String
    let focusLabel: String
    let showsHours: Bool
    let showsPrimary: Bool
    let showsFacility: Bool
    let showsLocation: Bool
    let showsFocus: Bool
}

extension ExperienceType {
    var detailFieldConfig: ExperienceDetailFieldConfig {
        switch self {
        case .shadowing:
            return ExperienceDetailFieldConfig(
                primaryLabel: "Physician / Mentor",
                facilityLabel: "Facility",
                focusLabel: "Specialty / Focus",
                showsHours: true,
                showsPrimary: true,
                showsFacility: true,
                showsLocation: true,
                showsFocus: true
            )
        case .clinical:
            return ExperienceDetailFieldConfig(
                primaryLabel: "Supervisor / Mentor",
                facilityLabel: "Facility",
                focusLabel: "Clinical Focus",
                showsHours: true,
                showsPrimary: true,
                showsFacility: true,
                showsLocation: true,
                showsFocus: true
            )
        case .leadership:
            return ExperienceDetailFieldConfig(
                primaryLabel: "Role / Title",
                facilityLabel: "Organization",
                focusLabel: "Initiative / Focus",
                showsHours: true,
                showsPrimary: true,
                showsFacility: true,
                showsLocation: true,
                showsFocus: false
            )
        case .research:
            return ExperienceDetailFieldConfig(
                primaryLabel: "PI / Mentor",
                facilityLabel: "Lab / Program",
                focusLabel: "Research Focus",
                showsHours: true,
                showsPrimary: true,
                showsFacility: true,
                showsLocation: true,
                showsFocus: true
            )
        case .work:
            return ExperienceDetailFieldConfig(
                primaryLabel: "Position",
                facilityLabel: "Employer",
                focusLabel: "Work Focus",
                showsHours: true,
                showsPrimary: true,
                showsFacility: true,
                showsLocation: true,
                showsFocus: false
            )
        case .service:
            return ExperienceDetailFieldConfig(
                primaryLabel: "Role",
                facilityLabel: "Organization",
                focusLabel: "Population / Cause",
                showsHours: true,
                showsPrimary: true,
                showsFacility: true,
                showsLocation: true,
                showsFocus: false
            )
        case .discernment:
            return ExperienceDetailFieldConfig(
                primaryLabel: "Mentor / Director",
                facilityLabel: "Community / Context",
                focusLabel: "Discernment Focus",
                showsHours: false,
                showsPrimary: false,
                showsFacility: false,
                showsLocation: false,
                showsFocus: true
            )
        case .other, .volunteer:
            return ExperienceDetailFieldConfig(
                primaryLabel: "Contact / Mentor",
                facilityLabel: "Organization / Site",
                focusLabel: "Focus",
                showsHours: false,
                showsPrimary: false,
                showsFacility: false,
                showsLocation: false,
                showsFocus: false
            )
        }
    }
}

@Model
final class ExamenSession {
    var id: UUID = UUID()
    var sessionType: ExamenType = ExamenType.daily
    var date: Date = Date.now
    var examenModeRaw: String?
    @Relationship(deleteRule: .cascade, inverse: \StepResponse.session) private var responseStorage: [StepResponse]?
    var personalStatement: String = ""

    /// Optional title (primarily for personal statement drafts; unused for typical journal entries)
    var title: String = ""

    /// Optional structured type for an entry (journal entries only)
    var experienceType: ExperienceType?
    
    /// Duration of the experience in hours
    var hours: Double = 0.0

    /// Optional structured metadata captured after finishing an Examen
    var physician: String?
    var facility: String?
    var specialty: String?
    var location: String?
    /// Phase 2 normalized metadata (additive; leaves legacy fields intact)
    var mentorOrSupervisor: String?
    var roleTitle: String?
    var organizationName: String?
    var focusArea: String?
    var notes: String?

    /// Lightweight tags for filtering (e.g., "insightful", "meaningful"). Kept simple for MVP; can be replaced by a Tag model later.
    var tags: [String] = []

    /// For statement drafts: store the UUIDs of any journal entries referenced/copied into this draft.
    /// (Avoids a heavy self-referential relationship for now; enables quick lookups and deep-links.)
    var referencedEntryIDs: [UUID] = []

    var applicationExperience: ApplicationExperience?

    var isFavorite: Bool = false

    var responses: [StepResponse] {
        get { responseStorage ?? [] }
        set { responseStorage = newValue }
    }

    var examenMode: ExamenMode {
        get {
            if let examenModeRaw, let persisted = ExamenMode(rawValue: examenModeRaw) {
                return persisted
            }
            if experienceType == .discernment {
                return .vocation
            }
            return .deep
        }
        set {
            examenModeRaw = newValue.rawValue
        }
    }

    init(id: UUID = UUID(),
         sessionType: ExamenType,
         date: Date = Date.now,
         examenMode: ExamenMode? = nil,
         responses: [StepResponse] = [],
         personalStatement: String = "",
         title: String = "",
         experienceType: ExperienceType? = nil,
         physician: String? = nil,
         facility: String? = nil,
         specialty: String? = nil,
         location: String? = nil,
         mentorOrSupervisor: String? = nil,
         roleTitle: String? = nil,
         organizationName: String? = nil,
         focusArea: String? = nil,
         notes: String? = nil,
         tags: [String] = [],
         referencedEntryIDs: [UUID] = [],
         applicationExperience: ApplicationExperience? = nil,
         isFavorite: Bool = false,
         hours: Double = 0.0)
    {
        self.id = id
        self.sessionType = sessionType
        self.date = date
        self.examenModeRaw = examenMode?.rawValue
        self.responseStorage = responses
        self.personalStatement = personalStatement
        self.title = title
        self.experienceType = experienceType
        self.physician = physician
        self.facility = facility
        self.specialty = specialty
        self.location = location
        self.mentorOrSupervisor = mentorOrSupervisor
        self.roleTitle = roleTitle
        self.organizationName = organizationName
        self.focusArea = focusArea
        self.notes = notes
        self.tags = tags
        self.referencedEntryIDs = referencedEntryIDs
        self.applicationExperience = applicationExperience
        self.isFavorite = isFavorite
        self.hours = hours
    }
}

enum ExamenType: String, CaseIterable, Codable {
    case daily, retreat, vocation, statementDraft
}

enum ExamenMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case quick, deep, vocation, spiritual
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .quick: return "Quick"
        case .deep: return "Deep"
        case .vocation: return "Vocational"
        case .spiritual: return "Spiritual"
        }
    }
    
    var description: String {
        switch self {
        case .quick: return "A brief, 4-step reflection to ground your day."
        case .deep: return "An extended reflection with standard and deep prompts."
        case .vocation: return "Focuses on pre-professional growth, ethics, and your future calling."
        case .spiritual: return "A faith-based lens focusing on grace, prayer, and presence."
        }
    }
    
    var promptCount: Int {
        switch self {
        case .quick: return 4
        case .deep: return 5
        case .vocation: return 5
        case .spiritual: return 5
        }
    }
    
    var allowSpiritualPrompts: Bool {
        switch self {
        case .spiritual: return true
        default: return false
        }
    }
    
    var emphasizedTags: [String] {
        switch self {
        case .vocation:
            return ["vocation", "pre-professional", "clinical", "ethics", "growth", "experience-specific"]
        case .spiritual:
            return ["spiritual", "presence", "compassion", "reflection", "hope"]
        default:
            return []
        }
    }
}

@Model
final class StepResponse {
    var id: UUID = UUID()
    var stepIndex: Int = 0
    var answerText: String = ""
    var additionalNotes: String?
    @Relationship var session: ExamenSession?

    // New fields for Deep Reflection
    var promptID: UUID = UUID()
    var stage: String = "unknown"

    init(id: UUID = UUID(),
         stepIndex: Int,
         answerText: String,
         additionalNotes: String? = nil,
         session: ExamenSession? = nil,
         promptID: UUID = UUID(),
         stage: String = "unknown")
    {
        self.id = id
        self.stepIndex = stepIndex
        self.answerText = answerText
        self.additionalNotes = additionalNotes
        self.session = session
        self.promptID = promptID
        self.stage = stage
    }
}

/// Helper to map stages to integer phases


/// Temporary draft state for an active Examen session.
/// Not persisted to SwiftData until the session is completed.
struct ExamenSessionDraft: Hashable {
    var type: ExperienceType
    var date: Date = Date.now
    var hours: Double = 0.0
    var examenMode: ExamenMode? = nil



    // NEW: answers keyed by prompt UUID
    var answersByPromptID: [UUID: String] = [:]

    // Metadata to be filled at the end
    var physician: String?
    var facility: String?
    var specialty: String?
    var location: String?
    // Phase 2 normalized metadata
    var mentorOrSupervisor: String?
    var roleTitle: String?
    var organizationName: String?
    var focusArea: String?
    var notes: String?
    var tags: [String] = []
    var personalStatement: String = ""
    var linkedApplicationExperienceID: UUID?
    var pendingApplicationExperience: ApplicationExperienceSeed?
}

extension ExamenSessionDraft {
    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var resolvedPrimaryDetail: String {
        let primary: String?
        switch type {
        case .leadership, .service, .work:
            primary = roleTitle ?? mentorOrSupervisor ?? physician
        default:
            primary = mentorOrSupervisor ?? physician ?? roleTitle
        }
        return primary ?? ""
    }

    var resolvedSecondaryDetail: String {
        organizationName ?? facility ?? ""
    }

    var resolvedFocusDetail: String {
        focusArea ?? specialty ?? ""
    }

    mutating func applyDetails(
        primary: String?,
        secondary: String?,
        focus: String?,
        location: String?,
        hours: Double?
    ) {
        let config = type.detailFieldConfig

        let primaryValue = normalized(primary)
        let secondaryValue = normalized(secondary)
        let focusValue = normalized(focus)
        let locationValue = normalized(location)

        self.location = config.showsLocation ? locationValue : nil
        self.organizationName = config.showsFacility ? secondaryValue : nil
        self.focusArea = config.showsFocus ? focusValue : nil

        switch type {
        case .shadowing, .clinical, .research:
            self.mentorOrSupervisor = config.showsPrimary ? primaryValue : nil
            self.roleTitle = nil
            self.physician = config.showsPrimary ? primaryValue : nil
        case .leadership, .service, .work:
            self.roleTitle = config.showsPrimary ? primaryValue : nil
            self.mentorOrSupervisor = nil
            self.physician = nil
        case .other, .volunteer, .discernment:
            self.roleTitle = nil
            self.mentorOrSupervisor = nil
            self.physician = nil
        }

        // Legacy compatibility fields retained for old records/readers.
        self.facility = config.showsFacility ? secondaryValue : nil
        self.specialty = config.showsFocus ? focusValue : nil
        self.hours = config.showsHours ? (hours ?? 0.0) : 0.0
    }
}

@Model
final class PromptTemplate {
    @Attribute(.unique) var id: UUID

    // Core prompt fields
    var text: String
    var stage: String
    var phase: Int          // CORRECT
    var depth: String  // "standard" or "deep"
    var stepIndex: Int

    // Filtering metadata
    var experienceTypes: [String]?       // normalized lowercase (from JSON)
    var professionTags: [String]?        // normalized lowercase or profile identifiers
    var tags: [String]?                  // catch-all tag list
    var intent: String?                  // optional descriptive intent

    init(
        id: UUID,
        text: String,
        phase: Int,
        stage: String,
        depth: String,
        stepIndex: Int,
        experienceTypes: [String]? = nil,
        professionTags: [String]? = nil,
        tags: [String]? = nil,
        intent: String? = nil
    ) {
        self.id = id
        self.text = text
        self.phase = phase
        self.stage = stage
        self.depth = depth
        self.stepIndex = stepIndex
        self.experienceTypes = experienceTypes
        self.professionTags = professionTags
        self.tags = tags
        self.intent = intent
    }
}

enum ThemeClusterScope: String, Codable, CaseIterable, Identifiable {
    case acrossExperiences
    case withinExperience

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .acrossExperiences: return "Across Experiences"
        case .withinExperience: return "Within Experience"
        }
    }
}

enum ThemeLabelSource: String, Codable {
    case taxonomy
    case emergent
}

@Model
final class ThemeCluster {
    var id: UUID = UUID()
    var label: String = ""
    var normalizedLabel: String = ""
    var scopeRaw: String = ThemeClusterScope.acrossExperiences.rawValue
    var labelSourceRaw: String = ThemeLabelSource.emergent.rawValue
    var experienceTypeRaw: String?
    var score: Double = 0
    var confidence: Double = 0
    var isAccepted: Bool = false
    var isHidden: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \ThemeEntryLink.cluster)
    private var linkStorage: [ThemeEntryLink]?

    var links: [ThemeEntryLink] {
        get { linkStorage ?? [] }
        set { linkStorage = newValue }
    }

    var scope: ThemeClusterScope {
        get { ThemeClusterScope(rawValue: scopeRaw) ?? .acrossExperiences }
        set { scopeRaw = newValue.rawValue }
    }

    var labelSource: ThemeLabelSource {
        get { ThemeLabelSource(rawValue: labelSourceRaw) ?? .emergent }
        set { labelSourceRaw = newValue.rawValue }
    }

    var experienceType: ExperienceType? {
        get {
            guard let experienceTypeRaw else { return nil }
            return ExperienceType(rawValue: experienceTypeRaw)
        }
        set {
            experienceTypeRaw = newValue?.rawValue
        }
    }

    init(
        id: UUID = UUID(),
        label: String,
        normalizedLabel: String? = nil,
        scope: ThemeClusterScope = .acrossExperiences,
        labelSource: ThemeLabelSource = .emergent,
        experienceType: ExperienceType? = nil,
        score: Double = 0,
        confidence: Double = 0,
        isAccepted: Bool = false,
        isHidden: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        links: [ThemeEntryLink] = []
    ) {
        self.id = id
        self.label = label
        self.normalizedLabel = normalizedLabel ?? ThemeCluster.normalize(label)
        self.scopeRaw = scope.rawValue
        self.labelSourceRaw = labelSource.rawValue
        self.experienceTypeRaw = experienceType?.rawValue
        self.score = score
        self.confidence = confidence
        self.isAccepted = isAccepted
        self.isHidden = isHidden
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.linkStorage = links
    }

    static func normalize(_ label: String) -> String {
        label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

@Model
final class ThemeEntryLink {
    var id: UUID = UUID()
    var entryID: UUID = UUID()
    var evidenceSnippet: String = ""
    var confidence: Double = 0

    var cluster: ThemeCluster?

    init(
        id: UUID = UUID(),
        entryID: UUID,
        evidenceSnippet: String,
        confidence: Double,
        cluster: ThemeCluster? = nil
    ) {
        self.id = id
        self.entryID = entryID
        self.evidenceSnippet = evidenceSnippet
        self.confidence = confidence
        self.cluster = cluster
    }
}

@Model
final class ThemeBundle {
    var id: UUID = UUID()
    var title: String = ""
    var themeLabel: String = ""
    var sourceClusterID: UUID?
    var entryIDStrings: [String] = []
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var entryIDs: [UUID] {
        get { entryIDStrings.compactMap(UUID.init(uuidString:)) }
        set { entryIDStrings = newValue.map(\.uuidString) }
    }

    init(
        id: UUID = UUID(),
        title: String,
        themeLabel: String,
        sourceClusterID: UUID? = nil,
        entryIDs: [UUID] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.themeLabel = themeLabel
        self.sourceClusterID = sourceClusterID
        self.entryIDStrings = entryIDs.map(\.uuidString)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class SemanticVectorCache {
    var id: UUID
    var entryID: UUID
    var values: [Double]
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        entryID: UUID,
        values: [Double],
        updatedAt: Date = .now
    ) {
        self.id = id
        self.entryID = entryID
        self.values = values
        self.updatedAt = updatedAt
    }
}
