import Foundation
import SwiftUI
import MLX
import MLXLMCommon
import Darwin.Mach

struct AIMemoryCheckpoint: Codable, Identifiable, Hashable {
    let id: UUID
    let label: String
    let timestamp: Date
    let physicalFootprintBytes: UInt64
    let activeMemoryBytes: Int64
    let cacheMemoryBytes: Int64
    let peakMemoryBytes: Int64
}

struct AIOperationState: Codable, Equatable {
    let phase: String
    let timestamp: Date
    let profileName: String?
    let inProgress: Bool
    let details: String?
}

struct AILastCompletedRun: Codable, Equatable {
    let profileKindRaw: String
    let profileName: String
    let timestamp: Date
    let modelDescriptor: String?

    var profileKind: AIModelProfile.Kind? {
        AIModelProfile.Kind(rawValue: profileKindRaw)
    }
}

@Observable
@MainActor
class MLXManager {
    static let shared = MLXManager()
    private let gpuCacheLimitBytes = 20 * 1024 * 1024
    private let memoryCheckpointsDefaultsKey = "ai.diagnostics.memoryCheckpoints"
    private let operationStateDefaultsKey = "ai.diagnostics.lastOperationState"
    private let lastCompletedRunDefaultsKey = "ai.diagnostics.lastCompletedRun"
    
    struct GenerationOverride {
        var maxTokens: Int?
        var temperature: Float?
        var topP: Float?
        var topK: Int?
        var minP: Float?
        var repetitionPenalty: Float?
        var repetitionContextSize: Int?
        var presencePenalty: Float?
        var presenceContextSize: Int?
        var frequencyPenalty: Float?
        var frequencyContextSize: Int?
        var maxKVSize: Int?
        var kvBits: Int?
        var prefillStepSize: Int?
    }
    
    // UI States
    var isModelLoaded = false
    var isGenerating = false
    var currentResponse: String = ""
    var loadErrorMessage: String?
    var loadedProfile: AIModelProfile?
    var loadedModelDescriptor: String?
    var lastPromptTokenCount = 0
    var lastGenerationTokenCount = 0
    var lastPromptTokensPerSecond: Double = 0
    var lastGenerationTokensPerSecond: Double = 0
    var memoryCheckpoints: [AIMemoryCheckpoint] = []
    var lastOperationState: AIOperationState?
    var lastCompletedRun: AILastCompletedRun?
    
    // MLX Engine references
    var context: ModelContext?
    
    private init() {
        restorePersistedDiagnostics()
    }

    var unexpectedTerminationSummary: String? {
        guard let lastOperationState, lastOperationState.inProgress else { return nil }
        var summary = "Previous AI session may have ended unexpectedly during \(lastOperationState.phase)"
        if let profileName = lastOperationState.profileName {
            summary += " on \(profileName)"
        }
        summary += "."
        if let details = lastOperationState.details, !details.isEmpty {
            summary += " \(details)"
        }
        return summary
    }

    var lastCompletedRunSummary: String? {
        guard let lastCompletedRun else { return nil }
        var summary = "\(lastCompletedRun.profileName) at \(lastCompletedRun.timestamp.formatted(date: .omitted, time: .shortened))"
        if let modelDescriptor = lastCompletedRun.modelDescriptor, !modelDescriptor.isEmpty {
            summary += "\n\(modelDescriptor)"
        }
        return summary
    }
    
    /// Called when the view appears or when the user explicitly requests to load the model into memory.
    func loadModelIfNeeded(preferredProfile: AIModelProfile = AIModelRuntimePolicy.requestedProfile) async {
        if isModelLoaded, loadedProfile == preferredProfile {
            return
        }

        if isModelLoaded, loadedProfile != preferredProfile {
            unloadModel()
        }

        loadErrorMessage = nil

        // Keep Metal cache tight to lower memory pressure on long prompts.
        MLX.Memory.cacheLimit = gpuCacheLimitBytes
        updateOperationState(
            phase: "Loading model",
            profileName: preferredProfile.displayName,
            inProgress: true,
            details: "Preparing on-device model resources."
        )
        recordMemoryCheckpoint("before model load (\(preferredProfile.displayName))")

        let candidates = AIModelRuntimePolicy.resolutionOrder(preferredKind: preferredProfile.kind)
        var loadFailures: [String] = []

        for profile in candidates {
            guard AIModelRuntimePolicy.canRun(profile: profile) else {
                loadFailures.append("\(profile.displayName): device memory below required threshold")
                continue
            }

            if case .onDemand = profile.deliveryMode {
                let isAvailable = await OnDemandModelManager.shared.ensureAvailable(profile: profile)
                if !isAvailable {
                    let reason = OnDemandModelManager.shared.lastError(profile: profile) ?? "\(profile.displayName): on-demand resource unavailable"
                    loadFailures.append(reason)
                    continue
                }
            }

            for directory in profile.preferredBundleDirectories {
                guard let directoryURL = Bundle.main.url(forResource: directory, withExtension: nil) else {
                    continue
                }

                let modelFileURL = directoryURL.appendingPathComponent("model.safetensors")
                let tokenizerFileURL = directoryURL.appendingPathComponent("tokenizer.json")

                guard fileExists(modelFileURL), fileExists(tokenizerFileURL) else {
                    loadFailures.append("\(profile.displayName): missing model/tokenizer in \(directory)")
                    continue
                }

                if isGitLFSPointer(at: modelFileURL) || isGitLFSPointer(at: tokenizerFileURL) {
                    loadFailures.append("\(profile.displayName): model files are Git LFS pointers in \(directory)")
                    continue
                }

                do {
                    self.context = try await MLXLMCommon.loadModel(directory: directoryURL)
                    self.isModelLoaded = true
                    self.loadedProfile = profile
                    self.loadedModelDescriptor = buildModelDescriptor(from: directoryURL)
                    self.loadErrorMessage = nil
                    recordMemoryCheckpoint("after model load (\(profile.displayName))")
                    updateOperationState(
                        phase: "Model loaded",
                        profileName: profile.displayName,
                        inProgress: false,
                        details: loadedModelDescriptor
                    )
                    print("Loaded AI model profile: \(profile.displayName) from \(directory)")
                    if let loadedModelDescriptor {
                        print("Loaded AI model descriptor: \(loadedModelDescriptor)")
                    }
                    return
                } catch {
                    loadFailures.append(friendlyLoadFailureMessage(error: error, profile: profile))
                    self.context = nil
                    self.isModelLoaded = false
                    self.loadedProfile = nil
                }
            }
        }

        // Fallback for flattened resources when folder references are not preserved.
        if let tokenizerURL = Bundle.main.url(forResource: "tokenizer", withExtension: "json") {
            let directoryURL = tokenizerURL.deletingLastPathComponent()
            let modelFileURL = directoryURL.appendingPathComponent("model.safetensors")
            if fileExists(modelFileURL), !isGitLFSPointer(at: modelFileURL), !isGitLFSPointer(at: tokenizerURL) {
                do {
                    self.context = try await MLXLMCommon.loadModel(directory: directoryURL)
                    self.isModelLoaded = true
                    self.loadedProfile = .qwen3_17bLegacy
                    self.loadedModelDescriptor = buildModelDescriptor(from: directoryURL)
                    self.loadErrorMessage = nil
                    updateOperationState(
                        phase: "Flattened fallback model loaded",
                        profileName: AIModelProfile.qwen3_17bLegacy.displayName,
                        inProgress: false,
                        details: loadedModelDescriptor
                    )
                    print("Loaded flattened fallback model directory at bundle root.")
                    if let loadedModelDescriptor {
                        print("Loaded AI model descriptor: \(loadedModelDescriptor)")
                    }
                    return
                } catch {
                    loadFailures.append("Flattened fallback: \(error.localizedDescription)")
                }
            }
        }

        self.isModelLoaded = false
        self.loadedProfile = nil
        self.loadedModelDescriptor = nil
        if loadFailures.isEmpty {
            loadErrorMessage = "Could not find bundled on-device model files. Add a Qwen model folder under Resources."
        } else {
            loadErrorMessage = "Unable to load a compatible on-device model. \(loadFailures.joined(separator: " | "))"
        }
        updateOperationState(
            phase: "Model load failed",
            profileName: preferredProfile.displayName,
            inProgress: false,
            details: loadErrorMessage
        )
    }
    
    /// Generates the AI stream from split system/user prompts.
    func generate(
        systemPrompt: String,
        userPrompt: String,
        requestedProfile: AIModelProfile,
        override: GenerationOverride? = nil
    ) async {
        guard let context = self.context, isModelLoaded else {
            loadErrorMessage = loadErrorMessage ?? "Model is not loaded."
            updateOperationState(
                phase: "Generation blocked",
                profileName: requestedProfile.displayName,
                inProgress: false,
                details: loadErrorMessage
            )
            return
        }
        guard !isGenerating else { return }
        
        loadErrorMessage = nil
        self.isGenerating = true
        self.currentResponse = ""
        let profile = loadedProfile ?? requestedProfile
        updateOperationState(
            phase: "Generating response",
            profileName: profile.displayName,
            inProgress: true,
            details: "Running prompt prefill and token generation."
        )
        recordMemoryCheckpoint("before analyze (\(profile.displayName))")
        let gpuBefore = MLX.Memory.snapshot()
        print("AI Advisor GPU before: \(gpuBefore.description)")
        var generationCompleted = false

        defer {
            self.isGenerating = false
            let gpuAfter = MLX.Memory.snapshot()
            print("AI Advisor GPU after: \(gpuAfter.description)")
            if generationCompleted {
                recordMemoryCheckpoint("after generation (\(profile.displayName))")
                lastCompletedRun = AILastCompletedRun(
                    profileKindRaw: profile.kind.rawValue,
                    profileName: profile.displayName,
                    timestamp: Date(),
                    modelDescriptor: loadedModelDescriptor
                )
                persistLastCompletedRun()
                updateOperationState(
                    phase: "Generation complete",
                    profileName: profile.displayName,
                    inProgress: false,
                    details: "Generated \(lastGenerationTokenCount) tokens."
                )
            }
        }
        
        do {
            let generationConfig = profile.generation
            let effectiveMaxTokens = override?.maxTokens ?? generationConfig.maxTokens
            let effectiveTemperature = override?.temperature ?? generationConfig.temperature
            let effectiveTopP = override?.topP ?? generationConfig.topP
            let effectiveTopK = override?.topK ?? generationConfig.topK
            let effectiveMinP = override?.minP ?? generationConfig.minP
            let effectiveRepetitionPenalty = override?.repetitionPenalty ?? generationConfig.repetitionPenalty
            let effectiveRepetitionContextSize = override?.repetitionContextSize ?? 96
            let effectivePresencePenalty = override?.presencePenalty ?? generationConfig.presencePenalty
            let effectivePresenceContextSize = override?.presenceContextSize ?? 96
            let effectiveFrequencyPenalty = override?.frequencyPenalty ?? generationConfig.frequencyPenalty
            let effectiveFrequencyContextSize = override?.frequencyContextSize ?? 96
            let effectiveMaxKVSize = override?.maxKVSize ?? generationConfig.maxKVSize
            let effectiveKVBits = override?.kvBits ?? generationConfig.kvBits
            let effectivePrefillStepSize = override?.prefillStepSize ?? generationConfig.prefillStepSize

            // 1. Process string into LLM tokens
            let userInput = UserInput(
                chat: [
                    .system(systemPrompt),
                    .user(userPrompt),
                ],
                additionalContext: ["enable_thinking": generationConfig.enableThinking]
            )
            let lmInput = try await context.processor.prepare(input: userInput)
            
            // 2. Configure generation constraints
            var parameters = GenerateParameters(
                maxTokens: effectiveMaxTokens,
                maxKVSize: effectiveMaxKVSize,
                kvBits: effectiveKVBits,
                temperature: effectiveTemperature,
                topP: effectiveTopP,
                topK: effectiveTopK,
                minP: effectiveMinP,
                repetitionPenalty: effectiveRepetitionPenalty,
                repetitionContextSize: effectiveRepetitionContextSize,
                presencePenalty: effectivePresencePenalty,
                presenceContextSize: effectivePresenceContextSize,
                frequencyPenalty: effectiveFrequencyPenalty,
                frequencyContextSize: effectiveFrequencyContextSize
            )
            parameters.prefillStepSize = effectivePrefillStepSize
            
            // 3. Request the Async stream
            let stream = try MLXLMCommon.generate(
                input: lmInput,
                parameters: parameters,
                context: context
            )
            
            // 4. Stream response to SwiftUI using the Async Sequence
            var didRecordPostPrefill = false
            for await event in stream {
                switch event {
                case .chunk(let text):
                    if !didRecordPostPrefill {
                        didRecordPostPrefill = true
                        recordMemoryCheckpoint("after prefill (\(profile.displayName))")
                        updateOperationState(
                            phase: "Prefill completed",
                            profileName: profile.displayName,
                            inProgress: true,
                            details: "Model finished prompt ingestion and began decoding."
                        )
                    }
                    self.currentResponse += text
                case .info(let info):
                    self.lastPromptTokenCount = info.promptTokenCount
                    self.lastGenerationTokenCount = info.generationTokenCount
                    self.lastPromptTokensPerSecond = info.promptTokensPerSecond
                    self.lastGenerationTokensPerSecond = info.tokensPerSecond

                    let promptTPS = String(format: "%.1f", info.promptTokensPerSecond)
                    let generationTPS = String(format: "%.1f", info.tokensPerSecond)
                    let summary = "AI profile=\(profile.displayName), " +
                        "promptTokens=\(info.promptTokenCount), generatedTokens=\(info.generationTokenCount), " +
                        "maxTokens=\(effectiveMaxTokens), promptTPS=\(promptTPS), genTPS=\(generationTPS)"
                    print("AI Advisor generation complete. \(summary)")
                    if info.generationTokenCount >= effectiveMaxTokens {
                        print("AI Advisor generation hit the max token cap (\(effectiveMaxTokens)).")
                    }
                default:
                    break
                }
            }
            generationCompleted = true
        } catch {
            if !Task.isCancelled {
                self.loadErrorMessage = "Generation failed: \(error.localizedDescription)"
                updateOperationState(
                    phase: "Generation failed",
                    profileName: profile.displayName,
                    inProgress: false,
                    details: error.localizedDescription
                )
                print("Generation failed: \(error)")
            }
        }
    }

    /// Backward-compatible entry point for call sites still using a single prompt string.
    func generate(prompt: String, maxTokens: Int = 320) async {
        let profile = loadedProfile ?? AIModelRuntimePolicy.defaultProfile
        let fallbackSystemPrompt = "Role: admissions personal statement reviewer. Follow all explicit constraints."
        await generate(systemPrompt: fallbackSystemPrompt, userPrompt: prompt, requestedProfile: profile)
    }
    
    func reset() {
        self.currentResponse = ""
        self.isGenerating = false
        self.loadErrorMessage = nil
        updateOperationState(
            phase: "Advisor state reset",
            profileName: loadedProfile?.displayName,
            inProgress: false,
            details: nil
        )
    }

    func unloadModel(releasingResourceAccess: Bool = false) {
        let unloadedProfile = loadedProfile
        if releasingResourceAccess, let unloadedProfile, case .onDemand = unloadedProfile.deliveryMode {
            OnDemandModelManager.shared.release(profile: unloadedProfile)
        }
        context = nil
        isModelLoaded = false
        loadedProfile = nil
        loadedModelDescriptor = nil
        Stream().synchronize()
        Memory.clearCache()
        recordMemoryCheckpoint("after unload")
        updateOperationState(
            phase: "Model unloaded",
            profileName: unloadedProfile?.displayName,
            inProgress: false,
            details: releasingResourceAccess
                ? "Released model references, cleared MLX cache, and ended on-demand resource access."
                : "Released model references and cleared MLX cache while keeping the model pack ready for the next run."
        )
    }

    func clearPersistedDiagnostics() {
        memoryCheckpoints.removeAll()
        lastOperationState = nil
        lastCompletedRun = nil
        UserDefaults.standard.removeObject(forKey: memoryCheckpointsDefaultsKey)
        UserDefaults.standard.removeObject(forKey: operationStateDefaultsKey)
        UserDefaults.standard.removeObject(forKey: lastCompletedRunDefaultsKey)
    }

    func clearMLXCache() {
        Stream().synchronize()
        Memory.clearCache()
        recordMemoryCheckpoint("after cache clear")
        updateOperationState(
            phase: "MLX cache cleared",
            profileName: loadedProfile?.displayName,
            inProgress: false,
            details: "Freed reusable MLX buffers."
        )
    }

    private func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private func friendlyLoadFailureMessage(error: Error, profile: AIModelProfile) -> String {
        let lowercased = error.localizedDescription.lowercased()
        if lowercased.contains("qwen3_5") || lowercased.contains("unknown model") {
            return "\(profile.displayName): runtime does not recognize this model architecture. Use an MLX-converted Qwen3/Qwen3.5 bundle compatible with mlx-swift-lm 2.30.6+."
        }
        return "\(profile.displayName): \(error.localizedDescription)"
    }

    private func isGitLFSPointer(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 256) else { return false }
        guard let prefix = String(data: data, encoding: .utf8) else { return false }
        return prefix.contains("git-lfs.github.com/spec/v1")
    }

    private func buildModelDescriptor(from directoryURL: URL) -> String? {
        let configURL = directoryURL.appendingPathComponent("config.json")
        guard
            let data = try? Data(contentsOf: configURL),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let modelType = json["model_type"] as? String ?? "unknown"
        let architecture = (json["architectures"] as? [String])?.first ?? "unknown"
        return "\(directoryURL.lastPathComponent) (\(modelType), \(architecture))"
    }

    private func recordMemoryCheckpoint(_ label: String) {
        let snapshot = MLX.Memory.snapshot()
        let checkpoint = AIMemoryCheckpoint(
            id: UUID(),
            label: label,
            timestamp: Date(),
            physicalFootprintBytes: currentPhysicalFootprint(),
            activeMemoryBytes: Int64(snapshot.activeMemory),
            cacheMemoryBytes: Int64(snapshot.cacheMemory),
            peakMemoryBytes: Int64(snapshot.peakMemory)
        )
        memoryCheckpoints.append(checkpoint)
        if memoryCheckpoints.count > 20 {
            memoryCheckpoints.removeFirst(memoryCheckpoints.count - 20)
        }
        persistMemoryCheckpoints()

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        let footprint = formatter.string(fromByteCount: Int64(checkpoint.physicalFootprintBytes))
        print("AI memory checkpoint [\(checkpoint.label)] footprint=\(footprint) active=\(snapshot.activeMemory) cache=\(snapshot.cacheMemory) peak=\(snapshot.peakMemory)")
    }

    private func updateOperationState(
        phase: String,
        profileName: String?,
        inProgress: Bool,
        details: String?
    ) {
        lastOperationState = AIOperationState(
            phase: phase,
            timestamp: Date(),
            profileName: profileName,
            inProgress: inProgress,
            details: details
        )
        persistOperationState()
    }

    private func restorePersistedDiagnostics() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: memoryCheckpointsDefaultsKey),
           let checkpoints = try? JSONDecoder().decode([AIMemoryCheckpoint].self, from: data) {
            memoryCheckpoints = checkpoints
        }

        if let data = defaults.data(forKey: operationStateDefaultsKey),
           let operationState = try? JSONDecoder().decode(AIOperationState.self, from: data) {
            lastOperationState = operationState
        }

        if let data = defaults.data(forKey: lastCompletedRunDefaultsKey),
           let lastCompletedRun = try? JSONDecoder().decode(AILastCompletedRun.self, from: data) {
            self.lastCompletedRun = lastCompletedRun
        }
    }

    private func persistMemoryCheckpoints() {
        guard let data = try? JSONEncoder().encode(memoryCheckpoints) else { return }
        UserDefaults.standard.set(data, forKey: memoryCheckpointsDefaultsKey)
    }

    private func persistOperationState() {
        guard let lastOperationState,
              let data = try? JSONEncoder().encode(lastOperationState)
        else {
            UserDefaults.standard.removeObject(forKey: operationStateDefaultsKey)
            return
        }
        UserDefaults.standard.set(data, forKey: operationStateDefaultsKey)
    }

    private func persistLastCompletedRun() {
        guard let lastCompletedRun,
              let data = try? JSONEncoder().encode(lastCompletedRun)
        else {
            UserDefaults.standard.removeObject(forKey: lastCompletedRunDefaultsKey)
            return
        }
        UserDefaults.standard.set(data, forKey: lastCompletedRunDefaultsKey)
    }

    private func currentPhysicalFootprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return info.phys_footprint
    }
}
