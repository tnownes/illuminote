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

            // 2. Clear existing prompts (dev mode)
            print("🗑️ Clearing existing prompts...")
            try? context.delete(model: PromptTemplate.self)

            var importedCount = 0
            var invalidIDCount = 0
            var duplicateIDCount = 0
            var seenIDs: Set<UUID> = []

            for imp in imports {
                guard let parsedID = UUID(uuidString: imp.id) else {
                    invalidIDCount += 1
                    print("⚠️ PromptImporter — Skipping prompt with invalid UUID: \(imp.id)")
                    continue
                }

                if seenIDs.contains(parsedID) {
                    duplicateIDCount += 1
                    print("⚠️ PromptImporter — Skipping duplicate prompt id: \(parsedID.uuidString)")
                    continue
                }
                seenIDs.insert(parsedID)

                // Create new model
                let p = PromptTemplate(
                    id: parsedID,
                    text: imp.text,
                    phase: imp.phase,
                    stage: imp.stage,
                    depth: imp.depth,
                    stepIndex: imp.stepIndex,
                    experienceTypes: imp.experienceTypes,
                    professionTags: imp.professionTags,
                    tags: imp.tags,
                    intent: imp.intent
                )

                context.insert(p)
                importedCount += 1
            }

            print("💾 Saving \(importedCount) prompts to database...")
            try context.save()
            print("✅ PromptImporter — Successfully imported \(importedCount) prompts")
            if invalidIDCount > 0 || duplicateIDCount > 0 {
                print("⚠️ PromptImporter — Skipped \(invalidIDCount) invalid-id prompts and \(duplicateIDCount) duplicate-id prompts")
            }
            if importedCount == 0 {
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
}
