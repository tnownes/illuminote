import Foundation
import Speech
import AVFoundation

class SpeechRecognitionManager: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    
    @Published var transcript: String = ""
    @Published var isRecording = false
    
    // Check authorizations
    func requestPermissions() async throws {
        // Request Speech Authorization
        let speechAuth = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechAuth == .authorized else {
            print("Speech recognition not authorized.")
            return
        }
        
        // Request Mic Authorization
        let micAuth = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard micAuth else {
            print("Microphone access not granted.")
            return
        }
    }
    
    func startRecording() throws {
        // Cancel existing task if any
        if task != nil {
            task?.cancel()
            task = nil
        }
        
        let recognizer = SFSpeechRecognizer()
        guard recognizer?.isAvailable == true else { return }
        
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { return }
        request.shouldReportPartialResults = true
        
        let audioSession = AVAudioSession.sharedInstance()
        // Use .playAndRecord so we can return to prompt playback in-session without stale input-only state.
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on the input node
        inputNode.removeTap(onBus: 0) // Safety remove
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        transcript = ""
        
        // Keep a reference to the task so we can cancel it
        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                // If there's an error or it's final (e.g. timeout), stop
                self.stopRecording()
            }
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        isRecording = false
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

@MainActor
final class PromptSpeechManager: NSObject, ObservableObject, @preconcurrency AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var requestedPromptID: UUID?
    private var requestedText: String?

    @Published private(set) var isSpeaking = false
    @Published private(set) var isPaused = false
    @Published private(set) var currentPromptID: UUID?

    var onUtteranceFinished: ((UUID?) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(text: String, promptID: UUID?, rate: Double) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if requestedPromptID == promptID && requestedText == trimmed {
            return
        }

        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("PromptSpeechManager audio session error: \(error)")
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        if let preferredVoice = AVSpeechSynthesisVoice(language: Locale.current.identifier) {
            utterance.voice = preferredVoice
        }
        utterance.rate = Float(rate)
        utterance.prefersAssistiveTechnologySettings = true

        requestedPromptID = promptID
        requestedText = trimmed
        currentPromptID = promptID
        synthesizer.speak(utterance)
    }

    func stop() {
        guard synthesizer.isSpeaking || synthesizer.isPaused || requestedPromptID != nil || currentPromptID != nil else { return }
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        isPaused = false
        currentPromptID = nil
        requestedPromptID = nil
        requestedText = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func pause() {
        guard synthesizer.isSpeaking else { return }
        _ = synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        guard synthesizer.isPaused else { return }
        _ = synthesizer.continueSpeaking()
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
        isPaused = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        isSpeaking = false
        isPaused = true
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        isSpeaking = true
        isPaused = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let finishedPromptID = currentPromptID
        isSpeaking = false
        isPaused = false
        currentPromptID = nil
        requestedPromptID = nil
        requestedText = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        onUtteranceFinished?(finishedPromptID)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        isPaused = false
        currentPromptID = nil
        requestedPromptID = nil
        requestedText = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
