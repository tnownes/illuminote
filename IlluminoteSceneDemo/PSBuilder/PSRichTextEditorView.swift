import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

// MARK: - Native Rich Text Editor
struct PSRichTextEditorView: View {
    @Bindable var draft: StatementDraft
    var onClose: (() -> Void)? = nil
    var isWritingMapVisible: Bool = false
    var onToggleWritingMap: (() -> Void)? = nil
    var onAdvisorPresentationChange: ((Bool) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \UserProfile.id) private var profiles: [UserProfile]
    @Query(sort: [SortDescriptor(\StatementDraft.dateModified, order: .reverse)])
    private var syncedDrafts: [StatementDraft]
    
    // State for the editor
    @State private var attributedText: NSAttributedString = NSAttributedString(string: "")
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    
    // Formatting State
    @State private var isBold: Bool = false
    @State private var isItalic: Bool = false
    @State private var isAdvisorPresented = false
    @State private var isOutlinePresented = false
    @State private var advisorDraftText = ""
    @State private var advisorReviewID = UUID()
    @State private var showingTargetPicker = false
    @State private var showingRenameDraftDialog = false
    @State private var draftRenameText = ""
    @State private var persistenceAlert: PersistenceAlertContext?
    @State private var showExportRTF = false
    @State private var showExportTXT = false
    @State private var exportDraftDocument: RichTextDocument?
    @State private var exportDraftTextDocument: PlainTextDocument?
    @State private var requirements: [StatementRequirement] = []
    @State private var availableTargets: [WritingTargetDefinition] = []
    @State private var activeDraftConflict: DraftSyncConflict?
    @State private var draftSyncStatusMessage: String?
    @State private var hasLoadedDraftSnapshot = false
    @State private var loadedDraftContentFingerprint = Data()
    @State private var observedDraftModifiedAt: Date?
    @State private var lastLocalSaveAt: Date?
    @State private var lastLocalSaveFingerprint = Data()
    
    // Editor Configuration
    @State private var fontName: String = "HelveticaNeue" // Default body font
    @State private var fontSize: CGFloat = 17
    


    
    // Internal coordinate for bridge
    private let textStorage = NSTextStorage()
    private let requirementsService = LocalStatementRequirementsService()
    private let targetCatalogService = LocalWritingTargetCatalogService()

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }

    private var usesWideEditorCanvas: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    private var allowsAdvisor: Bool {
        AppSettings.featurePolicy.allowsAdvisor
    }

    private var showsAdvancedWritingTools: Bool {
        AppSettings.featurePolicy.showsAdvancedWritingTools
    }

    private var editorCanvasMaxWidth: CGFloat {
        usesWideEditorCanvas ? 860 : .infinity
    }

    private var editorForegroundColor: UIColor {
        useImmersive ? .white : .label
    }

    private enum ReviewState {
        case notReviewed
        case reviewed
        case needsReReview
    }

    fileprivate struct DraftSyncConflict: Identifiable {
        let id = UUID()
        let remoteModifiedAt: Date
        let remotePreview: String
    }

    private var currentDraftTextForStatus: String {
        attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var syncedDraftSnapshot: StatementDraft? {
        syncedDrafts.first { $0.id == draft.id }
    }

    private var syncedDraftChangeToken: String {
        guard let syncedDraftSnapshot else { return "missing-\(draft.id.uuidString)" }
        let richTextSize = syncedDraftSnapshot.richTextData?.count ?? 0
        let sectionSignature = syncedDraftSnapshot.sections
            .sorted(by: { $0.order < $1.order })
            .map { "\($0.id.uuidString):\($0.order):\($0.content.count):\($0.date.timeIntervalSinceReferenceDate)" }
            .joined(separator: "|")
        return [
            syncedDraftSnapshot.id.uuidString,
            syncedDraftSnapshot.dateModified.timeIntervalSinceReferenceDate.description,
            (syncedDraftSnapshot.syncRevision ?? 0).description,
            richTextSize.description,
            sectionSignature
        ].joined(separator: "::")
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
        case .notReviewed: return "Not Yet Reviewed"
        case .reviewed: return "Reviewed"
        case .needsReReview: return "Updated Since Review"
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

    private var currentProfile: UserProfile? {
        profiles.first
    }

    private var currentTarget: WritingTargetDefinition? {
        targetCatalogService.target(
            withID: draft.writingTargetID,
            for: currentProfile,
            requirements: requirements
        )
    }

    private var currentServiceLabel: String? {
        currentTarget?.serviceCode?.displayName
    }

    private var characterCount: Int {
        currentDraftTextForStatus.count
    }

    private var characterLimit: Int? {
        currentTarget?.characterLimitMax
    }

    private var progressFraction: Double? {
        guard let characterLimit, characterLimit > 0 else { return nil }
        return Double(characterCount) / Double(characterLimit)
    }

    private var progressTint: Color {
        guard let progressFraction else { return useImmersive ? DSColor.goldLight : DSColor.brandAccent }
        if progressFraction > 1 {
            return useImmersive ? DSColor.error : .red
        }
        if progressFraction >= 0.9 {
            return useImmersive ? DSColor.warning : .orange
        }
        return useImmersive ? DSColor.goldLight : DSColor.brandAccent
    }

    private var progressText: String {
        if let characterLimit {
            return "\(characterCount) / \(characterLimit) chars"
        }
        return "\(characterCount) chars"
    }

    private var targetTitleText: String {
        currentTarget?.title ?? "Needs Assignment"
    }

    private var snapshotChip: some View {
        Group {
            if draft.isSnapshot {
                Text("Snapshot")
                    .font(DSFont.caption)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(useImmersive ? DSColor.goldLight : .orange)
                    .background(
                        Capsule().fill(
                            useImmersive ? DSColor.goldLight.opacity(0.18) : Color.orange.opacity(0.14)
                        )
                    )
            }
        }
    }

    private var writingContextCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(alignment: .top, spacing: DSSpacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Essay Type")
                        .font(DSFont.caption.weight(.semibold))
                        .foregroundStyle(useImmersive ? DSColor.quietTextMuted : .secondary)
                    Text(targetTitleText)
                        .font(DSFont.body.weight(.semibold))
                        .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                    if let currentServiceLabel {
                        Text(currentServiceLabel)
                            .font(DSFont.caption)
                            .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                    }
                    draftScopeChip
                }
                Spacer()
                if allowsAdvisor {
                    reviewStateChip
                }
                snapshotChip
            }

            if let customPrompt = draft.customPromptText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !customPrompt.isEmpty {
                Text(customPrompt)
                    .font(DSFont.caption)
                    .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text(progressText)
                    .font(DSFont.caption.weight(.semibold))
                    .foregroundStyle(progressTint)
                Spacer()
                Button(draft.writingTargetID == nil ? "Assign Essay Type" : "Change Essay Type") {
                    showingTargetPicker = true
                }
                .font(DSFont.caption.weight(.semibold))
            }

            if let progressFraction {
                ProgressView(value: min(progressFraction, 1))
                    .tint(progressTint)
                    .accessibilityLabel(progressText)
            }
        }
        .padding(DSSpacing.md)
        .if(useImmersive) { view in
            view.sacredCardStyle(highlighted: false)
        }
        .if(!useImmersive) { view in
            view.appSurfaceStyle(role: .interactive, highlighted: false)
        }
    }

    private var writingGuidanceMenu: some View {
        Menu {
            Link("AAMC essays", destination: URL(string: "https://students-residents.aamc.org/how-apply-medical-school-amcas/section-8-amcas-application-essays")!)
            Link("AACOMAS statement", destination: URL(string: "https://help.liaisonedu.com/AACOMAS_Applicant_Help_Center/Filling_Out_Your_AACOMAS_Application/Supporting_Information/5_Personal_Statement")!)
            Link("TMDSAS guide", destination: URL(string: "https://www.tmdsas.com/application-guide/")!)
        } label: {
            Label("Guidance", systemImage: "book")
        }
        .tint(useImmersive ? DSColor.goldLight : .accentColor)
        .accessibilityLabel("Writing guidance")
    }
    
    var body: some View {
        ZStack {
            if useImmersive {
                SacredScreenBackground(settings: settings)
            }
            VStack(spacing: useImmersive ? DSSpacing.sm : 0) {
                writingContextCard
                    .padding(.horizontal, useImmersive ? DSSpacing.md : DSSpacing.lg)
                    .padding(.top, useImmersive ? DSSpacing.sm : DSSpacing.lg)

                draftSyncNotice
                    .padding(.horizontal, useImmersive ? DSSpacing.md : DSSpacing.lg)

                if showsAdvancedWritingTools {
                    VStack(spacing: 0) {
                        RichTextToolbar(
                            isBold: isBold,
                            isItalic: isItalic,
                            useImmersive: useImmersive,
                            toggleBold: { toggleTrait(.traitBold) },
                            toggleItalic: { toggleTrait(.traitItalic) },
                            toggleUnderline: { toggleAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue) },
                            toggleStrikethrough: { toggleAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue) },
                            applyTextColor: applyTextColor,
                            clearTextColor: clearTextColor,
                            applyHighlight: applyHighlight,
                            clearHighlight: clearHighlight,
                            clearRevisionFormatting: clearRevisionFormatting,
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
            .frame(maxWidth: editorCanvasMaxWidth, maxHeight: .infinity)
            .frame(maxWidth: .infinity)
        }
        .background(useImmersive ? Color.clear : Color(uiColor: .systemGroupedBackground))
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onClose != nil || shouldShowWritingMapToggle {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if shouldShowWritingMapToggle, let onToggleWritingMap {
                        Button {
                            onToggleWritingMap()
                        } label: {
                            Label("Hide Writing Map", systemImage: "sidebar.left")
                        }
                        .tint(useImmersive ? DSColor.goldLight : .accentColor)
                        .accessibilityLabel("Hide Writing Map")
                    }

                    if let onClose {
                        Button {
                            saveDraft()
                            onClose()
                        } label: {
                            Label("Close Draft", systemImage: "xmark")
                        }
                        .tint(useImmersive ? DSColor.goldLight : .accentColor)
                        .accessibilityLabel("Close Draft")
                    }
                }
            }
            ToolbarItem(placement: .principal) {
                Text(draft.title.isEmpty ? "Untitled Draft" : draft.title)
                    .font(DSFont.heading2)
                    .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if allowsAdvisor {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        toggleAdvisor()
                    } label: {
                        Label("Advisor", systemImage: "sparkles")
                    }
                    .tint(isAdvisorPresented ? (useImmersive ? DSColor.goldLight : DSColor.brandAccent) : (useImmersive ? DSColor.goldLight : .accentColor))
                    .accessibilityLabel(isAdvisorPresented ? "Hide Advisor" : "Show Advisor")
                    .accessibilityValue(isAdvisorPresented ? "Open" : "Closed")
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    writingGuidanceMenu
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isOutlinePresented.toggle()
                } label: {
                    Label("Outline", systemImage: "list.bullet.indent")
                }
                .tint(isOutlinePresented ? (useImmersive ? DSColor.goldLight : DSColor.brandAccent) : (useImmersive ? DSColor.goldLight : .accentColor))
                .accessibilityLabel("Document Outline")
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
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename Draft") {
                        beginRenameDraft()
                    }
                    Button("Save Snapshot") {
                        saveSnapshot()
                    }
                    Button(draft.writingTargetID == nil ? "Assign Essay Type" : "Change Essay Type") {
                        showingTargetPicker = true
                    }
                    
                    Divider()
                    
                    Button {
                        prepareRTFExport()
                    } label: {
                        Label("Export Draft (RTF)", systemImage: "doc.richtext")
                    }
                    
                    Button {
                        prepareTXTExport()
                    } label: {
                        Label("Export Draft (TXT)", systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .tint(useImmersive ? DSColor.goldLight : .accentColor)
            }

        }
        .inspector(isPresented: $isAdvisorPresented) {
            AIAdvisorPanel(
                draftContent: advisorDraftText,
                draftID: draft.id,
                initialGuidelineScope: draft.draftScope.asAdvisorGuidelineScope
            )
            .id(advisorReviewID)
            .inspectorColumnWidth(min: 340, ideal: 390, max: 460)
            .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
        }
        .inspector(isPresented: $isOutlinePresented) {
            OutlineNavigatorPanel(
                headings: parseHeadings(from: attributedText),
                useImmersive: useImmersive,
                onSelect: { heading in
                    NotificationCenter.default.post(
                        name: .scrollToRangeCommand,
                        object: nil,
                        userInfo: ["range": heading.range]
                    )
                }
            )
            .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
            .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
        }
        .sheet(isPresented: $showingTargetPicker) {
            WritingDraftAssignmentSheet(
                draft: draft,
                targets: availableTargets
            )
            .presentationBackground(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemBackground))
        }
        .alert("Rename Draft", isPresented: $showingRenameDraftDialog) {
            TextField("Draft name", text: $draftRenameText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                commitDraftRename()
            }
        } message: {
            Text("Choose a name you will recognize when you return to this essay.")
        }
        .persistenceFailureAlert($persistenceAlert)
        .fileExporter(
            isPresented: $showExportRTF,
            document: exportDraftDocument,
            contentType: .rtf,
            defaultFilename: draft.title.isEmpty ? "Untitled Draft" : draft.title
        ) { result in
            if case .success(let url) = result {
                print("Draft exported to: \(url)")
            } else if case .failure(let error) = result {
                persistenceAlert = PersistenceAlertContext(
                    title: "Couldn't Export Draft",
                    message: "Illuminote couldn't export this draft as RTF. \(error.localizedDescription)"
                )
            }
        }
        .fileExporter(
            isPresented: $showExportTXT,
            document: exportDraftTextDocument,
            contentType: .plainText,
            defaultFilename: draft.title.isEmpty ? "Untitled Draft" : draft.title
        ) { result in
            if case .success(let url) = result {
                print("Draft exported to: \(url)")
            } else if case .failure(let error) = result {
                persistenceAlert = PersistenceAlertContext(
                    title: "Couldn't Export Draft",
                    message: "Illuminote couldn't export this draft as plain text. \(error.localizedDescription)"
                )
            }
        }
        .onAppear {
            if !allowsAdvisor {
                isAdvisorPresented = false
            }
            Task { @MainActor in
                loadDraft()
            }
        }
        .onDisappear {
            Task {
                await MainActor.run {
                    saveDraftOnDisappear()
                }
            }
        }
        .onChange(of: settings.appThemeMode) { _, _ in
            attributedText = normalizedAttributedText(attributedText)
        }
        .onChange(of: isAdvisorPresented) { _, isPresented in
            onAdvisorPresentationChange?(isPresented)
        }
        .onChange(of: draft.dateModified) { _, newValue in
            handleRemoteDraftSnapshotChange(
                modifiedAt: newValue,
                remoteFingerprint: persistedDraftContentFingerprint(for: draft),
                remotePreviewText: persistedDraftPlainText(for: draft)
            )
        }
        .onChange(of: syncedDraftChangeToken) { _, _ in
            checkForRemoteDraftUpdate()
        }
        .task(id: draft.id) {
            await monitorDraftForRemoteChanges()
        }
        .task(id: profileSignature) {
            await loadWritingTargets()
        }


    }

    private var shouldShowWritingMapToggle: Bool {
        isWritingMapVisible && onToggleWritingMap != nil
    }
    
    // MARK: - Logic

    @ViewBuilder
    private var draftSyncNotice: some View {
        if let activeDraftConflict {
            DraftSyncConflictCard(
                conflict: activeDraftConflict,
                useImmersive: useImmersive,
                onKeepLocalEdits: keepLocalDraftEdits,
                onReloadRemoteVersion: reloadRemoteDraftVersion,
                onSaveLocalCopy: { saveLocalDraftEditsAsCopy() }
            )
            .padding(.top, DSSpacing.xs)
        } else if let draftSyncStatusMessage {
            HStack(alignment: .top, spacing: DSSpacing.sm) {
                Image(systemName: "checkmark.icloud")
                    .foregroundStyle(useImmersive ? DSColor.goldLight : DSColor.brandAccent)
                Text(draftSyncStatusMessage)
                    .font(DSFont.caption)
                    .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                Spacer()
                Button("Dismiss") {
                    withAnimation(AnimationConfig.screenTransition) {
                        self.draftSyncStatusMessage = nil
                    }
                }
                .font(DSFont.caption.weight(.semibold))
            }
            .padding(DSSpacing.sm)
            .if(useImmersive) { view in
                view.sacredCardStyle(highlighted: false)
            }
            .if(!useImmersive) { view in
                view.appSurfaceStyle(role: .quiet, highlighted: false)
            }
            .padding(.top, DSSpacing.xs)
        }
    }
    
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
                persistenceAlert = PersistenceAlertContext(
                    title: "Couldn't Open Draft",
                    message: "Illuminote couldn't load the rich text for this draft. \(error.localizedDescription)"
                )
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
        } else {
            attributedText = normalizedAttributedText(NSAttributedString(string: ""))
        }

        markLoadedDraftSnapshot()
    }

    private func normalizedAttributedText(_ text: NSAttributedString) -> NSAttributedString {
        RichTextDefaultColorNormalizer.normalized(text, defaultColor: editorForegroundColor)
    }

    private var savedAdvisorSeedText: String {
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

    private var profileSignature: String {
        guard let profile = currentProfile else { return "no-profile" }
        return [
            profile.id.uuidString,
            profile.preProfessionalTrack?.canonical.rawValue ?? "general",
            profile.degreeIntent.rawValue,
            profile.isTexasApplicant.description,
            profile.isMDPhDApplicant.description
        ].joined(separator: "|")
    }

    private func loadWritingTargets() async {
        let loadedRequirements: [StatementRequirement]
        if let currentProfile {
            loadedRequirements = await requirementsService.requirements(for: currentProfile)
        } else {
            loadedRequirements = []
        }
        requirements = loadedRequirements
        availableTargets = targetCatalogService.targets(for: currentProfile, requirements: loadedRequirements)
    }

    private func parseHeadings(from attrString: NSAttributedString) -> [HeadingItem] {
        var items: [HeadingItem] = []
        let fullString = attrString.string
        
        let paragraphs = fullString.components(separatedBy: "\n")
        var currentPosition = 0
        
        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            let lineRange = NSRange(location: currentPosition, length: (paragraph as NSString).length)
            currentPosition += (paragraph as NSString).length + 1
            
            guard !trimmed.isEmpty else { continue }
            
            // 1. Markdown Check
            if trimmed.hasPrefix("#") {
                let hashCount = trimmed.prefix(while: { $0 == "#" }).count
                if hashCount > 0 && hashCount <= 6 {
                    let title = trimmed.dropFirst(hashCount).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty {
                        items.append(HeadingItem(title: String(title), range: lineRange, level: hashCount))
                        continue
                    }
                }
            }
            
            // 2. Bold / Underline Check
            if lineRange.length > 0 {
                var isParagraphBold = false
                var isParagraphUnderlined = false
                
                let attributes = attrString.attributes(at: lineRange.location, effectiveRange: nil)
                
                if let font = attributes[.font] as? UIFont {
                    if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                        isParagraphBold = true
                    }
                }
                
                if attributes[.underlineStyle] != nil {
                    isParagraphUnderlined = true
                }
                
                if isParagraphBold || isParagraphUnderlined {
                    let displayTitle = trimmed.count > 40 ? String(trimmed.prefix(40)) + "..." : trimmed
                    items.append(HeadingItem(title: displayTitle, range: lineRange, level: isParagraphBold ? 2 : 3))
                }
            }
        }
        
        return items
    }

    private func beginRenameDraft() {
        draftRenameText = draft.title.isEmpty ? "Untitled Draft" : draft.title
        showingRenameDraftDialog = true
    }

    private func prepareRTFExport() {
        exportDraftDocument = RichTextDocument(attributedText: attributedText)
        showExportRTF = true
    }

    private func prepareTXTExport() {
        exportDraftTextDocument = PlainTextDocument(text: attributedText.string)
        showExportTXT = true
    }

    private func commitDraftRename() {
        let trimmedTitle = draftRenameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, trimmedTitle != draft.title else { return }

        do {
            draft.title = trimmedTitle
            draft.dateModified = Date()
            draft.isLocked = false
            draft.syncRevision = (draft.syncRevision ?? 0) + 1
            observedDraftModifiedAt = draft.dateModified
            try modelContext.persistIfNeeded(for: "rename this draft")
        } catch let error as PersistenceOperationError {
            persistenceAlert = error.alertContext
        } catch {
            persistenceAlert = PersistenceAlertContext.saveFailure(
                for: "rename this draft",
                details: error.localizedDescription
            )
        }
    }

    private func toggleAdvisor() {
        guard !isAdvisorPresented else {
            isAdvisorPresented = false
            return
        }

        guard saveDraft() else { return }
        advisorDraftText = savedAdvisorSeedText
        advisorReviewID = UUID()
        isAdvisorPresented = true
    }
    
    @discardableResult
    private func saveDraft(resolvingConflict: Bool = false) -> Bool {
        guard hasDraftChangesToSave else { return true }

        do {
            let data = try attributedText.data(
                from: NSRange(location: 0, length: attributedText.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            let savedAt = Date()
            lastLocalSaveAt = savedAt
            draft.richTextData = data
            mirrorRichTextIntoDraftSection()
            draft.dateModified = savedAt
            draft.isLocked = false
            draft.syncRevision = (draft.syncRevision ?? 0) + 1
            lastLocalSaveFingerprint = attributedTextFingerprint(attributedText)
            if resolvingConflict {
                draft.lastConflictDetectedAt = Date()
            }
            try modelContext.persistIfNeeded(for: "save this draft")
            activeDraftConflict = nil
            markLoadedDraftSnapshot()
            return true
        } catch let error as PersistenceOperationError {
            persistenceAlert = error.alertContext
        } catch {
            persistenceAlert = PersistenceAlertContext.saveFailure(
                for: "save this draft",
                details: error.localizedDescription
            )
        }
        return false
    }

    private func saveSnapshot() {
        draft.isSnapshot = true
        saveDraft()
    }

    private func saveDraftOnDisappear() {
        checkForRemoteDraftUpdate()
        if activeDraftConflict != nil {
            saveLocalDraftEditsAsCopy(reloadRemoteAfterSave: false)
        } else if hasDraftChangesToSave {
            saveDraft()
        }
    }

    private func monitorDraftForRemoteChanges() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                checkForRemoteDraftUpdate()
            }
        }
    }

    private func checkForRemoteDraftUpdate() {
        guard hasLoadedDraftSnapshot else { return }
        let refreshedDraft: StatementDraft?
        if let syncedDraftSnapshot {
            refreshedDraft = syncedDraftSnapshot
        } else {
            let draftID = draft.id
            var descriptor = FetchDescriptor<StatementDraft>(
                predicate: #Predicate { candidate in
                    candidate.id == draftID
                }
            )
            descriptor.fetchLimit = 1
            refreshedDraft = try? modelContext.fetch(descriptor).first
        }

        guard let refreshedDraft else { return }
        handleRemoteDraftSnapshotChange(
            modifiedAt: refreshedDraft.dateModified,
            remoteFingerprint: persistedDraftContentFingerprint(for: refreshedDraft),
            remotePreviewText: persistedDraftPlainText(for: refreshedDraft)
        )
    }

    private func handleRemoteDraftSnapshotChange(
        modifiedAt newValue: Date,
        remoteFingerprint: Data,
        remotePreviewText: String
    ) {
        guard hasLoadedDraftSnapshot else { return }

        let localFingerprint = attributedTextFingerprint(attributedText)
        let localHasUnsavedEdits = localFingerprint != loadedDraftContentFingerprint
        let isLocalSaveEcho = lastLocalSaveAt.map {
            abs(newValue.timeIntervalSince($0)) < 0.01
        } ?? false

        if isLocalSaveEcho,
           remoteFingerprint == lastLocalSaveFingerprint,
           !localHasUnsavedEdits {
            observedDraftModifiedAt = newValue
            return
        }

        if let observedDraftModifiedAt,
           newValue <= observedDraftModifiedAt.addingTimeInterval(0.01) {
            return
        }

        if !localHasUnsavedEdits {
            loadDraft()
            draftSyncStatusMessage = "This draft was updated from iCloud."
            return
        }

        guard localFingerprint != remoteFingerprint else {
            markLoadedDraftSnapshot()
            return
        }

        observedDraftModifiedAt = newValue
        withAnimation(AnimationConfig.screenTransition) {
            activeDraftConflict = DraftSyncConflict(
                remoteModifiedAt: newValue,
                remotePreview: previewText(from: remotePreviewText)
            )
            draftSyncStatusMessage = nil
        }
    }

    private func keepLocalDraftEdits() {
        saveDraft(resolvingConflict: true)
        draftSyncStatusMessage = "Your edits were kept and saved over the iCloud version."
    }

    private func reloadRemoteDraftVersion() {
        loadDraft()
        activeDraftConflict = nil
        draftSyncStatusMessage = "The version from iCloud is now open."
    }

    private func saveLocalDraftEditsAsCopy(reloadRemoteAfterSave: Bool = true) {
        do {
            let data = try attributedText.data(
                from: NSRange(location: 0, length: attributedText.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            let baseTitle = draft.title.isEmpty ? "Untitled Draft" : draft.title
            let copy = StatementDraft(
                title: "\(baseTitle) Copy",
                version: draft.version,
                richTextData: data,
                draftScope: draft.draftScope,
                writingTargetID: draft.writingTargetID,
                writingTargetCategory: draft.writingTargetCategory,
                customPromptText: draft.customPromptText
            )
            copy.dateCreated = Date()
            copy.dateModified = Date()
            copy.syncRevision = 0
            modelContext.insert(copy)
            try modelContext.persistIfNeeded(for: "save a copy of this draft")
            if reloadRemoteAfterSave {
                loadDraft()
            }
            activeDraftConflict = nil
            draftSyncStatusMessage = reloadRemoteAfterSave
                ? "Your local edits were saved as \(copy.title). The iCloud version is now open here."
                : "Your local edits were saved as \(copy.title) to avoid overwriting the iCloud version."
        } catch let error as PersistenceOperationError {
            persistenceAlert = error.alertContext
        } catch {
            persistenceAlert = PersistenceAlertContext.saveFailure(
                for: "save a copy of this draft",
                details: error.localizedDescription
            )
        }
    }

    private func markLoadedDraftSnapshot() {
        hasLoadedDraftSnapshot = true
        loadedDraftContentFingerprint = attributedTextFingerprint(attributedText)
        observedDraftModifiedAt = draft.dateModified
    }

    private var hasDraftChangesToSave: Bool {
        attributedTextFingerprint(attributedText) != loadedDraftContentFingerprint
    }

    private func mirrorRichTextIntoDraftSection() {
        let plainText = attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let mirrorSourceID = draft.id
        if let existing = draft.sections.first(where: { $0.source == .manual && $0.sourceID == mirrorSourceID }) {
            existing.content = plainText
            existing.date = Date()
            existing.order = 0
            return
        }

        let section = StatementSection(
            source: .manual,
            content: plainText,
            order: 0,
            sourceID: mirrorSourceID
        )
        draft.sections.append(section)
    }

    private func attributedTextFingerprint(_ text: NSAttributedString) -> Data {
        if let data = try? text.data(
            from: NSRange(location: 0, length: text.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) {
            return data
        }
        return Data(text.string.utf8)
    }

    private func persistedDraftContentFingerprint() -> Data {
        persistedDraftContentFingerprint(for: draft)
    }

    private func persistedDraftContentFingerprint(for draft: StatementDraft) -> Data {
        if let data = draft.richTextData {
            return data
        }
        return Data(persistedDraftPlainText(for: draft).utf8)
    }

    private func persistedDraftPlainText() -> String {
        persistedDraftPlainText(for: draft)
    }

    private func persistedDraftPlainText(for draft: StatementDraft) -> String {
        if let data = draft.richTextData,
           let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
           ) {
            return attributed.string
        }

        return draft.sections
            .sorted(by: { $0.order < $1.order })
            .map(\.content)
            .joined(separator: "\n\n")
    }

    private func textFingerprint(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func previewText(from text: String) -> String {
        let trimmed = textFingerprint(text)
        guard trimmed.count > 180 else { return trimmed }
        return "\(trimmed.prefix(180))..."
    }

    // Removed legacy exportDraft() and exportDocument state in favor of ShareLink
    
    // MARK: - Formatting Helpers

    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        NotificationCenter.default.post(name: .applyFormatCommand, object: nil, userInfo: ["trait": trait])
    }
    
    private func toggleAttribute(_ key: NSAttributedString.Key, value: Any) {
         NotificationCenter.default.post(name: .applyFormatCommand, object: nil, userInfo: ["key": key, "value": value])
    }

    private func applyTextColor(_ color: RevisionTextColor) {
        NotificationCenter.default.post(
            name: .applyFormatCommand,
            object: nil,
            userInfo: ["key": NSAttributedString.Key.foregroundColor, "value": color.uiColor, "mode": "set"]
        )
    }

    private func clearTextColor() {
        NotificationCenter.default.post(
            name: .applyFormatCommand,
            object: nil,
            userInfo: ["removeKeys": [NSAttributedString.Key.foregroundColor], "defaultForegroundColor": editorForegroundColor]
        )
    }

    private func applyHighlight(_ color: RevisionHighlightColor) {
        NotificationCenter.default.post(
            name: .applyFormatCommand,
            object: nil,
            userInfo: ["key": NSAttributedString.Key.backgroundColor, "value": color.uiColor, "mode": "set"]
        )
    }

    private func clearHighlight() {
        NotificationCenter.default.post(
            name: .applyFormatCommand,
            object: nil,
            userInfo: ["removeKeys": [NSAttributedString.Key.backgroundColor]]
        )
    }

    private func clearRevisionFormatting() {
        NotificationCenter.default.post(
            name: .applyFormatCommand,
            object: nil,
            userInfo: [
                "removeKeys": [
                    NSAttributedString.Key.foregroundColor,
                    NSAttributedString.Key.backgroundColor,
                    NSAttributedString.Key.strikethroughStyle
                ],
                "defaultForegroundColor": editorForegroundColor
            ]
        )
    }
    
    private func setAlignment(_ alignment: NSTextAlignment) {
        NotificationCenter.default.post(name: .applyParagraphStyle, object: nil, userInfo: ["alignment": alignment])
    }
}

extension Notification.Name {
    static let applyFormatCommand = Notification.Name("PSRichTextEditor_ApplyFormat")
    static let applyParagraphStyle = Notification.Name("PSRichTextEditor_ApplyParagraph")
    static let scrollToRangeCommand = Notification.Name("PSRichTextEditor_ScrollToRange")
}

// MARK: - File Export Documents

struct RichTextDocument: FileDocument, @unchecked Sendable {
    static var readableContentTypes: [UTType] { [.rtf] }

    var attributedText: NSAttributedString

    init(attributedText: NSAttributedString) {
        self.attributedText = attributedText
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            self.attributedText = try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
        } else {
            self.attributedText = NSAttributedString(string: "")
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try attributedText.data(
            from: NSRange(location: 0, length: attributedText.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        return FileWrapper(regularFileWithContents: data)
    }
}

struct PlainTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let decoded = String(data: data, encoding: .utf8) {
            self.text = decoded
        } else {
            self.text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
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
                    writingTargetID: nil,
                    writingTargetCategoryRaw: nil,
                    customPromptText: nil,
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

private struct DraftSyncConflictCard: View {
    let conflict: PSRichTextEditorView.DraftSyncConflict
    let useImmersive: Bool
    let onKeepLocalEdits: () -> Void
    let onReloadRemoteVersion: () -> Void
    let onSaveLocalCopy: () -> Void

    private var timestampText: String {
        conflict.remoteModifiedAt.formatted(.dateTime.month().day().hour().minute())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(alignment: .top, spacing: DSSpacing.sm) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.headline)
                    .foregroundStyle(useImmersive ? DSColor.warning : .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Updated on another device")
                        .font(DSFont.body.weight(.semibold))
                        .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                    Text("This draft changed through iCloud at \(timestampText) while you had local edits open.")
                        .font(DSFont.caption)
                        .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !conflict.remotePreview.isEmpty {
                Text("Other version: \(conflict.remotePreview)")
                    .font(DSFont.caption)
                    .foregroundStyle(useImmersive ? DSColor.quietText : .secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: DSSpacing.xs) {
                Button("Save My Edits as a Copy", action: onSaveLocalCopy)
                    .buttonStyle(.appPrimary)
                Button("Keep My Edits Here", action: onKeepLocalEdits)
                    .buttonStyle(.appSecondary)
                Button("Reload iCloud Version", role: .destructive, action: onReloadRemoteVersion)
                    .buttonStyle(.appQuiet)
            }
            .padding(.top, DSSpacing.xs)
        }
        .padding(DSSpacing.md)
        .if(useImmersive) { view in
            view.sacredCardStyle(highlighted: true)
        }
        .if(!useImmersive) { view in
            view.appSurfaceStyle(role: .interactive, highlighted: true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Revision Formatting
enum RevisionTextColor: String, CaseIterable, Identifiable {
    case needsWork
    case strongSentence
    case cutOrReplace
    case evidence
    case theme

    var id: String { rawValue }

    var label: String {
        switch self {
        case .needsWork: return "Needs work"
        case .strongSentence: return "Strong sentence"
        case .cutOrReplace: return "Cut or replace"
        case .evidence: return "Evidence"
        case .theme: return "Theme"
        }
    }

    var systemImage: String {
        switch self {
        case .needsWork: return "pencil.and.scribble"
        case .strongSentence: return "checkmark.seal"
        case .cutOrReplace: return "scissors"
        case .evidence: return "quote.bubble"
        case .theme: return "sparkle"
        }
    }

    var swiftUIColor: Color { Color(uiColor: uiColor) }

    var uiColor: UIColor {
        switch self {
        case .needsWork:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.95, green: 0.74, blue: 0.33, alpha: 1.0)
                    : UIColor(red: 0.52, green: 0.34, blue: 0.00, alpha: 1.0)
            }
        case .strongSentence:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.49, green: 0.84, blue: 0.65, alpha: 1.0)
                    : UIColor(red: 0.10, green: 0.48, blue: 0.30, alpha: 1.0)
            }
        case .cutOrReplace:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 1.00, green: 0.54, blue: 0.50, alpha: 1.0)
                    : UIColor(red: 0.70, green: 0.15, blue: 0.12, alpha: 1.0)
            }
        case .evidence:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.56, green: 0.77, blue: 1.00, alpha: 1.0)
                    : UIColor(red: 0.10, green: 0.42, blue: 0.72, alpha: 1.0)
            }
        case .theme:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.85, green: 0.70, blue: 0.35, alpha: 1.0)
                    : UIColor(red: 0.54, green: 0.42, blue: 0.00, alpha: 1.0)
            }
        }
    }
}

enum RevisionHighlightColor: String, CaseIterable, Identifiable {
    case revise
    case keep
    case verify

    var id: String { rawValue }

    var label: String {
        switch self {
        case .revise: return "Revise"
        case .keep: return "Keep"
        case .verify: return "Verify"
        }
    }

    var systemImage: String {
        switch self {
        case .revise: return "highlighter"
        case .keep: return "bookmark"
        case .verify: return "magnifyingglass"
        }
    }

    var swiftUIColor: Color { Color(uiColor: uiColor) }

    var uiColor: UIColor {
        switch self {
        case .revise:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.35, green: 0.25, blue: 0.08, alpha: 1.0)
                    : UIColor(red: 1.00, green: 0.93, blue: 0.67, alpha: 1.0)
            }
        case .keep:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.12, green: 0.33, blue: 0.24, alpha: 1.0)
                    : UIColor(red: 0.78, green: 0.94, blue: 0.84, alpha: 1.0)
            }
        case .verify:
            return UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.11, green: 0.27, blue: 0.45, alpha: 1.0)
                    : UIColor(red: 0.80, green: 0.90, blue: 1.00, alpha: 1.0)
            }
        }
    }
}

fileprivate enum RichTextDefaultColorNormalizer {
    static func normalized(_ attributed: NSAttributedString, defaultColor: UIColor) -> NSAttributedString {
        guard attributed.length > 0 else { return attributed }
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: mutable.length)

        mutable.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            guard let color = value as? UIColor else {
                mutable.addAttribute(.foregroundColor, value: defaultColor, range: range)
                return
            }

            if isEditorDefaultColor(color) {
                mutable.addAttribute(.foregroundColor, value: defaultColor, range: range)
            }
        }

        return mutable
    }

    static func isEditorDefaultColor(_ color: UIColor) -> Bool {
        let editorDefaults: [UIColor] = [.white, .black, .label, .darkText, .lightText]
        return editorDefaults.contains { approximatelyMatches(color, $0) }
    }

    private static func approximatelyMatches(_ lhs: UIColor, _ rhs: UIColor) -> Bool {
        let styles: [UIUserInterfaceStyle] = [.light, .dark]
        return styles.contains { style in
            guard let left = rgba(lhs, style: style), let right = rgba(rhs, style: style) else {
                return lhs.isEqual(rhs)
            }

            return abs(left.red - right.red) < 0.02
                && abs(left.green - right.green) < 0.02
                && abs(left.blue - right.blue) < 0.02
                && abs(left.alpha - right.alpha) < 0.02
        }
    }

    private static func rgba(_ color: UIColor, style: UIUserInterfaceStyle) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        return (red, green, blue, alpha)
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
    var toggleStrikethrough: () -> Void
    var applyTextColor: (RevisionTextColor) -> Void
    var clearTextColor: () -> Void
    var applyHighlight: (RevisionHighlightColor) -> Void
    var clearHighlight: () -> Void
    var clearRevisionFormatting: () -> Void
    var alignLeft: () -> Void
    var alignCenter: () -> Void
    var alignRight: () -> Void

    private var toolbarForeground: Color {
        useImmersive ? DSColor.textPrimary : .primary
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Group {
                    RichTextToolbarButton(
                        systemName: "bold",
                        accessibilityLabel: "Bold",
                        isActive: isBold,
                        useImmersive: useImmersive,
                        action: toggleBold
                    )
                    RichTextToolbarButton(
                        systemName: "italic",
                        accessibilityLabel: "Italic",
                        isActive: isItalic,
                        useImmersive: useImmersive,
                        action: toggleItalic
                    )
                    RichTextToolbarButton(
                        systemName: "underline",
                        accessibilityLabel: "Underline",
                        useImmersive: useImmersive,
                        action: toggleUnderline
                    )
                    RichTextToolbarButton(
                        systemName: "strikethrough",
                        accessibilityLabel: "Strikethrough",
                        useImmersive: useImmersive,
                        action: toggleStrikethrough
                    )
                }
                
                Divider().frame(height: 20)

                Group {
                    Menu {
                        Section("Text color") {
                            ForEach(RevisionTextColor.allCases) { color in
                                Button {
                                    applyTextColor(color)
                                } label: {
                                    Label(color.label, systemImage: color.systemImage)
                                }
                            }
                        }
                        Button("Clear text color", systemImage: "xmark.circle", action: clearTextColor)
                    } label: {
                        Image(systemName: "paintpalette")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(toolbarForeground)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Text color")

                    Menu {
                        Section("Highlight") {
                            ForEach(RevisionHighlightColor.allCases) { color in
                                Button {
                                    applyHighlight(color)
                                } label: {
                                    Label(color.label, systemImage: color.systemImage)
                                }
                            }
                        }
                        Button("Clear highlight", systemImage: "xmark.circle", action: clearHighlight)
                        Button("Clear selected revision marks", systemImage: "eraser", action: clearRevisionFormatting)
                    } label: {
                        Image(systemName: "highlighter")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(toolbarForeground)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Highlight")
                }

                Divider().frame(height: 20)

                Group {
                    RichTextToolbarButton(
                        systemName: "text.alignleft",
                        accessibilityLabel: "Align left",
                        useImmersive: useImmersive,
                        action: alignLeft
                    )
                    RichTextToolbarButton(
                        systemName: "text.aligncenter",
                        accessibilityLabel: "Align center",
                        useImmersive: useImmersive,
                        action: alignCenter
                    )
                    RichTextToolbarButton(
                        systemName: "text.alignright",
                        accessibilityLabel: "Align right",
                        useImmersive: useImmersive,
                        action: alignRight
                    )
                }
            }
            .padding(.horizontal, DSSpacing.sm)
        }
    }
}

private struct RichTextToolbarButton: View {
    let systemName: String
    let accessibilityLabel: String
    var isActive: Bool = false
    let useImmersive: Bool
    let action: () -> Void

    private var foreground: Color {
        isActive ? DSColor.goldLight : (useImmersive ? DSColor.textPrimary : .primary)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(foreground)
                .frame(width: 44, height: 44)
                .background(isActive ? DSColor.goldLight.opacity(0.18) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .if(isActive) { view in
            view.accessibilityAddTraits(.isSelected)
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
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.handleScrollToRangeCommand(_:)), name: .scrollToRangeCommand, object: nil)
        
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
        context.coordinator.normalizeTypingForeground(in: uiView)
    }

    private func normalizedText(_ attributed: NSAttributedString, color: UIColor) -> NSAttributedString {
        RichTextDefaultColorNormalizer.normalized(attributed, defaultColor: color)
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
            normalizeDefaultForeground(in: textView)
            parent.text = textView.attributedText
            parent.selectedRange = textView.selectedRange
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdatingFromSwiftUI else { return }
            self.parent.selectedRange = textView.selectedRange
            normalizeTypingForeground(in: textView)
            updateFormattingState(textView)
        }

        fileprivate func normalizeTypingForeground(in textView: UITextView) {
            let targetColor: UIColor = parent.useImmersive ? .white : .label
            guard let currentColor = textView.typingAttributes[.foregroundColor] as? UIColor else {
                var typing = textView.typingAttributes
                typing[.foregroundColor] = targetColor
                textView.typingAttributes = typing
                return
            }

            guard RichTextDefaultColorNormalizer.isEditorDefaultColor(currentColor) else { return }

            var typing = textView.typingAttributes
            typing[.foregroundColor] = targetColor
            textView.typingAttributes = typing
        }

        private func normalizeDefaultForeground(in textView: UITextView) {
            let targetColor: UIColor = parent.useImmersive ? .white : .label
            guard textView.attributedText.length > 0 else { return }

            let selection = textView.selectedRange
            let normalized = RichTextDefaultColorNormalizer.normalized(textView.attributedText, defaultColor: targetColor)
            guard normalized != textView.attributedText else { return }

            isUpdatingFromSwiftUI = true
            textView.attributedText = normalized
            textView.selectedRange = selection
            isUpdatingFromSwiftUI = false
            normalizeTypingForeground(in: textView)
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
            
            if let trait = userInfo["trait"] as? UIFontDescriptor.SymbolicTraits {
                toggleTrait(trait, in: textView)
            }
            else if let keys = userInfo["removeKeys"] as? [NSAttributedString.Key] {
                clearAttributes(keys, defaultForegroundColor: userInfo["defaultForegroundColor"] as? UIColor, in: textView)
            }
            else if let key = userInfo["key"] as? NSAttributedString.Key, let value = userInfo["value"] {
                if userInfo["mode"] as? String == "set" {
                    setAttribute(key, value: value, in: textView)
                } else {
                    toggleAttribute(key, value: value, in: textView)
                }
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

        @objc func handleScrollToRangeCommand(_ notification: Notification) {
            guard let range = notification.userInfo?["range"] as? NSRange,
                  let textView = self.textView else { return }
            
            if range.location + range.length <= textView.text.count {
                textView.selectedRange = NSRange(location: range.location, length: 0)
                textView.scrollRangeToVisible(range)
            }
        }
        
        private func toggleAttribute(_ key: NSAttributedString.Key, value: Any, in textView: UITextView) {
            let range = textView.selectedRange
            var attributes = textView.typingAttributes
            
            if range.length > 0 {
                if selectionHasAttribute(key, value: value, range: range, in: textView) {
                    textView.textStorage.removeAttribute(key, range: range)
                    attributes.removeValue(forKey: key)
                } else {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    attributes[key] = value
                }
            } else if attributeValue(attributes[key], equals: value) {
                attributes.removeValue(forKey: key)
            } else {
                attributes[key] = value
            }

            textView.typingAttributes = attributes
            parent.text = textView.attributedText
        }

        private func setAttribute(_ key: NSAttributedString.Key, value: Any, in textView: UITextView) {
            let range = textView.selectedRange
            var attributes = textView.typingAttributes

            if range.length > 0 {
                textView.textStorage.addAttribute(key, value: value, range: range)
            }

            attributes[key] = value
            textView.typingAttributes = attributes
            parent.text = textView.attributedText
        }

        private func clearAttributes(_ keys: [NSAttributedString.Key], defaultForegroundColor: UIColor?, in textView: UITextView) {
            let range = textView.selectedRange
            var attributes = textView.typingAttributes

            if range.length > 0 {
                keys.forEach { textView.textStorage.removeAttribute($0, range: range) }
                if keys.contains(.foregroundColor), let defaultForegroundColor {
                    textView.textStorage.addAttribute(.foregroundColor, value: defaultForegroundColor, range: range)
                }
            }

            keys.forEach { attributes.removeValue(forKey: $0) }
            if keys.contains(.foregroundColor), let defaultForegroundColor {
                attributes[.foregroundColor] = defaultForegroundColor
            }
            textView.typingAttributes = attributes
            parent.text = textView.attributedText
        }

        private func selectionHasAttribute(_ key: NSAttributedString.Key, value: Any, range: NSRange, in textView: UITextView) -> Bool {
            var hasAttributeAcrossSelection = true
            textView.attributedText.enumerateAttribute(key, in: range, options: []) { currentValue, _, stop in
                if !attributeValue(currentValue, equals: value) {
                    hasAttributeAcrossSelection = false
                    stop.pointee = true
                }
            }
            return hasAttributeAcrossSelection
        }

        private func attributeValue(_ currentValue: Any?, equals targetValue: Any) -> Bool {
            switch (currentValue, targetValue) {
            case let (current as Int, target as Int):
                return current == target
            case let (current as UIColor, target as UIColor):
                return current.isEqual(target)
            case let (current as NSObject, target as NSObject):
                return current.isEqual(target)
            default:
                return false
            }
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

// MARK: - Outline Navigator Models & Component
struct HeadingItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let range: NSRange
    let level: Int // 1 for Markdown H1, 2 for Bold, 3 for Underline
}

struct OutlineNavigatorPanel: View {
    let headings: [HeadingItem]
    let useImmersive: Bool
    let onSelect: (HeadingItem) -> Void
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Document Outline")
                        .font(DSFont.heading2)
                        .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                    Text("Navigate statements by headers")
                        .font(DSFont.caption)
                        .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .appCircleControl()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.top, DSSpacing.md)
            
            Divider()
                .background(useImmersive ? DSColor.divider : Color(uiColor: .separator))

            if headings.isEmpty {
                VStack(spacing: DSSpacing.md) {
                    Spacer()
                    Image(systemName: "list.bullet.indent")
                        .font(.system(size: 32))
                        .foregroundStyle(useImmersive ? DSColor.quietTextMuted : .secondary)
                    
                    Text("No headings found.")
                        .font(DSFont.supporting.weight(.semibold))
                        .foregroundStyle(useImmersive ? DSColor.textSecondary : .primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Use bold text or Markdown `#` prefixes to organize your drafts into logical sections.")
                        .font(DSFont.caption)
                        .foregroundStyle(useImmersive ? DSColor.quietText : .secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DSSpacing.lg)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        ForEach(headings) { heading in
                            Button {
                                onSelect(heading)
                            } label: {
                                HStack {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(useImmersive ? DSColor.goldLight : DSColor.brandAccent)
                                        .opacity(0.7)
                                    
                                    Text(heading.title)
                                        .font(DSFont.supporting.weight(heading.level == 1 ? .bold : .medium))
                                        .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                                        .lineLimit(1)
                                        .padding(.leading, CGFloat(heading.level - 1) * 8)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, DSSpacing.sm)
                                .contentShape(Rectangle())
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(useImmersive ? DSColor.quietSurface.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.sm)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(useImmersive ? DSColor.backgroundPrimary : Color(uiColor: .systemGroupedBackground))
    }
}
