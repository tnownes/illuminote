//
//  PromptImporter.swift
//  IlluminoteSceneDemo
//
//  Updated by ChatGPT
//

import Foundation
import SwiftData

// Root of the JSON file
struct PromptRootImport: Decodable {
    let prompts: [PromptTemplateImport]
}

// Mirror of JSON prompt object
struct PromptTemplateImport: Decodable {
    let id: String
    let text: String
    let phase: Int
    let stage: String
    let depth: String
    let stepIndex: Int

    let experienceTypes: [String]?
    let professionTags: [String]?
    let intent: String?
    let tags: [String]?
}

struct PromptImportSummary: Equatable {
    var insertedCount = 0
    var updatedCount = 0
    var unchangedCount = 0
    var deletedStaleCount = 0
    var invalidIDCount = 0
    var duplicateIDCount = 0

    var importedCount: Int {
        insertedCount + updatedCount + unchangedCount
    }

    var didMutate: Bool {
        insertedCount > 0 || updatedCount > 0 || deletedStaleCount > 0
    }
}

struct PromptImporter {

    @MainActor
    static func importIfNeeded(context: ModelContext) {
        print("🔄 PromptImporter — Starting import process...")

        // 1. Locate the JSON file in bundle
        guard let url = Bundle.main.url(forResource: "prompts", withExtension: "json") else {
            print("❌ PromptImporter — prompts.json not found in bundle.")
            return
        }

        print("✓ Found prompts.json at: \(url.path)")

        do {
            let data = try Data(contentsOf: url)
            print("✓ Loaded \(data.count) bytes of JSON data")

            let decoder = JSONDecoder()
            let root = try decoder.decode(PromptRootImport.self, from: data)
            let imports = root.prompts

            print("✓ Decoded \(imports.count) prompts from JSON")

            let summary = try reconcile(imports, context: context)
            if summary.didMutate {
                print("💾 Saving prompt seed changes...")
                try context.save()
            } else {
                print("✓ Prompt seed data is already current.")
            }

            print("✅ PromptImporter — \(summary.insertedCount) inserted, \(summary.updatedCount) updated, \(summary.unchangedCount) unchanged, \(summary.deletedStaleCount) stale deleted")
            if summary.invalidIDCount > 0 || summary.duplicateIDCount > 0 {
                print("⚠️ PromptImporter — Skipped \(summary.invalidIDCount) invalid-id prompts and \(summary.duplicateIDCount) duplicate-id prompts")
            }
            if summary.importedCount == 0 {
                print("⚠️ PromptImporter — Imported zero prompts. Check prompts.json integrity.")
            }

        } catch {
            print("❌ PromptImporter — Error during import: \(error)")

            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("   Data corrupted: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("   Key '\(key.stringValue)' not found: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch for \(type): \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("   Value not found for \(type): \(context.debugDescription)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }
        }
    }

    @MainActor
    @discardableResult
    static func reconcile(
        _ imports: [PromptTemplateImport],
        context: ModelContext
    ) throws -> PromptImportSummary {
        var summary = PromptImportSummary()
        var seenIDs: Set<UUID> = []
        let existingPrompts = try context.fetch(FetchDescriptor<PromptTemplate>())
        let existingByID = Dictionary(uniqueKeysWithValues: existingPrompts.map { ($0.id, $0) })

        for importedPrompt in imports {
            guard let parsedID = UUID(uuidString: importedPrompt.id) else {
                summary.invalidIDCount += 1
                print("⚠️ PromptImporter — Skipping prompt with invalid UUID: \(importedPrompt.id)")
                continue
            }

            if !seenIDs.insert(parsedID).inserted {
                summary.duplicateIDCount += 1
                print("⚠️ PromptImporter — Skipping duplicate prompt id: \(parsedID.uuidString)")
                continue
            }

            if let existing = existingByID[parsedID] {
                if existing.apply(importedPrompt) {
                    summary.updatedCount += 1
                } else {
                    summary.unchangedCount += 1
                }
            } else {
                context.insert(importedPrompt.makeModel(id: parsedID))
                summary.insertedCount += 1
            }
        }

        for existing in existingPrompts where !seenIDs.contains(existing.id) {
            context.delete(existing)
            summary.deletedStaleCount += 1
        }

        return summary
    }
}

private extension PromptTemplateImport {
    func makeModel(id: UUID) -> PromptTemplate {
        PromptTemplate(
            id: id,
            text: text,
            phase: phase,
            stage: stage,
            depth: depth,
            stepIndex: stepIndex,
            experienceTypes: experienceTypes,
            professionTags: professionTags,
            tags: tags,
            intent: intent
        )
    }
}

private extension PromptTemplate {
    func apply(_ importedPrompt: PromptTemplateImport) -> Bool {
        var didChange = false

        update(&text, to: importedPrompt.text, didChange: &didChange)
        update(&phase, to: importedPrompt.phase, didChange: &didChange)
        update(&stage, to: importedPrompt.stage, didChange: &didChange)
        update(&depth, to: importedPrompt.depth, didChange: &didChange)
        update(&stepIndex, to: importedPrompt.stepIndex, didChange: &didChange)
        update(&experienceTypes, to: importedPrompt.experienceTypes, didChange: &didChange)
        update(&professionTags, to: importedPrompt.professionTags, didChange: &didChange)
        update(&tags, to: importedPrompt.tags, didChange: &didChange)
        update(&intent, to: importedPrompt.intent, didChange: &didChange)

        return didChange
    }

    private func update<Value: Equatable>(
        _ current: inout Value,
        to newValue: Value,
        didChange: inout Bool
    ) {
        guard current != newValue else { return }
        current = newValue
        didChange = true
    }
}
