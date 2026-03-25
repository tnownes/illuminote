import SwiftUI
import SwiftData

struct ExamenSessionContainer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    // Data Queries for prompt fetching
    @Query private var promptTemplates: [PromptTemplate]
    @Query(sort: \UserProfile.id) private var profiles: [UserProfile]
    @Query private var allSessions: [ExamenSession]
    
    // State
    @State private var vm: ExamenSessionViewModel
    @State private var showExitAlert = false
    @StateObject private var speechManager = SpeechRecognitionManager()
    @StateObject private var promptSpeechManager = PromptSpeechManager()
    @State private var isPromptSpeechEnabled = false
    @State private var reflectiveHoldTask: Task<Void, Never>?
    
    private var headerState: ExamenHeaderState? {
        guard vm.stage == .promptPhase else { return nil }
        return ExamenHeaderState(
            phase: vm.currentPhase,
            totalPhases: vm.phases.count,
            currentPromptIndex: vm.phasePromptIndex,
            promptCount: vm.currentPhasePrompts.count,
            timerProgress: vm.timerProgress
        )
    }

    private var currentPromptIdentity: UUID? {
        guard vm.stage == .promptPhase else { return nil }
        return vm.currentPrompt?.id
    }

    private var canGoBackWithinFlow: Bool {
        guard let firstPhase = vm.phases.first else { return false }
        return vm.phasePromptIndex > 0 || vm.currentPhase != firstPhase
    }
    
    // Init with optional starting point (e.g. for "New Note" shortcut)
    init(draft: ExamenSessionDraft = ExamenSessionDraft(type: .other),
         initialStage: ExamenStage = .selectType) {
        _vm = State(initialValue: ExamenSessionViewModel(draft: draft, initialStage: initialStage))
    }
    
    var body: some View {
        ZStack {
            // Shared Background
            settings.selectedTheme.anySceneView
                .ignoresSafeArea()
            
            // Content Switcher
            content
                .transition(.opacity)
        }
        // Inject shared SpeechRecognitionManager for all child views
        .environmentObject(speechManager)
        .environmentObject(promptSpeechManager)
        // Global Session Configuration
        .onAppear {
            settings.isTabBarVisible = false
            isPromptSpeechEnabled = settings.readPromptsAloudEnabled
            // Request speech permissions once per session
            Task {
                try? await speechManager.requestPermissions()
            }
            promptSpeechManager.onUtteranceFinished = { finishedPromptID in
                guard isPromptSpeechEnabled else { return }
                guard vm.stage == .promptPhase else { return }
                guard !vm.isLastPromptInPhase else { return }
                guard let currentPrompt = vm.currentPrompt else { return }
                guard finishedPromptID == currentPrompt.id else { return }
                scheduleReflectiveHoldStart(for: currentPrompt.id, delay: 0)
            }
        }
        .onDisappear {
            settings.isTabBarVisible = true
            reflectiveHoldTask?.cancel()
            reflectiveHoldTask = nil
            promptSpeechManager.stop()
            promptSpeechManager.onUtteranceFinished = nil
            vm.cancelPromptTimer()
        }
        // Handle "Done" state by dismissing
        .onChange(of: vm.stage) { _, newStage in
            if newStage != .promptPhase {
                reflectiveHoldTask?.cancel()
                reflectiveHoldTask = nil
                promptSpeechManager.stop()
                vm.cancelPromptTimer()
            }
            if newStage == .done {
                dismiss()
            }
        }
        .task(id: currentPromptIdentity) {
            guard currentPromptIdentity != nil else { return }
            coordinatePromptReadAndTimer()
        }
        .alert("Are you sure you want to Exit?", isPresented: $showExitAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Exit", role: .destructive) {
                promptSpeechManager.stop()
                dismiss()
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch vm.stage {
        
        case .selectType:
            ExperienceTypeSelectionView(
                onSelect: { type in
                    vm.selectType(type)
                    let templates = fetchPrompts(for: type)

                    if templates.isEmpty {
                        let fallback = defaultQuestions.map { text in
                            PromptTemplate(
                                id: UUID(),
                                text: text,
                                phase: 0,
                                stage: "fallback",
                                depth: "standard",
                                stepIndex: 0,
                                experienceTypes: nil,
                                professionTags: nil,
                                tags: nil,
                                intent: "fallback"
                            )
                        }
                        vm.setPrompts(fallback)
                    } else {
                        vm.setPrompts(templates)
                        updateRecentPromptHistory(with: templates)
                    }

                    // Examen AI generation is intentionally disabled for now.
                    withAnimation(AnimationConfig.examenPostureHandoff) {
                        vm.advanceFromType()
                    }
                },
                onCancel: {
                    withAnimation(AnimationConfig.transitionOut) {
                        dismiss()
                    }
                }
            )
            .transition(.opacity)

        case .prayerfulPosture:
            PrayerPostureView(
                onConfirm: {
                    withAnimation(AnimationConfig.examenPostureHandoff) {
                        vm.advanceFromPosture()
                    }
                }
            )
            .transition(.opacity)

        case .promptPhase:
            Group {
                if let prompt = vm.currentPrompt, let headerState = headerState {
                    ExamenStepView(
                        question: prompt.text,
                        sessionReferencePrompt: vm.longestPromptText,
                        stageName: prompt.stage.uppercased(),
                        showDebugStageLabel: AppSettings.examenDebugLabelsAllowedInThisBuild && settings.showExamenDebugLabels,
                        initialText: vm.answerForCurrentPrompt(),
                        currentStep: vm.phasePromptIndex,
                        isFinalStep: vm.isLastPhase && vm.isLastPromptInPhase,
                        showNoteButton: true,
                        isPromptSpeechEnabled: isPromptSpeechEnabled,
                        onTogglePromptSpeech: togglePromptSpeechForSession,
                        onNext: { answer in
                            reflectiveHoldTask?.cancel()
                            reflectiveHoldTask = nil
                            promptSpeechManager.stop()
                            vm.continueTapped(answer: answer)
                        }
                    )
                    .safeAreaInset(edge: .top, spacing: 0) {
                        ExamenPromptHeader(
                            state: headerState,
                            canGoBack: canGoBackWithinFlow,
                            timerPaused: vm.timerPaused,
                            onBack: {
                                reflectiveHoldTask?.cancel()
                                reflectiveHoldTask = nil
                                promptSpeechManager.stop()
                                vm.goBackWithinPhase()
                            },
                            onTogglePause: {
                                withAnimation(AnimationConfig.examenControl) {
                                    handlePauseToggle()
                                }
                            },
                            onExit: {
                                showExitAlert = true
                            }
                        )
                    }
                }
            }
            .transition(.opacity)

        case .details:
            ExamenDetailsView(
                draft: vm.draft,
                onSave: { updatedDraft in
                    // 1. Update VM with final details
                    vm.advanceFromDetails(finalDraft: updatedDraft)
                    
                    // 2. Perform Save
                    vm.saveSession(context: modelContext)
                },
                onCancel: {
                    // User requested "Close without saving" functionality similar to Exit
                    showExitAlert = true
                }
            )
            .transition(.opacity)

        case .summary:
            ExamenCompletionView(
                onReturnHome: {
                    withAnimation(AnimationConfig.transitionOut) {
                        vm.finishSession()
                    }
                }
            )
            .transition(.opacity)

        case .done:
            Color.clear
        }
    }
    
    // MARK: - Helper Logic
    
    private let defaultQuestions: [String] = [
        "What are you grateful for today?",
        "Where did you feel a sense of presence?",
        "What challenged you?",
        "What are you being invited to do next?"
    ]

    private func coordinatePromptReadAndTimer() {
        guard vm.stage == .promptPhase else { return }
        guard let prompt = vm.currentPrompt else { return }
        reflectiveHoldTask?.cancel()
        reflectiveHoldTask = nil
        vm.cancelPromptTimer()

        if isPromptSpeechEnabled {
            promptSpeechManager.speak(
                text: prompt.text,
                promptID: prompt.id,
                rate: settings.promptSpeechRate
            )
        } else {
            promptSpeechManager.stop()
            if !vm.isLastPromptInPhase {
                scheduleReflectiveHoldStart(
                    for: prompt.id,
                    delay: AnimationConfig.examenReflectiveLeadInDuration
                )
            }
        }
    }

    private func togglePromptSpeechForSession() {
        if isPromptSpeechEnabled {
            isPromptSpeechEnabled = false
            promptSpeechManager.stop()
            reflectiveHoldTask?.cancel()
            reflectiveHoldTask = nil
            if vm.stage == .promptPhase, let prompt = vm.currentPrompt, !vm.isLastPromptInPhase {
                scheduleReflectiveHoldStart(for: prompt.id, delay: 0)
            }
        } else {
            isPromptSpeechEnabled = true
            reflectiveHoldTask?.cancel()
            reflectiveHoldTask = nil
            coordinatePromptReadAndTimer()
        }
    }

    private func handlePauseToggle() {
        if promptSpeechManager.isSpeaking {
            promptSpeechManager.pause()
            if !vm.timerPaused {
                vm.toggleTimerPause()
            }
            return
        }

        if promptSpeechManager.isPaused {
            if vm.timerPaused {
                vm.toggleTimerPause()
            }
            promptSpeechManager.resume()
            return
        }

        vm.toggleTimerPause()
    }

    private func scheduleReflectiveHoldStart(for promptID: UUID, delay: TimeInterval) {
        reflectiveHoldTask?.cancel()
        reflectiveHoldTask = Task { @MainActor in
            if delay > 0 {
                let nanoseconds = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }

            guard !Task.isCancelled else { return }
            guard vm.stage == .promptPhase else { return }
            guard vm.currentPrompt?.id == promptID else { return }
            guard !vm.isLastPromptInPhase else { return }

            vm.startPromptTimer(
                duration: AnimationConfig.examenReflectiveHoldDuration,
                startsPaused: vm.timerPaused
            )
        }
    }

    private func updateRecentPromptHistory(with templates: [PromptTemplate]) {
        guard let profile = profiles.first else { return }

        let selectedIDs = templates.map(\.id)
        guard !selectedIDs.isEmpty else { return }

        // Keep recency list ordered from oldest -> newest with dedupe.
        var updated = profile.recentPromptIDs.filter { !selectedIDs.contains($0) }
        updated.append(contentsOf: selectedIDs)

        let maxRecentCount = 60
        if updated.count > maxRecentCount {
            updated = Array(updated.suffix(maxRecentCount))
        }

        profile.recentPromptIDs = updated

        do {
            try modelContext.save()
        } catch {
            print("⚠️ Failed to update recent prompt history: \(error)")
        }
    }
    
    private func fetchPrompts(for experienceType: ExperienceType) -> [PromptTemplate] {
        guard let profile = profiles.first else {
            print("No user profile available — return empty prompt list.")
            return []
        }

        if profiles.count > 1 {
            let modeSummary = profiles.map { "\($0.id.uuidString.prefix(8)):\($0.defaultMode.rawValue)" }.joined(separator: ", ")
            print("⚠️ Multiple user profiles detected (\(profiles.count)). Using first by sorted id: \(profile.id.uuidString.prefix(8)). Modes: [\(modeSummary)]")
        }
        
        // Normalize experience type
        let experienceTag = experienceType.rawValue.lowercased()
        let experienceContextTags: [String]
        if experienceType == .other {
            experienceContextTags = ["other", "daily", "dailylife"]
        } else if experienceType == .discernment {
            experienceContextTags = ["discernment", "vocation"]
        } else {
            experienceContextTags = [experienceTag]
        }
        
        // Normalize profession tag from profile (if any)
        let professionTagList: [String]
        if let track = profile.preProfessionalTrack {
            let canonical = track.canonical.rawValue.lowercased()
            let stored = track.rawValue.lowercased()
            professionTagList = Array(Set([canonical, stored]))
        } else {
            professionTagList = []
        }

        let priorJournalCount = allSessions.filter { $0.sessionType != .statementDraft }.count
        
        let templates = PromptSelector.selectPrompts(
            allPrompts: promptTemplates,
            mode: profile.defaultMode,
            experienceContextTags: experienceContextTags,
            professionTags: professionTagList,
            recentPromptIDs: Set(profile.recentPromptIDs),
            priorJournalCount: priorJournalCount
        )

        let byPhase = Dictionary(grouping: templates, by: \.phase).mapValues(\.count)
        let canonicalTrack = profile.preProfessionalTrack?.canonical.rawValue ?? "nil"
        print("📌 Examen prompt fetch — mode: \(profile.defaultMode.rawValue), track: \(canonicalTrack), experience: \(experienceTag), priorJournalCount: \(priorJournalCount), total: \(templates.count), byPhase: \(byPhase)")
        if profile.defaultMode != .quick && templates.count <= 5 {
            print("⚠️ Non-quick mode returned \(templates.count) prompts. Check profile mode persistence and prompt import state.")
        }
        
        return templates
    }
}

private struct ExamenPromptHeader: View {
    let state: ExamenHeaderState
    let canGoBack: Bool
    let timerPaused: Bool
    let onBack: () -> Void
    let onTogglePause: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.sm) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundStyle(Color.white.opacity(canGoBack ? 0.9 : 0.35))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(canGoBack ? 0.10 : 0.04))
                        .clipShape(Circle())
                }
                .disabled(!canGoBack)
                .accessibilityLabel("Go back")

                Spacer()

                Button(action: onTogglePause) {
                    Image(systemName: timerPaused ? "play.fill" : "pause.fill")
                        .font(.headline)
                        .foregroundStyle(Color.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
                .accessibilityLabel(timerPaused ? "Resume timer" : "Pause timer")

                Button(action: onExit) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Exit Examen")
            }
            .accessibilitySortPriority(3)

            PhaseTitleView(state: state)
                .accessibilitySortPriority(2)
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.top, DSSpacing.xs)
        .padding(.bottom, DSSpacing.sm)
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.22)
                LinearGradient(
                    colors: [Color.black.opacity(0.40), Color.black.opacity(0.18), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .accessibilityElement(children: .contain)
    }
}

#Preview("Prompt Header Compact") {
    ZStack {
        Color.black
        ExamenPromptHeader(
            state: ExamenHeaderState(
                phase: 0,
                totalPhases: 5,
                currentPromptIndex: 1,
                promptCount: 3,
                timerProgress: 0.45
            ),
            canGoBack: true,
            timerPaused: false,
            onBack: {},
            onTogglePause: {},
            onExit: {}
        )
    }
    .frame(width: 320, height: 180)
}

#Preview("Prompt Header Accessibility") {
    ZStack {
        Color.black
        ExamenPromptHeader(
            state: ExamenHeaderState(
                phase: 4,
                totalPhases: 5,
                currentPromptIndex: 0,
                promptCount: 2,
                timerProgress: 0.7
            ),
            canGoBack: true,
            timerPaused: true,
            onBack: {},
            onTogglePause: {},
            onExit: {}
        )
    }
    .frame(width: 320, height: 210)
    .environment(\.dynamicTypeSize, .accessibility2)
}
