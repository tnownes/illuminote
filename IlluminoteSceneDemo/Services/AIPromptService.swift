//
//  AIPromptService.swift
//  IlluminoteSceneDemo
//
//  Created for Phase 2: On-Device AI Generation
//

import Foundation
import SwiftData

// -----------------------------------------------------------------------------
// MARK: - AI Stubs to suppress compile errors
// -----------------------------------------------------------------------------

// We stub these types so this file always compiles even if on-device AI APIs
// aren’t available in this SDK. We do *not* rely on any unavailable frameworks.

struct TextGenerationRequest {
    let prompt: String
    let maxTokens: Int
}

struct TextGenerationResponse {
    let generatedText: String
}

class SystemTextGenerator {
    init() throws {}
    
    func generate(request: TextGenerationRequest) async throws -> TextGenerationResponse {
        // SIMULATION DELAY
        try await Task.sleep(nanoseconds: 1 * 1_000_000_000) // 1 second
        
        // Return context-aware mock response
        let p = request.prompt.lowercased()
        
        if p.contains("standard") {
            return TextGenerationResponse(generatedText: "What is a simple joy you noticed today?")
        } else if p.contains("shadowing") {
            return TextGenerationResponse(generatedText: "Recall a moment when the physician's actions surprised you. What did this reveal about their vocational drive?")
        } else if p.contains("clinical") {
            return TextGenerationResponse(generatedText: "Consider a patient interaction where you felt helpless. How did you navigate that feeling?")
        } else {
            return TextGenerationResponse(generatedText: "Reflect on a moment where your expectations were challenged today.")
        }
    }
}


// -----------------------------------------------------------------------------
// MARK: - AIPromptService
// -----------------------------------------------------------------------------

enum AIPromptError: Error {
    case unavailable
    case generationFailed
}

@MainActor
class AIPromptService {
    static let shared = AIPromptService()
    
    private init() {}
    
    /// Checks if the device supports on-device generative AI
    var isAvailable: Bool {
        guard AppSettings.aiFeaturesAllowedInThisBuild else {
            return false
        }

        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
    
    /// Generates a new prompt based on the user's current context
    func generatePrompt(
        for stage: String,
        phase: Int,
        experienceType: String,
        profession: String,
        previousAnswers: [String]
    ) async throws -> PromptTemplate {
        guard isAvailable else {
            throw AIPromptError.unavailable
        }
        
        // 1. Construct Context
        let context = """
        Generate a reflective question for a student in the \(profession) track having a \(experienceType) experience.
        Stage: \(stage) (Phase \(phase)).
        Context so far: \(previousAnswers.joined(separator: "; ")).
        """
        
        // 2. Call Model
        let generatedText: String
        
        if #available(iOS 26.0, *) {
            // Real API Call (Hypothetical Syntax)
            // #if canImport(FoundationModels)
            // let model = try SystemTextGenerator()
            // let req = TextGenerationRequest(prompt: context, maxTokens: 60)
            // let res = try await model.generate(request: req)
            // generatedText = res.generatedText
            // #else
            let model = try SystemTextGenerator() // Uses our sim struct above
            let req = TextGenerationRequest(prompt: context, maxTokens: 60)
            let res = try await model.generate(request: req)
            generatedText = res.generatedText
            // #endif
        } else {
            // Simulation logic for older iOS versions (Demo Mode)
            let model = try SystemTextGenerator()
            let req = TextGenerationRequest(prompt: context, maxTokens: 60)
            let res = try await model.generate(request: req)
            generatedText = res.generatedText
        }
        
        // 3. Wrap in Template
        return PromptTemplate(
            id: UUID(),
            text: generatedText,
            phase: phase,
            stage: stage,
            depth: "deep", // AI prompts are inherently 'deep'
            stepIndex: 0,
            experienceTypes: [experienceType],
            professionTags: [profession],
            tags: ["ai-generated", stage],
            intent: "dynamic-reflection"
        )
    }
}
