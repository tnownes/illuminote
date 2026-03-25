import Foundation
import SwiftData

struct PromptSeeder {

    @MainActor
    static func seed(context: ModelContext) {
        let descriptor = FetchDescriptor<PromptTemplate>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0

        guard existingCount == 0 else {
            print("Prompts already seeded.")
            return
        }

        print("Seeding default prompts...")

        let seedData: [(String, String, String, Int, [String]?, [String]?, String?)] = [
            ("What are you grateful for today?", "gratitude", "standard", 0, nil, nil, nil),
            ("Where did you feel a sense of presence?", "presence", "standard", 1, nil, nil, nil),
            ("What challenged you today?", "challenge", "standard", 2, nil, nil, nil),
            ("What surprised you about the professional's day-to-day life?", "opening", "standard", 0, ["shadowing"], nil, nil),
            ("How did the professional handle stress or uncertainty?", "disquiet", "standard", 1, ["shadowing"], nil, nil),
            ("Who did you serve today, and what did you learn from them?", "presence", "standard", 0, ["service"], nil, nil),
            ("How did this experience challenge your assumptions about community needs?", "assumptions", "standard", 1, ["service"], nil, nil),
            ("Describe a patient interaction that moved you today.", "opening", "standard", 0, ["clinical"], ["preMedicine"], nil),
            ("How did you see empathy practiced in the clinical setting?", "empathy", "standard", 1, ["clinical"], ["preMedicine"], nil)
        ]

        for item in seedData {
            let (text, stage, depth, stepIndex, expTypes, profTags, intent) = item

            let phaseIndex = ExamenPhase.phase(forStage: stage)

            let template = PromptTemplate(
                id: UUID(),
                text: text,
                phase: phaseIndex,
                stage: stage,
                depth: depth,
                stepIndex: stepIndex,
                experienceTypes: expTypes,
                professionTags: profTags,
                tags: nil,
                intent: intent
            )

            context.insert(template)
        }

        try? context.save()
        print("Seeding complete.")
    }
}
