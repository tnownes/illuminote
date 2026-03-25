import Foundation
import SwiftData

@Model
final class StatementDraft {
    @Attribute(.unique) var id: UUID
    var title: String
    var version: Int
    var draftScopeRaw: String?
    var isFinal: Bool
    var isLocked: Bool
    @Relationship(deleteRule: .cascade) var sections: [StatementSection]
    var dateCreated: Date
    var dateModified: Date
    var richTextData: Data?

    var draftScope: StatementDraftScope {
        get { StatementDraftScope(rawValue: draftScopeRaw ?? "") ?? .full }
        set { draftScopeRaw = newValue.rawValue }
    }

    init(
        title: String,
        version: Int = 1,
        richTextData: Data? = nil,
        draftScope: StatementDraftScope = .full
    ) {
        self.id = UUID()
        self.title = title
        self.version = version
        self.draftScopeRaw = draftScope.rawValue
        self.isFinal = false
        self.isLocked = false
        self.sections = []
        self.dateCreated = Date()
        self.dateModified = Date()
        self.richTextData = richTextData
    }
}

@Model
final class StatementSection {
    @Attribute(.unique) var id: UUID
    var order: Int
    var source: SectionSource
    var content: String  // plain text or markdown
    var date: Date
    
    // Optional reference to original source ID (e.g. ExamenSession.id) for tracing back
    var sourceID: UUID?

    init(source: SectionSource, content: String, order: Int, sourceID: UUID? = nil) {
        self.id = UUID()
        self.source = source
        self.content = content
        self.order = order
        self.date = Date()
        self.sourceID = sourceID
    }
}

enum SectionSource: String, Codable {
    case journalEntry
    case examenNote
    case manual
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
