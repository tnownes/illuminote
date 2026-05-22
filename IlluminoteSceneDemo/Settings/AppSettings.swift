// AppSettings.swift
// Illuminote
// Converted to use @Observable macro for iOS 17+

import SwiftUI
import Observation
import AVFAudio

enum AppBuildChannel: String {
    case development
    case internalTestFlight = "internal_testflight"
    case alphaExternal = "alpha_external"
    case appStore = "app_store"

    private static let infoPlistKey = "IlluminoteBuildChannel"

    static var current: AppBuildChannel {
        if let rawValue = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String {
            let normalized = rawValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if let channel = AppBuildChannel(rawValue: normalized) {
                return channel
            }
        }

        #if DEBUG
        return .development
        #else
        return .alphaExternal
        #endif
    }
}

enum AppRuntimeFlags {
    static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
    }

    static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static var isMLXDisabledForTesting: Bool {
        #if ILLUMINOTE_DISABLE_MLX_LINK
        return true
        #else
        isRunningUITests
            || isRunningUnitTests
            || ProcessInfo.processInfo.arguments.contains("-disable-mlx")
            || ProcessInfo.processInfo.environment["ILLUMINOTE_DISABLE_MLX"] == "1"
        #endif
    }
}

enum IlluminoteExperienceMode: String {
    case core
    case full

    private static let launchArgumentPrefix = "-illuminote-experience="
    private static let environmentKey = "ILLUMINOTE_EXPERIENCE_MODE"

    static func current(for channel: AppBuildChannel) -> IlluminoteExperienceMode {
        if let override = overrideValue() {
            return override
        }

        switch channel {
        case .development:
            return .full
        case .internalTestFlight, .alphaExternal, .appStore:
            return .core
        }
    }

    private static func overrideValue() -> IlluminoteExperienceMode? {
        if let rawValue = ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix(launchArgumentPrefix) })?
            .dropFirst(launchArgumentPrefix.count) {
            return IlluminoteExperienceMode(rawValue: String(rawValue).lowercased())
        }

        if ProcessInfo.processInfo.arguments.contains("-illuminote-core") {
            return .core
        }

        if ProcessInfo.processInfo.arguments.contains("-illuminote-full") {
            return .full
        }

        if let rawValue = ProcessInfo.processInfo.environment[environmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
            return IlluminoteExperienceMode(rawValue: rawValue)
        }

        return nil
    }
}

struct IlluminoteFeaturePolicy {
    let mode: IlluminoteExperienceMode
    let allowsAdvisor: Bool
    let allowsExamenVoiceTranscription: Bool
    let allowsExamenPromptSpeech: Bool
    let allowsExamenInlineNotes: Bool
    let allowsExamenApplicationRecordDuringReflection: Bool
    let showsHomeApplicationRecordPrompts: Bool
    let showsAdvancedWritingTools: Bool
    let showsAISettings: Bool
    let showsCoreGuidance: Bool

    static func policy(for mode: IlluminoteExperienceMode) -> IlluminoteFeaturePolicy {
        switch mode {
        case .core:
            return IlluminoteFeaturePolicy(
                mode: mode,
                allowsAdvisor: false,
                allowsExamenVoiceTranscription: false,
                allowsExamenPromptSpeech: false,
                allowsExamenInlineNotes: false,
                allowsExamenApplicationRecordDuringReflection: false,
                showsHomeApplicationRecordPrompts: false,
                showsAdvancedWritingTools: false,
                showsAISettings: false,
                showsCoreGuidance: true
            )
        case .full:
            return IlluminoteFeaturePolicy(
                mode: mode,
                allowsAdvisor: true,
                allowsExamenVoiceTranscription: true,
                allowsExamenPromptSpeech: true,
                allowsExamenInlineNotes: true,
                allowsExamenApplicationRecordDuringReflection: true,
                showsHomeApplicationRecordPrompts: true,
                showsAdvancedWritingTools: true,
                showsAISettings: true,
                showsCoreGuidance: false
            )
        }
    }
}

struct AppBuildPolicy {
    let channel: AppBuildChannel
    let allowsAI: Bool
    let bundlesPrimaryAIModel: Bool
    let allowsExperimentalModels: Bool
    let allowsInternalDiagnostics: Bool
    let allowsExamenDebugLabels: Bool
    let allowsKnowledgeBaseVerification: Bool
    let allowsDeveloperResetActions: Bool

    static var current: AppBuildPolicy {
        switch AppBuildChannel.current {
        case .development:
            return AppBuildPolicy(
                channel: .development,
                allowsAI: true,
                bundlesPrimaryAIModel: true,
                allowsExperimentalModels: true,
                allowsInternalDiagnostics: true,
                allowsExamenDebugLabels: true,
                allowsKnowledgeBaseVerification: true,
                allowsDeveloperResetActions: true
            )
        case .internalTestFlight:
            return AppBuildPolicy(
                channel: .internalTestFlight,
                allowsAI: true,
                bundlesPrimaryAIModel: true,
                allowsExperimentalModels: true,
                allowsInternalDiagnostics: true,
                allowsExamenDebugLabels: true,
                allowsKnowledgeBaseVerification: true,
                allowsDeveloperResetActions: true
            )
        case .alphaExternal:
            return AppBuildPolicy(
                channel: .alphaExternal,
                allowsAI: true,
                bundlesPrimaryAIModel: false,
                allowsExperimentalModels: false,
                allowsInternalDiagnostics: false,
                allowsExamenDebugLabels: false,
                allowsKnowledgeBaseVerification: false,
                allowsDeveloperResetActions: false
            )
        case .appStore:
            return AppBuildPolicy(
                channel: .appStore,
                allowsAI: true,
                bundlesPrimaryAIModel: false,
                allowsExperimentalModels: false,
                allowsInternalDiagnostics: false,
                allowsExamenDebugLabels: false,
                allowsKnowledgeBaseVerification: false,
                allowsDeveloperResetActions: false
            )
        }
    }
}

enum AppRootTab: Hashable {
    case home
    case journal
    case insights
    case statement
    case settings
}

@Observable
final class AppSettings {
    static var buildChannel: AppBuildChannel { AppBuildPolicy.current.channel }
    static var buildPolicy: AppBuildPolicy { AppBuildPolicy.current }
    static var experienceMode: IlluminoteExperienceMode { IlluminoteExperienceMode.current(for: buildChannel) }
    static var featurePolicy: IlluminoteFeaturePolicy { IlluminoteFeaturePolicy.policy(for: experienceMode) }
    static var aiFeaturesAllowedInThisBuild: Bool { buildPolicy.allowsAI }
    static var advisorAllowedInThisExperience: Bool { featurePolicy.allowsAdvisor }
    static var bundlesPrimaryAIModelInThisBuild: Bool { buildPolicy.bundlesPrimaryAIModel }
    static var experimentalModelsAllowedInThisBuild: Bool { buildPolicy.allowsExperimentalModels }
    static var internalAIDiagnosticsAllowedInThisBuild: Bool { buildPolicy.allowsInternalDiagnostics }
    static var examenDebugLabelsAllowedInThisBuild: Bool { buildPolicy.allowsExamenDebugLabels }
    static var knowledgeBaseVerificationAllowedInThisBuild: Bool { buildPolicy.allowsKnowledgeBaseVerification }
    static var developerResetActionsAllowedInThisBuild: Bool { buildPolicy.allowsDeveloperResetActions }

    // MARK: - Track Settings
    // Track is now managed via UserProfile in SwiftData

    // MARK: - App Preferences
    // These settings are app-wide and persisted in UserDefaults.
    // User-specific preferences (frequency, notifications, etc.) are stored in UserProfile via SwiftData.
    private let animationKey = "backgroundAnimationEnabled"
    private let themeKey = "selectedTheme"
    private let appThemeModeKey = "appThemeMode"
    private let aiEnabledKey = "aiEnabled"
    private let readPromptsAloudKey = "readPromptsAloudEnabled"
    private let promptSpeechRateKey = "promptSpeechRate"
    private let examenDebugLabelsKey = "showExamenDebugLabels"

    static let promptSpeechRateRange: ClosedRange<Double> = 0.42...0.58

    var appThemeMode: AppTheme {
        didSet {
            UserDefaults.standard.set(appThemeMode == .core ? "core" : "reflective", forKey: appThemeModeKey)
        }
    }
    
    var aiEnabled: Bool {
        didSet {
            UserDefaults.standard.set(aiEnabled, forKey: aiEnabledKey)
        }
    }

    var readPromptsAloudEnabled: Bool {
        didSet {
            UserDefaults.standard.set(readPromptsAloudEnabled, forKey: readPromptsAloudKey)
        }
    }

    var promptSpeechRate: Double {
        didSet {
            let clamped = Self.clampPromptSpeechRate(promptSpeechRate)
            if clamped != promptSpeechRate {
                promptSpeechRate = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: promptSpeechRateKey)
        }
    }

    var showExamenDebugLabels: Bool {
        didSet {
            UserDefaults.standard.set(showExamenDebugLabels, forKey: examenDebugLabelsKey)
        }
    }

    /// Effective AI availability after applying build policy.
    var effectiveAIEnabled: Bool {
        Self.aiFeaturesAllowedInThisBuild
            && aiEnabled
            && AIModelRuntimePolicy.supportsCurrentRuntimeForAI
    }

    var backgroundAnimationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(backgroundAnimationEnabled, forKey: animationKey)
        }
    }
    
    // Store the raw value so Observation can track changes
    var selectedThemeRaw: String {
        didSet {
            UserDefaults.standard.set(selectedThemeRaw, forKey: themeKey)
        }
    }

    var selectedTheme: ExamenTheme {
        get { ExamenTheme(rawValue: selectedThemeRaw) ?? .sacredVoid }
        set { selectedThemeRaw = newValue.rawValue }
    }

    var selectedTab: AppRootTab = .home
    var pendingJournalEntryID: UUID?
    var pendingInsightEntryIDs: [UUID] = []
    var pendingInsightsLensRaw: String?
    var pendingWritingTargetID: String?
    var pendingWritingDraftID: UUID?
    var isTabBarVisible: Bool = true

    var pendingInsightsLens: InsightLens? {
        get {
            guard let pendingInsightsLensRaw else { return nil }
            return InsightLens(rawValue: pendingInsightsLensRaw)
        }
        set {
            pendingInsightsLensRaw = newValue?.rawValue
        }
    }

    init() {
        self.backgroundAnimationEnabled = UserDefaults.standard.object(forKey: animationKey) as? Bool ?? true
        self.selectedThemeRaw = UserDefaults.standard.string(forKey: themeKey) ?? ExamenTheme.sacredVoid.rawValue
        let modeStr = UserDefaults.standard.string(forKey: appThemeModeKey) ?? "core"
        self.appThemeMode = modeStr == "reflective" ? .reflective : .core
        self.aiEnabled = UserDefaults.standard.object(forKey: aiEnabledKey) as? Bool ?? false
        self.readPromptsAloudEnabled = UserDefaults.standard.object(forKey: readPromptsAloudKey) as? Bool ?? false
        let storedPromptRate = UserDefaults.standard.object(forKey: promptSpeechRateKey) as? Double ?? Double(AVSpeechUtteranceDefaultSpeechRate)
        self.promptSpeechRate = Self.clampPromptSpeechRate(storedPromptRate)
        self.showExamenDebugLabels = UserDefaults.standard.object(forKey: examenDebugLabelsKey) as? Bool ?? false
        applyBuildPolicy()
    }

    func resetToDefaults() {
        backgroundAnimationEnabled = true
        selectedThemeRaw = ExamenTheme.sacredVoid.rawValue
        selectedTab = .home
        pendingJournalEntryID = nil
        pendingInsightEntryIDs = []
        pendingInsightsLensRaw = nil
        pendingWritingTargetID = nil
        pendingWritingDraftID = nil
        isTabBarVisible = true
        appThemeMode = .core
        aiEnabled = Self.aiFeaturesAllowedInThisBuild && AIModelRuntimePolicy.supportsCurrentRuntimeForAI
        readPromptsAloudEnabled = false
        promptSpeechRate = Double(AVSpeechUtteranceDefaultSpeechRate)
        showExamenDebugLabels = false
        applyBuildPolicy()
    }

    private static func clampPromptSpeechRate(_ value: Double) -> Double {
        min(max(value, promptSpeechRateRange.lowerBound), promptSpeechRateRange.upperBound)
    }

    private func applyBuildPolicy() {
        if !ExamenTheme.availableThemes(for: Self.buildPolicy).contains(selectedTheme) {
            selectedTheme = .sacredVoid
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: themeKey)
        }

        if !Self.aiFeaturesAllowedInThisBuild || !AIModelRuntimePolicy.supportsCurrentRuntimeForAI {
            aiEnabled = false
            UserDefaults.standard.set(false, forKey: aiEnabledKey)
        }

        if !Self.advisorAllowedInThisExperience {
            aiEnabled = false
            UserDefaults.standard.set(false, forKey: aiEnabledKey)
        }

        if !Self.featurePolicy.allowsExamenPromptSpeech {
            readPromptsAloudEnabled = false
            UserDefaults.standard.set(false, forKey: readPromptsAloudKey)
        }

        if !Self.examenDebugLabelsAllowedInThisBuild {
            showExamenDebugLabels = false
            UserDefaults.standard.set(false, forKey: examenDebugLabelsKey)
        }

        if !Self.experimentalModelsAllowedInThisBuild {
            AIModelRuntimePolicy.setExperimental4BEnabled(false)
        }
    }
}

#if DEBUG
struct AppSettingsPreview_Previews: PreviewProvider {
    static var previews: some View {
        let settings = AppSettings()
        VStack(spacing: 16) {
            Toggle("Animation Enabled", isOn: .constant(settings.backgroundAnimationEnabled))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
