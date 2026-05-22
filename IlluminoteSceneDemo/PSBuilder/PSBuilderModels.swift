import Foundation
import SwiftData

@Model
final class StatementDraft {
    var id: UUID = UUID()
    var title: String = ""
    var version: Int = 1
    var draftScopeRaw: String?
    var writingTargetID: String?
    var writingTargetCategoryRaw: String?
    var customPromptText: String?
    var isFinal: Bool = false
    var isLocked: Bool = false
    @Relationship(deleteRule: .cascade, originalName: "sections", inverse: \StatementSection.draft) private var sectionStorage: [StatementSection]?
    var dateCreated: Date = Date.now
    var dateModified: Date = Date.now
    var richTextData: Data?
    var syncRevision: Int?
    var lastSyncedAt: Date?
    var lastConflictDetectedAt: Date?

    var sections: [StatementSection] {
        get { sectionStorage ?? [] }
        set { sectionStorage = newValue }
    }

    var draftScope: StatementDraftScope {
        get { StatementDraftScope(rawValue: draftScopeRaw ?? "") ?? .full }
        set { draftScopeRaw = newValue.rawValue }
    }

    var writingTargetCategory: WritingTargetCategory? {
        get {
            guard let writingTargetCategoryRaw else { return nil }
            return WritingTargetCategory(rawValue: writingTargetCategoryRaw)
        }
        set {
            writingTargetCategoryRaw = newValue?.rawValue
        }
    }

    init(
        title: String,
        version: Int = 1,
        richTextData: Data? = nil,
        draftScope: StatementDraftScope = .full,
        writingTargetID: String? = nil,
        writingTargetCategory: WritingTargetCategory? = nil,
        customPromptText: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.version = version
        self.draftScopeRaw = draftScope.rawValue
        self.writingTargetID = writingTargetID
        self.writingTargetCategoryRaw = writingTargetCategory?.rawValue
        self.customPromptText = customPromptText
        self.isFinal = false
        self.isLocked = false
        self.sectionStorage = []
        self.dateCreated = Date()
        self.dateModified = Date()
        self.richTextData = richTextData
        self.syncRevision = 0
        self.lastSyncedAt = nil
        self.lastConflictDetectedAt = nil
    }

    var isSnapshot: Bool {
        get { isFinal }
        set { isFinal = newValue }
    }

    func assignWritingTarget(_ target: WritingTargetDefinition) {
        writingTargetID = target.id
        writingTargetCategory = target.category
        if !target.allowsCustomPrompt {
            customPromptText = nil
        }
    }
}

@Model
final class StatementSection {
    var id: UUID = UUID()
    var order: Int = 0
    var source: SectionSource = SectionSource.manual
    var content: String = ""  // plain text or markdown
    var date: Date = Date.now
    
    // Optional reference to original source ID (e.g. ExamenSession.id) for tracing back
    var sourceID: UUID?
    var draft: StatementDraft?

    init(source: SectionSource, content: String, order: Int, sourceID: UUID? = nil) {
        self.id = UUID()
        self.source = source
        self.content = content
        self.order = order
        self.date = Date()
        self.sourceID = sourceID
        self.draft = nil
    }
}

enum SectionSource: String, Codable {
    case journalEntry
    case examenNote
    case insightWorkspace
    case manual

    var displayName: String {
        switch self {
        case .journalEntry:
            return "Journal"
        case .examenNote:
            return "Examen"
        case .insightWorkspace:
            return "Brainstorming"
        case .manual:
            return "Manual"
        }
    }
}

enum StatementDraftScope: String, Codable, CaseIterable, Identifiable {
    case full
    case opening
    case body
    case closing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .full: return "Full Draft"
        case .opening: return "Opening Paragraph"
        case .body: return "Body Paragraphs"
        case .closing: return "Closing Paragraph"
        }
    }

    var shortLabel: String {
        switch self {
        case .full: return "Full"
        case .opening: return "Opening"
        case .body: return "Body"
        case .closing: return "Closing"
        }
    }
}

extension StatementDraftScope {
    var asAdvisorGuidelineScope: AdvisorGuidelineScope {
        switch self {
        case .full: return .full
        case .opening: return .opening
        case .body: return .body
        case .closing: return .closing
        }
    }
}



extension StatementDraft {
    func toFilePayload() -> StatementDraftFilePayload {
        StatementDraftFilePayload(
            id: id,
            title: title,
            version: version,
            draftScopeRaw: draftScopeRaw,
            writingTargetID: writingTargetID,
            writingTargetCategoryRaw: writingTargetCategoryRaw,
            customPromptText: customPromptText,
            isFinal: isFinal,
            isLocked: isLocked,
            dateCreated: dateCreated,
            dateModified: dateModified,
            richTextData: richTextData,
            sections: sections
                .sorted { $0.order < $1.order }
                .map {
                    .init(
                        id: $0.id,
                        order: $0.order,
                        source: $0.source,
                        content: $0.content,
                        date: $0.date,
                        sourceID: $0.sourceID
                    )
                }
        )
    }
    
    static func fromPayload(
        _ payload: StatementDraftFilePayload,
        context: ModelContext,
        asCopy: Bool = true
    ) -> StatementDraft {
        let draft = StatementDraft(
            title: payload.title,
            version: payload.version,
            richTextData: payload.richTextData,
            draftScope: StatementDraftScope(rawValue: payload.draftScopeRaw ?? "") ?? .full
        )

        if !asCopy {
            draft.id = payload.id
        }

        draft.isFinal = payload.isFinal
        draft.isLocked = payload.isLocked
        draft.dateCreated = payload.dateCreated
        draft.dateModified = payload.dateModified
        draft.draftScopeRaw = payload.draftScopeRaw
        draft.writingTargetID = payload.writingTargetID
        draft.writingTargetCategoryRaw = payload.writingTargetCategoryRaw
        draft.customPromptText = payload.customPromptText

        // Note: We deliberately create new section objects (transplanting content)
        // rather than reusing IDs, consistent with 'copy' semantics suitable for import.
        payload.sections.sorted(by: { $0.order < $1.order }).forEach { sectionPayload in
             let section = StatementSection(
                source: sectionPayload.source,
                content: sectionPayload.content,
                order: sectionPayload.order,
                sourceID: sectionPayload.sourceID
            )
            draft.sections.append(section)
        }

        context.insert(draft)
        return draft
    }
}
