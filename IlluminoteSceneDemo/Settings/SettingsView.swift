// SettingsView.swift
// Illuminote
// Converted for @Observable usage

import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @Query(sort: \UserProfile.id) private var profiles: [UserProfile]
    
    @State private var onDemandModelManager = OnDemandModelManager.shared
    @State private var mlxManager = MLXManager.shared
    @State private var showPermissionDeniedAlert = false
    @State private var showOnboarding = false
    @State private var showResetAlert = false
    @State private var showPrimaryAIInstallSheet = false
    @State private var experimental4BEnabled = AIModelRuntimePolicy.isExperimental4BEnabled
    @State private var primaryAIDownloadTask: Task<Void, Never>?
    @State private var fourBDownloadTask: Task<Void, Never>?
    
    private let privacyPolicyURL = URL(string: "https://tnownes.github.io/illuminote/")!

    private var settingsTextContext: ThemedText.Context {
        colorScheme == .dark ? .onDark : .onLight
    }

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
            return "Bundled"
        case .notInstalled:
            return "Not installed"
        case .downloading:
            return "Downloading"
        case .ready:
            return "Ready"
        case .inUse:
            return "In use"
        case .released:
            return "Released"
        case .failed:
            return "Needs attention"
        }
    }

    private var primaryAIStatusText: String {
        switch primaryAIState {
        case .bundled:
            return "This build already includes the on-device AI model."
        case .notInstalled:
            return "AI Advisor is optional in this build. Download about \(primaryAIDownloadSizeText) to add private, on-device feedback whenever you want it."
        case .downloading:
            return "Downloading the on-device AI model now. You can keep using Illuminote while it finishes."
        case .ready:
            return "On-device AI is installed and ready for Advisor feedback."
        case .inUse:
            return "On-device AI is installed and active for this Advisor session."
        case .released:
            return "On-device AI was installed earlier and is currently unloaded to save memory. Illuminote will reconnect it the next time you open Advisor."
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
            return "Downloading the 4B model pack now. The Advisor will continue using 2B until the download finishes."
        }

        if experimental4BEnabled,
           mlxManager.loadedProfile?.kind == .qwen35_4b {
            return "The 4B model is currently loaded for this Advisor session."
        }

        if onDemandModelManager.isAvailable(profile: experimental4BProfile) {
            if experimental4BEnabled {
                if mlxManager.lastCompletedRun?.profileKind == .qwen35_4b, mlxManager.loadedProfile == nil {
                    return "The last Advisor review used 4B successfully. The weights were unloaded afterward to reclaim memory, and the model pack is still ready for the next review."
                }
                return "The 4B model pack is ready for new Advisor sessions."
            }
            return "The 4B model pack is ready. Turn on High-Fidelity Advisor to use it."
        }

        if onDemandModelManager.hasPreparedResources(profile: experimental4BProfile) {
            if experimental4BEnabled {
                return "The 4B model was downloaded previously. The app will reacquire the pack automatically for the next Advisor review."
            }
            return "The 4B model was downloaded previously and can be reacquired when needed."
        }

        if let lastError = onDemandModelManager.lastError(profile: experimental4BProfile) {
            return lastError
        }

        if experimental4BEnabled {
            return "High-Fidelity Advisor is selected, but the app will stay on 2B until the 4B model finishes downloading."
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
        @Bindable var bindableSettings = appSettings
        NavigationStack {
            Form {
                // AI Section
                Section(header: settingsText("AI", style: .subtext)) {
                    Toggle(isOn: Binding(
                        get: { bindableSettings.aiEnabled },
                        set: { newValue in
                            bindableSettings.aiEnabled = newValue
                            handleAIEnabledToggle(newValue)
                        }
                    )) {
                        settingsText("Enable On-Device AI", style: .body)
                    }
                    .disabled(!AppSettings.aiFeaturesAllowedInThisBuild)

                    if !AppSettings.aiFeaturesAllowedInThisBuild {
                        Text("AI features are disabled for this TestFlight build.")
                            .font(DSFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    if AppSettings.aiFeaturesAllowedInThisBuild && !AIModelRuntimePolicy.isDeviceEligibleForAnyAI {
                        Text("This device does not meet the current memory requirements for on-device AI.")
                            .font(DSFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    if supportsPrimaryAIDownload {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                settingsText("On-Device AI Model", style: .body)
                                Spacer()
                                Text(primaryAIStateLabel)
                                    .foregroundStyle(.secondary)
                            }

                            Text(primaryAIStatusText)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)

                            if case .downloading(let progress) = primaryAIState {
                                ProgressView(value: progress) {
                                    Text("Downloading AI model")
                                } currentValueLabel: {
                                    Text(progress, format: .percent.precision(.fractionLength(0)))
                                }
                                .tint(DSColor.goldLight)
                            } else {
                                if case .notInstalled = primaryAIState {
                                    Button {
                                        showPrimaryAIInstallSheet = true
                                    } label: {
                                        HStack {
                                            settingsText("Download On-Device AI", style: .body)
                                            Spacer()
                                            Image(systemName: "arrow.down.circle")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                } else if case .released = primaryAIState {
                                    Button {
                                        startPrimaryAIDownloadIfNeeded()
                                    } label: {
                                        HStack {
                                            settingsText("Reacquire AI Model", style: .body)
                                            Spacer()
                                            Image(systemName: "arrow.clockwise")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .disabled(!bindableSettings.effectiveAIEnabled)
                                } else if case .failed = primaryAIState {
                                    Button {
                                        showPrimaryAIInstallSheet = true
                                    } label: {
                                        HStack {
                                            settingsText("Retry AI Download", style: .body)
                                            Spacer()
                                            Image(systemName: "arrow.clockwise")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }

                            if case .ready = primaryAIState {
                                Button {
                                    releasePrimaryAIResourceAccess()
                                } label: {
                                    HStack {
                                        settingsText("Release AI Model Pack", style: .body)
                                        Spacer()
                                        Image(systemName: "externaldrive.badge.minus")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .disabled(mlxManager.isGenerating)
                            } else if case .inUse = primaryAIState {
                                Button {
                                    releasePrimaryAIResourceAccess()
                                } label: {
                                    HStack {
                                        settingsText("Unload and Release AI Model", style: .body)
                                        Spacer()
                                        Image(systemName: "eject")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .disabled(mlxManager.isGenerating)
                            }
                        }
                    }
                }

                if supportsExperimental4B {
                    Section(header: settingsText("AI MODEL", style: .subtext)) {
                        HStack {
                            settingsText("Selected Advisor Model", style: .body)
                            Spacer()
                            Text(activeAIModelName)
                                .foregroundStyle(.secondary)
                        }

                        HStack(alignment: .firstTextBaseline) {
                            settingsText("Last Successful Review", style: .body)
                            Spacer()
                            Text(lastCompletedRunModelText)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                        }

                        Toggle(isOn: Binding(
                            get: { experimental4BEnabled },
                            set: { newValue in
                                experimental4BEnabled = newValue
                                handleExperimental4BToggle(newValue)
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                settingsText("Enable High-Fidelity Advisor (Experimental 4B)", style: .body)
                                Text("Approximate download: \(fourBDownloadSizeText)")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(!bindableSettings.effectiveAIEnabled)
                        .tint(DSColor.goldLight)

                        if onDemandModelManager.isDownloading(profile: experimental4BProfile) {
                            ProgressView(value: onDemandModelManager.downloadProgress(profile: experimental4BProfile)) {
                                Text("Downloading 4B model")
                            } currentValueLabel: {
                                Text(onDemandModelManager.downloadProgress(profile: experimental4BProfile), format: .percent.precision(.fractionLength(0)))
                            }
                            .tint(DSColor.goldLight)
                        } else if experimental4BEnabled && !onDemandModelManager.isAvailable(profile: experimental4BProfile) {
                            Button {
                                start4BDownloadIfNeeded()
                            } label: {
                                HStack {
                                    settingsText("Retry 4B Download", style: .body)
                                    Spacer()
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(!bindableSettings.effectiveAIEnabled)
                        }

                        Text(experimental4BStatusText)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)
                    }
                }
                
                // Profile Section
                Section(header: settingsText("PROFILE", style: .subtext)) {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        settingsText("My Profile", style: .body)
                    }
                }
                
                // Preferences Section (User Specific)
                if let profile = profiles.first {
                    Section(header: settingsText("PREFERENCES", style: .subtext)) {
                        Picker(selection: Bindable(profile).examenFrequency) {
                            ForEach(ExamenFrequency.allCases) { freq in
                                Text(freq.displayName).tag(freq)
                            }
                        } label: {
                            settingsText("Frequency", style: .body)
                        }
                        .onChange(of: profile.examenFrequency) { _, _ in
                            saveContext()
                            NotificationManager.shared.scheduleNotifications(for: profile)
                        }
                        
                        Picker(selection: Bindable(profile).preferredTimeOfDay) {
                            ForEach(PreferredTimeOfDay.allCases) { time in
                                Text(time.displayName).tag(time)
                            }
                        } label: {
                            settingsText("Preferred Time", style: .body)
                        }
                        .onChange(of: profile.preferredTimeOfDay) { _, _ in saveContext() }
                        
                        Picker(selection: Bindable(profile).sessionLength) {
                            ForEach(SessionLength.allCases) { length in
                                Text(length.displayName).tag(length)
                            }
                        } label: {
                            settingsText("Session Length", style: .body)
                        }
                        .onChange(of: profile.sessionLength) { _, _ in saveContext() }
                        
                        Picker(selection: Bindable(profile).defaultMode) {
                            ForEach(ExamenMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        } label: {
                            settingsText("Default Mode", style: .body)
                        }
                        .onChange(of: profile.defaultMode) { _, _ in saveContext() }
                        
                        Text(profile.defaultMode.description)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)

                        Toggle(isOn: $bindableSettings.readPromptsAloudEnabled) {
                            settingsText("Read Examen Prompts Aloud", style: .body)
                        }
                        .tint(DSColor.goldLight)

                        Text("Uses Apple's built-in voice to read each Examen prompt.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)

                        if bindableSettings.readPromptsAloudEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    settingsText("Prompt Voice Speed", style: .body)
                                    Spacer()
                                    Text(bindableSettings.promptSpeechRate.formatted(.number.precision(.fractionLength(2))))
                                        .foregroundStyle(.secondary)
                                }

                                Slider(
                                    value: $bindableSettings.promptSpeechRate,
                                    in: AppSettings.promptSpeechRateRange,
                                    step: 0.01
                                )
                                .tint(DSColor.goldLight)

                                HStack {
                                    Text("Slower")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("Faster")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if bindableSettings.readPromptsAloudEnabled {
                            Button {
                                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                openURL(url)
                            } label: {
                                HStack {
                                    settingsText("Open Device Settings", style: .body)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text("If voice playback does not start, open iOS Settings > Accessibility > Spoken Content to configure voices.")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        
                        Toggle(isOn: Bindable(profile).notificationsEnabled) {
                            settingsText("Enable Notifications", style: .body)
                        }
                        .onChange(of: profile.notificationsEnabled) { _, newValue in
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
                        
                        if profile.notificationsEnabled {
                            DatePicker(selection: Bindable(profile).notificationTime, displayedComponents: .hourAndMinute) {
                                settingsText("Notification Time", style: .body)
                            }
                            .onChange(of: profile.notificationTime) { _, _ in
                                saveContext()
                                NotificationManager.shared.scheduleNotifications(for: profile)
                            }
                        }
                    }
                } else {
                    // Fallback UI if no profile exists yet
                    ContentUnavailableView {
                        Label("No Profile Found", systemImage: "person.crop.circle.badge.exclamationmark")
                    } description: {
                        Text("Creating a new profile...")
                    }
                }

                // App-Wide Settings Section
                Section(header: settingsText("BACKGROUND & ANIMATION", style: .subtext)) {
                    Picker(selection: $bindableSettings.appThemeMode) {
                        Text("Core App").tag(AppTheme.core)
                        Text("Reflective").tag(AppTheme.reflective)
                    } label: {
                         settingsText("App Theme Mode", style: .body)
                    }
                    
                    Toggle(isOn: $bindableSettings.backgroundAnimationEnabled) {
                        settingsText("Enable Background Animation", style: .body)
                    }
                    .toggleStyle(.switch)
                    
                    Picker(selection: $bindableSettings.selectedTheme) {
                        ForEach(ExamenTheme.availableThemes(for: AppSettings.buildPolicy)) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    } label: {
                        settingsText("Examen Background", style: .body)
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    AppButton(title: "Restore Defaults", style: .secondary) {
                        bindableSettings.resetToDefaults()
                    }
                }

                Section(header: settingsText("HELP & SUPPORT", style: .subtext)) {
                    Button {
                        showOnboarding = true
                    } label: {
                        HStack {
                            settingsText("App Introduction", style: .body)
                            Spacer()
                            Image(systemName: "hand.wave")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Link(destination: privacyPolicyURL) {
                        HStack {
                            settingsText("Privacy Policy", style: .body)
                            Spacer()
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if internalAIDiagnosticsVisible {
                    Section(header: settingsText("INTERNAL AI DIAGNOSTICS", style: .subtext)) {
                        if let unexpectedTerminationSummary = mlxManager.unexpectedTerminationSummary {
                            Text(unexpectedTerminationSummary)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.orange)
                        }

                        diagnosticsRow(label: "Device RAM", value: currentDeviceMemoryText)
                        diagnosticsRow(label: "Requested Model", value: AIModelRuntimePolicy.requestedProfile.displayName)
                        diagnosticsRow(label: "Loaded Model", value: mlxManager.loadedProfile?.displayName ?? "None")
                        diagnosticsRow(label: "Last Successful Review", value: mlxManager.lastCompletedRun?.profileName ?? "None")
                        diagnosticsRow(label: "4B Resource", value: fourBResourceStatusText)

                        if let loadedModelDescriptor = mlxManager.loadedModelDescriptor {
                            Text(loadedModelDescriptor)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.secondary)
                        }

                        Text(lastOperationSummaryText)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)

                        if let loadErrorMessage = mlxManager.loadErrorMessage, !loadErrorMessage.isEmpty {
                            Text(loadErrorMessage)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.secondary)
                        }

                        Toggle(isOn: $bindableSettings.showExamenDebugLabels) {
                            settingsText("Show Examen Debug Labels", style: .body)
                        }
                        .tint(DSColor.goldLight)

                        Text("Internal testing toggle for prompt-stage labels during the live Examen.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)

                        if AppSettings.developerResetActionsAllowedInThisBuild {
                            Button {
                                if !mlxManager.isGenerating {
                                    mlxManager.unloadModel()
                                }
                            } label: {
                                HStack {
                                    settingsText("Unload Active Model", style: .body)
                                    Spacer()
                                    Image(systemName: "eject")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(!mlxManager.isModelLoaded || mlxManager.isGenerating)

                            Button {
                                if !mlxManager.isGenerating {
                                    mlxManager.clearMLXCache()
                                }
                            } label: {
                                HStack {
                                    settingsText("Clear MLX Cache", style: .body)
                                    Spacer()
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(mlxManager.isGenerating)

                            Button {
                                switchBackTo2B()
                            } label: {
                                HStack {
                                    settingsText("Switch Back to 2B", style: .body)
                                    Spacer()
                                    Image(systemName: "arrow.uturn.backward")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(mlxManager.isGenerating)

                            Button {
                                release4BResourceAccess()
                            } label: {
                                HStack {
                                    settingsText("Release 4B Resource Access", style: .body)
                                    Spacer()
                                    Image(systemName: "externaldrive.badge.minus")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(mlxManager.isGenerating)

                            Button(role: .destructive) {
                                mlxManager.clearPersistedDiagnostics()
                            } label: {
                                HStack {
                                    settingsText("Clear AI Diagnostics", style: .body)
                                    Spacer()
                                    Image(systemName: "trash")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Button("Reset Onboarding Flag") {
                                showResetAlert = true
                            }
                            .foregroundStyle(.red)
                        }
                    }
                }

                if internalAIDiagnosticsVisible && !mlxManager.memoryCheckpoints.isEmpty {
                    Section(header: settingsText("RECENT AI MEMORY", style: .subtext)) {
                        ForEach(Array(mlxManager.memoryCheckpoints.suffix(8).reversed())) { checkpoint in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(checkpoint.label)
                                    .font(.caption.weight(.semibold))
                                Text(memoryCheckpointSummary(for: checkpoint))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
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
                    saveContext()
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
                                    startPrimaryAIDownloadIfNeeded()
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
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView()
                .interactiveDismissDisabled()
        }
    }

    private func saveContext() {
        try? modelContext.save()
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

    @ViewBuilder
    private func diagnosticsRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            settingsText(label, style: .body)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func settingsText(_ text: String, style: ThemedText.Style) -> some View {
        ThemedText(text: text, style: style, context: settingsTextContext)
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
