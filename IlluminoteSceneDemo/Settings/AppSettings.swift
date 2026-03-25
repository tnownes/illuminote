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

@Observable
final class AppSettings {
    static var buildChannel: AppBuildChannel { AppBuildPolicy.current.channel }
    static var buildPolicy: AppBuildPolicy { AppBuildPolicy.current }
    static var aiFeaturesAllowedInThisBuild: Bool { buildPolicy.allowsAI }
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
        Self.aiFeaturesAllowedInThisBuild && aiEnabled
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

    var isTabBarVisible: Bool = true

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
        isTabBarVisible = true
        appThemeMode = .core
        aiEnabled = Self.aiFeaturesAllowedInThisBuild
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

        if !Self.aiFeaturesAllowedInThisBuild {
            aiEnabled = false
            UserDefaults.standard.set(false, forKey: aiEnabledKey)
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
