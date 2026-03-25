import SwiftData
import Foundation

/// Loads the bundled JSON seed and inserts into SwiftData
@MainActor
func importKnowledgeBaseSeed(to context: ModelContext) async throws {
    // 1. Locate the JSON in the bundle
    guard let url = Bundle.main.url(forResource: "KnowledgeBaseSeed", withExtension: "json") else {
        print("KnowledgeBaseSeed.json not found in bundle")
        return
    }
    
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    let seedRoot = try decoder.decode(SeedRoot.self, from: data)

    // 1b. Skip if already seeded (prevents duplicates on subsequent launches)
    let descriptor = FetchDescriptor<StatementField>()
    let existingCount = (try? context.fetchCount(descriptor)) ?? 0
    if existingCount > 0 {
        print("🧠 Knowledge Base already seeded (\(existingCount) fields). Skipping.")
        return
    }

    // 2. Insert into SwiftData
    for fieldSeed in seedRoot.fields {
        let field = StatementField(
            id: fieldSeed.id,
            name: fieldSeed.name,
            fieldDescription: fieldSeed.fieldDescription
        )
        context.insert(field) // Insert parent first

        // Insert services & prompts
        for serviceSeed in fieldSeed.services {
            let service = ApplicationService(id: serviceSeed.id, name: serviceSeed.name)
            // Manual relationship setting
            service.field = field
            field.services.append(service)
            
            for promptSeed in serviceSeed.cyclePrompts {
                let prompt = PromptCycle(
                    id: promptSeed.id,
                    cycle: promptSeed.cycle,
                    promptText: promptSeed.promptText,
                    characterLimit: promptSeed.characterLimit
                )
                prompt.service = service
                service.cyclePrompts.append(prompt)
            }
        }

        // Best practice
        if let bpSeed = fieldSeed.bestPractice {
            let tone = ToneGuidelines(
                id: bpSeed.toneGuidelines.id,
                recommendedTone: bpSeed.toneGuidelines.recommendedTone,
                avoidList: bpSeed.toneGuidelines.avoidList
            )
            
            let structRec = StructureRecommendations(
                id: bpSeed.structure.id,
                introduction: bpSeed.structure.introduction,
                body: bpSeed.structure.body,
                conclusion: bpSeed.structure.conclusion
            )
            
            let bestPractice = BestPractice(
                id: bpSeed.id,
                overview: bpSeed.overview,
                toneGuidelines: tone,
                structure: structRec
            )
            
            // Set relationships
            bestPractice.field = field
            field.bestPractice = bestPractice
            
            tone.bestPractice = bestPractice
            structRec.bestPractice = bestPractice

            // Themes
            for themeSeed in bpSeed.commonThemes {
                let theme = PracticeTheme(
                    id: themeSeed.id,
                    title: themeSeed.title,
                    themeDescription: themeSeed.themeDescription
                )
                theme.bestPractice = bestPractice
                bestPractice.commonThemes.append(theme)
            }
        }
    }

    try context.save()
    print("🧠 Knowledge Base Seed Imported")
}

// MARK: - Intermediate Codable Structs
// These match the structure of KnowledgeBaseSeed.json exactly.

struct SeedRoot: Codable {
    let fields: [FieldSeed]
}

struct FieldSeed: Codable {
    let id: String
    let name: String
    let fieldDescription: String
    let services: [ServiceSeed]
    let bestPractice: BestPracticeSeed?
}

struct ServiceSeed: Codable {
    let id: String
    let name: String
    let cyclePrompts: [CyclePromptSeed]
}

struct CyclePromptSeed: Codable {
    let id: String
    let cycle: String
    let promptText: String
    let characterLimit: Int
}

struct BestPracticeSeed: Codable {
    let id: String
    let overview: String
    let commonThemes: [ThemeSeed]
    let toneGuidelines: ToneGuidelinesSeed
    let structure: StructureSeed
}

struct ThemeSeed: Codable {
    let id: String
    let title: String
    let themeDescription: String
}

struct ToneGuidelinesSeed: Codable {
    let id: String
    let recommendedTone: String
    let avoidList: [String]
}

struct StructureSeed: Codable {
    let id: String
    let introduction: String
    let body: String
    let conclusion: String
}
