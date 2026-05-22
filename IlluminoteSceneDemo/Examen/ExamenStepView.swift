import SwiftUI

struct ExamenStepView: View {
    // MARK: - Inputs
    let promptID: UUID?
    let question: String
    let sessionReferencePrompt: String
    let stageName: String // New
    let showDebugStageLabel: Bool
    let initialText: String
    let currentStep: Int // Added for styling
    var onNext: (String) -> Void
    // onBack removed as it is now handled by parent view

    /// If true, the note editor starts expanded (e.g., step 5). Otherwise it starts collapsed.
    let isFinalStep: Bool
    /// If true, displays the "Write a Note" button in the bottom bar.
    let showNoteButton: Bool
    /// If true, surfaces a one-time first-use cue for note-taking.
    let showPromptToolsHint: Bool
    /// If true, the note editor can append dictated text.
    let allowsVoiceTranscription: Bool
    /// Session-level speech toggle state driven by parent flow.
    let isPromptSpeechEnabled: Bool
    /// If true, displays the prompt speech toggle.
    let allowsPromptSpeech: Bool
    /// Toggles session-level speech behavior for the current Examen run.
    let onTogglePromptSpeech: () -> Void
    /// Placeholder for the reflection capture field.
    let notePlaceholder: String

    // Controls whether the TextEditor is visible
    @State private var showEditor: Bool = false
    // The user's in‑progress answer for this step
    @State private var draft: String = ""
    // Manage focus for the TextEditor
    @FocusState private var editorFocused: Bool
    
    // Live Dictation Manager
    @EnvironmentObject private var speechManager: SpeechRecognitionManager
    @EnvironmentObject private var promptSpeechManager: PromptSpeechManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var displayedQuestion: String = ""
    @State private var outgoingQuestion: String?
    @State private var incomingPromptOpacity: Double = 1
    @State private var outgoingPromptOpacity: Double = 0
    @State private var promptTransitionTask: Task<Void, Never>?

    private var isAccessibilityTextSize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var resolvedReferencePrompt: String {
        let trimmed = sessionReferencePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? question : trimmed
    }

    private var promptFontCandidates: [CGFloat] {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return [42, 40, 38, 36, 34, 32, 30, 28, 26, 24]
        case .medium, .large:
            return [40, 38, 36, 34, 32, 30, 28, 26, 24, 22]
        case .xLarge, .xxLarge:
            return [38, 36, 34, 32, 30, 28, 26, 24, 22, 20]
        case .xxxLarge, .accessibility1:
            return [36, 34, 32, 30, 28, 26, 24, 22, 20]
        default:
            return [34, 32, 30, 28, 26, 24, 22, 20, 18]
        }
    }

    private var promptContainerMinHeight: CGFloat {
        isAccessibilityTextSize ? 260 : 200
    }

    private var promptContainerMaxHeight: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium, .large:
            return 360
        case .xLarge, .xxLarge, .xxxLarge:
            return 420
        case .accessibility1, .accessibility2:
            return 520
        default:
            return 580
        }
    }

    private var contentPadding: CGFloat {
        isAccessibilityTextSize ? DSSpacing.lg : DSSpacing.xl
    }

    // MARK: - Backward-compatible initializer
    init(question: String, isFinalStep: Bool = false, onNext: @escaping () -> Void) {
        self.promptID = nil
        self.question = question
        self.sessionReferencePrompt = ""
        self.stageName = ""
        self.showDebugStageLabel = false
        self.initialText = ""
        self.currentStep = 0
        self.isFinalStep = isFinalStep
        self.showNoteButton = isFinalStep // Default behavior
        self.showPromptToolsHint = false
        self.allowsVoiceTranscription = true
        self.isPromptSpeechEnabled = false
        self.allowsPromptSpeech = true
        self.onTogglePromptSpeech = {}
        self.notePlaceholder = "Type your note..."
        self.onNext = { _ in onNext() }
    }

    // MARK: - Preferred initializer
    init(promptID: UUID? = nil,
         question: String,
         sessionReferencePrompt: String = "",
         stageName: String = "",
         showDebugStageLabel: Bool = false,
         initialText: String = "",
         currentStep: Int = 0,
         isFinalStep: Bool = false,
         showNoteButton: Bool = false,
         showPromptToolsHint: Bool = false,
         allowsVoiceTranscription: Bool = true,
         isPromptSpeechEnabled: Bool = false,
         allowsPromptSpeech: Bool = true,
         onTogglePromptSpeech: @escaping () -> Void = {},
         notePlaceholder: String = "Type your note...",
         onNext: @escaping (String) -> Void,
         onBack: (() -> Void)? = nil) {
        self.promptID = promptID
        self.question = question
        self.sessionReferencePrompt = sessionReferencePrompt
        self.stageName = stageName
        self.showDebugStageLabel = showDebugStageLabel
        self.initialText = initialText
        self.currentStep = currentStep
        self.isFinalStep = isFinalStep
        self.showNoteButton = showNoteButton
        self.showPromptToolsHint = showPromptToolsHint
        self.allowsVoiceTranscription = allowsVoiceTranscription
        self.isPromptSpeechEnabled = isPromptSpeechEnabled
        self.allowsPromptSpeech = allowsPromptSpeech
        self.onTogglePromptSpeech = onTogglePromptSpeech
        self.notePlaceholder = notePlaceholder
        self.onNext = onNext
    }

    var body: some View {
        ZStack {
            // Glass-pane overlay inset from edges
            /* Removed manual background, handled by ExamenFlowView's ZStack */

            // 2) Content layer
            VStack(spacing: isAccessibilityTextSize ? DSSpacing.md : DSSpacing.lg) {
                VStack(spacing: isAccessibilityTextSize ? DSSpacing.xs : DSSpacing.sm) {
                    if showDebugStageLabel && !stageName.isEmpty {
                        Text(stageName.uppercased())
                            .font(DSFont.eyebrow)
                            .foregroundStyle(DSColor.quietTextMuted)
                            .padding(.top, 4)
                    }

                    ZStack {
                        if let outgoingQuestion {
                            promptLayout(
                                text: outgoingQuestion,
                                accessibilityHidden: true
                            )
                            .opacity(outgoingPromptOpacity)
                        }

                        promptLayout(
                            text: activePromptText,
                            accessibilityHidden: false
                        )
                        .opacity(incomingPromptOpacity)
                    }
                    .frame(
                        minHeight: promptContainerMinHeight,
                        maxHeight: showEditor ? max(promptContainerMinHeight, promptContainerMaxHeight * 0.72) : promptContainerMaxHeight,
                        alignment: .center
                    )
                    .padding(.vertical, isAccessibilityTextSize ? DSSpacing.md : DSSpacing.lg)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, isAccessibilityTextSize ? DSSpacing.sm : DSSpacing.md)
                .padding(.vertical, isAccessibilityTextSize ? DSSpacing.sm : DSSpacing.md)
                .appSurfaceStyle(role: .reading, highlighted: true)
                .accessibilityElement(children: .contain)
                .accessibilitySortPriority(2)

                if showEditor {
                    ZStack(alignment: .bottomTrailing) {
                        TextEditor(text: $draft)
                            .scrollContentBackground(.hidden)
                            .focused($editorFocused)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled(false)
                            .frame(minHeight: 180)
                            .padding(12)
                            .padding(.bottom, allowsVoiceTranscription ? 44 : 8)
                            .background(DSColor.readingSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(DSColor.dividerSoft, lineWidth: 1)
                            )
                            .foregroundStyle(DSColor.textPrimary)
                            .accessibilityLabel("Your response")
                            .textSelection(.enabled)

                        // Lightweight placeholder when empty
                        if draft.isEmpty {
                            Text(notePlaceholder)
                                .font(DSFont.body)
                                .foregroundStyle(DSColor.quietText)
                                .padding(.top, 20)
                                .padding(.leading, 16)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .allowsHitTesting(false)
                        }
                        
                        if allowsVoiceTranscription {
                            Button {
                                if speechManager.isRecording {
                                    speechManager.stopRecording()
                                    appendTranscriptIfAvailable()
                                } else {
                                    promptSpeechManager.stop()
                                    do {
                                        try speechManager.startRecording()
                                    } catch {
                                        print("Speech start error:", error)
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: speechManager.isRecording ? "stop.fill" : "mic.fill")
                                        .font(.headline)
                                    if speechManager.isRecording {
                                        Text("Listening...")
                                            .font(DSFont.meta)
                                            .fontWeight(.medium)
                                    }
                                }
                                .foregroundStyle(speechManager.isRecording ? .white : DSColor.textSecondary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    speechManager.isRecording
                                        ? AnyShapeStyle(Color.red.opacity(0.9))
                                        : AnyShapeStyle(Material.ultraThinMaterial)
                                )
                                .clipShape(Capsule())
                                .shadow(radius: 2)
                            }
                            .padding(12)
                        }
                    }
                    .appSurfaceStyle(role: .interactive)
                }

                Spacer(minLength: isAccessibilityTextSize ? DSSpacing.xs : DSSpacing.sm)

                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    if shouldShowPromptToolsHint {
                        Text("Write a note any time")
                            .font(DSFont.supporting)
                            .foregroundStyle(DSColor.quietText)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }

                    ViewThatFits(in: .horizontal) {
                        promptControlsRow(labelStyle: .full)
                        promptControlsRow(labelStyle: .compact)

                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            promptToolsCluster(labelStyle: .full)
                            nextButton
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.bottom, DSSpacing.sm)
                .accessibilitySortPriority(1)
            }
            .animation(.easeInOut(duration: 0.2), value: showEditor)
            .padding(contentPadding)
            // Top Left Back Button removed here, moved to parent container
        }
        .onAppear {
            displayedQuestion = question
            incomingPromptOpacity = 1
            outgoingPromptOpacity = 0
            syncDraftWithCurrentPrompt()
        }
        .onDisappear {
            promptTransitionTask?.cancel()
            promptTransitionTask = nil
        }
        .onChange(of: promptID, initial: false) { _, _ in
            syncDraftWithCurrentPrompt()
        }
        .onChange(of: question, initial: false) { oldQuestion, newQuestion in
            guard newQuestion != oldQuestion else { return }
            crossfadePrompt(to: newQuestion)
        }
        .onChange(of: showEditor, initial: false) { _, isShown in
            if isShown { editorFocused = true }
        }
        // Live transcript update
        .onChange(of: speechManager.transcript) { _, newTranscript in
            // Typically we'd append only on stop. 
            // But if we want "live" updates in the text editor, we need a way to insert it.
            // A simple approach is to show the live transcript in a separate overlay or 
            // append it temporarily? 
            // User requested: "As the user speaks, the partial transcription updates live."
            // Simple implementation: Let 'draft' = 'savedText' + 'currentTranscript'.
            // For now, let's keep it simple: Commit on Stop. 
            // Or, if we want live update, we have to manage the cursor carefully.
            // Let's stick to commit-on-stop for safety as implemented in button action, 
            // UNLESS user insists on live text editor updates which is tricky with SwiftUI TextEditor binding.
            // Re-reading plan: "As the user speaks, the partial transcription updates live."
            // Ideally we show it maybe below the text editor or overlay?
            // Or we just update `draft`.
            // Let's try updating draft if it's safe? No, that messes up if user types simultaneously.
            // Better: Show a "Listening..." indicator with the live text.
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    editorFocused = false
                    // Also dismiss the editor overlay if it was not auto-enabled (e.g. final step)
                    // or if the user wants to close it.
                    // User request: "allow the user to dismiss the note screen when they click the 'Done' button"
                    withAnimation {
                         showEditor = false
                    }
                }
            }
        }
    }

    private func appendTranscriptIfAvailable() {
        let newText = speechManager.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newText.isEmpty {
            draft += (draft.isEmpty ? "" : " ") + newText
        }
    }

    private func syncDraftWithCurrentPrompt() {
        draft = initialText
        showEditor = isFinalStep || !initialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !showEditor {
            editorFocused = false
        }
    }

    private var activePromptText: String {
        displayedQuestion.isEmpty ? question : displayedQuestion
    }

    private var shouldShowPromptToolsHint: Bool {
        showPromptToolsHint && !showEditor
    }

    private var nextButtonRowWidth: CGFloat {
        isAccessibilityTextSize ? 144 : 156
    }

    private func crossfadePrompt(to newQuestion: String) {
        promptTransitionTask?.cancel()

        let currentQuestion = displayedQuestion.isEmpty ? question : displayedQuestion
        guard newQuestion != currentQuestion else { return }

        outgoingQuestion = currentQuestion
        displayedQuestion = newQuestion
        outgoingPromptOpacity = 1
        incomingPromptOpacity = 0

        withAnimation(AnimationConfig.examenPromptCrossfade) {
            outgoingPromptOpacity = 0
            incomingPromptOpacity = 1
        }

        promptTransitionTask = Task { @MainActor in
            let duration = UInt64(AnimationConfig.examenReflectiveLeadInDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: duration)
            guard !Task.isCancelled else { return }
            outgoingQuestion = nil
        }
    }

    @ViewBuilder
    private func promptLayout(text: String, accessibilityHidden: Bool) -> some View {
        ViewThatFits(in: .vertical) {
            ForEach(promptFontCandidates, id: \.self) { pointSize in
                // Use the longest prompt in the session as the fitting reference so typography stays stable across steps.
                ZStack {
                    promptText(
                        resolvedReferencePrompt,
                        pointSize: pointSize,
                        hidden: true,
                        accessibilityHidden: true
                    )
                    promptText(
                        text,
                        pointSize: pointSize,
                        hidden: false,
                        accessibilityHidden: accessibilityHidden
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func promptText(_ text: String, pointSize: CGFloat, hidden: Bool, accessibilityHidden: Bool) -> some View {
        Text(text)
            .font(.system(size: pointSize, weight: .regular, design: .serif))
            .foregroundStyle(hidden ? Color.clear : DSColor.textPrimary)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, DSSpacing.md)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(accessibilityHidden)
            .allowsHitTesting(false)
    }

    private enum PromptControlsLabelStyle {
        case full
        case compact
    }

    @ViewBuilder
    private func promptControlsRow(labelStyle: PromptControlsLabelStyle) -> some View {
        HStack(alignment: .center, spacing: DSSpacing.sm) {
            promptToolsCluster(labelStyle: labelStyle)
            Spacer(minLength: DSSpacing.sm)
            nextButton
                .frame(width: nextButtonRowWidth)
        }
    }

    @ViewBuilder
    private func promptToolsCluster(labelStyle: PromptControlsLabelStyle) -> some View {
        HStack(spacing: DSSpacing.sm) {
            if showNoteButton {
                Button {
                    withAnimation(AnimationConfig.confirmation) {
                        showEditor.toggle()
                    }
                } label: {
                    Label(noteButtonTitle(for: labelStyle),
                          systemImage: showEditor ? "keyboard.chevron.compact.down" : "square.and.pencil")
                        .font(DSFont.meta.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.appSecondary)
                .accessibilityLabel(showEditor ? "Hide note" : "Write a note")
                .accessibilityHint(showEditor ? "Closes the note editor." : "Opens the note editor for this prompt.")
            }

            if allowsPromptSpeech {
                Button {
                    if speechManager.isRecording {
                        speechManager.stopRecording()
                        appendTranscriptIfAvailable()
                    }
                    onTogglePromptSpeech()
                } label: {
                    Image(systemName: isPromptSpeechEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.headline)
                        .appCircleControl(active: isPromptSpeechEnabled, emphasized: isPromptSpeechEnabled)
                }
                .accessibilityLabel(isPromptSpeechEnabled ? "Turn prompt speech off" : "Turn prompt speech on")
            }
        }
    }

    private func noteButtonTitle(for style: PromptControlsLabelStyle) -> String {
        if showEditor {
            return "Hide"
        }

        switch style {
        case .full:
            return "Write"
        case .compact:
            return "Write"
        }
    }

    private var nextButton: some View {
        Button {
            if speechManager.isRecording {
                speechManager.stopRecording()
                appendTranscriptIfAvailable()
            }

            editorFocused = false
            onNext(draft.trimmingCharacters(in: .whitespacesAndNewlines))
        } label: {
            HStack(spacing: 8) {
                Text("Next")
                    .fontWeight(.medium)
                Image(systemName: "chevron.right")
            }
            .padding(.horizontal, DSSpacing.sm)
        }
        .buttonStyle(SacredButtonStyle())
        .accessibilityLabel("Next step")
    }
}

#if DEBUG
struct ExamenStepView_Previews: PreviewProvider {
    static var previews: some View {
        ExamenStepView(
            question: "Where did you feel most alive today?",
            initialText: "I noticed …",
            isFinalStep: true,
            onNext: { _ in }
        )
        .background(Color.black)
    }
}
#endif
