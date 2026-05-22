import Foundation
import SwiftData

enum InsightLens: String, CaseIterable, Identifiable {
    case themes
    case experiences
    case values
    case why

    var id: String { rawValue }

    var title: String {
        if AppSettings.featurePolicy.mode == .core {
            switch self {
            case .themes: return "Patterns"
            case .experiences: return "Experiences"
            case .values: return "Values"
            case .why: return "Calling"
            }
        }

        switch self {
        case .themes: return "Themes"
        case .experiences: return "Experiences"
        case .values: return "Values"
        case .why: return "Why"
        }
    }

    var systemImage: String {
        switch self {
        case .themes: return "sparkles.rectangle.stack"
        case .experiences: return "briefcase"
        case .values: return "heart.text.square"
        case .why: return "lightbulb"
        }
    }

    var summary: String {
        if AppSettings.featurePolicy.mode == .core {
            switch self {
            case .themes:
                return "What keeps showing up."
            case .experiences:
                return "Moments worth returning to."
            case .values:
                return "What your actions reveal."
            case .why:
                return "What draws you forward."
            }
        }

        switch self {
        case .themes:
            return "Patterns that recur across multiple reflections."
        case .experiences:
            return "Journal-backed moments and settings worth understanding before you draft."
        case .values:
            return "Traits and professional values grounded in evidence."
        case .why:
            return "Motivations and discernment signals you can build into your own thinking."
        }
    }

    var nodeKind: InsightNodeKind? {
        switch self {
        case .themes: return .theme
        case .experiences: return .experience
        case .values: return .value
        case .why: return .motivation
        }
    }
}

enum InsightNodeKind: String, Codable, CaseIterable, Identifiable {
    case theme
    case experience
    case value
    case motivation

    var id: String { rawValue }

    var lens: InsightLens {
        switch self {
        case .theme: return .themes
        case .experience: return .experiences
        case .value: return .values
        case .motivation: return .why
        }
    }

    var displayName: String {
        if AppSettings.featurePolicy.mode == .core, self == .motivation {
            return "Calling"
        }

        switch self {
        case .theme: return "Theme"
        case .experience: return "Experience"
        case .value: return "Value"
        case .motivation: return "Why"
        }
    }
}

enum InsightNodeStatus: String, Codable, CaseIterable {
    case suggested
    case accepted
}

enum InsightNodeSource: String, Codable, CaseIterable {
    case deterministic
    case aiAssisted
    case manual
}

@Model
final class InsightNode {
    var id: UUID = UUID()
    var kindRaw: String = InsightNodeKind.theme.rawValue
    var title: String = ""
    var normalizedTitle: String = ""
    var statusRaw: String = InsightNodeStatus.suggested.rawValue
    var confidence: Double = 0
    var sourceRaw: String = InsightNodeSource.deterministic.rawValue
    var experienceTypeRaw: String?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var isPinned: Bool = false
    var isHidden: Bool = false
    var sourceThemeClusterID: UUID?

    @Relationship(deleteRule: .cascade, inverse: \InsightEntryLink.insightNode)
    private var linkStorage: [InsightEntryLink]?

    @Relationship(inverse: \InsightWorkspaceEntry.linkedInsightNode)
    private var workspaceEntryStorage: [InsightWorkspaceEntry]?

    var links: [InsightEntryLink] {
        get { linkStorage ?? [] }
        set { linkStorage = newValue }
    }

    var kind: InsightNodeKind {
        get { InsightNodeKind(rawValue: kindRaw) ?? .theme }
        set { kindRaw = newValue.rawValue }
    }

    var status: InsightNodeStatus {
        get { InsightNodeStatus(rawValue: statusRaw) ?? .suggested }
        set { statusRaw = newValue.rawValue }
    }

    var source: InsightNodeSource {
        get { InsightNodeSource(rawValue: sourceRaw) ?? .deterministic }
        set { sourceRaw = newValue.rawValue }
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
        kind: InsightNodeKind,
        title: String,
        normalizedTitle: String? = nil,
        status: InsightNodeStatus = .suggested,
        confidence: Double = 0,
        source: InsightNodeSource = .deterministic,
        experienceType: ExperienceType? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isPinned: Bool = false,
        isHidden: Bool = false,
        sourceThemeClusterID: UUID? = nil,
        links: [InsightEntryLink] = []
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.title = title
        self.normalizedTitle = normalizedTitle ?? InsightNode.normalize(title)
        self.statusRaw = status.rawValue
        self.confidence = confidence
        self.sourceRaw = source.rawValue
        self.experienceTypeRaw = experienceType?.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.isHidden = isHidden
        self.sourceThemeClusterID = sourceThemeClusterID
        self.linkStorage = links
    }

    func rename(to title: String) {
        self.title = title
        self.normalizedTitle = InsightNode.normalize(title)
        self.updatedAt = .now
    }

    func touch() {
        updatedAt = .now
    }

    static func normalize(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    static func identityKey(
        kind: InsightNodeKind,
        normalizedTitle: String,
        experienceType: ExperienceType?
    ) -> String {
        "\(kind.rawValue)|\(experienceType?.rawValue ?? "all")|\(normalizedTitle)"
    }
}

@Model
final class InsightEntryLink {
    var id: UUID = UUID()
    var entryID: UUID = UUID()
    var evidenceSnippet: String = ""
    var confidence: Double = 0
    var createdAt: Date = Date.now

    var insightNode: InsightNode?

    init(
        id: UUID = UUID(),
        entryID: UUID,
        evidenceSnippet: String,
        confidence: Double,
        createdAt: Date = .now,
        insightNode: InsightNode? = nil
    ) {
        self.id = id
        self.entryID = entryID
        self.evidenceSnippet = evidenceSnippet
        self.confidence = confidence
        self.createdAt = createdAt
        self.insightNode = insightNode
    }
}

@Model
final class InsightWorkspaceEntry {
    var id: UUID = UUID()
    var lensRaw: String = InsightLens.themes.rawValue
    var title: String = ""
    var promptKey: String?
    var body: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var isPinned: Bool = false
    var sourceEntryIDs: [UUID] = []
    var linkedInsightNode: InsightNode?
    var syncRevision: Int?
    var lastSyncedAt: Date?
    var lastConflictDetectedAt: Date?

    var lens: InsightLens {
        get { InsightLens(rawValue: lensRaw) ?? .themes }
        set { lensRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        lens: InsightLens,
        title: String,
        promptKey: String? = nil,
        body: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isPinned: Bool = false,
        sourceEntryIDs: [UUID] = [],
        linkedInsightNode: InsightNode? = nil
    ) {
        self.id = id
        self.lensRaw = lens.rawValue
        self.title = title
        self.promptKey = promptKey
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.sourceEntryIDs = sourceEntryIDs
        self.linkedInsightNode = linkedInsightNode
        self.syncRevision = 0
        self.lastSyncedAt = nil
        self.lastConflictDetectedAt = nil
    }

    func rename(to title: String) {
        self.title = title
        touch()
    }

    func touch() {
        updatedAt = .now
    }

    func applyEditorDraft(
        title: String,
        body: String,
        promptKey: String?,
        sourceEntryIDs: [UUID],
        linkedInsightNode: InsightNode? = nil,
        resolvingConflict: Bool = false,
        at date: Date = .now
    ) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        self.promptKey = promptKey
        self.sourceEntryIDs = sourceEntryIDs
        if let linkedInsightNode {
            self.linkedInsightNode = linkedInsightNode
        }
        updatedAt = date
        syncRevision = (syncRevision ?? 0) + 1
        if resolvingConflict {
            lastConflictDetectedAt = date
        }
    }
}

struct InsightWorkspaceEntrySyncConflict: Identifiable, Equatable {
    let id = UUID()
    let remoteModifiedAt: Date
    let remotePreview: String
}

struct InsightWorkspaceEntrySyncSnapshot: Equatable {
    let id: UUID
    let lensRaw: String
    let title: String
    let promptKey: String?
    let body: String
    let sourceEntryIDs: [UUID]
    let linkedInsightNodeID: UUID?
    let updatedAt: Date
    let syncRevision: Int

    init(entry: InsightWorkspaceEntry) {
        id = entry.id
        lensRaw = entry.lensRaw
        title = entry.title
        promptKey = entry.promptKey
        body = entry.body
        sourceEntryIDs = entry.sourceEntryIDs
        linkedInsightNodeID = entry.linkedInsightNode?.id
        updatedAt = entry.updatedAt
        syncRevision = entry.syncRevision ?? 0
    }

    var contentFingerprint: String {
        Self.contentFingerprint(
            lensRaw: lensRaw,
            title: title,
            promptKey: promptKey,
            body: body,
            sourceEntryIDs: sourceEntryIDs,
            linkedInsightNodeID: linkedInsightNodeID
        )
    }

    var changeToken: String {
        [
            id.uuidString,
            updatedAt.timeIntervalSinceReferenceDate.description,
            syncRevision.description,
            contentFingerprint
        ].joined(separator: "::")
    }

    func remoteConflictIfNeeded(
        openedSnapshot: InsightWorkspaceEntrySyncSnapshot,
        currentLocalFingerprint: String,
        observedUpdatedAt: Date?,
        observedSyncRevision: Int?
    ) -> InsightWorkspaceEntrySyncConflict? {
        guard id == openedSnapshot.id else { return nil }

        let localHasUnsavedEdits = currentLocalFingerprint != openedSnapshot.contentFingerprint
        guard localHasUnsavedEdits else { return nil }

        let observedRevision = observedSyncRevision ?? openedSnapshot.syncRevision
        let observedDate = observedUpdatedAt ?? openedSnapshot.updatedAt
        let isNewRemoteRevision = syncRevision > observedRevision
        let isNewRemoteDate = updatedAt > observedDate.addingTimeInterval(0.01)
        guard isNewRemoteRevision || isNewRemoteDate else { return nil }
        guard contentFingerprint != currentLocalFingerprint else { return nil }

        return InsightWorkspaceEntrySyncConflict(
            remoteModifiedAt: updatedAt,
            remotePreview: Self.previewText(from: body)
        )
    }

    static func contentFingerprint(
        lensRaw: String,
        title: String,
        promptKey: String?,
        body: String,
        sourceEntryIDs: [UUID],
        linkedInsightNodeID: UUID?
    ) -> String {
        [
            lensRaw,
            normalized(title),
            promptKey ?? "",
            normalized(body),
            sourceEntryIDs.map(\.uuidString).sorted().joined(separator: ","),
            linkedInsightNodeID?.uuidString ?? ""
        ].joined(separator: "\u{1F}")
    }

    static func previewText(from text: String) -> String {
        let trimmed = normalized(text)
        guard trimmed.count > 180 else { return trimmed }
        return "\(trimmed.prefix(180))..."
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct InsightPromptContext: Hashable {
    let lens: InsightLens
    let signalTitles: [String]
    let entryCount: Int

    var signalSummary: String {
        let trimmedSignals = signalTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if trimmedSignals.isEmpty {
            return "the reflections already in view"
        }

        if trimmedSignals.count == 1 {
            return trimmedSignals[0]
        }

        if trimmedSignals.count == 2 {
            return "\(trimmedSignals[0]) and \(trimmedSignals[1])"
        }

        return trimmedSignals.prefix(3).joined(separator: ", ")
    }
}

struct InsightPromptTemplate: Identifiable, Hashable {
    let lens: InsightLens
    let promptKey: String
    let title: String
    let promptTemplate: String
    let placeholder: String
    let suggestedTitleTemplate: String

    var id: String { promptKey }

    func resolvedPrompt(using context: InsightPromptContext) -> String {
        promptTemplate
            .replacingOccurrences(of: "{signals}", with: context.signalSummary)
            .replacingOccurrences(of: "{entryCount}", with: "\(context.entryCount)")
    }

    func suggestedTitle(using context: InsightPromptContext) -> String {
        suggestedTitleTemplate
            .replacingOccurrences(of: "{signals}", with: context.signalSummary)
    }
}

enum InsightPromptCatalog {
    static func templates(for lens: InsightLens) -> [InsightPromptTemplate] {
        switch lens {
        case .themes:
            return themeTemplates
        case .experiences:
            return experienceTemplates
        case .values:
            return valueTemplates
        case .why:
            return whyTemplates
        }
    }

    static func template(for promptKey: String?) -> InsightPromptTemplate? {
        guard let promptKey else { return nil }
        return all.first(where: { $0.promptKey == promptKey })
    }

    static func deterministicFallback(for lens: InsightLens, concept: String?) -> String {
        let defaultConcept = concept?.capitalized ?? "this pattern"
        switch lens {
        case .themes: return "\n\n— *What is the underlying cause driving \(defaultConcept)?*"
        case .experiences: return "\n\n— *What specific moment solidified your understanding of \(defaultConcept)?*"
        case .values: return "\n\n— *How does \(defaultConcept) align with your deepest convictions?*"
        case .why: return "\n\n— *Why does \(defaultConcept) matter to your overarching mission?*"
        }
    }

    private static let themeTemplates: [InsightPromptTemplate] = [
        InsightPromptTemplate(
            lens: .themes,
            promptKey: "themes.pattern",
            title: "What keeps repeating?",
            promptTemplate: "What keeps repeating across {signals}, and what does that pattern reveal about the way you move through your work?",
            placeholder: "Write about the pattern you keep noticing and why it matters.",
            suggestedTitleTemplate: "Pattern in {signals}"
        ),
        InsightPromptTemplate(
            lens: .themes,
            promptKey: "themes.tension",
            title: "Where is the tension?",
            promptTemplate: "Where do these reflections around {signals} hold tension, growth, or unfinished meaning that you do not want to lose?",
            placeholder: "Name the tension or contrast that still feels important.",
            suggestedTitleTemplate: "Tension inside {signals}"
        ),
        InsightPromptTemplate(
            lens: .themes,
            promptKey: "themes.change",
            title: "How are you changing?",
            promptTemplate: "How have the last {entryCount} reflection(s) connected to {signals} changed the way you see yourself or your work?",
            placeholder: "Describe what is shifting in you.",
            suggestedTitleTemplate: "How {signals} is changing me"
        )
    ]

    private static let experienceTemplates: [InsightPromptTemplate] = [
        InsightPromptTemplate(
            lens: .experiences,
            promptKey: "experiences.moment",
            title: "What happened here?",
            promptTemplate: "Looking at {signals}, what happened in these moments that still feels vivid, unresolved, or worth returning to before you draft?",
            placeholder: "Capture the concrete scene, interaction, or moment that still matters.",
            suggestedTitleTemplate: "Moment inside {signals}"
        ),
        InsightPromptTemplate(
            lens: .experiences,
            promptKey: "experiences.meaning",
            title: "Why does this matter?",
            promptTemplate: "Why do the experiences gathered around {signals} matter to you beyond the fact that they happened?",
            placeholder: "Write about the meaning you are making from these experiences.",
            suggestedTitleTemplate: "Why {signals} matters"
        ),
        InsightPromptTemplate(
            lens: .experiences,
            promptKey: "experiences.voice",
            title: "What would you want to say later?",
            promptTemplate: "If you returned to {signals} while drafting later, what would you want your future self to remember or name clearly?",
            placeholder: "Leave yourself a precise note for later drafting.",
            suggestedTitleTemplate: "What to remember from {signals}"
        )
    ]

    private static let valueTemplates: [InsightPromptTemplate] = [
        InsightPromptTemplate(
            lens: .values,
            promptKey: "values.costly",
            title: "Which value felt costly?",
            promptTemplate: "Among {signals}, which value felt costly, tested, or most real in practice, and what did that cost teach you?",
            placeholder: "Describe the value that was tested and what it demanded from you.",
            suggestedTitleTemplate: "Value tested in {signals}"
        ),
        InsightPromptTemplate(
            lens: .values,
            promptKey: "values-earned",
            title: "Which value was earned?",
            promptTemplate: "Which value inside {signals} feels earned rather than merely claimed, and what concrete evidence makes it feel true?",
            placeholder: "Ground the value in concrete details from your reflections.",
            suggestedTitleTemplate: "Evidence for {signals}"
        ),
        InsightPromptTemplate(
            lens: .values,
            promptKey: "values-future",
            title: "How should this guide you?",
            promptTemplate: "How should the values emerging from {signals} shape the way you want to show up in future work or service?",
            placeholder: "Write about how this value should guide you going forward.",
            suggestedTitleTemplate: "How {signals} should guide me"
        )
    ]

    private static let whyTemplates: [InsightPromptTemplate] = [
        InsightPromptTemplate(
            lens: .why,
            promptKey: "why-drawing-back",
            title: "What keeps drawing you back?",
            promptTemplate: "Looking at {signals}, what keeps drawing you back to this work, this kind of need, or this kind of person?",
            placeholder: "Write about what keeps returning and why it still matters.",
            suggestedTitleTemplate: "What keeps drawing me back"
        ),
        InsightPromptTemplate(
            lens: .why,
            promptKey: "why-calling",
            title: "When did this feel like a calling?",
            promptTemplate: "When did the reflections gathered around {signals} stop feeling like tasks and start feeling more like a calling, conviction, or responsibility?",
            placeholder: "Name the moment or realization that changed the meaning of this path.",
            suggestedTitleTemplate: "When this began to feel like a calling"
        ),
        InsightPromptTemplate(
            lens: .why,
            promptKey: "why-response",
            title: "What are you responding to?",
            promptTemplate: "What kind of suffering, need, or human reality do the reflections around {signals} make you feel responsible to respond to?",
            placeholder: "Describe the need or reality that you feel drawn to answer.",
            suggestedTitleTemplate: "What I feel called to respond to"
        ),
        InsightPromptTemplate(
            lens: .why,
            promptKey: "why-future-self",
            title: "What future self is emerging?",
            promptTemplate: "How are the last {entryCount} reflection(s), especially around {signals}, changing the kind of professional or person you believe you are becoming?",
            placeholder: "Write about the future self this path is asking of you.",
            suggestedTitleTemplate: "Who I am becoming"
        )
    ]

    private static let all: [InsightPromptTemplate] = themeTemplates + experienceTemplates + valueTemplates + whyTemplates
}

extension InsightWorkspaceEntry {
    var promptTemplate: InsightPromptTemplate? {
        InsightPromptCatalog.template(for: promptKey)
    }

    var draftSourceContent: String {
        draftSourceContent(linkedSourceEntries: [])
    }

    func draftSourceContent(linkedSourceEntries: [ExamenSession]) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let promptTitle = promptTemplate?.title

        var sections = ["Brainstorming (\(lens.title))"]

        if !trimmedTitle.isEmpty {
            sections.append(trimmedTitle)
        }

        if let promptTitle {
            sections.append("Prompt: \(promptTitle)")
        }

        if !trimmedBody.isEmpty {
            sections.append(trimmedBody)
        }

        let linkedExperiences = Self.uniqueLinkedExperiences(from: linkedSourceEntries)
        if !linkedExperiences.isEmpty {
            let heading = linkedExperiences.count == 1 ? "Linked Application Record" : "Linked Application Records"
            sections.append(([heading] + linkedExperiences.map(\.insightDraftContextSummary)).joined(separator: "\n\n"))
        }

        return sections.joined(separator: "\n\n")
    }

    private static func uniqueLinkedExperiences(from entries: [ExamenSession]) -> [ApplicationExperience] {
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
}

extension ApplicationExperience {
    var insightDraftContextSummary: String {
        var lines = [exportTitle, "Category: \(category.displayName)"]

        if let organization = organizationName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !organization.isEmpty {
            lines.append("Organization: \(organization)")
        }

        if let role = roleTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !role.isEmpty {
            lines.append("Role: \(role)")
        }

        if let location = location?.trimmingCharacters(in: .whitespacesAndNewlines),
           !location.isEmpty {
            lines.append("Location: \(location)")
        }

        let hours = periods.reduce(0) { $0 + max(0, $1.totalHours) }
        if hours > 0 {
            lines.append("Hours: \(hours.formatted(.number.precision(.fractionLength(0...1))))")
        }

        return lines.joined(separator: "\n")
    }
}

struct InsightTaxonomyTerm: Identifiable, Hashable {
    let id: String
    let title: String
    let keywords: [String]
    let supportedTrackRawValues: [String]
    let supportedDegreeIntentRawValues: [String]
    let emphasizedModeRawValues: [String]

    init(
        id: String,
        title: String,
        keywords: [String],
        supportedTrackRawValues: [String] = [],
        supportedDegreeIntentRawValues: [String] = [],
        emphasizedModeRawValues: [ExamenMode] = []
    ) {
        self.id = id
        self.title = title
        self.keywords = keywords
        self.supportedTrackRawValues = supportedTrackRawValues
        self.supportedDegreeIntentRawValues = supportedDegreeIntentRawValues
        self.emphasizedModeRawValues = emphasizedModeRawValues.map(\.rawValue)
    }

    func supports(track: PreProfessionalTrack?, degreeIntent: DegreeIntent) -> Bool {
        let trackMatches = supportedTrackRawValues.isEmpty || supportedTrackRawValues.contains {
            $0 == track?.rawValue || $0 == track?.canonical.rawValue
        }
        let degreeMatches = supportedDegreeIntentRawValues.isEmpty || supportedDegreeIntentRawValues.contains(degreeIntent.rawValue)
        return trackMatches && degreeMatches
    }

    func emphasizes(mode: ExamenMode) -> Bool {
        emphasizedModeRawValues.contains(mode.rawValue)
    }
}

enum ProfessionalValueTaxonomy {
    static let shared: [InsightTaxonomyTerm] = [
        InsightTaxonomyTerm(
            id: "service-empathy",
            title: "Empathy",
            keywords: ["listen", "presence", "patient", "comfort", "suffering", "compassion", "care", "accompany"]
        ),
        InsightTaxonomyTerm(
            id: "service-humility",
            title: "Humility",
            keywords: ["learn", "uncertain", "small", "receive", "teach", "correction", "curious"]
        ),
        InsightTaxonomyTerm(
            id: "service-resilience",
            title: "Resilience",
            keywords: ["persist", "difficult", "challenge", "fatigue", "return", "steady", "recover"]
        ),
        InsightTaxonomyTerm(
            id: "service-leadership",
            title: "Leadership",
            keywords: ["lead", "coordinate", "organize", "guide", "mentor", "delegate", "initiative"]
        ),
        InsightTaxonomyTerm(
            id: "service-integrity",
            title: "Integrity",
            keywords: ["honest", "truth", "accountable", "ethic", "responsibility", "trust", "integrity"]
        ),
        InsightTaxonomyTerm(
            id: "service-teamwork",
            title: "Teamwork",
            keywords: ["team", "collaborate", "together", "support", "handoff", "communicate"]
        ),
        InsightTaxonomyTerm(
            id: "medicine-clinical-curiosity",
            title: "Clinical Curiosity",
            keywords: ["diagnosis", "medicine", "physician", "symptom", "shadowing", "clinical", "patient", "observe"],
            supportedTrackRawValues: [PreProfessionalTrack.preMedicine.rawValue, PreProfessionalTrack.general.rawValue],
            supportedDegreeIntentRawValues: [DegreeIntent.md.rawValue, DegreeIntent.doDetail.rawValue]
        ),
        InsightTaxonomyTerm(
            id: "dentistry-manual-attention",
            title: "Attention to Detail",
            keywords: ["precision", "detail", "hands", "dexterity", "patient", "teeth", "procedure"],
            supportedTrackRawValues: [PreProfessionalTrack.preDentistry.rawValue, PreProfessionalTrack.general.rawValue]
        ),
        InsightTaxonomyTerm(
            id: "law-advocacy",
            title: "Advocacy",
            keywords: ["justice", "voice", "argue", "defend", "policy", "equity", "client"],
            supportedTrackRawValues: [PreProfessionalTrack.preLaw.rawValue, PreProfessionalTrack.general.rawValue]
        )
    ]
}

enum MotivationTaxonomy {
    static let shared: [InsightTaxonomyTerm] = [
        InsightTaxonomyTerm(
            id: "why-service",
            title: "Service",
            keywords: ["serve", "service", "others", "neighbor", "care", "need", "response"],
            emphasizedModeRawValues: [.spiritual, .vocation]
        ),
        InsightTaxonomyTerm(
            id: "why-calling",
            title: "Calling",
            keywords: ["call", "called", "calling", "vocation", "discern", "discernment", "path"],
            emphasizedModeRawValues: [.vocation, .spiritual]
        ),
        InsightTaxonomyTerm(
            id: "why-healing",
            title: "Healing",
            keywords: ["heal", "healing", "restore", "mercy", "suffering", "whole", "relief"],
            supportedTrackRawValues: [
                PreProfessionalTrack.preMedicine.rawValue,
                PreProfessionalTrack.preDentistry.rawValue,
                PreProfessionalTrack.prePharmacy.rawValue,
                PreProfessionalTrack.preOccupationalTherapy.rawValue,
                PreProfessionalTrack.prePhysicalTherapy.rawValue,
                PreProfessionalTrack.prePhysicianAssistant.rawValue,
                PreProfessionalTrack.preVeterinaryMedicine.rawValue,
                PreProfessionalTrack.preOptometry.rawValue,
                PreProfessionalTrack.general.rawValue
            ],
            emphasizedModeRawValues: [.vocation, .spiritual]
        ),
        InsightTaxonomyTerm(
            id: "why-accompaniment",
            title: "Accompaniment",
            keywords: ["accompany", "presence", "listen", "walk with", "companionship", "trust"],
            emphasizedModeRawValues: [.spiritual, .vocation]
        ),
        InsightTaxonomyTerm(
            id: "why-justice",
            title: "Justice",
            keywords: ["justice", "equity", "access", "system", "fair", "advocacy", "dignity"],
            supportedTrackRawValues: [PreProfessionalTrack.preLaw.rawValue, PreProfessionalTrack.general.rawValue]
        ),
        InsightTaxonomyTerm(
            id: "why-craft",
            title: "Craft",
            keywords: ["craft", "skill", "precision", "practice", "discipline", "mastery"],
            supportedTrackRawValues: [PreProfessionalTrack.preDentistry.rawValue, PreProfessionalTrack.general.rawValue]
        )
    ]
}
