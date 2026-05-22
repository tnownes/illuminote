import Foundation

struct AIModelProfile: Identifiable, Equatable {
    enum Kind: String {
        case qwen35_2b
        case qwen35_4b
        case qwen3_17bLegacy
    }

    enum DeliveryMode: Equatable {
        case bundled
        case onDemand(tag: String)
    }

    enum AvailabilityRequirement: Equatable {
        case alwaysPresent
        case downloadRequired
    }

    struct PromptBudget: Equatable {
        let maxEssayCharacters: Int
        let minimumEssayCharacters: Int
        let defaultGuidelineCharacters: Int
        let minimumGuidelineCharacters: Int
        let defaultPriorFeedbackCharacters: Int
        let minimumPriorFeedbackCharacters: Int
        let defaultRubricDetailCharacters: Int
        let minimumRubricDetailCharacters: Int
        let maxPromptCharactersStandard: Int
        let maxPromptCharactersRevision: Int
    }

    struct GenerationConfig: Equatable {
        let maxTokens: Int
        let temperature: Float
        let topP: Float
        let topK: Int
        let minP: Float
        let repetitionPenalty: Float
        let presencePenalty: Float
        let frequencyPenalty: Float
        let maxKVSize: Int?
        let kvBits: Int?
        let prefillStepSize: Int
        let enableThinking: Bool
    }

    let kind: Kind
    let displayName: String
    let preferredBundleDirectories: [String]
    let deliveryMode: DeliveryMode
    let approximateDownloadSizeMB: Int?
    let availabilityRequirement: AvailabilityRequirement
    let minimumPhysicalMemoryBytes: UInt64
    let promptBudget: PromptBudget
    let generation: GenerationConfig
    let fallbackKinds: [Kind]
    let fewShotExample: String?

    var id: String { kind.rawValue }

    private static var primaryModelDeliveryMode: DeliveryMode {
        AppSettings.bundlesPrimaryAIModelInThisBuild
            ? .bundled
            : .onDemand(tag: "qwen35_2b_model")
    }

    private static var primaryModelAvailabilityRequirement: AvailabilityRequirement {
        AppSettings.bundlesPrimaryAIModelInThisBuild ? .alwaysPresent : .downloadRequired
    }

    private static var primaryModelApproximateDownloadSizeMB: Int? {
        AppSettings.bundlesPrimaryAIModelInThisBuild ? nil : 1450
    }

    static var qwen35_2b: AIModelProfile {
        AIModelProfile(
            kind: .qwen35_2b,
            displayName: "Qwen3.5-2B",
            preferredBundleDirectories: [
                "Qwen3.5-2B-4bit-OptiQ",
                "Qwen3.5-2B-4bit",
                "Qwen3.5-2B"
            ],
            deliveryMode: primaryModelDeliveryMode,
            approximateDownloadSizeMB: primaryModelApproximateDownloadSizeMB,
            availabilityRequirement: primaryModelAvailabilityRequirement,
            minimumPhysicalMemoryBytes: 7 * 1024 * 1024 * 1024,
            promptBudget: .init(
                maxEssayCharacters: 4600,
                minimumEssayCharacters: 2600,
                defaultGuidelineCharacters: 1700,
                minimumGuidelineCharacters: 900,
                defaultPriorFeedbackCharacters: 900,
                minimumPriorFeedbackCharacters: 450,
                defaultRubricDetailCharacters: 700,
                minimumRubricDetailCharacters: 250,
                maxPromptCharactersStandard: 8200,
                maxPromptCharactersRevision: 9000
            ),
            generation: .init(
                maxTokens: 352,
                temperature: 0.24,
                topP: 0.88,
                topK: 40,
                minP: 0.03,
                repetitionPenalty: 1.08,
                presencePenalty: 0.04,
                frequencyPenalty: 0.12,
                maxKVSize: nil,
                kvBits: nil,
                prefillStepSize: 192,
                enableThinking: false
            ),
            fallbackKinds: [.qwen3_17bLegacy],
            fewShotExample: nil
        )
    }

    static var qwen35_4b: AIModelProfile {
        AIModelProfile(
            kind: .qwen35_4b,
            displayName: "Qwen3.5-4B (Experimental)",
            preferredBundleDirectories: [
                "Qwen3.5-4B-OptiQ-4bit",
                "Qwen3.5-4B-4bit-OptiQ",
                "Qwen3.5-4B-4bit",
                "Qwen3.5-4B"
            ],
            deliveryMode: .onDemand(tag: "qwen35_4b_model"),
            approximateDownloadSizeMB: 2950,
            availabilityRequirement: .downloadRequired,
            minimumPhysicalMemoryBytes: 10 * 1024 * 1024 * 1024,
            promptBudget: .init(
                maxEssayCharacters: 2200,
                minimumEssayCharacters: 1200,
                defaultGuidelineCharacters: 900,
                minimumGuidelineCharacters: 500,
                defaultPriorFeedbackCharacters: 450,
                minimumPriorFeedbackCharacters: 250,
                defaultRubricDetailCharacters: 450,
                minimumRubricDetailCharacters: 160,
                maxPromptCharactersStandard: 4300,
                maxPromptCharactersRevision: 5200
            ),
            generation: .init(
                maxTokens: 224,
                temperature: 0.16,
                topP: 0.84,
                topK: 28,
                minP: 0.04,
                repetitionPenalty: 1.08,
                presencePenalty: 0.02,
                frequencyPenalty: 0.09,
                maxKVSize: 2048,
                kvBits: nil,
                prefillStepSize: 64,
                enableThinking: false
            ),
            fallbackKinds: [.qwen35_2b, .qwen3_17bLegacy],
            fewShotExample: nil
        )
    }

    static var qwen3_17bLegacy: AIModelProfile {
        AIModelProfile(
            kind: .qwen3_17bLegacy,
            displayName: "Qwen3-1.7B (Legacy)",
            preferredBundleDirectories: ["Qwen3-1.7B-4bit"],
            deliveryMode: .bundled,
            approximateDownloadSizeMB: nil,
            availabilityRequirement: .alwaysPresent,
            minimumPhysicalMemoryBytes: 7 * 1024 * 1024 * 1024,
            promptBudget: .init(
                maxEssayCharacters: 5600,
                minimumEssayCharacters: 4200,
                defaultGuidelineCharacters: 2100,
                minimumGuidelineCharacters: 1200,
                defaultPriorFeedbackCharacters: 1100,
                minimumPriorFeedbackCharacters: 500,
                defaultRubricDetailCharacters: 900,
                minimumRubricDetailCharacters: 250,
                maxPromptCharactersStandard: 9800,
                maxPromptCharactersRevision: 10500
            ),
            generation: .init(
                maxTokens: 384,
                temperature: 0.22,
                topP: 0.9,
                topK: 48,
                minP: 0.02,
                repetitionPenalty: 1.06,
                presencePenalty: 0.03,
                frequencyPenalty: 0.08,
                maxKVSize: nil,
                kvBits: nil,
                prefillStepSize: 256,
                enableThinking: false
            ),
            fallbackKinds: [],
            fewShotExample: nil
        )
    }

    static func profile(for kind: Kind) -> AIModelProfile {
        switch kind {
        case .qwen35_2b:
            return qwen35_2b
        case .qwen35_4b:
            return qwen35_4b
        case .qwen3_17bLegacy:
            return qwen3_17bLegacy
        }
    }
}

enum AIPrimaryModelState: Equatable {
    case bundled
    case notInstalled
    case downloading(progress: Double)
    case ready
    case inUse
    case released
    case failed(message: String)
}

enum AIModelRuntimePolicy {
    private static let enable4BKey = "ai.experimental4BProfileEnabled"

    static var physicalMemory: UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }

    static var supportsCurrentRuntimeForAI: Bool {
        guard !AppRuntimeFlags.isMLXDisabledForTesting else {
            return false
        }

        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    static var availabilityMessage: String? {
        guard AppSettings.aiFeaturesAllowedInThisBuild else {
            return "AI features are disabled for this build."
        }

        guard supportsCurrentRuntimeForAI else {
            if AppRuntimeFlags.isMLXDisabledForTesting {
                return "On-device AI is disabled for this test run."
            }
            return "On-device AI is not available in the iOS Simulator. Use a physical iPhone to test local model features."
        }

        guard physicalMemory < AIModelProfile.qwen35_2b.minimumPhysicalMemoryBytes else {
            return nil
        }

        return "This device does not currently meet the memory requirements for on-device AI."
    }

    static var isDeviceEligibleForAnyAI: Bool {
        supportsCurrentRuntimeForAI
            && physicalMemory >= AIModelProfile.qwen35_2b.minimumPhysicalMemoryBytes
    }

    static var isDeviceEligibleForExperimental4B: Bool {
        AppSettings.experimentalModelsAllowedInThisBuild && canRun(profile: .qwen35_4b)
    }

    static var isExperimental4BEnabled: Bool {
        AppSettings.experimentalModelsAllowedInThisBuild && UserDefaults.standard.bool(forKey: enable4BKey)
    }

    static var primaryAdvisorProfile: AIModelProfile {
        .qwen35_2b
    }

    static var primaryAdvisorRequiresDownload: Bool {
        primaryAdvisorProfile.availabilityRequirement == .downloadRequired
    }

    static func setExperimental4BEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(
            enabled && AppSettings.experimentalModelsAllowedInThisBuild,
            forKey: enable4BKey
        )
    }

    static var requestedProfile: AIModelProfile {
        if isExperimental4BEnabled && isDeviceEligibleForExperimental4B {
            return .qwen35_4b
        }
        return .qwen35_2b
    }

    static var defaultProfile: AIModelProfile {
        if requestedProfile.kind == .qwen35_4b,
           OnDemandModelManager.shared.isAvailable(profile: .qwen35_4b) {
            return .qwen35_4b
        }
        return .qwen35_2b
    }

    static func canRun(profile: AIModelProfile, on memory: UInt64 = physicalMemory) -> Bool {
        supportsCurrentRuntimeForAI && memory >= profile.minimumPhysicalMemoryBytes
    }

    static func resolutionOrder(preferredKind: AIModelProfile.Kind? = nil) -> [AIModelProfile] {
        let preferred = AIModelProfile.profile(for: preferredKind ?? requestedProfile.kind)
        var order = [preferred]

        for fallbackKind in preferred.fallbackKinds {
            order.append(AIModelProfile.profile(for: fallbackKind))
        }

        if !order.contains(where: { $0.kind == .qwen3_17bLegacy }) {
            order.append(.qwen3_17bLegacy)
        }

        return order
    }

    static func primaryAdvisorState(
        loadedProfile: AIModelProfile?,
        onDemandManager: OnDemandModelManager
    ) -> AIPrimaryModelState {
        let profile = primaryAdvisorProfile

        switch profile.availabilityRequirement {
        case .alwaysPresent:
            return loadedProfile?.kind == profile.kind ? .inUse : .bundled
        case .downloadRequired:
            break
        }

        if loadedProfile?.kind == profile.kind {
            return .inUse
        }

        if onDemandManager.isDownloading(profile: profile) {
            return .downloading(progress: onDemandManager.downloadProgress(profile: profile))
        }

        if onDemandManager.isAvailable(profile: profile) {
            return .ready
        }

        if let lastError = onDemandManager.lastError(profile: profile), !lastError.isEmpty {
            return .failed(message: lastError)
        }

        if onDemandManager.hasPreparedResources(profile: profile) {
            return .released
        }

        return .notInstalled
    }
}

struct DeviceCapabilities {
    /// Determines if the device has sufficient physical memory to run the SLM locally (requires >= 8GB).
    static var hasSufficientMemoryForAI: Bool {
        AIModelRuntimePolicy.isDeviceEligibleForAnyAI
    }
}
