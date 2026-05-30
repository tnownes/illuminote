import Foundation
import SwiftData
import SwiftUI

enum ExamenStage: Hashable {
    case selectType
    case prayerfulPosture
    case promptPhase
    case finalReflection
    case details
    case summary
    case done
}

@MainActor
@Observable
final class ExamenSessionViewModel {

    // MARK: - State

    var stage: ExamenStage = .selectType
    var draft: ExamenSessionDraft

    // Flattened list of all selected prompts
    var prompts: [PromptTemplate] = []

    // Phase navigation
    var currentPhase: Int = 0
    var phasePromptIndex: Int = 0

    // Answers stored by Prompt UUID so it stays stable
    private var answersByPromptID: [UUID: String] = [:]
    private(set) var lastSavedSessionID: UUID?
    private(set) var lastApplicationRecordOutcomeText: String?

    // MARK: - Computed Helpers

    var phases: [Int] {
        Array(Set(prompts.map { $0.phase })).sorted()
    }

    var currentPhasePrompts: [PromptTemplate] {
        let phasePrompts = prompts.filter { $0.phase == currentPhase }
        if currentPhase == 0 {
            return phasePrompts.sorted { lhs, rhs in
                let lhsIsFirstPrinciple = lhs.stage.lowercased() == "first-principle"
                let rhsIsFirstPrinciple = rhs.stage.lowercased() == "first-principle"
                if lhsIsFirstPrinciple != rhsIsFirstPrinciple {
                    return lhsIsFirstPrinciple && !rhsIsFirstPrinciple
                }
                if lhs.stepIndex != rhs.stepIndex {
                    return lhs.stepIndex < rhs.stepIndex
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }

        return phasePrompts.sorted { $0.stepIndex < $1.stepIndex }
    }

    var currentPrompt: PromptTemplate? {
        guard !currentPhasePrompts.isEmpty,
              phasePromptIndex < currentPhasePrompts.count
        else { return nil }
        return currentPhasePrompts[phasePromptIndex]
    }

    var longestPromptText: String {
        prompts.max(by: { $0.text.count < $1.text.count })?.text ?? ""
    }

    var isLastPromptInPhase: Bool {
        guard currentPhasePrompts.indices.contains(phasePromptIndex) else { return false }
        return phasePromptIndex + 1 == currentPhasePrompts.count
    }

    var isLastPhase: Bool {
        guard let last = phases.last else { return false }
        return currentPhase == last
    }

    // MARK: - Init

    init(draft: ExamenSessionDraft = ExamenSessionDraft(type: .other),
         initialStage: ExamenStage = .selectType) {
        self.draft = draft
        self.stage = initialStage
        self.answersByPromptID = draft.answersByPromptID
    }

    // MARK: - Navigation / Actions

    func selectType(_ type: ExperienceType) {
        draft.type = type
    }

    func setPrompts(_ newPrompts: [PromptTemplate]) {
        self.prompts = newPrompts
        currentPhase = phases.first ?? 0
        phasePromptIndex = 0
    }

    func recordActiveMode(_ mode: ExamenMode) {
        draft.examenMode = mode
    }
    
    // MARK: - Phase 2: AI Enhancement
    func enhancePromptsWithAI(experienceType: String, profession: String, aiEnabled: Bool) async {
        guard aiEnabled else { return }
        guard AIPromptService.shared.isAvailable else { return }
        
        do {
            // Generate a targeted question for the 'reflection' phase (typically phase 2 or 3)
            let targetPhase = 2
            let stageName = "reflection"
            
            let newPrompt = try await AIPromptService.shared.generatePrompt(
                for: stageName,
                phase: targetPhase,
                experienceType: experienceType,
                profession: profession,
                previousAnswers: [] // No answers yet at start of session
            )
            
            // Insert into our prompt list
            // We want to add it to the correct phase grouping
            self.prompts.append(newPrompt)
            
            // Re-sort prompts to ensure they appear in correct step order
            // (Assuming stepIndex 0 for new prompt, we might colliding indices, but sort handles it stably usually)
            // Ideally we'd set stepIndex = count + 1 for that phase.
            // For MVP: simple append and stable sort by phase then stepIndex.
            
            self.prompts.sort {
                if $0.phase != $1.phase { return $0.phase < $1.phase }
                return $0.stepIndex < $1.stepIndex
            }
            
            print("✨ AI Prompt generated and added for \(stageName).")
            
        } catch {
            print("⚠️ AI Generation failed: \(error)")
        }
    }

    func advanceFromType() {
        stage = .prayerfulPosture
    }

    func advanceFromPosture() {
        stage = prompts.isEmpty ? .details : .promptPhase
    }

    func goToPhase(_ index: Int) {
        // Validation
        guard index >= 0 && index < phases.count else { return }
        
        // update current phase
        currentPhase = phases[index]
        
        // reset prompt index within phase
        phasePromptIndex = 0
        
        // Cancel timer
        invalidatePromptTimer()
    }
    
    func goToPromptWithinPhase(_ index: Int) {
        guard index >= 0 && index < currentPhasePrompts.count else { return }
        phasePromptIndex = index
        invalidatePromptTimer() // Pause/Reset timer on manual interaction
    }

    /// Tap Continue logic
    func continueTapped(answer: String, usesSeparateFinalReflection: Bool = false) {
        // Save answer
        if let prompt = currentPrompt {
            answersByPromptID[prompt.id] = answer
        }
        
        invalidatePromptTimer()
        
        // if there are more prompts in current phase
        if phasePromptIndex + 1 < currentPhasePrompts.count {
            phasePromptIndex += 1
        }
        // else move to next phase
        else if let idx = phases.firstIndex(of: currentPhase), idx + 1 < phases.count {
            currentPhase = phases[idx + 1]
            phasePromptIndex = 0
        }
        // else show details/summary
        else {
            stage = usesSeparateFinalReflection ? .finalReflection : .details
        }
    }

    // Alias for compatibility
    func advanceFromPrompt(answer: String) {
        continueTapped(answer: answer)
    }

    func continueFromFinalReflection(answer: String) {
        draft.personalStatement = answer
        invalidatePromptTimer()
        stage = .details
    }

    func goBackWithinPhase() {
        invalidatePromptTimer()

        if phasePromptIndex > 0 {
            phasePromptIndex -= 1
        } else if let idx = phases.firstIndex(of: currentPhase), idx > 0 {
            let prevPhase = phases[idx - 1]
            currentPhase = prevPhase
            phasePromptIndex = currentPhasePrompts.count - 1
        }
    }

    func advanceFromDetails(finalDraft: ExamenSessionDraft) {
        self.draft = finalDraft
        self.draft.answersByPromptID = answersByPromptID
        stage = .summary
    }

    func finishSession() {
        stage = .done
        lastApplicationRecordOutcomeText = nil
    }

    func answerForCurrentPrompt() -> String {
        guard let prompt = currentPrompt else { return "" }
        return answersByPromptID[prompt.id] ?? ""
    }


    // MARK: - Timed Prompt & Audio Support

    private(set) var timerProgress: CGFloat = 0
    private weak var promptTimer: Timer?

    // Timer pause control
    var timerPaused: Bool = false

    func startPromptTimer(duration: TimeInterval = AnimationConfig.examenReflectiveHoldDuration,
                          startsPaused: Bool = false) {
        invalidatePromptTimer()
        timerProgress = 0
        timerPaused = startsPaused

        promptTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                guard !self.timerPaused else { return }

                self.timerProgress += CGFloat(0.1 / duration)
                if self.timerProgress >= 1.0 {
                    timer.invalidate()
                    self.promptTimer = nil
                    self.advanceFromPromptAutomatically()
                }
            }
        }
    }

    func toggleTimerPause() {
        timerPaused.toggle()
    }

    func cancelPromptTimer(resetProgress: Bool = true) {
        invalidatePromptTimer(resetProgress: resetProgress)
    }

    private func invalidatePromptTimer(resetProgress: Bool = true) {
        promptTimer?.invalidate()
        promptTimer = nil
        if resetProgress {
            timerProgress = 0
        }
    }

    private func advanceFromPromptAutomatically() {
        let currentAns = answerForCurrentPrompt()
        advanceFromPrompt(answer: currentAns)
    }

    // MARK: - Persistence
    
    func saveSession(context: ModelContext) {
        lastApplicationRecordOutcomeText = nil
        let linkedExperience = resolveApplicationExperience(in: context)

        // 1. Create the persistent session object
        let newSession = ExamenSession(
            sessionType: .daily,
            date: draft.date,
            examenMode: draft.examenMode,
            personalStatement: draft.personalStatement,
            experienceType: draft.type,
            physician: draft.physician?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : draft.physician,
            facility: draft.facility?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : draft.facility,
            specialty: draft.specialty?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : draft.specialty,
            location: draft.location?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : draft.location,
            mentorOrSupervisor: draft.mentorOrSupervisor?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : draft.mentorOrSupervisor,
            roleTitle: draft.roleTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : draft.roleTitle,
            organizationName: draft.organizationName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : draft.organizationName,
            focusArea: draft.focusArea?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : draft.focusArea,
            notes: draft.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : draft.notes,
            tags: draft.tags.filter { !$0.isEmpty },
            applicationExperience: linkedExperience,
            isFavorite: false,
            hours: draft.hours
        )
        
        // 2. Iterate through all prompts that were presented
        // use 'prompts' array which contains the ordered templates
        for prompt in prompts {
            // Check if we have an answer
            if let answerText = answersByPromptID[prompt.id], !answerText.isEmpty {
                // Create StepResponse
                let response = StepResponse(
                    stepIndex: prompt.stepIndex,
                    answerText: answerText,
                    session: newSession,
                    promptID: prompt.id,
                    stage: prompt.stage
                )
                newSession.responses.append(response)
            }
        }
        
        // 3. Insert and Save
        context.insert(newSession)
        
        do {
            try context.save()
            lastSavedSessionID = newSession.id
            print("✅ Examen Session Saved Successfully: \(newSession.id)")
        } catch {
            lastSavedSessionID = nil
            print("❌ Failed to save Examen Session: \(error)")
        }
    }

    private func resolveApplicationExperience(in context: ModelContext) -> ApplicationExperience? {
        if let linkedID = draft.linkedApplicationExperienceID {
            let descriptor = FetchDescriptor<ApplicationExperience>(
                predicate: #Predicate { experience in
                    experience.id == linkedID
                }
            )

            if let existing = try? context.fetch(descriptor).first {
                existing.touch()
                lastApplicationRecordOutcomeText = "Connected Application Record: \(existing.exportTitle)"
                return existing
            }
        }

        if let pending = draft.pendingApplicationExperience {
            let experience = pending.buildModel()
            context.insert(experience)
            lastApplicationRecordOutcomeText = "Created Application Record: \(experience.exportTitle)"
            return experience
        }

        return nil
    }
}
