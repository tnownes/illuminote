//
//  PromptPhase.swift
//  IlluminoteSceneDemo
//
//  Created by Tobias on 1/2/26.
//
enum ExamenPhase: Int, CaseIterable {
    case centering = 0       // Opening & Centering
    case reviewGratitude = 1 // Review the Day with Gratitude
    case emotions = 2        // Pay Attention to Your Emotions
    case featurePrayer = 3   // Choose a Feature & Pray from It
    case lookForward = 4     // Look Toward Tomorrow

    static func phase(forStage stage: String) -> Int {
        switch stage.lowercased() {
        // Phase 0: Opening & Centering
        case "opening", "first-principle":
            return ExamenPhase.centering.rawValue

        // Phase 1: Review the Day with Gratitude
        case "gratitude", "review":
            return ExamenPhase.reviewGratitude.rawValue

        // Phase 2: Pay Attention to Emotions (consolation + desolation)
        case "presence", "consolation", "desolation",
             "disquiet", "tension", "hesitation",
             "assumptions", "humanity", "contrition",
             "vocation-reflection":
            return ExamenPhase.emotions.rawValue

        // Phase 3: Choose a Feature & Pray from It
        case "discernment", "calling", "compassion",
             "empathy", "compassion-toward-self",
             "feature-prayer", "affirmation", "reflection":
            return ExamenPhase.featurePrayer.rawValue

        // Phase 4: Look Toward Tomorrow
        case "commitment", "memory":
            return ExamenPhase.lookForward.rawValue

        default:
            return ExamenPhase.centering.rawValue
        }
    }
}
