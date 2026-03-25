import SwiftUI
import UniformTypeIdentifiers

struct StatementDraftDocument: FileDocument {
    // Fallback to standard JSON if custom type fails
    static var readableContentTypes: [UTType] { [.illuminoteDraft, .json] }

    var payload: StatementDraftFilePayload

    init(payload: StatementDraftFilePayload) {
        self.payload = payload
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        payload = try JSONDecoder().decode(
            StatementDraftFilePayload.self,
            from: data
        )
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(payload)
        return FileWrapper(regularFileWithContents: data)
    }
}

extension UTType {
    static var illuminoteDraft: UTType {
        // Match the identifier in Info.plist
        UTType(exportedAs: "com.illuminote.draft", conformingTo: .json)
    }
}
