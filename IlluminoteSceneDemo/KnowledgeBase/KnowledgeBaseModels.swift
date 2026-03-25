import SwiftData
import Foundation

// MARK: - Field

@Model
final class StatementField {
    @Attribute(.unique) var id: String
    var name: String
    var fieldDescription: String
    
    // Valid SwiftData syntax: explicit inverse or just plain relation (many-to-many or one-to-many inferred)
    // If we want cascade delete from Field -> Service, we specify it here.
    // Assuming a Field "owns" its services for this knowledge base structure.
    @Relationship(deleteRule: .cascade)
    var services: [ApplicationService] = []
    
    // One-to-one relationship
    @Relationship(deleteRule: .cascade)
    var bestPractice: BestPractice?
    
    init(
        id: String,
        name: String,
        fieldDescription: String,
        services: [ApplicationService] = [],
        bestPractice: BestPractice? = nil
    ) {
        self.id = id
        self.name = name
        self.fieldDescription = fieldDescription
        self.services = services
        self.bestPractice = bestPractice
    }
}

// MARK: - Application Service

@Model
final class ApplicationService {
    @Attribute(.unique) var id: String
    var name: String
    
    @Relationship(deleteRule: .cascade)
    var cyclePrompts: [PromptCycle] = []
    
    @Relationship(inverse: \StatementField.services)
    var field: StatementField?
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Prompt Cycle

@Model
final class PromptCycle {
    @Attribute(.unique) var id: String
    var cycle: String
    var promptText: String
    var characterLimit: Int
    
    @Relationship(inverse: \ApplicationService.cyclePrompts)
    var service: ApplicationService?
    
    init(
        id: String,
        cycle: String,
        promptText: String,
        characterLimit: Int
    ) {
        self.id = id
        self.cycle = cycle
        self.promptText = promptText
        self.characterLimit = characterLimit
    }
}

// MARK: - Best Practice

@Model
final class BestPractice {
    @Attribute(.unique) var id: String
    var overview: String
    
    @Relationship(deleteRule: .cascade)
    var commonThemes: [PracticeTheme] = []
    
    @Relationship(deleteRule: .cascade)
    var toneGuidelines: ToneGuidelines?
    
    @Relationship(deleteRule: .cascade)
    var structure: StructureRecommendations?
    
    @Relationship(inverse: \StatementField.bestPractice)
    var field: StatementField?
    
    init(
        id: String,
        overview: String,
        toneGuidelines: ToneGuidelines? = nil,
        structure: StructureRecommendations? = nil
    ) {
        self.id = id
        self.overview = overview
        self.toneGuidelines = toneGuidelines
        self.structure = structure
    }
}

// MARK: - Practice Theme

@Model
final class PracticeTheme {
    @Attribute(.unique) var id: String
    var title: String
    var themeDescription: String
    
    @Relationship(inverse: \BestPractice.commonThemes)
    var bestPractice: BestPractice?
    
    init(id: String, title: String, themeDescription: String) {
        self.id = id
        self.title = title
        self.themeDescription = themeDescription
    }
}

// MARK: - Tone Guidelines

@Model
final class ToneGuidelines {
    @Attribute(.unique) var id: String
    var recommendedTone: String
    var avoidList: [String]
    
    @Relationship(inverse: \BestPractice.toneGuidelines)
    var bestPractice: BestPractice?
    
    init(id: String, recommendedTone: String, avoidList: [String]) {
        self.id = id
        self.recommendedTone = recommendedTone
        self.avoidList = avoidList
    }
}

// MARK: - Structure Recommendations

@Model
final class StructureRecommendations {
    @Attribute(.unique) var id: String
    var introduction: String
    var body: String
    var conclusion: String
    
    @Relationship(inverse: \BestPractice.structure)
    var bestPractice: BestPractice?
    
    init(id: String, introduction: String, body: String, conclusion: String) {
        self.id = id
        self.introduction = introduction
        self.body = body
        self.conclusion = conclusion
    }
}

