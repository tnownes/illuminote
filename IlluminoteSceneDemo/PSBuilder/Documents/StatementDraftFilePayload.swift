import Foundation

/// Pure Codable payload that mirrors the draft at export time.
struct StatementDraftFilePayload: Codable {
    struct Section: Codable {
        let id: UUID
        let order: Int
        let source: SectionSource
        let content: String
        let date: Date
        let sourceID: UUID?
    }

    let id: UUID
    let title: String
    let version: Int
    let draftScopeRaw: String?
    let writingTargetID: String?
    let writingTargetCategoryRaw: String?
    let customPromptText: String?
    let isFinal: Bool
    let isLocked: Bool
    let dateCreated: Date
    let dateModified: Date
    let richTextData: Data?
    let sections: [Section]
}
