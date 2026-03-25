import SwiftUI
import UIKit
import CryptoKit
import SwiftData

private enum AdvisorGenerationPass {
    case singlePass
    case diagnostic
    case synthesis
    case revision
    case followUp
    case repair
}

private enum AdvisorVisibleOperation {
    case analysis
    case followUp
}

private struct AdvisorSamplingProfile {
    let maxTokens: Int
    let temperature: Float
    let topP: Float
    let topK: Int
    let minP: Float
    let repetitionPenalty: Float
    let repetitionContextSize: Int
    let presencePenalty: Float
    let presenceContextSize: Int
    let frequencyPenalty: Float
    let frequencyContextSize: Int
    let maxKVSize: Int?
    let kvBits: Int?
    let prefillStepSize: Int

    func generationOverride() -> MLXManager.GenerationOverride {
        MLXManager.GenerationOverride(
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP,
            topK: topK,
            minP: minP,
            repetitionPenalty: repetitionPenalty,
            repetitionContextSize: repetitionContextSize,
            presencePenalty: presencePenalty,
            presenceContextSize: presenceContextSize,
            frequencyPenalty: frequencyPenalty,
            frequencyContextSize: frequencyContextSize,
            maxKVSize: maxKVSize,
            kvBits: kvBits,
            prefillStepSize: prefillStepSize
        )
    }

    static func resolve(
        mode: AIAdvisorPanel.AdvisorMode,
        experiment: AIAdvisorPanel.AdvisorABProfile,
        pass: AdvisorGenerationPass,
        profile: AIModelProfile
    ) -> AdvisorSamplingProfile {
        let base = profile.generation

        let modeTemperature: Float = switch mode {
        case .clarity: 0.24
        case .tone: 0.22
        case .insights: 0.32
        case .structure: 0.30
        case .revision: 0.22
        }

        let modeTopP: Float = switch mode {
        case .clarity: 0.87
        case .tone: 0.86
        case .insights: 0.90
        case .structure: 0.89
        case .revision: 0.88
        }

        let modeTopK: Int = switch mode {
        case .clarity: 36
        case .tone: 32
        case .insights: 48
        case .structure: 44
        case .revision: 40
        }

        let modeMinP: Float = switch mode {
        case .clarity: 0.04
        case .tone: 0.04
        case .insights: 0.02
        case .structure: 0.03
        case .revision: 0.03
        }

        let modeRepetition: Float = switch mode {
        case .clarity: 1.09
        case .tone: 1.10
        case .insights: 1.06
        case .structure: 1.07
        case .revision: 1.08
        }

        let modePresence: Float = switch mode {
        case .clarity: 0.03
        case .tone: 0.02
        case .insights: 0.06
        case .structure: 0.04
        case .revision: 0.03
        }

        let modeFrequency: Float = switch mode {
        case .clarity: 0.14
        case .tone: 0.16
        case .insights: 0.10
        case .structure: 0.11
        case .revision: 0.12
        }

        let repetitionContextSize = 128
        let presenceContextSize = 96
        let frequencyContextSize = 128

        switch pass {
        case .singlePass:
            return AdvisorSamplingProfile(
                maxTokens: min(max(base.maxTokens, 352), 384),
                temperature: modeTemperature,
                topP: modeTopP,
                topK: modeTopK,
                minP: modeMinP,
                repetitionPenalty: modeRepetition,
                repetitionContextSize: repetitionContextSize,
                presencePenalty: modePresence,
                presenceContextSize: presenceContextSize,
                frequencyPenalty: modeFrequency,
                frequencyContextSize: frequencyContextSize,
                maxKVSize: base.maxKVSize,
                kvBits: base.kvBits,
                prefillStepSize: base.prefillStepSize
            )
        case .diagnostic:
            return AdvisorSamplingProfile(
                maxTokens: experiment == .twoPass ? 96 : 80,
                temperature: max(0.14, modeTemperature - 0.08),
                topP: min(modeTopP, 0.86),
                topK: min(modeTopK, 32),
                minP: max(modeMinP, 0.04),
                repetitionPenalty: max(modeRepetition, 1.08),
                repetitionContextSize: repetitionContextSize,
                presencePenalty: 0.02,
                presenceContextSize: presenceContextSize,
                frequencyPenalty: 0.08,
                frequencyContextSize: frequencyContextSize,
                maxKVSize: base.maxKVSize,
                kvBits: base.kvBits,
                prefillStepSize: base.prefillStepSize
            )
        case .synthesis:
            return AdvisorSamplingProfile(
                maxTokens: experiment == .twoPass ? 400 : 384,
                temperature: modeTemperature,
                topP: min(modeTopP + 0.01, 0.90),
                topK: modeTopK,
                minP: modeMinP,
                repetitionPenalty: modeRepetition,
                repetitionContextSize: repetitionContextSize,
                presencePenalty: modePresence,
                presenceContextSize: presenceContextSize,
                frequencyPenalty: modeFrequency,
                frequencyContextSize: frequencyContextSize,
                maxKVSize: base.maxKVSize,
                kvBits: base.kvBits,
                prefillStepSize: base.prefillStepSize
            )
        case .revision:
            return AdvisorSamplingProfile(
                maxTokens: min(max(base.maxTokens, 320), 352),
                temperature: 0.22,
                topP: 0.88,
                topK: 40,
                minP: 0.03,
                repetitionPenalty: 1.08,
                repetitionContextSize: repetitionContextSize,
                presencePenalty: 0.03,
                presenceContextSize: presenceContextSize,
                frequencyPenalty: 0.12,
                frequencyContextSize: frequencyContextSize,
                maxKVSize: base.maxKVSize,
                kvBits: base.kvBits,
                prefillStepSize: base.prefillStepSize
            )
        case .followUp:
            return AdvisorSamplingProfile(
                maxTokens: 288,
                temperature: 0.24,
                topP: 0.88,
                topK: 40,
                minP: 0.03,
                repetitionPenalty: 1.08,
                repetitionContextSize: repetitionContextSize,
                presencePenalty: 0.03,
                presenceContextSize: presenceContextSize,
                frequencyPenalty: 0.10,
                frequencyContextSize: frequencyContextSize,
                maxKVSize: base.maxKVSize,
                kvBits: base.kvBits,
                prefillStepSize: base.prefillStepSize
            )
        case .repair:
            return AdvisorSamplingProfile(
                maxTokens: 192,
                temperature: 0,
                topP: 1.0,
                topK: 32,
                minP: 0,
                repetitionPenalty: 1.08,
                repetitionContextSize: repetitionContextSize,
                presencePenalty: 0,
                presenceContextSize: presenceContextSize,
                frequencyPenalty: 0.08,
                frequencyContextSize: frequencyContextSize,
                maxKVSize: base.maxKVSize,
                kvBits: base.kvBits,
                prefillStepSize: base.prefillStepSize
            )
        }
    }
}

struct AIAdvisorPanel: View {
    @Environment(AppSettings.self) private var appSettings
    @Query(sort: \UserProfile.id) private var profiles: [UserProfile]
    let draftContent: String
    let draftID: UUID?
    
    enum AdvisorMode: String, CaseIterable, Identifiable {
        case clarity = "Clarity"
        case insights = "Insights"
        case tone = "Tone"
        case structure = "Structure"
        case revision = "Revision Follow-up"

        static var baselineModes: [AdvisorMode] {
            [.clarity, .insights, .tone, .structure]
        }
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .clarity: return "eyeglasses"
            case .insights: return "brain.head.profile"
            case .tone: return "waveform.path.ecg"
            case .structure: return "square.stack.3d.down.right"
            case .revision: return "arrow.triangle.2.circlepath"
            }
        }
    }

    enum AdvisorABProfile: String, CaseIterable, Identifiable {
        case singlePass = "A: Single-Pass"
        case twoPass = "B: Two-Pass"

        var id: String { rawValue }

        var usesTwoPass: Bool { self == .twoPass }

        var subtitle: String {
            switch self {
            case .singlePass:
                return "Tuned one-pass critique"
            case .twoPass:
                return "Hidden diagnostic plus synthesis"
            }
        }
    }
    
    @State private var selectedMode: AdvisorMode = .clarity
    @State private var selectedGuidelineScope: AdvisorGuidelineScope = .full
    @State private var selectedABProfile: AdvisorABProfile = .singlePass
    @State private var mlxManager = MLXManager.shared
    @State private var draftText: String
    @State private var displayedFeedback: String = ""
    @State private var followUpQuestion: String = ""
    @State private var followUpResponse: String = ""
    @State private var showPrimaryAIInstallSheet = false
    @State private var analysisTask: Task<Void, Never>?
    @State private var primaryAIDownloadTask: Task<Void, Never>?
    @State private var activeOperation: AdvisorVisibleOperation?

    init(
        draftContent: String,
        draftID: UUID? = nil,
        initialGuidelineScope: AdvisorGuidelineScope = .full
    ) {
        self.draftContent = draftContent
        self.draftID = draftID
        _draftText = State(initialValue: draftContent)
        _selectedGuidelineScope = State(initialValue: initialGuidelineScope)
    }

    private var isDeviceSupportedForAI: Bool {
        AIModelRuntimePolicy.isDeviceEligibleForAnyAI
    }

    private var useImmersive: Bool {
        appSettings.appThemeMode == .core
    }

    private var isAIAvailable: Bool {
        appSettings.effectiveAIEnabled && isDeviceSupportedForAI
    }

    private var primaryAIProfile: AIModelProfile {
        .qwen35_2b
    }

    private var primaryAIState: AIPrimaryModelState {
        AIModelRuntimePolicy.primaryAdvisorState(
            loadedProfile: mlxManager.loadedProfile,
            onDemandManager: OnDemandModelManager.shared
        )
    }

    private var needsInitialPrimaryAIInstall: Bool {
        guard AIModelRuntimePolicy.primaryAdvisorRequiresDownload else { return false }
        switch primaryAIState {
        case .notInstalled, .downloading, .failed:
            return true
        default:
            return false
        }
    }

    private var primaryAIDownloadSizeText: String {
        guard let approximateDownloadSizeMB = primaryAIProfile.approximateDownloadSizeMB else {
            return "1.5 GB"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(approximateDownloadSizeMB) * 1_000_000)
    }

    private var primaryAIInstallDescription: String {
        switch primaryAIState {
        case .notInstalled:
            return "Advisor is optional in this build so the initial app download can stay smaller. Download about \(primaryAIDownloadSizeText) to add private, on-device feedback when you're ready."
        case .downloading:
            return "Downloading the on-device AI model now. You can leave this screen and come back when it finishes."
        case .failed(let message):
            return "We couldn't finish the AI download. \(message)"
        case .released:
            return "The AI model was installed earlier and is currently unloaded. Reconnect it to start another Advisor session."
        case .ready:
            return "The AI model is installed and ready for Advisor feedback."
        case .inUse, .bundled:
            return "The AI model is available for Advisor sessions."
        }
    }

    private var unavailableMessage: String {
        if !AppSettings.aiFeaturesAllowedInThisBuild {
            return "AI features are disabled in this TestFlight build."
        }
        if !appSettings.aiEnabled {
            return "AI is turned off in Settings. Turn on \"Enable On-Device AI\" to use Advisor."
        }
        return "AI Advisor is unavailable on this device."
    }

    private var availableModes: [AdvisorMode] {
        guard draftID != nil else { return AdvisorMode.baselineModes }
        if is4BSurvivalModeActive {
            return AdvisorMode.baselineModes
        }
        return AdvisorMode.allCases
    }

    private var advisorProfile: AIModelProfile {
        AIModelRuntimePolicy.requestedProfile
    }

    private var effectiveAdvisorProfile: AIModelProfile {
        mlxManager.loadedProfile ?? AIModelRuntimePolicy.defaultProfile
    }

    private var is4BSurvivalModeActive: Bool {
        effectiveAdvisorProfile.kind == .qwen35_4b
    }

    private var effectiveABProfile: AdvisorABProfile {
        is4BSurvivalModeActive ? .singlePass : selectedABProfile
    }

    private var advisorStatusText: String? {
        let activeKind = mlxManager.loadedProfile?.kind ?? AIModelRuntimePolicy.defaultProfile.kind

        if AIModelRuntimePolicy.requestedProfile.kind == .qwen35_4b,
           mlxManager.loadedProfile == nil,
           mlxManager.lastCompletedRun?.profileKind == .qwen35_4b {
            return "The last review ran on 4B successfully. The model was unloaded afterward to reclaim memory and will reload automatically for the next review."
        }

        if AIModelRuntimePolicy.requestedProfile.kind == .qwen35_4b && activeKind != .qwen35_4b {
            return "High-Fidelity 4B is selected, but Advisor is using 2B until the model pack becomes available."
        }

        if activeKind == .qwen35_4b {
            return "High-Fidelity Advisor selected. 4B runs in survival mode: single-pass baseline reviews only, with the model unloading after each review."
        }

        return nil
    }

    private var selectedAnalysisStyle: AIAdvisorPromptBuilder.AnalysisStyle {
        effectiveABProfile == .twoPass && AdvisorMode.baselineModes.contains(selectedMode) ? .richer : .stable
    }

    private var usesHiddenDiagnostic: Bool {
        effectiveABProfile.usesTwoPass && AdvisorMode.baselineModes.contains(selectedMode)
    }

    private var latestFeedbackSnapshot: AdvisorFeedbackSnapshot? {
        guard let draftID else { return nil }
        return AdvisorFeedbackStore.loadLatest(for: draftID)
    }

    private var trimmedDraftText: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentDraftHash: String? {
        guard !trimmedDraftText.isEmpty else { return nil }
        return AdvisorFeedbackStore.hash(for: trimmedDraftText)
    }

    private var activeTrack: PreProfessionalTrack {
        profiles.first?.preProfessionalTrack?.canonical ?? .general
    }

    private var hasDisplayedFeedback: Bool {
        !displayedFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isGeneratingAnalysis: Bool {
        activeOperation == .analysis && mlxManager.isGenerating
    }

    private var isGeneratingFollowUp: Bool {
        activeOperation == .followUp && mlxManager.isGenerating
    }

    private var isFollowUpAvailable: Bool {
        !is4BSurvivalModeActive
    }

    private var isRevisionModeEnabled: Bool {
        guard let snapshot = latestFeedbackSnapshot,
              let hash = currentDraftHash
        else { return false }
        return snapshot.analyzedTextHash != hash
    }

    private var revisionStatusText: String? {
        guard draftID != nil else { return nil }
        if latestFeedbackSnapshot == nil {
            return "Run one baseline analysis first, then use Revision Follow-up after edits."
        }
        if !isRevisionModeEnabled {
            return "Edit the draft before running Revision Follow-up."
        }
        if let mode = latestFeedbackSnapshot?.modeRaw {
            return "Revision Follow-up compares this draft against your last \(mode) feedback."
        }
        return "Revision Follow-up compares this draft against your latest saved feedback."
    }
    
    var body: some View {
        ZStack {
            if useImmersive {
                SacredScreenBackground(settings: appSettings)
            }
            VStack(spacing: 0) {
                if isAIAvailable && !needsInitialPrimaryAIInstall {
                    // Mode Selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableModes) { mode in
                                Button(action: {
                                    if selectedMode != mode {
                                        selectedMode = mode
                                        clearAdvisorOutputs()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: mode.icon)
                                        Text(mode.rawValue)
                                    }
                                    .font(DSFont.subtext)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(
                                        selectedMode == mode
                                            ? (useImmersive ? DSColor.goldLight : DSColor.accentPrimary)
                                            : (useImmersive ? DSColor.surfaceElevated : Color.secondary.opacity(0.1))
                                    )
                                    .foregroundStyle(selectedMode == mode ? Color.white : (useImmersive ? DSColor.textPrimary : Color.primary))
                                    .clipShape(Capsule())
                                }
                                .disabled(
                                    mlxManager.isGenerating
                                    || (mode == .revision && !isRevisionModeEnabled)
                                )
                            }
                        }
                        .padding()
                    }
                    .background(useImmersive ? DSColor.backgroundSecondary : Color(uiColor: .systemGroupedBackground))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(AdvisorGuidelineScope.allCases) { scope in
                                Button(action: {
                                    if selectedGuidelineScope != scope {
                                        selectedGuidelineScope = scope
                                        clearAdvisorOutputs()
                                    }
                                }) {
                                    Text(scope.displayName)
                                        .font(DSFont.caption)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(
                                            selectedGuidelineScope == scope
                                                ? (useImmersive ? DSColor.goldLight.opacity(0.9) : DSColor.accentPrimary)
                                                : (useImmersive ? DSColor.surfaceElevated : Color.secondary.opacity(0.1))
                                        )
                                        .foregroundStyle(
                                            selectedGuidelineScope == scope
                                                ? Color.white
                                                : (useImmersive ? DSColor.textPrimary : Color.primary)
                                        )
                                        .clipShape(Capsule())
                                }
                                .disabled(mlxManager.isGenerating)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if is4BSurvivalModeActive {
                                Label("4B survival mode uses single-pass only.", systemImage: "shield.lefthalf.filled")
                                    .font(DSFont.caption)
                                    .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(useImmersive ? DSColor.surfaceElevated : Color.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                            } else {
                                ForEach(AdvisorABProfile.allCases) { profile in
                                    Button(action: {
                                        if selectedABProfile != profile {
                                            selectedABProfile = profile
                                            clearAdvisorOutputs()
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(profile.rawValue)
                                                .font(DSFont.caption)
                                            Text(profile.subtitle)
                                                .font(.caption2)
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(
                                            selectedABProfile == profile
                                                ? (useImmersive ? DSColor.goldLight.opacity(0.9) : DSColor.accentPrimary)
                                                : (useImmersive ? DSColor.surfaceElevated : Color.secondary.opacity(0.1))
                                        )
                                        .foregroundStyle(
                                            selectedABProfile == profile
                                                ? Color.white
                                                : (useImmersive ? DSColor.textPrimary : Color.primary)
                                        )
                                        .clipShape(Capsule())
                                    }
                                    .disabled(mlxManager.isGenerating)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }

                    if let revisionStatusText, selectedMode == .revision || latestFeedbackSnapshot == nil {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                            Text(revisionStatusText)
                                .font(DSFont.caption)
                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }

                    if let descriptor = mlxManager.loadedModelDescriptor {
                        HStack(spacing: 8) {
                            Image(systemName: "cpu")
                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                            Text("Model: \(descriptor)")
                                .font(.caption2)
                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }

                    if let advisorStatusText {
                        HStack(spacing: 8) {
                            Image(systemName: advisorStatusText.contains("active") ? "sparkles" : "arrow.down.circle")
                                .foregroundStyle(useImmersive ? DSColor.goldLight : .secondary)
                            Text(advisorStatusText)
                                .font(.caption2)
                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    
                    Divider()
                }
                
                // Content Area
                if !isAIAvailable {
                    VStack(spacing: 16) {
                        Image(systemName: "cpu.slash")
                            .font(.largeTitle)
                            .foregroundStyle(useImmersive ? DSColor.textTertiary : .secondary)
                        Text(unavailableMessage)
                            .font(DSFont.body)
                            .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: .infinity)
                } else if needsInitialPrimaryAIInstall {
                    VStack(spacing: 18) {
                        Image(systemName: "arrow.down.circle")
                            .font(.largeTitle)
                            .foregroundStyle(useImmersive ? DSColor.goldLight : .accentColor)

                        Text("Add On-Device AI")
                            .font(DSFont.heading2)
                            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)

                        Text(primaryAIInstallDescription)
                            .font(DSFont.body)
                            .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if case .downloading(let progress) = primaryAIState {
                            ProgressView(value: progress) {
                                Text("Downloading on-device AI")
                            } currentValueLabel: {
                                Text(progress, format: .percent.precision(.fractionLength(0)))
                            }
                            .tint(useImmersive ? DSColor.goldLight : .accentColor)
                            .padding(.horizontal)
                        } else {
                            Button {
                                showPrimaryAIInstallSheet = true
                            } label: {
                                Text("Download AI Advisor")
                                    .font(DSFont.heading2)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(useImmersive ? DSColor.goldLight : DSColor.accentPrimary)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal)
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else if isGeneratingAnalysis && !hasDisplayedFeedback {
                    VStack {
                        ProgressView()
                        Text("Asking Advisor...")
                            .font(DSFont.caption)
                            .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                            .padding(.top)
                    }
                    .frame(maxHeight: .infinity)
                } else if let errorMessage = mlxManager.loadErrorMessage, !hasDisplayedFeedback {
                    VStack(spacing: 12) {
                        essayInputCard
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(useImmersive ? DSColor.warning : .orange)
                            Text(errorMessage)
                                .font(DSFont.body)
                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Button("Retry") {
                                analyze()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(useImmersive ? DSColor.goldLight : .accentColor)
                        }
                        .frame(maxHeight: .infinity)
                    }
                } else if hasDisplayedFeedback {
                    VStack(spacing: 12) {
                        essayInputCard
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(useImmersive ? DSColor.goldLight : .yellow)
                                    Text("Feedback: \(selectedMode.rawValue) • \(selectedGuidelineScope.displayName)")
                                        .font(DSFont.heading2)
                                        .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                                }
                                
                                Text(displayedFeedback)
                                    .font(DSFont.body)
                                    .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)

                                Divider()

                                if isFollowUpAvailable {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Ask Follow-up")
                                            .font(DSFont.heading2)
                                            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)

                                        TextField("Ask a specific follow-up question about this feedback...", text: $followUpQuestion, axis: .vertical)
                                            .lineLimit(2...4)
                                            .textFieldStyle(.plain)
                                            .padding(10)
                                            .background(useImmersive ? DSColor.surfaceElevated : Color(uiColor: .secondarySystemBackground))
                                            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .disabled(mlxManager.isGenerating)

                                        Button {
                                            askFollowUp()
                                        } label: {
                                            Text("Ask Follow-up")
                                                .font(DSFont.caption)
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 12)
                                                .background(useImmersive ? DSColor.goldLight : DSColor.accentPrimary)
                                                .foregroundStyle(.white)
                                                .clipShape(Capsule())
                                        }
                                        .disabled(mlxManager.isGenerating || followUpQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                        if isGeneratingFollowUp {
                                            HStack(spacing: 10) {
                                                ProgressView()
                                                Text("Answering your follow-up...")
                                                    .font(DSFont.caption)
                                                    .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                            }
                                        } else if !followUpResponse.isEmpty {
                                            Text("Follow-up Response")
                                                .font(DSFont.caption)
                                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                            Text(followUpResponse)
                                                .font(DSFont.body)
                                                .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                                        }
                                    }
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.shield")
                                            .foregroundStyle(useImmersive ? DSColor.goldLight : .orange)
                                        Text("4B survival mode disables follow-up chat so we can isolate baseline memory stability. Switch back to 2B to ask follow-up questions.")
                                            .font(DSFont.caption)
                                            .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        essayInputCard
                        Image(systemName: "arrow.up.message")
                            .font(.largeTitle)
                            .foregroundStyle(useImmersive ? DSColor.textTertiary : .secondary)
                        Text("Paste or edit your draft text, select a mode, then tap Analyze.")
                            .font(DSFont.body)
                            .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: analyze) {
                            Text("Analyze Statement")
                                .font(DSFont.heading2)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(useImmersive ? DSColor.goldLight : DSColor.accentPrimary)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                        .disabled(mlxManager.isGenerating || draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .if(useImmersive) { view in
                view
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.sm)
                    .sacredCardStyle(highlighted: false)
            }
        }
        .background(useImmersive ? Color.clear : Color(uiColor: .systemBackground))
        .onAppear {
            enforceSurvivalModeConstraints()
            if advisorProfile.kind == .qwen35_4b {
                Task {
                    _ = await OnDemandModelManager.shared.ensureAvailable(profile: .qwen35_4b)
                }
            }
            if isAIAvailable && needsInitialPrimaryAIInstall {
                showPrimaryAIInstallSheet = true
            }
        }
        .onChange(of: is4BSurvivalModeActive) { _, _ in
            enforceSurvivalModeConstraints()
        }
        .onDisappear {
            analysisTask?.cancel()
            primaryAIDownloadTask?.cancel()
            activeOperation = nil
        }
        .sheet(isPresented: $showPrimaryAIInstallSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add On-Device AI")
                            .font(DSFont.heading1)
                            .foregroundStyle(DSColor.textPrimary)

                        Text("The AI Advisor works privately on your device. To keep the main app download lighter, this model installs only if you choose it.")
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textSecondary)

                        Text("Download about \(primaryAIDownloadSizeText) to add the stable on-device Advisor whenever you want it.")
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textSecondary)
                    }

                    if case .downloading(let progress) = primaryAIState {
                        ProgressView(value: progress) {
                            Text("Downloading on-device AI")
                        } currentValueLabel: {
                            Text(progress, format: .percent.precision(.fractionLength(0)))
                        }
                        .tint(DSColor.goldLight)
                    } else {
                        VStack(spacing: 12) {
                            Button {
                                startPrimaryAIDownload()
                            } label: {
                                Text("Download AI Advisor")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SacredButtonStyle())

                            Button("Not Now") {
                                showPrimaryAIInstallSheet = false
                            }
                            .buttonStyle(.bordered)
                            .tint(DSColor.goldLight)
                        }
                    }

                    Spacer()
                }
                .padding()
                .navigationTitle("Add On-Device AI")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showPrimaryAIInstallSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    private var essayInputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Essay Text")
                    .font(DSFont.caption)
                    .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                Spacer()
                Button("Paste") {
                    if let clipboard = UIPasteboard.general.string, !clipboard.isEmpty {
                        draftText = clipboard
                    }
                }
                .font(DSFont.caption)
                .disabled(mlxManager.isGenerating)
            }

            TextEditor(text: $draftText)
                .frame(minHeight: 100, maxHeight: 160)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(useImmersive ? DSColor.surfaceElevated : Color(uiColor: .secondarySystemBackground))
                .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(mlxManager.isGenerating)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func analyze() {
        guard isAIAvailable else {
            clearAdvisorOutputs()
            return
        }

        guard !needsInitialPrimaryAIInstall else {
            mlxManager.loadErrorMessage = "Download On-Device AI to use Advisor in this build."
            showPrimaryAIInstallSheet = true
            return
        }

        guard !mlxManager.isGenerating else { return }

        let trimmedEssay = trimmedDraftText
        guard !trimmedEssay.isEmpty else {
            mlxManager.loadErrorMessage = "Add some draft text before requesting AI feedback."
            return
        }

        if selectedMode == .revision {
            guard !is4BSurvivalModeActive else {
                mlxManager.loadErrorMessage = "4B survival mode supports baseline reviews only. Switch back to 2B to use Revision Follow-up."
                return
            }
            guard latestFeedbackSnapshot != nil else {
                mlxManager.loadErrorMessage = "Run one baseline analysis first to unlock Revision Follow-up."
                return
            }
            guard isRevisionModeEnabled else {
                mlxManager.loadErrorMessage = "No new edits detected. Update your draft before running Revision Follow-up."
                return
            }
        }

        guard let analysisHash = currentDraftHash else {
            mlxManager.loadErrorMessage = "Unable to analyze an empty draft."
            return
        }

        analysisTask?.cancel()
        analysisTask = Task {
            activeOperation = .analysis
            defer { activeOperation = nil }

            displayedFeedback = ""
            followUpResponse = ""
            mlxManager.reset()
            await mlxManager.loadModelIfNeeded(preferredProfile: advisorProfile)

            guard !Task.isCancelled else { return }

            if !mlxManager.isModelLoaded {
                return
            }

            let activeProfile = mlxManager.loadedProfile ?? advisorProfile
            let shouldUnloadAfterRun = activeProfile.kind == .qwen35_4b
            defer {
                if shouldUnloadAfterRun {
                    mlxManager.unloadModel()
                }
            }

            var diagnosticSummary: String?
            if usesHiddenDiagnostic {
                diagnosticSummary = await runHiddenDiagnostic(
                    essay: trimmedEssay,
                    profile: activeProfile
                )
                guard !Task.isCancelled else { return }
            }

            let payload: AIAdvisorPromptPayload
            if selectedMode == .revision,
               let latestFeedbackSnapshot {
                payload = AIAdvisorPromptBuilder.buildRevisionPrompt(
                    essay: trimmedEssay,
                    track: activeTrack,
                    priorFeedback: latestFeedbackSnapshot.feedbackText,
                    priorModeLabel: latestFeedbackSnapshot.modeRaw,
                    scope: selectedGuidelineScope,
                    profile: activeProfile,
                    style: selectedAnalysisStyle
                )
            } else {
                payload = AIAdvisorPromptBuilder.buildPrompt(
                    essay: trimmedEssay,
                    track: activeTrack,
                    mode: selectedMode,
                    scope: selectedGuidelineScope,
                    profile: activeProfile,
                    style: selectedAnalysisStyle,
                    diagnosticSummary: diagnosticSummary
                )
            }

            await mlxManager.generate(
                systemPrompt: payload.systemPrompt,
                userPrompt: payload.userPrompt,
                requestedProfile: activeProfile,
                override: samplingOverride(for: activeProfile, mode: selectedMode, pass: selectedMode == .revision ? .revision : (usesHiddenDiagnostic ? .synthesis : .singlePass))
            )

            guard !Task.isCancelled else { return }
            guard mlxManager.loadErrorMessage == nil else { return }

            var feedbackText = mlxManager.currentResponse
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !feedbackText.isEmpty else { return }

            feedbackText = await enforceGuardrailsIfNeeded(
                response: feedbackText,
                mode: selectedMode,
                profile: activeProfile
            )
            guard !Task.isCancelled else { return }
            feedbackText = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !feedbackText.isEmpty else { return }

            displayedFeedback = feedbackText
            mlxManager.currentResponse = ""

            if let draftID {
                let snapshot = AdvisorFeedbackSnapshot(
                    createdAt: Date(),
                    analyzedTextHash: analysisHash,
                    modeRaw: selectedMode.rawValue,
                    feedbackText: feedbackText
                )
                AdvisorFeedbackStore.saveLatest(snapshot, for: draftID)
            }
        }
    }

    private func askFollowUp() {
        guard isAIAvailable else { return }
        guard !needsInitialPrimaryAIInstall else {
            showPrimaryAIInstallSheet = true
            return
        }
        guard !mlxManager.isGenerating else { return }
        guard isFollowUpAvailable else {
            mlxManager.loadErrorMessage = "4B survival mode disables follow-up chat. Switch back to 2B to ask follow-up questions."
            return
        }

        let question = followUpQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else {
            mlxManager.loadErrorMessage = "Ask a follow-up question first."
            return
        }

        let trimmedEssay = trimmedDraftText
        guard !trimmedEssay.isEmpty else {
            mlxManager.loadErrorMessage = "Add draft text before asking a follow-up."
            return
        }

        let baselineFeedback = displayedFeedback.trimmingCharacters(in: .whitespacesAndNewlines)
        let priorFeedback = baselineFeedback.isEmpty ? (latestFeedbackSnapshot?.feedbackText ?? "") : baselineFeedback
        guard !priorFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            mlxManager.loadErrorMessage = "Run one analysis first, then ask a follow-up."
            return
        }

        analysisTask?.cancel()
        analysisTask = Task {
            activeOperation = .followUp
            defer { activeOperation = nil }

            mlxManager.loadErrorMessage = nil
            followUpResponse = ""

            await mlxManager.loadModelIfNeeded(preferredProfile: advisorProfile)
            guard !Task.isCancelled else { return }
            guard mlxManager.isModelLoaded else {
                return
            }

            let activeProfile = mlxManager.loadedProfile ?? advisorProfile
            let shouldUnloadAfterRun = activeProfile.kind == .qwen35_4b
            defer {
                if shouldUnloadAfterRun {
                    mlxManager.unloadModel()
                }
            }
            let payload = AIAdvisorPromptBuilder.buildFollowUpPrompt(
                essay: trimmedEssay,
                track: activeTrack,
                mode: selectedMode,
                priorFeedback: priorFeedback,
                followUpQuestion: question,
                scope: selectedGuidelineScope,
                profile: activeProfile,
                style: selectedAnalysisStyle
            )

            await mlxManager.generate(
                systemPrompt: payload.systemPrompt,
                userPrompt: payload.userPrompt,
                requestedProfile: activeProfile,
                override: samplingOverride(for: activeProfile, mode: selectedMode, pass: .followUp)
            )

            guard !Task.isCancelled else { return }

            if let error = mlxManager.loadErrorMessage {
                followUpResponse = "Follow-up failed: \(error)"
                mlxManager.loadErrorMessage = nil
                return
            }

            let response = mlxManager.currentResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            let sanitizedResponse = sanitizeFollowUpResponse(response)
            if !sanitizedResponse.isEmpty {
                followUpResponse = sanitizedResponse
                followUpQuestion = ""
            }
            mlxManager.currentResponse = ""
        }
    }

    private func clearAdvisorOutputs() {
        displayedFeedback = ""
        followUpResponse = ""
        mlxManager.reset()
    }

    private func startPrimaryAIDownload() {
        primaryAIDownloadTask?.cancel()
        primaryAIDownloadTask = Task {
            let didPrepare = await OnDemandModelManager.shared.ensureAvailable(profile: primaryAIProfile)
            if didPrepare {
                showPrimaryAIInstallSheet = false
            }
        }
    }

    private func samplingOverride(
        for profile: AIModelProfile,
        mode: AdvisorMode,
        pass: AdvisorGenerationPass
    ) -> MLXManager.GenerationOverride {
        AdvisorSamplingProfile
            .resolve(mode: mode, experiment: effectiveABProfile, pass: pass, profile: profile)
            .generationOverride()
    }

    private func enforceSurvivalModeConstraints() {
        guard is4BSurvivalModeActive else { return }

        if selectedABProfile != .singlePass {
            selectedABProfile = .singlePass
        }

        if selectedMode == .revision {
            selectedMode = .clarity
            clearAdvisorOutputs()
        }
    }

    private func runHiddenDiagnostic(
        essay: String,
        profile: AIModelProfile
    ) async -> String? {
        let payload = AIAdvisorPromptBuilder.buildDiagnosticPrompt(
            essay: essay,
            track: activeTrack,
            mode: selectedMode,
            scope: selectedGuidelineScope,
            profile: profile
        )

        await mlxManager.generate(
            systemPrompt: payload.systemPrompt,
            userPrompt: payload.userPrompt,
            requestedProfile: profile,
            override: samplingOverride(for: profile, mode: selectedMode, pass: .diagnostic)
        )

        guard !Task.isCancelled else { return nil }
        guard mlxManager.loadErrorMessage == nil else {
            print("AI Advisor hidden diagnostic skipped due to error: \(mlxManager.loadErrorMessage ?? "unknown")")
            return nil
        }

        let summary = sanitizedDiagnosticSummary(from: mlxManager.currentResponse)
        mlxManager.currentResponse = ""
        return summary
    }

    private func sanitizedDiagnosticSummary(from response: String) -> String? {
        let cleaned = response
            .replacingOccurrences(of: "<think>", with: "")
            .replacingOccurrences(of: "</think>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return nil }

        let bannedFragments = ["the user wants", "system prompt", "language model", "let's tackle", "as an ai"]
        let lines = cleaned
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                !line.isEmpty && !bannedFragments.contains { fragment in
                    line.localizedCaseInsensitiveContains(fragment)
                }
            }

        let expectedPrefixes = ["Primary issue:", "Evidence gap:", "Most important next move:"]
        let labeled = lines.filter { line in
            expectedPrefixes.contains { prefix in
                line.lowercased().hasPrefix(prefix.lowercased())
            }
        }

        if labeled.count >= 3 {
            return labeled.prefix(3).joined(separator: "\n")
        }

        let compact = lines.joined(separator: " ")
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !compact.isEmpty else { return nil }
        return String(compact.prefix(240))
    }

    private func sanitizeFollowUpResponse(_ response: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return cleaned }

        let duplicateFeedbackHeadings = [
            "Critical Risks:",
            "What Works (if any):",
            "Revisions to Consider:",
            "Questions for the Writer:"
        ]

        if let firstRepeatedHeading = duplicateFeedbackHeadings.first(where: { heading in
            cleaned.localizedCaseInsensitiveContains(heading)
        }), let range = cleaned.range(of: firstRepeatedHeading, options: .caseInsensitive) {
            cleaned = String(cleaned[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return cleaned
    }

    private func enforceGuardrailsIfNeeded(
        response: String,
        mode: AdvisorMode,
        profile: AIModelProfile
    ) async -> String {
        let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedResponse.isEmpty else { return response }

        let violations = guardrailViolations(in: trimmedResponse, mode: mode)
        guard !violations.isEmpty else { return trimmedResponse }

        print("AI Advisor guardrail repair triggered for mode=\(mode.rawValue): \(violations.joined(separator: " | "))")

        let payload = AIAdvisorPromptBuilder.buildGuardrailRepairPrompt(
            mode: mode,
            invalidFeedback: trimmedResponse,
            violations: violations,
            style: selectedAnalysisStyle
        )

        let previousResponse = trimmedResponse
        let previousError = mlxManager.loadErrorMessage
        mlxManager.loadErrorMessage = nil

        await mlxManager.generate(
            systemPrompt: payload.systemPrompt,
            userPrompt: payload.userPrompt,
            requestedProfile: profile,
            override: samplingOverride(for: profile, mode: mode, pass: .repair)
        )

        guard !Task.isCancelled else {
            mlxManager.currentResponse = previousResponse
            return previousResponse
        }

        let repaired = mlxManager.currentResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repaired.isEmpty, mlxManager.loadErrorMessage == nil else {
            mlxManager.currentResponse = previousResponse
            mlxManager.loadErrorMessage = previousError
            return previousResponse
        }

        let remainingViolations = guardrailViolations(in: repaired, mode: mode)
        guard remainingViolations.isEmpty else {
            print("AI Advisor guardrail repair unresolved for mode=\(mode.rawValue): \(remainingViolations.joined(separator: " | "))")
            mlxManager.currentResponse = previousResponse
            mlxManager.loadErrorMessage = previousError
            return previousResponse
        }

        mlxManager.loadErrorMessage = nil
        return repaired
    }

    private func guardrailViolations(in response: String, mode: AdvisorMode) -> [String] {
        var violations: [String] = []

        let expectedHeadings = sectionHeadings(for: mode)
        for heading in expectedHeadings where !response.localizedCaseInsensitiveContains("\(heading):") {
            violations.append("missing heading: \(heading)")
        }

        if containsRewritePattern(response) {
            violations.append("rewrite wording detected")
        }

        if containsMetaReasoning(response) {
            violations.append("meta/internal reasoning text detected")
        }

        if mode != .revision, whatWorksNeedsEvidenceRepair(response, headings: expectedHeadings) {
            violations.append("What Works has unsupported praise (missing quoted evidence)")
        }

        return violations
    }

    private func sectionHeadings(for mode: AdvisorMode) -> [String] {
        if mode == .revision {
            return ["Addressed", "Still Needs Work", "New Issues", "Questions for the Writer"]
        }
        return ["Critical Risks", "What Works (if any)", "Revisions to Consider", "Questions for the Writer"]
    }

    private func containsRewritePattern(_ text: String) -> Bool {
        let patterns = [
            #"(?i)\byou (could|can|should) write\b"#,
            #"(?i)\bconsider writing\b"#,
            #"(?i)\brewrite (it|this|as)\b"#,
            #"(?i)\brephrase (it|this|as)\b"#,
            #"(?i)\breplace .{1,100} with .{1,100}\b"#,
            #"(?i)\binstead of .{1,100} use .{1,100}\b"#,
            #"(?i)\bchange .{1,100} to .{1,100}\b"#
        ]
        return patterns.contains { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        }
    }

    private func containsMetaReasoning(_ text: String) -> Bool {
        let patterns = [
            #"(?i)\bthe user wants\b"#,
            #"(?i)\blet'?s tackle\b"#,
            #"(?i)\bsystem prompt\b"#,
            #"(?i)\bas an ai\b"#,
            #"(?i)\blanguage model\b"#,
            #"(?i)\bmy instructions\b"#,
            #"(?i)<think>"#
        ]
        return patterns.contains { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        }
    }

    private func whatWorksNeedsEvidenceRepair(_ text: String, headings: [String]) -> Bool {
        let sections = parseSections(from: text, headings: headings)
        guard let lines = sections["What Works (if any)"], !lines.isEmpty else {
            return false
        }

        let joined = lines.joined(separator: "\n")
        if joined.localizedCaseInsensitiveContains("No reliable strengths yet.") {
            return false
        }

        let quotePattern = #"[\"“][^\"”\n]{4,80}[\"”]"#
        for line in lines where line.hasPrefix("-") || line.hasPrefix("•") {
            guard let regex = try? NSRegularExpression(pattern: quotePattern) else { return true }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            let hasQuotedEvidence = regex.firstMatch(in: line, options: [], range: range) != nil
            if !hasQuotedEvidence {
                return true
            }
        }
        return false
    }

    private func parseSections(from text: String, headings: [String]) -> [String: [String]] {
        let normalizedHeadings = Dictionary(uniqueKeysWithValues: headings.map { ($0.lowercased(), $0) })
        var sections: [String: [String]] = [:]
        var currentHeading: String?

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasSuffix(":") {
                let candidate = String(trimmed.dropLast()).lowercased()
                if let heading = normalizedHeadings[candidate] {
                    currentHeading = heading
                    if sections[heading] == nil {
                        sections[heading] = []
                    }
                    continue
                }
            }

            guard let currentHeading, !trimmed.isEmpty else { continue }
            sections[currentHeading, default: []].append(trimmed)
        }

        return sections
    }
}

struct AdvisorFeedbackSnapshot: Codable {
    let createdAt: Date
    let analyzedTextHash: String
    let modeRaw: String
    let feedbackText: String
}

enum AdvisorFeedbackStore {
    private static let keyPrefix = "aiAdvisor.latestFeedback."

    static func loadLatest(for draftID: UUID) -> AdvisorFeedbackSnapshot? {
        let key = keyPrefix + draftID.uuidString
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AdvisorFeedbackSnapshot.self, from: data)
    }

    static func saveLatest(_ snapshot: AdvisorFeedbackSnapshot, for draftID: UUID) {
        let key = keyPrefix + draftID.uuidString
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func removeLatest(for draftID: UUID) {
        let key = keyPrefix + draftID.uuidString
        UserDefaults.standard.removeObject(forKey: key)
    }

    static func hash(for text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

#Preview {
    AIAdvisorPanel(draftContent: "This is a sample draft content...")
        .environment(AppSettings())
}
