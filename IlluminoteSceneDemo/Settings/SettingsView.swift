// SettingsView.swift
// Illuminote
// Converted for @Observable usage

import SwiftUI
import SwiftData
import UIKit
#if ILLUMINOTE_ENABLE_CLOUDKIT_DIAGNOSTICS
import CloudKit
#endif

struct SettingsView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \UserProfile.id) private var profiles: [UserProfile]
    
    @State private var onDemandModelManager = OnDemandModelManager.shared
    @State private var mlxManager = MLXManager.shared
    @State private var showPermissionDeniedAlert = false
    @State private var showOnboarding = false
    @State private var showExamenGuide = false
    @State private var showResetAlert = false
    @State private var showPrimaryAIInstallSheet = false
    @State private var experimental4BEnabled = AIModelRuntimePolicy.isExperimental4BEnabled
    @State private var primaryAIDownloadTask: Task<Void, Never>?
    @State private var fourBDownloadTask: Task<Void, Never>?
    @State private var showAdvisorLab = false
    @State private var showDiagnostics = false
    @State private var showDeveloperActions = false
    @State private var showRecentMemory = false
    @State private var showPhase2StoreDiagnostics = false
    @State private var phase2StoreDiagnostics = Phase2StoreDiagnostics.unavailable
    @State private var iCloudAccountStatusText = "Not refreshed"
    @State private var iCloudContainerText = CloudKitSyncConfiguration.containerIdentifier
    @State private var persistenceAlert: PersistenceAlertContext?
    @AppStorage(AppCoachStorageKey.home) private var isHomeCoachDismissed = false
    @AppStorage(AppCoachStorageKey.journal) private var isJournalCoachDismissed = false
    @AppStorage(AppCoachStorageKey.insights) private var isInsightsCoachDismissed = false
    @AppStorage(AppCoachStorageKey.writing) private var isWritingCoachDismissed = false
    
    private let privacyPolicyURL = URL(string: "https://tnownes.github.io/illuminote/")!

    private var experimental4BProfile: AIModelProfile {
        .qwen35_4b
    }

    private var primaryAIProfile: AIModelProfile {
        .qwen35_2b
    }

    private var supportsExperimental4B: Bool {
        AppSettings.experimentalModelsAllowedInThisBuild && AIModelRuntimePolicy.isDeviceEligibleForExperimental4B
    }

    private var supportsPrimaryAIDownload: Bool {
        AppSettings.aiFeaturesAllowedInThisBuild
            && AIModelRuntimePolicy.primaryAdvisorRequiresDownload
            && AIModelRuntimePolicy.isDeviceEligibleForAnyAI
    }

    private var primaryAIState: AIPrimaryModelState {
        AIModelRuntimePolicy.primaryAdvisorState(
            loadedProfile: mlxManager.loadedProfile,
            onDemandManager: onDemandModelManager
        )
    }

    private var activeAIModelName: String {
        mlxManager.loadedProfile?.displayName ?? AIModelRuntimePolicy.requestedProfile.displayName
    }

    private var activeAIModelLabel: String {
        switch mlxManager.loadedProfile?.kind ?? AIModelRuntimePolicy.requestedProfile.kind {
        case .qwen35_4b:
            return "High-fidelity"
        default:
            return "Standard"
        }
    }

    private var lastCompletedRunModelText: String {
        mlxManager.lastCompletedRunSummary ?? "No completed Advisor review recorded yet."
    }

    private var fourBDownloadSizeText: String {
        guard let approximateDownloadSizeMB = experimental4BProfile.approximateDownloadSizeMB else {
            return "Unknown size"
        }
        return formattedFileSize(fromMB: approximateDownloadSizeMB)
    }

    private var primaryAIDownloadSizeText: String {
        guard let approximateDownloadSizeMB = primaryAIProfile.approximateDownloadSizeMB else {
            return "Unknown size"
        }
        return formattedFileSize(fromMB: approximateDownloadSizeMB)
    }

    private var primaryAIStateLabel: String {
        switch primaryAIState {
        case .bundled:
            return "Built in"
        case .notInstalled:
            return "Not installed"
        case .downloading:
            return "Downloading"
        case .ready:
            return "Ready"
        case .inUse:
            return "In use"
        case .released:
            return "Saved for later"
        case .failed:
            return "Needs attention"
        }
    }

    private var primaryAIStatusText: String {
        switch primaryAIState {
        case .bundled:
            return "This build already includes the on-device Advisor."
        case .notInstalled:
            return "Advisor feedback is optional. Download about \(primaryAIDownloadSizeText) to add private, on-device help when you want it."
        case .downloading:
            return "Downloading the on-device Advisor now. You can keep using Illuminote while it finishes."
        case .ready:
            return "On-device Advisor is installed and ready whenever you want feedback on a draft."
        case .inUse:
            return "On-device Advisor is active for this review."
        case .released:
            return "On-device Advisor is installed but resting to save memory. Illuminote will make it available again the next time you open Advisor."
        case .failed(let message):
            return "The AI download needs attention. \(message)"
        }
    }

    private var shouldPromptForPrimaryAIInstall: Bool {
        guard supportsPrimaryAIDownload, appSettings.effectiveAIEnabled else { return false }
        if case .notInstalled = primaryAIState {
            return true
        }
        return false
    }

    private var experimental4BStatusText: String {
        if onDemandModelManager.isDownloading(profile: experimental4BProfile) {
            return "Downloading the enhanced Advisor now. The standard Advisor will stay active until it finishes."
        }

        if experimental4BEnabled,
           mlxManager.loadedProfile?.kind == .qwen35_4b {
            return "The enhanced Advisor is active for this review."
        }

        if onDemandModelManager.isAvailable(profile: experimental4BProfile) {
            if experimental4BEnabled {
                if mlxManager.lastCompletedRun?.profileKind == .qwen35_4b, mlxManager.loadedProfile == nil {
                    return "The last review used the enhanced Advisor successfully. It was unloaded afterward to save memory, and it is still ready for the next review."
                }
                return "The enhanced Advisor is ready for new reviews."
            }
            return "The enhanced Advisor is ready. Turn on High-fidelity Advisor to use it."
        }

        if onDemandModelManager.hasPreparedResources(profile: experimental4BProfile) {
            if experimental4BEnabled {
                return "The enhanced Advisor was downloaded previously. The app will make it available again automatically for the next review."
            }
            return "The enhanced Advisor was downloaded previously and can be made available again when needed."
        }

        if let lastError = onDemandModelManager.lastError(profile: experimental4BProfile) {
            return lastError
        }

        if experimental4BEnabled {
            return "High-fidelity Advisor is turned on, but Illuminote will keep using the standard Advisor until the enhanced version finishes downloading."
        }

        return "Optional internal-evaluation download for 10 GB+ devices."
    }

    private var internalAIDiagnosticsVisible: Bool {
        AppSettings.internalAIDiagnosticsAllowedInThisBuild
    }

    private var currentDeviceMemoryText: String {
        formattedByteCount(Int64(AIModelRuntimePolicy.physicalMemory), style: .memory)
    }

    private var fourBResourceStatusText: String {
        if onDemandModelManager.isDownloading(profile: experimental4BProfile) {
            return "Downloading (\(formattedPercent(onDemandModelManager.downloadProgress(profile: experimental4BProfile))))"
        }
        if onDemandModelManager.isAvailable(profile: experimental4BProfile) {
            return mlxManager.loadedProfile?.kind == .qwen35_4b ? "Available and in use" : "Available"
        }
        if onDemandModelManager.hasPreparedResources(profile: experimental4BProfile) {
            return "Previously downloaded (reacquires automatically)"
        }
        if let lastError = onDemandModelManager.lastError(profile: experimental4BProfile) {
            return "Unavailable: \(lastError)"
        }
        return "Not downloaded"
    }

    private var lastOperationSummaryText: String {
        guard let state = mlxManager.lastOperationState else {
            return "No persisted AI operation state yet."
        }

        let time = state.timestamp.formatted(date: .omitted, time: .shortened)
        let activity = state.inProgress ? "In progress" : "Completed"
        var summary = "\(activity) • \(state.phase) • \(time)"
        if let profileName = state.profileName {
            summary += " • \(profileName)"
        }
        if let details = state.details, !details.isEmpty {
            summary += "\n\(details)"
        }
        return summary
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SacredScreenBackground(settings: appSettings)

                AppPageScrollView {
                    AppPageHeader(
                        title: "Settings",
                        subtitle: settingsSubtitle
                    )

                    profilePanel

                    if let profile = currentProfile {
                        reflectionPreferencesPanel(profile: profile)
                        notificationsPanel(profile: profile)
                    } else {
                        pendingProfilePanel
                    }

                    appearancePanel
                    supportPanel
                    iCloudSyncPanel
                    #if DEBUG
                    experienceModeDebugPanel
                    #endif
                    if AppSettings.featurePolicy.showsAISettings {
                        aiPanel
                    }
                    restoreDefaultsPanel

                    if AppSettings.featurePolicy.showsAISettings
                        && (internalAIDiagnosticsVisible || supportsExperimental4B) {
                        advancedInternalPanel
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                refreshICloudDiagnostics()
                refreshPhase2StoreDiagnostics()
                experimental4BEnabled = AIModelRuntimePolicy.isExperimental4BEnabled
                if !AppSettings.experimentalModelsAllowedInThisBuild {
                    AIModelRuntimePolicy.setExperimental4BEnabled(false)
                    experimental4BEnabled = false
                    fourBDownloadTask?.cancel()
                    if mlxManager.loadedProfile?.kind == .qwen35_4b {
                        mlxManager.unloadModel(releasingResourceAccess: true)
                    } else {
                        onDemandModelManager.release(profile: experimental4BProfile)
                    }
                } else if experimental4BEnabled && appSettings.effectiveAIEnabled {
                    start4BDownloadIfNeeded()
                }
                if profiles.isEmpty {
                    let newProfile = UserProfile()
                    modelContext.insert(newProfile)
                    saveContext("prepare your settings profile")
                }
            }
            .alert("Notifications Disabled", isPresented: $showPermissionDeniedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enable notifications in iOS Settings to use this feature.")
            }
            .alert("Reset Onboarding?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    if let profile = profiles.first {
                        profile.hasSeenOnboarding = false
                        saveContext()
                    }
                }
            } message: {
                Text("This will reset the 'hasSeenOnboarding' flag. You will see the onboarding flow again on next launch.")
            }
            .persistenceFailureAlert($persistenceAlert)
            .sheet(isPresented: $showPrimaryAIInstallSheet) {
                NavigationStack {
                    ZStack {
                        SacredScreenBackground(settings: appSettings)

                        VStack(alignment: .leading, spacing: DSSpacing.lg) {
                            AppPanel(
                                title: "Add on-device AI",
                                subtitle: "The Advisor stays private on your device. Install it only if and when you want writing support.",
                                role: .reading,
                                highlighted: true
                            ) {
                                VStack(alignment: .leading, spacing: DSSpacing.md) {
                                    Text("Download about \(primaryAIDownloadSizeText) to add the stable Advisor model for reflective writing feedback.")
                                        .font(DSFont.supporting)
                                        .foregroundStyle(DSColor.quietText)

                                    if case .downloading(let progress) = primaryAIState {
                                        ProgressView(value: progress) {
                                            Text("Downloading on-device AI")
                                                .font(DSFont.supporting)
                                                .foregroundStyle(DSColor.textPrimary)
                                        } currentValueLabel: {
                                            Text(progress, format: .percent.precision(.fractionLength(0)))
                                                .font(DSFont.meta)
                                                .foregroundStyle(DSColor.quietText)
                                        }
                                        .tint(DSColor.brandAccent)
                                    } else {
                                        AppButton(title: "Download Advisor", style: .primary) {
                                            startPrimaryAIDownloadIfNeeded()
                                        }

                                        AppButton(title: "Not Now", style: .quiet) {
                                            showPrimaryAIInstallSheet = false
                                        }
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(DSSpacing.lg)
                    }
                    .navigationTitle("Add On-Device Advisor")
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
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView()
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showExamenGuide) {
            NavigationStack {
                ExamenExplainerView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showExamenGuide = false
                            }
                        }
                    }
            }
        }
    }

    private var settingsSubtitle: String {
        AppSettings.featurePolicy.mode == .core
            ? "Update your profile, reflection defaults, reminders, and appearance."
            : "Update your profile, reflection defaults, reminders, appearance, and AI."
    }

    private var iCloudSyncNoteText: String {
        if AppSettings.featurePolicy.showsAISettings {
            return "Journal entries, writing drafts, insights, profile, and Application Records sync through your private iCloud database when iCloud is available. On-device AI downloads, Advisor cache, and device preferences stay on this device."
        }

        return "Journal entries, writing drafts, insights, profile, and Application Records sync through your private iCloud database when iCloud is available. Device preferences stay on this device."
    }

    #if DEBUG
    private var experienceModeDebugPanel: some View {
        AppPanel(
            title: "Debug mode",
            subtitle: "Confirms which experience policy this launch is using.",
            role: .quiet
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                SettingsKeyValueRow(label: "Experience", value: AppSettings.experienceMode.rawValue.capitalized)
                SettingsKeyValueRow(label: "Build channel", value: AppSettings.buildChannel.rawValue)
                SettingsKeyValueRow(label: "Advisor allowed", value: AppSettings.featurePolicy.allowsAdvisor ? "Yes" : "No")
            }
        }
    }
    #endif

    private var currentProfile: UserProfile? {
        profiles.first
    }

    private var aiEnabledBinding: Binding<Bool> {
        Binding(
            get: { appSettings.aiEnabled },
            set: { newValue in
                appSettings.aiEnabled = newValue
                handleAIEnabledToggle(newValue)
            }
        )
    }

    private var readPromptsAloudBinding: Binding<Bool> {
        Binding(
            get: { appSettings.readPromptsAloudEnabled },
            set: { appSettings.readPromptsAloudEnabled = $0 }
        )
    }

    private var promptSpeechRateBinding: Binding<Double> {
        Binding(
            get: { appSettings.promptSpeechRate },
            set: { appSettings.promptSpeechRate = $0 }
        )
    }

    private var backgroundAnimationBinding: Binding<Bool> {
        Binding(
            get: { appSettings.backgroundAnimationEnabled },
            set: { appSettings.backgroundAnimationEnabled = $0 }
        )
    }

    private var appThemeModeBinding: Binding<AppTheme> {
        Binding(
            get: { appSettings.appThemeMode },
            set: { appSettings.appThemeMode = $0 }
        )
    }

    private var showExamenDebugLabelsBinding: Binding<Bool> {
        Binding(
            get: { appSettings.showExamenDebugLabels },
            set: { appSettings.showExamenDebugLabels = $0 }
        )
    }

    private var selectedTrackSummary: String {
        currentProfile?.preProfessionalTrack?.canonical.displayName ?? "Personal"
    }

    private var appThemeModeLabel: String {
        switch appSettings.appThemeMode {
        case .core:
            return "Core App"
        case .reflective:
            return "Reflective"
        }
    }

    private var aiActionTitle: String? {
        switch primaryAIState {
        case .notInstalled:
            return "Download Advisor"
        case .released:
            return "Make Advisor Available Again"
        case .failed:
            return "Retry AI Download"
        case .ready:
            return "Free Up AI Memory"
        case .inUse:
            return "Free Up AI Memory"
        case .bundled, .downloading:
            return nil
        }
    }

    private var aiActionStyle: AppButton.Style {
        switch primaryAIState {
        case .notInstalled, .failed:
            return .secondary
        case .released, .ready, .inUse:
            return .quiet
        case .bundled, .downloading:
            return .quiet
        }
    }

    private var profilePanel: some View {
        AppPanel(
            title: "Profile",
            subtitle: "Update your track and profile details.",
            role: .interactive
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                NavigationLink {
                    ProfileView()
                } label: {
                    SettingsNavigationRow(
                        icon: "person.crop.circle",
                        title: "My Profile",
                        subtitle: "Track, formation, and profile details.",
                        valueText: selectedTrackSummary
                    )
                }
                .buttonStyle(.plain)

                HStack(spacing: DSSpacing.sm) {
                    AppInfoChip(text: selectedTrackSummary, icon: "graduationcap")
                    if let profile = currentProfile {
                        AppInfoChip(text: profile.defaultMode.displayName, icon: "sparkles")
                    }
                }
            }
        }
    }

    private var pendingProfilePanel: some View {
        AppPanel(
            title: "Preparing your settings",
            subtitle: "Creating your profile so your preferences can be saved.",
            role: .quiet
        ) {
            ProgressView()
                .tint(DSColor.brandAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func reflectionPreferencesPanel(profile: UserProfile) -> some View {
        let frequencyBinding = Binding(
            get: { profile.examenFrequency },
            set: { newValue in
                profile.examenFrequency = newValue
                saveContext()
                NotificationManager.shared.scheduleNotifications(for: profile)
            }
        )
        let preferredTimeBinding = Binding(
            get: { profile.preferredTimeOfDay },
            set: { newValue in
                profile.preferredTimeOfDay = newValue
                saveContext()
            }
        )
        let sessionLengthBinding = Binding(
            get: { profile.sessionLength },
            set: { newValue in
                profile.sessionLength = newValue
                saveContext()
            }
        )
        let defaultModeBinding = Binding(
            get: { profile.defaultMode },
            set: { newValue in
                profile.defaultMode = newValue
                saveContext()
            }
        )

        return AppPanel(
            title: "Reflection Preferences",
            subtitle: "Choose your default reflection settings.",
            role: .quiet
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                SettingsPickerRow(
                    icon: "calendar",
                    title: "Reflection frequency",
                    subtitle: "How often you want to reflect.",
                    selection: frequencyBinding,
                    options: ExamenFrequency.allCases
                ) { $0.displayName }

                SettingsDivider()

                SettingsPickerRow(
                    icon: "sun.max",
                    title: "Preferred time",
                    subtitle: "The time of day that usually fits best.",
                    selection: preferredTimeBinding,
                    options: PreferredTimeOfDay.allCases
                ) { $0.displayName }

                SettingsDivider()

                SettingsPickerRow(
                    icon: "hourglass",
                    title: "Session length",
                    subtitle: "How much time a session should assume.",
                    selection: sessionLengthBinding,
                    options: SessionLength.allCases
                ) { $0.displayName }

                SettingsDivider()

                SettingsPickerRow(
                    icon: "sparkles.rectangle.stack",
                    title: "Default mode",
                    subtitle: "The mode the app should open with by default.",
                    selection: defaultModeBinding,
                    options: ExamenMode.allCases
                ) { $0.displayName }

                SettingsNote(text: profile.defaultMode.description)

                if AppSettings.featurePolicy.allowsExamenPromptSpeech {
                    SettingsDivider()

                    SettingsToggleRow(
                        icon: "speaker.wave.2",
                        title: "Read prompts aloud",
                        subtitle: "Have the app read each Examen prompt aloud.",
                        isOn: readPromptsAloudBinding
                    )

                    if appSettings.readPromptsAloudEnabled {
                        SettingsDivider()

                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            HStack {
                                Text("Prompt voice speed")
                                    .font(DSFont.supporting)
                                    .foregroundStyle(DSColor.textPrimary)
                                Spacer()
                                Text(appSettings.promptSpeechRate.formatted(.number.precision(.fractionLength(2))))
                                    .font(DSFont.meta)
                                    .foregroundStyle(DSColor.quietText)
                            }

                            Slider(
                                value: promptSpeechRateBinding,
                                in: AppSettings.promptSpeechRateRange,
                                step: 0.01
                            )
                            .tint(DSColor.brandAccent)

                            HStack {
                                Text("Slower")
                                Spacer()
                                Text("Faster")
                            }
                            .font(DSFont.meta)
                            .foregroundStyle(DSColor.quietTextMuted)
                        }

                        Button {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            openURL(url)
                        } label: {
                            SettingsNavigationRow(
                                icon: "arrow.up.right.square",
                                title: "Open device settings",
                                subtitle: "Adjust Spoken Content and installed voices in iOS Settings."
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func notificationsPanel(profile: UserProfile) -> some View {
        let notificationsBinding = Binding(
            get: { profile.notificationsEnabled },
            set: { newValue in
                profile.notificationsEnabled = newValue
                saveContext()
                if newValue {
                    NotificationManager.shared.requestPermission { granted in
                        if granted {
                            NotificationManager.shared.scheduleNotifications(for: profile)
                        } else {
                            profile.notificationsEnabled = false
                            showPermissionDeniedAlert = true
                            saveContext()
                        }
                    }
                } else {
                    NotificationManager.shared.cancelNotifications()
                }
            }
        )
        let notificationTimeBinding = Binding(
            get: { profile.notificationTime },
            set: { newValue in
                profile.notificationTime = newValue
                saveContext()
                NotificationManager.shared.scheduleNotifications(for: profile)
            }
        )

        return AppPanel(
            title: "Notifications",
            subtitle: "Turn reminders on or off and choose when they arrive.",
            role: .interactive
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                SettingsToggleRow(
                    icon: "bell.badge",
                    title: "Reflection reminders",
                    subtitle: "Send reminders to reflect.",
                    isOn: notificationsBinding
                )

                if profile.notificationsEnabled {
                    SettingsDivider()

                    SettingsRowShell(
                        icon: "clock.badge",
                        title: "Reminder time",
                        subtitle: "Choose when reminders arrive.",
                        layout: .stacked
                    ) {
                        DatePicker(
                            "",
                            selection: notificationTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                }
            }
        }
    }

    private var appearancePanel: some View {
        AppPanel(
            title: "Appearance",
            subtitle: "Choose how the app looks.",
            role: .interactive
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                SettingsPickerRow(
                    icon: "square.3.layers.3d.top.filled",
                    title: "App presentation",
                    subtitle: "Core keeps support screens simple. Reflective uses more atmosphere throughout the app.",
                    selection: appThemeModeBinding,
                    options: [AppTheme.core, AppTheme.reflective]
                ) { theme in
                    switch theme {
                    case .core:
                        return "Core App"
                    case .reflective:
                        return "Reflective"
                    }
                }

                SettingsDivider()

                NavigationLink {
                    ThemePickerView()
                } label: {
                    SettingsNavigationRow(
                        icon: "sparkles",
                        title: "Examen atmosphere",
                        subtitle: appSettings.selectedTheme == .sacredVoid
                            ? "Recommended for Examen and guided reflection."
                            : "Choose the background style for Examen and guided reflection.",
                        valueText: appSettings.selectedTheme.displayName
                    )
                }
                .buttonStyle(.plain)

                HStack(spacing: DSSpacing.sm) {
                    AppInfoChip(
                        text: appSettings.selectedTheme == .sacredVoid ? "House style" : "Alternate scene",
                        icon: appSettings.selectedTheme == .sacredVoid ? "checkmark.seal" : "sparkles",
                        emphasized: appSettings.selectedTheme == .sacredVoid
                    )
                    AppInfoChip(text: appThemeModeLabel, icon: "square.stack.3d.down.right")
                }

                SettingsDivider()

                SettingsToggleRow(
                    icon: "circle.lefthalf.filled",
                    title: "Background motion",
                    subtitle: "Turn slow background motion on or off.",
                    isOn: backgroundAnimationBinding
                )
            }
        }
    }

    private var supportPanel: some View {
        AppPanel(
            title: "Support",
            subtitle: "Open onboarding and privacy information.",
            role: .quiet
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Button {
                    showOnboarding = true
                } label: {
                    SettingsNavigationRow(
                        icon: "hand.wave",
                        title: "App introduction",
                        subtitle: "View the onboarding flow again."
                    )
                }
                .buttonStyle(.plain)

                SettingsDivider()

                Button {
                    showExamenGuide = true
                } label: {
                    SettingsNavigationRow(
                        icon: "sparkles",
                        title: "About the Examen",
                        subtitle: "Replay the short guide to the reflection practice."
                    )
                }
                .buttonStyle(.plain)

                SettingsDivider()

                Button {
                    restoreHelperGuidance()
                } label: {
                    SettingsActionRow(
                        icon: "arrow.counterclockwise",
                        title: "Show helper guidance again",
                        subtitle: "Bring back the teaching panels on Home, Journal, Insights, and Writing.",
                        actionText: "Restore"
                    )
                }
                .buttonStyle(.plain)

                SettingsDivider()

                Button {
                    openURL(privacyPolicyURL)
                } label: {
                    SettingsNavigationRow(
                            icon: "hand.raised",
                            title: "Privacy policy",
                            subtitle: AppSettings.featurePolicy.showsAISettings
                                ? "View privacy details for reflections and AI."
                                : "View privacy details for reflections."
                        )
                    }
                .buttonStyle(.plain)

                SettingsNote(text: "You can revisit this introduction and change most defaults any time.")
            }
        }
    }

    private var iCloudSyncPanel: some View {
        AppPanel(
            title: "iCloud Sync",
            subtitle: "Keep your reflections and drafts available across your own devices.",
            role: .quiet
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                SettingsKeyValueRow(label: "iCloud account", value: iCloudAccountStatusText)
                SettingsDivider()
                SettingsKeyValueRow(label: "Sync", value: CloudKitSyncConfiguration.statusText)
                SettingsDivider()
                SettingsKeyValueRow(label: "Container", value: CloudKitSyncConfiguration.containerIdentifier)

                SettingsNote(text: iCloudSyncNoteText)

                AppButton(title: "Refresh iCloud Status", style: .quiet) {
                    refreshICloudDiagnostics()
                    refreshPhase2StoreDiagnostics()
                }
            }
        }
    }

    private var aiPanel: some View {
        AppPanel(
            title: "AI",
            subtitle: "Turn Advisor on or off and manage downloads.",
            role: .interactive
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                SettingsToggleRow(
                    icon: "sparkles",
                    title: "On-device Advisor",
                    subtitle: "Enable private, on-device writing feedback.",
                    isOn: aiEnabledBinding
                )
                .opacity(AppSettings.aiFeaturesAllowedInThisBuild ? 1 : 0.55)
                .disabled(!AppSettings.aiFeaturesAllowedInThisBuild || !AIModelRuntimePolicy.isDeviceEligibleForAnyAI)

                SettingsNote(text: primaryAIStatusText)

                HStack(spacing: DSSpacing.sm) {
                    AppInfoChip(text: primaryAIStateLabel, icon: "cpu", emphasized: appSettings.effectiveAIEnabled)
                    AppInfoChip(text: activeAIModelLabel, icon: "waveform")
                }

                if !AppSettings.aiFeaturesAllowedInThisBuild {
                    SettingsNote(text: "AI features are disabled for this build.")
                } else if let availabilityMessage = AIModelRuntimePolicy.availabilityMessage {
                    SettingsNote(text: availabilityMessage)
                }

                if case .downloading(let progress) = primaryAIState {
                    ProgressView(value: progress) {
                        Text("Downloading AI model")
                            .font(DSFont.supporting)
                            .foregroundStyle(DSColor.textPrimary)
                    } currentValueLabel: {
                        Text(progress, format: .percent.precision(.fractionLength(0)))
                            .font(DSFont.meta)
                            .foregroundStyle(DSColor.quietText)
                    }
                    .tint(DSColor.brandAccent)
                } else if let aiActionTitle {
                    AppButton(title: aiActionTitle, style: aiActionStyle) {
                        switch primaryAIState {
                        case .notInstalled, .failed:
                            showPrimaryAIInstallSheet = true
                        case .released:
                            startPrimaryAIDownloadIfNeeded()
                        case .ready, .inUse:
                            releasePrimaryAIResourceAccess()
                        case .bundled, .downloading:
                            break
                        }
                    }
                }
            }
        }
    }

    private var restoreDefaultsPanel: some View {
        AppPanel(
            title: "Restore defaults",
            subtitle: "Reset app preferences without deleting reflections or drafts.",
            role: .quiet
        ) {
            AppButton(title: "Restore Defaults", style: .secondary) {
                appSettings.resetToDefaults()
            }
        }
    }

    private var advancedInternalPanel: some View {
        AppPanel(
            title: "Advanced / Internal",
            subtitle: "Testing tools and developer options.",
            role: .quiet
        ) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                if supportsExperimental4B {
                    DisclosureGroup(isExpanded: $showAdvisorLab) {
                        VStack(alignment: .leading, spacing: DSSpacing.md) {
                            SettingsKeyValueRow(label: "Selected advisor model", value: activeAIModelName)
                            SettingsKeyValueRow(label: "Last successful review", value: lastCompletedRunModelText)

                            SettingsToggleRow(
                                icon: "cpu",
                                title: "High-fidelity Advisor (Experimental)",
                                subtitle: "Approximate download: \(fourBDownloadSizeText)",
                                isOn: Binding(
                                    get: { experimental4BEnabled },
                                    set: { newValue in
                                        experimental4BEnabled = newValue
                                        handleExperimental4BToggle(newValue)
                                    }
                                )
                            )
                            .opacity(appSettings.effectiveAIEnabled ? 1 : 0.55)
                            .disabled(!appSettings.effectiveAIEnabled)

                            if onDemandModelManager.isDownloading(profile: experimental4BProfile) {
                                ProgressView(value: onDemandModelManager.downloadProgress(profile: experimental4BProfile)) {
                                    Text("Downloading enhanced Advisor")
                                } currentValueLabel: {
                                    Text(onDemandModelManager.downloadProgress(profile: experimental4BProfile), format: .percent.precision(.fractionLength(0)))
                                }
                                .tint(DSColor.brandAccent)
                            } else if experimental4BEnabled && !onDemandModelManager.isAvailable(profile: experimental4BProfile) {
                                AppButton(title: "Retry Enhanced Download", style: .quiet) {
                                    start4BDownloadIfNeeded()
                                }
                            }

                            SettingsNote(text: experimental4BStatusText)
                        }
                        .padding(.top, DSSpacing.sm)
                    } label: {
                        SettingsDisclosureLabel(
                            icon: "cpu.fill",
                            title: "Advisor lab",
                            subtitle: "Experimental Advisor controls and download status."
                        )
                    }
                }

                if internalAIDiagnosticsVisible {
                    if supportsExperimental4B {
                        SettingsDivider()
                    }

                    DisclosureGroup(isExpanded: $showDiagnostics) {
                        VStack(alignment: .leading, spacing: DSSpacing.md) {
                            if let unexpectedTerminationSummary = mlxManager.unexpectedTerminationSummary {
                                Text(unexpectedTerminationSummary)
                                    .font(DSFont.supporting.weight(.semibold))
                                    .foregroundStyle(DSColor.warning)
                            }

                            SettingsKeyValueRow(label: "Device RAM", value: currentDeviceMemoryText)
                            SettingsKeyValueRow(label: "iCloud account", value: iCloudAccountStatusText)
                            SettingsKeyValueRow(label: "Planned CloudKit container", value: iCloudContainerText)
                            SettingsKeyValueRow(label: "Requested model", value: AIModelRuntimePolicy.requestedProfile.displayName)
                            SettingsKeyValueRow(label: "Loaded model", value: mlxManager.loadedProfile?.displayName ?? "None")
                            SettingsKeyValueRow(label: "Last successful review", value: mlxManager.lastCompletedRun?.profileName ?? "None")
                            SettingsKeyValueRow(label: "4B resource", value: fourBResourceStatusText)

                            if let loadedModelDescriptor = mlxManager.loadedModelDescriptor {
                                SettingsNote(text: loadedModelDescriptor)
                            }

                            SettingsNote(text: lastOperationSummaryText)
                            SettingsNote(text: "SwiftData uses split stores. User-content CloudKit sync is gated behind the ILLUMINOTE_ENABLE_CLOUDKIT_SYNC build condition so Phase 2 local validation remains safe while Phase 3 diagnostics are enabled.")

                            if let loadErrorMessage = mlxManager.loadErrorMessage, !loadErrorMessage.isEmpty {
                                SettingsNote(text: loadErrorMessage)
                            }

#if DEBUG
                            DisclosureGroup(isExpanded: $showPhase2StoreDiagnostics) {
                                VStack(alignment: .leading, spacing: DSSpacing.md) {
                                    SettingsKeyValueRow(label: "Status", value: phase2StoreDiagnostics.statusText)
                                    SettingsKeyValueRow(label: "Synced user store", value: phase2StoreDiagnostics.syncedUserStoreName)
                                    SettingsKeyValueRow(label: "Local app store", value: phase2StoreDiagnostics.localAppStoreName)
                                    SettingsKeyValueRow(label: "CloudKit", value: phase2StoreDiagnostics.cloudKitStatusText)
                                    SettingsKeyValueRow(label: "User content", value: phase2StoreDiagnostics.userContentSummary)
                                    SettingsKeyValueRow(label: "Writing", value: phase2StoreDiagnostics.writingSummary)
                                    SettingsKeyValueRow(label: "Insights", value: phase2StoreDiagnostics.insightsSummary)
                                    SettingsKeyValueRow(label: "Experiences", value: phase2StoreDiagnostics.experienceSummary)
                                    SettingsKeyValueRow(label: "Local reference data", value: phase2StoreDiagnostics.localReferenceSummary)
                                    SettingsKeyValueRow(label: "Semantic cache", value: "\(phase2StoreDiagnostics.semanticVectorCacheCount)")

                                    if phase2StoreDiagnostics.warnings.isEmpty {
                                        SettingsNote(text: "No Phase 2 duplicate warnings detected. Confirm visible app data manually during the upgrade rehearsal.")
                                    } else {
                                        ForEach(phase2StoreDiagnostics.warnings, id: \.self) { warning in
                                            SettingsNote(text: warning)
                                        }
                                    }

                                    AppButton(title: "Refresh Store Diagnostics", style: .quiet) {
                                        refreshPhase2StoreDiagnostics()
                                    }
                                }
                                .padding(.top, DSSpacing.sm)
                            } label: {
                                SettingsDisclosureLabel(
                                    icon: "externaldrive.badge.icloud",
                                    title: "Phase 2 store validation",
                                    subtitle: "Local split-store counts and duplicate checks for upgrade testing."
                                )
                            }
#endif

                            SettingsToggleRow(
                                icon: "ladybug",
                                title: "Show Examen debug labels",
                                subtitle: "Internal testing toggle for prompt-stage labels during the live Examen.",
                                isOn: showExamenDebugLabelsBinding
                            )

                            if !mlxManager.memoryCheckpoints.isEmpty {
                                DisclosureGroup(isExpanded: $showRecentMemory) {
                                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                                        ForEach(Array(mlxManager.memoryCheckpoints.suffix(8).reversed())) { checkpoint in
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(checkpoint.label)
                                                    .font(DSFont.meta.weight(.semibold))
                                                    .foregroundStyle(DSColor.textPrimary)
                                                Text(memoryCheckpointSummary(for: checkpoint))
                                                    .font(DSFont.meta)
                                                    .foregroundStyle(DSColor.quietText)
                                            }
                                        }
                                    }
                                    .padding(.top, DSSpacing.sm)
                                } label: {
                                    SettingsDisclosureLabel(
                                        icon: "waveform.path.ecg",
                                        title: "Recent AI memory",
                                        subtitle: "A short tail of recent memory checkpoints."
                                    )
                                }
                            }
                        }
                        .padding(.top, DSSpacing.sm)
                    } label: {
                        SettingsDisclosureLabel(
                            icon: "stethoscope",
                            title: "Diagnostics",
                            subtitle: "Device and model state used while testing."
                        )
                    }

                    if AppSettings.developerResetActionsAllowedInThisBuild {
                        SettingsDivider()

                        DisclosureGroup(isExpanded: $showDeveloperActions) {
                            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                                AppButton(title: "Unload Active Model", style: .quiet) {
                                    if !mlxManager.isGenerating {
                                        mlxManager.unloadModel()
                                    }
                                }
                                .disabled(!mlxManager.isModelLoaded || mlxManager.isGenerating)

                                AppButton(title: "Clear MLX Cache", style: .quiet) {
                                    if !mlxManager.isGenerating {
                                        mlxManager.clearMLXCache()
                                    }
                                }
                                .disabled(mlxManager.isGenerating)

                                AppButton(title: "Switch Back to Standard Advisor", style: .quiet) {
                                    switchBackTo2B()
                                }
                                .disabled(mlxManager.isGenerating)

                                AppButton(title: "Release Enhanced Advisor Access", style: .quiet) {
                                    release4BResourceAccess()
                                }
                                .disabled(mlxManager.isGenerating)

                                AppButton(title: "Clear AI Diagnostics", style: .destructive) {
                                    mlxManager.clearPersistedDiagnostics()
                                }

                                AppButton(title: "Reset Onboarding Flag", style: .quiet) {
                                    showResetAlert = true
                                }
                            }
                            .padding(.top, DSSpacing.sm)
                        } label: {
                            SettingsDisclosureLabel(
                                icon: "wrench.and.screwdriver",
                                title: "Developer actions",
                                subtitle: "Reset and cleanup tools used while testing."
                            )
                        }
                    }
                }
            }
        }
    }

    private func saveContext(_ operation: String = "save your settings") {
        do {
            try modelContext.persistIfNeeded(for: operation)
        } catch let error as PersistenceOperationError {
            persistenceAlert = error.alertContext
        } catch {
            persistenceAlert = PersistenceAlertContext.saveFailure(
                for: operation,
                details: error.localizedDescription
            )
        }
    }

    private func refreshICloudDiagnostics() {
        iCloudContainerText = CloudKitSyncConfiguration.containerIdentifier
        #if ILLUMINOTE_ENABLE_CLOUDKIT_DIAGNOSTICS
        CKContainer.default().accountStatus { status, error in
            let statusText: String
            if let error {
                statusText = "Unavailable: \(error.localizedDescription)"
            } else {
                switch status {
                case .available:
                    statusText = "Available"
                case .couldNotDetermine:
                    statusText = "Could not determine"
                case .noAccount:
                    statusText = "No iCloud account"
                case .restricted:
                    statusText = "Restricted"
                case .temporarilyUnavailable:
                    statusText = "Temporarily unavailable"
                @unknown default:
                    statusText = "Unknown"
                }
            }

            Task { @MainActor in
                iCloudAccountStatusText = statusText
            }
        }
        #else
        iCloudAccountStatusText = "Diagnostics disabled in this build"
        #endif
    }

    private func refreshPhase2StoreDiagnostics() {
#if DEBUG
        phase2StoreDiagnostics = Phase2StoreDiagnostics.capture(from: modelContext)
#endif
    }

    private func handleAIEnabledToggle(_ enabled: Bool) {
        if !enabled {
            primaryAIDownloadTask?.cancel()
            return
        }

        if shouldPromptForPrimaryAIInstall {
            showPrimaryAIInstallSheet = true
        }
    }

    private func handleExperimental4BToggle(_ enabled: Bool) {
        AIModelRuntimePolicy.setExperimental4BEnabled(enabled)

        if enabled {
            start4BDownloadIfNeeded()
        } else {
            fourBDownloadTask?.cancel()
            if mlxManager.loadedProfile?.kind == .qwen35_4b {
                guard !mlxManager.isGenerating else { return }
                mlxManager.unloadModel(releasingResourceAccess: true)
            } else {
                onDemandModelManager.release(profile: experimental4BProfile)
            }
        }
    }

    private func start4BDownloadIfNeeded() {
        guard !onDemandModelManager.isAvailable(profile: experimental4BProfile) else { return }
        fourBDownloadTask?.cancel()
        fourBDownloadTask = Task {
            _ = await onDemandModelManager.ensureAvailable(profile: experimental4BProfile)
        }
    }

    private func startPrimaryAIDownloadIfNeeded() {
        guard supportsPrimaryAIDownload else { return }
        primaryAIDownloadTask?.cancel()
        primaryAIDownloadTask = Task {
            let didPrepare = await onDemandModelManager.ensureAvailable(profile: primaryAIProfile)
            if didPrepare {
                showPrimaryAIInstallSheet = false
            }
        }
    }

    private func releasePrimaryAIResourceAccess() {
        guard supportsPrimaryAIDownload else { return }
        primaryAIDownloadTask?.cancel()
        if mlxManager.loadedProfile?.kind == primaryAIProfile.kind {
            guard !mlxManager.isGenerating else { return }
            mlxManager.unloadModel(releasingResourceAccess: true)
            return
        }
        onDemandModelManager.release(profile: primaryAIProfile)
    }

    private func switchBackTo2B() {
        experimental4BEnabled = false
        AIModelRuntimePolicy.setExperimental4BEnabled(false)
        fourBDownloadTask?.cancel()
        if mlxManager.loadedProfile?.kind == .qwen35_4b {
            mlxManager.unloadModel(releasingResourceAccess: true)
        }
        onDemandModelManager.release(profile: experimental4BProfile)
    }

    private func release4BResourceAccess() {
        fourBDownloadTask?.cancel()
        if mlxManager.loadedProfile?.kind == .qwen35_4b {
            mlxManager.unloadModel(releasingResourceAccess: true)
            return
        }
        onDemandModelManager.release(profile: experimental4BProfile)
    }

    private func memoryCheckpointSummary(for checkpoint: AIMemoryCheckpoint) -> String {
        let time = checkpoint.timestamp.formatted(date: .omitted, time: .standard)
        let footprint = formattedByteCount(Int64(checkpoint.physicalFootprintBytes), style: .memory)
        let active = formattedByteCount(checkpoint.activeMemoryBytes, style: .memory)
        let cache = formattedByteCount(checkpoint.cacheMemoryBytes, style: .memory)
        let peak = formattedByteCount(checkpoint.peakMemoryBytes, style: .memory)
        return "\(time) • Footprint \(footprint) • Active \(active) • Cache \(cache) • Peak \(peak)"
    }

    private func formattedByteCount(_ value: Int64, style: ByteCountFormatter.CountStyle) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = style
        return formatter.string(fromByteCount: value)
    }

    private func formattedFileSize(fromMB megabytes: Int) -> String {
        let bytes = Int64(megabytes) * 1_000_000
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formattedPercent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int((value * 100).rounded()))%"
    }

    private func restoreHelperGuidance() {
        isHomeCoachDismissed = false
        isJournalCoachDismissed = false
        isInsightsCoachDismissed = false
        isWritingCoachDismissed = false
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(DSColor.dividerSoft)
            .frame(height: 1)
    }
}

private struct SettingsNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DSFont.supporting)
            .foregroundStyle(DSColor.quietText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private enum SettingsRowLayout {
    case inline
    case stacked
}

private struct SettingsRowShell<Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let icon: String
    let title: String
    let subtitle: String?
    let supportingValueText: String?
    let layout: SettingsRowLayout
    let trailing: Trailing

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        supportingValueText: String? = nil,
        layout: SettingsRowLayout = .inline,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.supportingValueText = supportingValueText
        self.layout = layout
        self.trailing = trailing()
    }

    var body: some View {
        switch resolvedLayout {
        case .inline:
            inlineLayout
        case .stacked:
            stackedLayout
        }
    }

    private var resolvedLayout: SettingsRowLayout {
        if layout == .stacked || dynamicTypeSize.isAccessibilitySize {
            return .stacked
        }
        return .inline
    }

    private var needsTopAlignment: Bool {
        subtitle != nil || supportingValueText != nil || resolvedLayout == .stacked
    }

    private var iconView: some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(DSColor.brandAccent)
            .frame(width: 20)
            .padding(.top, needsTopAlignment ? 4 : 2)
    }

    private var labelBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DSFont.supporting.weight(.semibold))
                .foregroundStyle(DSColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .font(DSFont.supporting)
                    .foregroundStyle(DSColor.quietText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let supportingValueText {
                Text(supportingValueText)
                    .font(DSFont.meta)
                    .foregroundStyle(DSColor.quietTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inlineLayout: some View {
        HStack(alignment: needsTopAlignment ? .top : .center, spacing: DSSpacing.md) {
            iconView
            labelBlock
            Spacer(minLength: DSSpacing.md)
            trailing
        }
    }

    private var stackedLayout: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            iconView

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                labelBlock

                trailing
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SettingsNavigationRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    var valueText: String? = nil

    var body: some View {
        SettingsRowShell(
            icon: icon,
            title: title,
            subtitle: subtitle,
            supportingValueText: valueText
        ) {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColor.quietTextMuted)
        }
    }
}

private struct SettingsActionRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let actionText: String

    var body: some View {
        SettingsRowShell(icon: icon, title: title, subtitle: subtitle) {
            Text(actionText)
                .font(DSFont.meta.weight(.semibold))
                .foregroundStyle(DSColor.brandAccent)
        }
    }
}

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        SettingsRowShell(icon: icon, title: title, subtitle: subtitle, layout: .inline) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(DSColor.brandAccent)
        }
    }
}

private struct SettingsPickerRow<Selection: Hashable>: View {
    let icon: String
    let title: String
    let subtitle: String?
    @Binding var selection: Selection
    let options: [Selection]
    let optionLabel: (Selection) -> String

    var body: some View {
        SettingsRowShell(icon: icon, title: title, subtitle: subtitle, layout: .stacked) {
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(optionLabel(option)).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(DSColor.textPrimary)
        }
    }
}

private struct SettingsKeyValueRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let label: String
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.md) {
                    Text(label)
                        .font(DSFont.supporting.weight(.semibold))
                        .foregroundStyle(DSColor.textPrimary)
                    Spacer(minLength: DSSpacing.md)
                    Text(value)
                        .font(DSFont.supporting)
                        .foregroundStyle(DSColor.quietText)
                        .multilineTextAlignment(.trailing)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(DSFont.supporting.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                Text(value)
                    .font(DSFont.supporting)
                    .foregroundStyle(DSColor.quietText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SettingsDisclosureLabel: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        SettingsRowShell(icon: icon, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

private struct Phase2StoreDiagnostics {
    var capturedAt: Date?
    var syncedUserStoreName: String
    var localAppStoreName: String
    var cloudKitStatusText: String
    var userProfileCount: Int
    var examenSessionCount: Int
    var stepResponseCount: Int
    var statementDraftCount: Int
    var statementSectionCount: Int
    var applicationExperienceCount: Int
    var experiencePeriodCount: Int
    var insightNodeCount: Int
    var insightEntryLinkCount: Int
    var insightWorkspaceEntryCount: Int
    var themeClusterCount: Int
    var themeEntryLinkCount: Int
    var themeBundleCount: Int
    var promptTemplateCount: Int
    var semanticVectorCacheCount: Int
    var statementFieldCount: Int
    var applicationServiceCount: Int
    var promptCycleCount: Int
    var bestPracticeCount: Int
    var practiceThemeCount: Int
    var toneGuidelinesCount: Int
    var structureRecommendationsCount: Int
    var warnings: [String]

    static let unavailable = Phase2StoreDiagnostics(
        capturedAt: nil,
        syncedUserStoreName: "Illuminote",
        localAppStoreName: "IlluminoteLocalAppContent",
        cloudKitStatusText: "Disabled (.none)",
        userProfileCount: 0,
        examenSessionCount: 0,
        stepResponseCount: 0,
        statementDraftCount: 0,
        statementSectionCount: 0,
        applicationExperienceCount: 0,
        experiencePeriodCount: 0,
        insightNodeCount: 0,
        insightEntryLinkCount: 0,
        insightWorkspaceEntryCount: 0,
        themeClusterCount: 0,
        themeEntryLinkCount: 0,
        themeBundleCount: 0,
        promptTemplateCount: 0,
        semanticVectorCacheCount: 0,
        statementFieldCount: 0,
        applicationServiceCount: 0,
        promptCycleCount: 0,
        bestPracticeCount: 0,
        practiceThemeCount: 0,
        toneGuidelinesCount: 0,
        structureRecommendationsCount: 0,
        warnings: ["Diagnostics have not been refreshed yet."]
    )

    var statusText: String {
        guard let capturedAt else { return "Not refreshed" }
        return "Captured \(capturedAt.formatted(date: .omitted, time: .standard))"
    }

    var userContentSummary: String {
        "\(userProfileCount) profiles • \(examenSessionCount) sessions • \(stepResponseCount) responses"
    }

    var writingSummary: String {
        "\(statementDraftCount) drafts • \(statementSectionCount) sections"
    }

    var insightsSummary: String {
        "\(insightNodeCount) nodes • \(insightEntryLinkCount) links • \(insightWorkspaceEntryCount) workspace entries • \(themeClusterCount) legacy themes • \(themeBundleCount) bundles"
    }

    var experienceSummary: String {
        "\(applicationExperienceCount) experiences • \(experiencePeriodCount) periods"
    }

    var localReferenceSummary: String {
        "\(promptTemplateCount) prompts • \(statementFieldCount) fields • \(applicationServiceCount) services • \(promptCycleCount) cycles • \(bestPracticeCount) best practices"
    }

    @MainActor
    static func capture(from context: ModelContext) -> Phase2StoreDiagnostics {
        var warnings: [String] = []
        let promptTemplates = fetchModels(PromptTemplate.self, context: context, warnings: &warnings)
        let statementFields = fetchModels(StatementField.self, context: context, warnings: &warnings)
        let applicationServices = fetchModels(ApplicationService.self, context: context, warnings: &warnings)

        appendDuplicateWarning(
            label: "PromptTemplate.id",
            ids: promptTemplates.map(\.id.uuidString),
            warnings: &warnings
        )
        appendDuplicateWarning(
            label: "StatementField.id",
            ids: statementFields.map(\.id),
            warnings: &warnings
        )
        appendDuplicateWarning(
            label: "ApplicationService.id",
            ids: applicationServices.map(\.id),
            warnings: &warnings
        )

        return Phase2StoreDiagnostics(
            capturedAt: .now,
            syncedUserStoreName: "Illuminote",
            localAppStoreName: "IlluminoteLocalAppContent",
            cloudKitStatusText: CloudKitSyncConfiguration.statusText,
            userProfileCount: fetchCount(UserProfile.self, context: context, warnings: &warnings),
            examenSessionCount: fetchCount(ExamenSession.self, context: context, warnings: &warnings),
            stepResponseCount: fetchCount(StepResponse.self, context: context, warnings: &warnings),
            statementDraftCount: fetchCount(StatementDraft.self, context: context, warnings: &warnings),
            statementSectionCount: fetchCount(StatementSection.self, context: context, warnings: &warnings),
            applicationExperienceCount: fetchCount(ApplicationExperience.self, context: context, warnings: &warnings),
            experiencePeriodCount: fetchCount(ExperiencePeriod.self, context: context, warnings: &warnings),
            insightNodeCount: fetchCount(InsightNode.self, context: context, warnings: &warnings),
            insightEntryLinkCount: fetchCount(InsightEntryLink.self, context: context, warnings: &warnings),
            insightWorkspaceEntryCount: fetchCount(InsightWorkspaceEntry.self, context: context, warnings: &warnings),
            themeClusterCount: fetchCount(ThemeCluster.self, context: context, warnings: &warnings),
            themeEntryLinkCount: fetchCount(ThemeEntryLink.self, context: context, warnings: &warnings),
            themeBundleCount: fetchCount(ThemeBundle.self, context: context, warnings: &warnings),
            promptTemplateCount: promptTemplates.count,
            semanticVectorCacheCount: fetchCount(SemanticVectorCache.self, context: context, warnings: &warnings),
            statementFieldCount: statementFields.count,
            applicationServiceCount: applicationServices.count,
            promptCycleCount: fetchCount(PromptCycle.self, context: context, warnings: &warnings),
            bestPracticeCount: fetchCount(BestPractice.self, context: context, warnings: &warnings),
            practiceThemeCount: fetchCount(PracticeTheme.self, context: context, warnings: &warnings),
            toneGuidelinesCount: fetchCount(ToneGuidelines.self, context: context, warnings: &warnings),
            structureRecommendationsCount: fetchCount(StructureRecommendations.self, context: context, warnings: &warnings),
            warnings: warnings
        )
    }

    @MainActor
    private static func fetchCount<Model: PersistentModel>(
        _ modelType: Model.Type,
        context: ModelContext,
        warnings: inout [String]
    ) -> Int {
        do {
            return try context.fetchCount(FetchDescriptor<Model>())
        } catch {
            warnings.append("Could not count \(modelType): \(error.localizedDescription)")
            return 0
        }
    }

    @MainActor
    private static func fetchModels<Model: PersistentModel>(
        _ modelType: Model.Type,
        context: ModelContext,
        warnings: inout [String]
    ) -> [Model] {
        do {
            return try context.fetch(FetchDescriptor<Model>())
        } catch {
            warnings.append("Could not fetch \(modelType): \(error.localizedDescription)")
            return []
        }
    }

    private static func appendDuplicateWarning(
        label: String,
        ids: [String],
        warnings: inout [String]
    ) {
        let counts = Dictionary(grouping: ids, by: { $0 }).mapValues(\.count)
        let duplicates = counts.filter { $0.value > 1 }.keys.sorted()
        guard !duplicates.isEmpty else { return }
        warnings.append("Duplicate \(label) values: \(duplicates.prefix(5).joined(separator: ", "))")
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: UserProfile.self, configurations: config)
        let profile = UserProfile()
        container.mainContext.insert(profile)
        
        return SettingsView()
            .environment(AppSettings())
            .modelContainer(container)
    }
}
#endif
