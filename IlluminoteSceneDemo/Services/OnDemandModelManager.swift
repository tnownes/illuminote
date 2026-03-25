import Foundation
import Observation

@Observable
final class OnDemandModelManager {
    static let shared = OnDemandModelManager()
    private let preparedStateDefaultsPrefix = "ai.odr.prepared."

    private struct DownloadState {
        var isDownloading = false
        var progress: Double = 0
        var lastError: String?
    }

    private var requests: [AIModelProfile.Kind: NSBundleResourceRequest] = [:]
    private var progressObservers: [AIModelProfile.Kind: NSKeyValueObservation] = [:]
    private var states: [AIModelProfile.Kind: DownloadState] = [:]
    private var inFlightDownloads: [AIModelProfile.Kind: Task<Bool, Never>] = [:]

    private init() {}

    func isAvailable(profile: AIModelProfile) -> Bool {
        resolveResourceDirectory(for: profile) != nil
    }

    func isDownloading(profile: AIModelProfile) -> Bool {
        states[profile.kind]?.isDownloading ?? false
    }

    func hasPreparedResources(profile: AIModelProfile) -> Bool {
        UserDefaults.standard.bool(forKey: preparedStateDefaultsKey(for: profile.kind))
    }

    func downloadProgress(profile: AIModelProfile) -> Double {
        if isAvailable(profile: profile) {
            return 1
        }
        return states[profile.kind]?.progress ?? 0
    }

    func lastError(profile: AIModelProfile) -> String? {
        states[profile.kind]?.lastError
    }

    @discardableResult
    func ensureAvailable(profile: AIModelProfile) async -> Bool {
        if isAvailable(profile: profile) {
            updateState(for: profile.kind, isDownloading: false, progress: 1, lastError: nil)
            persistPreparedState(true, for: profile.kind)
            return true
        }

        if let existingTask = inFlightDownloads[profile.kind] {
            return await existingTask.value
        }

        guard case .onDemand(let tag) = profile.deliveryMode else {
            let message = "Bundled model files were not found for \(profile.displayName)."
            updateState(for: profile.kind, isDownloading: false, progress: 0, lastError: message)
            return false
        }

        let task = Task { [weak self] in
            guard let self else { return false }

            let request = self.resourceRequest(for: profile.kind, tag: tag)
            request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
            self.observeProgress(for: profile.kind, request: request)
            self.updateState(for: profile.kind, isDownloading: true, progress: max(self.states[profile.kind]?.progress ?? 0, 0.01), lastError: nil)

            do {
                try await self.beginAccessingResources(for: request)
            } catch {
                let message = "Could not download \(profile.displayName): \(error.localizedDescription)"
                self.updateState(for: profile.kind, isDownloading: false, progress: 0, lastError: message)
                return false
            }

            if self.isAvailable(profile: profile) {
                self.updateState(for: profile.kind, isDownloading: false, progress: 1, lastError: nil)
                self.persistPreparedState(true, for: profile.kind)
                return true
            }

            let message = "\(profile.displayName) finished downloading, but the required MLX model files were not found in the tagged resource pack."
            self.updateState(for: profile.kind, isDownloading: false, progress: 0, lastError: message)
            return false
        }

        inFlightDownloads[profile.kind] = task
        let result = await task.value
        inFlightDownloads[profile.kind] = nil
        return result
    }

    func release(profile: AIModelProfile) {
        let kind = profile.kind
        inFlightDownloads.removeValue(forKey: kind)?.cancel()
        if let request = requests.removeValue(forKey: kind) {
            request.progress.cancel()
            request.endAccessingResources()
        }
        progressObservers.removeValue(forKey: kind)?.invalidate()
        updateState(
            for: kind,
            isDownloading: false,
            progress: isAvailable(profile: profile) ? 1 : 0,
            lastError: nil
        )
    }

    private func resolveResourceDirectory(for profile: AIModelProfile) -> URL? {
        for directory in profile.preferredBundleDirectories {
            guard let directoryURL = Bundle.main.url(forResource: directory, withExtension: nil) else {
                continue
            }

            let modelURL = directoryURL.appendingPathComponent("model.safetensors")
            let tokenizerURL = directoryURL.appendingPathComponent("tokenizer.json")
            guard fileExists(modelURL), fileExists(tokenizerURL) else {
                continue
            }
            if isGitLFSPointer(at: modelURL) || isGitLFSPointer(at: tokenizerURL) {
                continue
            }
            return directoryURL
        }
        return nil
    }

    private func resourceRequest(for kind: AIModelProfile.Kind, tag: String) -> NSBundleResourceRequest {
        if let request = requests[kind] {
            return request
        }

        let request = NSBundleResourceRequest(tags: [tag])
        request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        requests[kind] = request
        return request
    }

    private func observeProgress(for kind: AIModelProfile.Kind, request: NSBundleResourceRequest) {
        if progressObservers[kind] != nil {
            return
        }

        progressObservers[kind] = request.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] progress, _ in
            guard let self else { return }
            let current = min(max(progress.fractionCompleted, 0), 1)
            self.updateState(for: kind, isDownloading: current < 1, progress: current, lastError: nil)
        }
    }

    private func beginAccessingResources(for request: NSBundleResourceRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            request.beginAccessingResources { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func updateState(
        for kind: AIModelProfile.Kind,
        isDownloading: Bool,
        progress: Double,
        lastError: String?
    ) {
        states[kind] = DownloadState(
            isDownloading: isDownloading,
            progress: progress,
            lastError: lastError
        )
    }

    private func persistPreparedState(_ prepared: Bool, for kind: AIModelProfile.Kind) {
        UserDefaults.standard.set(prepared, forKey: preparedStateDefaultsKey(for: kind))
    }

    private func preparedStateDefaultsKey(for kind: AIModelProfile.Kind) -> String {
        preparedStateDefaultsPrefix + kind.rawValue
    }

    private func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private func isGitLFSPointer(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 256) else { return false }
        guard let prefix = String(data: data, encoding: .utf8) else { return false }
        return prefix.contains("git-lfs.github.com/spec/v1")
    }
}
