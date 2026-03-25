import SwiftUI
import SwiftData
import UIKit

// MARK: - Native Rich Text Editor
struct PSRichTextEditorView: View {
    @Bindable var draft: StatementDraft
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    // State for the editor
    @State private var attributedText: NSAttributedString = NSAttributedString(string: "")
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    
    // Formatting State
    @State private var isBold: Bool = false
    @State private var isItalic: Bool = false
    @State private var showingAIAdvisor = false
    
    // Editor Configuration
    @State private var fontName: String = "HelveticaNeue" // Default body font
    @State private var fontSize: CGFloat = 17
    


    
    // Internal coordinate for bridge
    private let textStorage = NSTextStorage()

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }

    private var editorForegroundColor: UIColor {
        useImmersive ? .white : .label
    }

    private enum ReviewState {
        case notReviewed
        case reviewed
        case needsReReview
    }

    private var currentDraftTextForStatus: String {
        attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var reviewState: ReviewState {
        guard let snapshot = AdvisorFeedbackStore.loadLatest(for: draft.id) else {
            return .notReviewed
        }
        guard !currentDraftTextForStatus.isEmpty else {
            return .notReviewed
        }
        let currentHash = AdvisorFeedbackStore.hash(for: currentDraftTextForStatus)
        return snapshot.analyzedTextHash == currentHash ? .reviewed : .needsReReview
    }

    private var reviewStateLabel: String {
        switch reviewState {
        case .notReviewed: return "Not Reviewed"
        case .reviewed: return "Reviewed"
        case .needsReReview: return "Needs Re-Review"
        }
    }

    private var reviewStateForeground: Color {
        switch reviewState {
        case .notReviewed:
            return useImmersive ? DSColor.textSecondary : .secondary
        case .reviewed:
            return useImmersive ? DSColor.success : .green
        case .needsReReview:
            return useImmersive ? DSColor.warning : .orange
        }
    }

    private var reviewStateBackground: Color {
        switch reviewState {
        case .notReviewed:
            return useImmersive ? DSColor.surfaceElevated : Color(uiColor: .tertiarySystemFill)
        case .reviewed:
            return useImmersive ? DSColor.success.opacity(0.18) : Color.green.opacity(0.14)
        case .needsReReview:
            return useImmersive ? DSColor.warning.opacity(0.18) : Color.orange.opacity(0.14)
        }
    }

    private var reviewStateChip: some View {
        Text(reviewStateLabel)
            .font(DSFont.caption)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(reviewStateForeground)
            .background(Capsule().fill(reviewStateBackground))
    }

    private var draftScopeChip: some View {
        Text(draft.draftScope.shortLabel)
            .font(DSFont.caption)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
            .background(
                Capsule().fill(
                    useImmersive ? DSColor.surfaceElevated : Color(uiColor: .tertiarySystemFill)
                )
            )
    }
    
    var body: some View {
        ZStack {
            if useImmersive {
                SacredScreenBackground(settings: settings)
            }
            VStack(spacing: useImmersive ? DSSpacing.sm : 0) {
                VStack(spacing: 0) {
                    RichTextToolbar(
                        isBold: isBold,
                        isItalic: isItalic,
                        useImmersive: useImmersive,
                        toggleBold: { toggleAttribute(.font, value: UIFont.boldSystemFont(ofSize: fontSize)) }, // Simplified toggle logic needed
                        toggleItalic: { toggleTrait(.traitItalic) },
                        toggleUnderline: { toggleAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue) },
                        alignLeft: { setAlignment(.left) },
                        alignCenter: { setAlignment(.center) },
                        alignRight: { setAlignment(.right) }
                    )
                    .padding(.vertical, 8)
                    .background(useImmersive ? Color.clear : Color(uiColor: .secondarySystemBackground))
                    
                    Divider()
                        .background(useImmersive ? DSColor.divider : Color(uiColor: .separator))
                }
                .if(useImmersive) { view in
                    view
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.top, DSSpacing.sm)
                        .sacredCardStyle(highlighted: false)
                }
                
                // MARK: - Editor
                NativeUITextViewWrapper(
                    text: $attributedText,
                    selectedRange: $selectedRange,
                    isBold: $isBold,
                    isItalic: $isItalic,
                    useImmersive: useImmersive
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, useImmersive ? DSSpacing.md : 0)
                .padding(.bottom, useImmersive ? DSSpacing.sm : 0)
                .background(useImmersive ? Color.clear : Color(uiColor: .systemBackground))
                .if(useImmersive) { view in
                    view.sacredCardStyle(highlighted: false)
                }
            }
        }
        .background(useImmersive ? Color.clear : Color(uiColor: .systemGroupedBackground))
        .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 3) {
                    Text(draft.title.isEmpty ? "Untitled Draft" : draft.title)
                        .font(DSFont.heading2)
                        .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    HStack(spacing: 6) {
                        draftScopeChip
                        reviewStateChip
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAIAdvisor = true
                } label: {
                    Label("AI Advisor", systemImage: "sparkles")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveDraft() }
                    .tint(useImmersive ? DSColor.goldLight : .accentColor)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: StatementDraftExportable(payload: draft.toFilePayload(), title: draft.title), preview: SharePreview(draft.title, icon: Image(systemName: "doc.text"))) {
                     Image(systemName: "square.and.arrow.up")
                }
                .tint(useImmersive ? DSColor.goldLight : .accentColor)
            }

        }
        .sheet(isPresented: $showingAIAdvisor) {
            AIAdvisorPanel(
                draftContent: advisorSeedText,
                draftID: draft.id,
                initialGuidelineScope: draft.draftScope.asAdvisorGuidelineScope
            )
                .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
        }
        .onAppear {
            Task { @MainActor in
                loadDraft()
            }
        }
        .onDisappear {
            Task {
                await MainActor.run {
                    saveDraft()
                }
            }
        }
        .onChange(of: settings.appThemeMode) { _, _ in
            attributedText = normalizedAttributedText(attributedText)
        }


    }
    
    // MARK: - Logic
    
    private func loadDraft() {
        if let data = draft.richTextData {
            do {
                let loadedText = try NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                )
                attributedText = normalizedAttributedText(loadedText)
            } catch {
                print("Error loading RTF: \(error)")
            }
        } else if !draft.sections.isEmpty {
            // Migration: Convert plain text sections to RTF
            let fullText = draft.sections.sorted(by: { $0.order < $1.order })
                .map { $0.content }
                .joined(separator: "\n\n")
            
            let mutable = NSMutableAttributedString(string: fullText)
            // Set default font
            mutable.addAttribute(.font, value: UIFont.systemFont(ofSize: 17), range: NSRange(location: 0, length: fullText.count))
            mutable.addAttribute(.foregroundColor, value: editorForegroundColor, range: NSRange(location: 0, length: fullText.count))
            attributedText = normalizedAttributedText(mutable)
        }
    }

    private func normalizedAttributedText(_ text: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: text)
        let range = NSRange(location: 0, length: mutable.length)
        guard range.length > 0 else { return mutable }
        mutable.addAttribute(.foregroundColor, value: editorForegroundColor, range: range)
        return mutable
    }

    private var advisorSeedText: String {
        let liveText = attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !liveText.isEmpty {
            return liveText
        }

        if let data = draft.richTextData,
           let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
           ) {
            let savedText = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !savedText.isEmpty {
                return savedText
            }
        }

        return draft.sections
            .sorted(by: { $0.order < $1.order })
            .map(\.content)
            .joined(separator: "\n\n")
    }
    
    private func saveDraft() {
        do {
            let data = try attributedText.data(
                from: NSRange(location: 0, length: attributedText.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            draft.richTextData = data
            draft.dateModified = Date()
            try? modelContext.save()
        } catch {
            print("Error saving RTF: \(error)")
        }
    }
    
    // Removed legacy exportDraft() and exportDocument state in favor of ShareLink
    
    // MARK: - Formatting Helpers
    
    // ... helper logic methods follow
    // In a real implementation this requires more robust attribute inspection of currently selected range.
    // For MVP, we pass commands to the wrapper via Binding or Notification? 
    // Actually, modifying `attributedText` directly triggers the UIViewRepresentable to update.
    // BUT preserving selection and not resetting typing state is tricky with direct State update.
    // A better approach for formatting is usually direct commands to the UITextView via a Coordinator or ID.
    // We will stick to simple attribute modification on the binding for now, 
    // aware that full-blown rich text editors often need a reference to the UITextView or TextKit.
    
    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        // This is complex to simple "toggle" without checking current selection state
        // We need 'current attributes' from the selection. 
        // For this MVP step, I will implement a simpler 'Apply' approach 
        // or delegate this to the UIKit layer through a Coordinator if possible.
        // Let's rely on the UIKit layer (UIViewRepresentable) to expose a "applyAttribute" API? 
        // No, SwiftUI views act on State.
        // I'll leave placeholders inside the view above, but the real logic needs the UITextView.
        // See NativeUITextViewWrapper below.
        
        // NotificationCenter is a quick way to send commands to the active editor
        NotificationCenter.default.post(name: .applyFormatCommand, object: nil, userInfo: ["trait": trait])
    }
    
    private func toggleAttribute(_ key: NSAttributedString.Key, value: Any) {
         NotificationCenter.default.post(name: .applyFormatCommand, object: nil, userInfo: ["key": key, "value": value])
    }
    
    private func setAlignment(_ alignment: NSTextAlignment) {
        NotificationCenter.default.post(name: .applyParagraphStyle, object: nil, userInfo: ["alignment": alignment])
    }
}

extension Notification.Name {
    static let applyFormatCommand = Notification.Name("PSRichTextEditor_ApplyFormat")
    static let applyParagraphStyle = Notification.Name("PSRichTextEditor_ApplyParagraph")
}

// MARK: - Export Helper
struct StatementDraftExportable: Transferable {
    var payload: StatementDraftFilePayload
    var title: String
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .rtf) { exportable in
            let tempDir = FileManager.default.temporaryDirectory
            // Sanitize filename
            let safeTitle = exportable.title.replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let fileName = "\(safeTitle).rtf"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            try? FileManager.default.removeItem(at: fileURL)
            
            // Prefer existing rich text data
            if let rtfData = exportable.payload.richTextData {
                try rtfData.write(to: fileURL)
            } else {
                // Fallback: Create simple RTF from sections if no rich text data exists (legacy migration support)
                let fullText = exportable.payload.sections.sorted(by: { $0.order < $1.order })
                    .map { $0.content }
                    .joined(separator: "\n\n")
                
                let attributed = NSAttributedString(string: fullText)
                let data = try attributed.data(from: NSRange(location: 0, length: attributed.length),
                                             documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                try data.write(to: fileURL)
            }
            
            return SentTransferredFile(fileURL)
        } importing: { received in
            // Basic import support for RTF
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent(received.file.lastPathComponent)
            try FileManager.default.copyItem(at: received.file, to: temp)
            let data = try Data(contentsOf: temp)
            
            // We need to wrap this back into a payload structure for the app to understand,
            // or we just return a payload that encapsulates this new RTF.
            // Since this is primarily for EXPORT per the user request, we will keep the import simple/stubbed 
            // or best-effort for now as the user primarily cared about export.
            // NOTE: Re-importing a raw RTF into a structured StatementDraftFilePayload (which expects sections/metadata) is lossy.
            // We will create a fresh payload with the RTF content.
            
            return StatementDraftExportable(
                payload: StatementDraftFilePayload(
                    id: UUID(),
                    title: received.file.deletingPathExtension().lastPathComponent,
                    version: 1,
                    draftScopeRaw: StatementDraftScope.full.rawValue,
                    isFinal: false,
                    isLocked: false,
                    dateCreated: Date(),
                    dateModified: Date(),
                    richTextData: data,
                    sections: [] // We lose specific sections on RTF re-import, treated as one blob
                ),
                title: received.file.deletingPathExtension().lastPathComponent
            )
        }
    }
}

// MARK: - Toolbar View
struct RichTextToolbar: View {
    var isBold: Bool
    var isItalic: Bool
    var useImmersive: Bool
    var toggleBold: () -> Void
    var toggleItalic: () -> Void
    var toggleUnderline: () -> Void
    var alignLeft: () -> Void
    var alignCenter: () -> Void
    var alignRight: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                Group {
                    Button(action: toggleBold) { 
                        Image(systemName: "bold")
                            .foregroundStyle(isBold ? DSColor.goldLight : (useImmersive ? DSColor.textPrimary : .primary))
                            .padding(4)
                            .background(isBold ? DSColor.goldLight.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Button(action: toggleItalic) { 
                        Image(systemName: "italic")
                            .foregroundStyle(isItalic ? DSColor.goldLight : (useImmersive ? DSColor.textPrimary : .primary))
                            .padding(4)
                            .background(isItalic ? DSColor.goldLight.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Button(action: toggleUnderline) {
                        Image(systemName: "underline")
                            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                    }
                }
                
                Divider().frame(height: 20)
                
                Group {
                    Button(action: alignLeft) {
                        Image(systemName: "text.alignleft")
                            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                    }
                    Button(action: alignCenter) {
                        Image(systemName: "text.aligncenter")
                            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                    }
                    Button(action: alignRight) {
                        Image(systemName: "text.alignright")
                            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Native UITextView Wrapper
struct NativeUITextViewWrapper: UIViewRepresentable {
    @Binding var text: NSAttributedString
    @Binding var selectedRange: NSRange
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    let useImmersive: Bool

    private var targetForegroundColor: UIColor {
        useImmersive ? .white : .label
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.attributedText = normalizedText(text, color: targetForegroundColor)
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 17) // Default
        textView.allowsEditingTextAttributes = true
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.keyboardAppearance = useImmersive ? .dark : .default
        textView.tintColor = useImmersive ? UIColor(DSColor.goldLight) : .systemBlue
        textView.typingAttributes[.foregroundColor] = targetForegroundColor
        
        // Store reference for commands
        context.coordinator.textView = textView
        
        // Listen for internal commands
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.handleFormatCommand(_:)), name: .applyFormatCommand, object: nil)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.handleParagraphCommand(_:)), name: .applyParagraphStyle, object: nil)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        let normalized = normalizedText(text, color: targetForegroundColor)

        // Prevent cyclic updates: Only update if content changed meaningfully
        if uiView.attributedText != normalized {
            context.coordinator.isUpdatingFromSwiftUI = true
            let selection = uiView.selectedRange
            uiView.attributedText = normalized
            uiView.selectedRange = selection
            context.coordinator.isUpdatingFromSwiftUI = false
        }
        uiView.keyboardAppearance = useImmersive ? .dark : .default
        uiView.tintColor = useImmersive ? UIColor(DSColor.goldLight) : .systemBlue
        if var typingAttributes = uiView.typingAttributes as [NSAttributedString.Key : Any]? {
            typingAttributes[.foregroundColor] = targetForegroundColor
            uiView.typingAttributes = typingAttributes
        }
    }

    private func normalizedText(_ attributed: NSAttributedString, color: UIColor) -> NSAttributedString {
        guard attributed.length > 0 else { return attributed }
        let mutable = NSMutableAttributedString(attributedString: attributed)
        mutable.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: mutable.length))
        return mutable
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: NativeUITextViewWrapper
        weak var textView: UITextView?
        var isUpdatingFromSwiftUI = false
        
        // Track current font info to smartly toggle bold/italic
        // This requires inspecting the attributed string at selection.
        
        init(_ parent: NativeUITextViewWrapper) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdatingFromSwiftUI else { return }
            enforceForegroundColor(in: textView)
            parent.text = textView.attributedText
            parent.selectedRange = textView.selectedRange
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdatingFromSwiftUI else { return }
            self.parent.selectedRange = textView.selectedRange
            if parent.useImmersive {
                var typing = textView.typingAttributes
                typing[.foregroundColor] = UIColor.white
                textView.typingAttributes = typing
            } else {
                var typing = textView.typingAttributes
                typing[.foregroundColor] = UIColor.label
                textView.typingAttributes = typing
            }
            // Update UI toolbar state binding
            updateFormattingState(textView)
        }

        private func enforceForegroundColor(in textView: UITextView) {
            let targetColor: UIColor = parent.useImmersive ? .white : .label
            guard textView.attributedText.length > 0 else { return }

            var needsNormalization = false
            textView.attributedText.enumerateAttribute(
                .foregroundColor,
                in: NSRange(location: 0, length: textView.attributedText.length),
                options: []
            ) { value, _, stop in
                guard let color = value as? UIColor else {
                    needsNormalization = true
                    stop.pointee = true
                    return
                }

                if !color.isEqual(targetColor) {
                    needsNormalization = true
                    stop.pointee = true
                }
            }

            guard needsNormalization else { return }

            let selection = textView.selectedRange
            let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
            mutable.addAttribute(.foregroundColor, value: targetColor, range: NSRange(location: 0, length: mutable.length))

            isUpdatingFromSwiftUI = true
            textView.attributedText = mutable
            textView.selectedRange = selection
            isUpdatingFromSwiftUI = false

            var typing = textView.typingAttributes
            typing[.foregroundColor] = targetColor
            textView.typingAttributes = typing
        }
        
        private func updateFormattingState(_ textView: UITextView) {
            let font: UIFont?
            
            if textView.selectedRange.length > 0 {
                // Check attribute at start of selection
                if let f = textView.attributedText.attribute(.font, at: textView.selectedRange.location, effectiveRange: nil) as? UIFont {
                    font = f
                } else {
                    font = nil
                }
            } else {
                font = textView.typingAttributes[.font] as? UIFont
            }
            
            if let font = font {
                parent.isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                parent.isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
            } else {
                parent.isBold = false
                parent.isItalic = false
            }
        }
        
        // MARK: - Command Handling
        @objc func handleFormatCommand(_ notification: Notification) {
            guard let textView = self.textView else { return }
            guard let userInfo = notification.userInfo else { return }
            
            // Trait Handling (Bold/Italic)
            if let trait = userInfo["trait"] as? UIFontDescriptor.SymbolicTraits {
                toggleTrait(trait, in: textView)
            }
            // Attribute Handling (Underline)
            else if let key = userInfo["key"] as? NSAttributedString.Key, let value = userInfo["value"] {
                toggleAttribute(key, value: value, in: textView)
            }
        }
        
        @objc func handleParagraphCommand(_ notification: Notification) {
            guard let textView = self.textView else { return }
            guard let align = notification.userInfo?["alignment"] as? NSTextAlignment else { return }
            
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = align
            
            let range = textView.selectedRange
            let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
            mutable.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraph, range: range.length > 0 ? range : NSRange(location: range.location, length: 0))
            
            // To apply to current typing attributes:
            var current = textView.typingAttributes
            current[NSAttributedString.Key.paragraphStyle] = paragraph
            textView.typingAttributes = current
            
            // To apply to selection
            if range.length > 0 {
                textView.textStorage.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraph, range: range)
            }
            
            // Update binding
            parent.text = textView.attributedText
        }
        
        private func toggleAttribute(_ key: NSAttributedString.Key, value: Any, in textView: UITextView) {
            let range = textView.selectedRange
            var attributes = textView.typingAttributes
            
            if range.length > 0 {
                 // Check if already applied. If so, remove.
                 // Simplification: Just applying 'value' for now.
                 // Real toggle logic requires inspecting range.
                 textView.textStorage.addAttribute(key, value: value, range: range)
            }
            
            attributes[key] = value
            textView.typingAttributes = attributes
            parent.text = textView.attributedText
        }
        
        private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits, in textView: UITextView) {
            let range = textView.selectedRange
            
            // Function to flip font trait
            let flipFont: (UIFont) -> UIFont = { font in
                var traits = font.fontDescriptor.symbolicTraits
                if traits.contains(trait) {
                    traits.remove(trait)
                } else {
                    traits.insert(trait)
                }
                
                if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                    return UIFont(descriptor: descriptor, size: font.pointSize)
                }
                return font
            }
            
            if range.length > 0 {
                textView.textStorage.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
                    if let font = value as? UIFont {
                        let newFont = flipFont(font)
                        textView.textStorage.addAttribute(.font, value: newFont, range: subRange)
                    }
                }
            } else {
                if let font = textView.typingAttributes[.font] as? UIFont {
                    textView.typingAttributes[.font] = flipFont(font)
                }
            }
            
             parent.text = textView.attributedText
        }
    }
}
