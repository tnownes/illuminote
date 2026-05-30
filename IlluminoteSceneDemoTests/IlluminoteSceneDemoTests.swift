//
//  IlluminoteSceneDemoTests.swift
//  IlluminoteSceneDemoTests
//
//  Created by Nownes, Tobias on 5/2/25.
//

import XCTest
import SwiftData
@testable import IlluminoteSceneDemo

final class IlluminoteSceneDemoTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testExperienceModeDefaultsByBuildChannel() throws {
        let hasLaunchOverride = ProcessInfo.processInfo.arguments.contains(where: { argument in
            argument.hasPrefix("-illuminote-experience=")
                || argument == "-illuminote-core"
                || argument == "-illuminote-full"
        })
        let hasEnvironmentOverride = ProcessInfo.processInfo.environment["ILLUMINOTE_EXPERIENCE_MODE"] != nil
        try XCTSkipIf(hasLaunchOverride || hasEnvironmentOverride, "Experience mode override is active.")

        XCTAssertEqual(IlluminoteExperienceMode.current(for: .development), .full)
        XCTAssertEqual(IlluminoteExperienceMode.current(for: .internalTestFlight), .core)
        XCTAssertEqual(IlluminoteExperienceMode.current(for: .alphaExternal), .core)
        XCTAssertEqual(IlluminoteExperienceMode.current(for: .appStore), .core)
    }

    func testCoreFeaturePolicyHidesAdvancedSurfaces() {
        let policy = IlluminoteFeaturePolicy.policy(for: .core)

        XCTAssertFalse(policy.allowsAdvisor)
        XCTAssertFalse(policy.allowsExamenVoiceTranscription)
        XCTAssertFalse(policy.allowsExamenPromptSpeech)
        XCTAssertFalse(policy.allowsExamenInlineNotes)
        XCTAssertFalse(policy.allowsExamenApplicationRecordDuringReflection)
        XCTAssertFalse(policy.showsHomeApplicationRecordPrompts)
        XCTAssertFalse(policy.showsAdvancedWritingTools)
        XCTAssertFalse(policy.showsAISettings)
        XCTAssertTrue(policy.showsCoreGuidance)
    }

    func testFullFeaturePolicyPreservesAdvancedSurfaces() {
        let policy = IlluminoteFeaturePolicy.policy(for: .full)

        XCTAssertTrue(policy.allowsAdvisor)
        XCTAssertTrue(policy.allowsExamenVoiceTranscription)
        XCTAssertTrue(policy.allowsExamenPromptSpeech)
        XCTAssertTrue(policy.allowsExamenInlineNotes)
        XCTAssertTrue(policy.allowsExamenApplicationRecordDuringReflection)
        XCTAssertTrue(policy.showsHomeApplicationRecordPrompts)
        XCTAssertTrue(policy.showsAdvancedWritingTools)
        XCTAssertTrue(policy.showsAISettings)
        XCTAssertFalse(policy.showsCoreGuidance)
    }

    func testApplyDetailsLeadershipMapsRoleAndOrganization() {
        var draft = ExamenSessionDraft(type: .leadership)

        draft.applyDetails(
            primary: " Team Lead ",
            secondary: " Campus Org ",
            focus: " ignored ",
            location: " Omaha ",
            hours: 12.5
        )

        XCTAssertEqual(draft.roleTitle, "Team Lead")
        XCTAssertNil(draft.mentorOrSupervisor)
        XCTAssertNil(draft.physician)
        XCTAssertEqual(draft.organizationName, "Campus Org")
        XCTAssertEqual(draft.facility, "Campus Org")
        XCTAssertNil(draft.focusArea)
        XCTAssertNil(draft.specialty)
        XCTAssertEqual(draft.location, "Omaha")
        XCTAssertEqual(draft.hours, 12.5, accuracy: 0.001)
    }

    func testApplyDetailsClinicalMapsMentorOrganizationAndFocus() {
        var draft = ExamenSessionDraft(type: .clinical)

        draft.applyDetails(
            primary: " Nurse Smith ",
            secondary: " UNMC ",
            focus: " Internal Medicine ",
            location: " Omaha ",
            hours: 8
        )

        XCTAssertEqual(draft.mentorOrSupervisor, "Nurse Smith")
        XCTAssertEqual(draft.physician, "Nurse Smith")
        XCTAssertNil(draft.roleTitle)
        XCTAssertEqual(draft.organizationName, "UNMC")
        XCTAssertEqual(draft.focusArea, "Internal Medicine")
        XCTAssertEqual(draft.facility, "UNMC")
        XCTAssertEqual(draft.specialty, "Internal Medicine")
        XCTAssertEqual(draft.location, "Omaha")
        XCTAssertEqual(draft.hours, 8, accuracy: 0.001)
    }

    func testApplyDetailsOtherClearsStructuredFields() {
        var draft = ExamenSessionDraft(type: .other)
        draft.mentorOrSupervisor = "Existing Mentor"
        draft.roleTitle = "Existing Role"
        draft.organizationName = "Existing Org"
        draft.focusArea = "Existing Focus"
        draft.location = "Existing Location"
        draft.physician = "Existing Physician"
        draft.facility = "Existing Facility"
        draft.specialty = "Existing Specialty"
        draft.hours = 4

        draft.applyDetails(
            primary: "Ignored Primary",
            secondary: "Ignored Secondary",
            focus: "Ignored Focus",
            location: "Ignored Location",
            hours: 9
        )

        XCTAssertNil(draft.mentorOrSupervisor)
        XCTAssertNil(draft.roleTitle)
        XCTAssertNil(draft.organizationName)
        XCTAssertNil(draft.focusArea)
        XCTAssertNil(draft.location)
        XCTAssertNil(draft.physician)
        XCTAssertNil(draft.facility)
        XCTAssertNil(draft.specialty)
        XCTAssertEqual(draft.hours, 0, accuracy: 0.001)
    }

    func testStatementDraftScopeDefaultsToFull() {
        let draft = StatementDraft(title: "Sample")
        XCTAssertEqual(draft.draftScope, .full)
    }

    func testStatementDraftPayloadPreservesScopeRawValue() {
        let draft = StatementDraft(title: "Scoped", draftScope: .closing)
        let payload = draft.toFilePayload()
        XCTAssertEqual(payload.draftScopeRaw, StatementDraftScope.closing.rawValue)
    }

    @MainActor
    func testStatementDraftPayloadPreservesWritingTargetMetadata() {
        let draft = StatementDraft(
            title: "School Essay",
            draftScope: .body,
            writingTargetID: "school.generic.amcas",
            writingTargetCategory: .schoolSpecificEssay,
            customPromptText: "Why this school?"
        )

        let payload = draft.toFilePayload()
        let container = try! ModelContainer(
            for: Schema([StatementDraft.self, StatementSection.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let restored = StatementDraft.fromPayload(payload, context: container.mainContext, asCopy: true)

        XCTAssertEqual(payload.writingTargetID, "school.generic.amcas")
        XCTAssertEqual(payload.writingTargetCategoryRaw, WritingTargetCategory.schoolSpecificEssay.rawValue)
        XCTAssertEqual(payload.customPromptText, "Why this school?")
        XCTAssertEqual(restored.writingTargetID, draft.writingTargetID)
        XCTAssertEqual(restored.writingTargetCategory, .schoolSpecificEssay)
        XCTAssertEqual(restored.customPromptText, "Why this school?")
    }

    func testAssignWritingTargetClearsUnsupportedCustomPrompt() {
        let draft = StatementDraft(
            title: "Draft",
            customPromptText: "Temporary prompt"
        )
        let target = WritingTargetDefinition(
            id: "core.amcas",
            category: .coreStatement,
            title: "Personal Comments Essay",
            summary: "Main application essay.",
            promptText: "Prompt",
            serviceCodeRaw: RequirementApplicationService.amcas.rawValue,
            trackRaw: PreProfessionalTrack.preMedicine.rawValue,
            characterLimitMin: nil,
            characterLimitMax: 5300,
            wordLimitMin: nil,
            wordLimitMax: nil,
            officialLink: nil,
            allowsCustomPrompt: false
        )

        draft.assignWritingTarget(target)

        XCTAssertEqual(draft.writingTargetID, "core.amcas")
        XCTAssertEqual(draft.writingTargetCategory, .coreStatement)
        XCTAssertNil(draft.customPromptText)
    }

    func testWritingTargetCatalogBuildsCoreAndGenericTargetsForCurrentService() {
        let profile = UserProfile(
            preProfessionalTrack: .preMedicine,
            hasSeenOnboarding: true,
            degreeIntent: .md
        )
        let requirements = [
            makeRequirement(
                id: "amcas-2027",
                serviceCode: .amcas,
                officialTitle: "Personal Comments Essay",
                promptText: "Describe why you want to study medicine.",
                characterLimitMax: 5300
            )
        ]

        let targets = LocalWritingTargetCatalogService().targets(for: profile, requirements: requirements)

        XCTAssertEqual(
            targets.first(where: { $0.id == "core.amcas" && $0.category == .coreStatement })?.title,
            "Personal Comments Essay"
        )
        XCTAssertNotNil(targets.first(where: { $0.id == "supplemental.generic.amcas" && $0.category == .supplementalEssay }))
        XCTAssertNotNil(targets.first(where: { $0.id == "school.generic.amcas" && $0.category == .schoolSpecificEssay }))
    }

    func testWritingTargetCatalogFallsBackToGenericEssayTypesWithoutActiveServices() {
        let profile = UserProfile(
            preProfessionalTrack: .general,
            hasSeenOnboarding: true,
            degreeIntent: .md
        )

        let targets = LocalWritingTargetCatalogService().targets(for: profile, requirements: [])
        let targetIDs = Set(targets.map(\.id))

        XCTAssertTrue(targetIDs.contains("core.generic"))
        XCTAssertTrue(targetIDs.contains("supplemental.generic"))
        XCTAssertTrue(targetIDs.contains("school.generic"))
        XCTAssertGreaterThanOrEqual(targets.filter { $0.category == .coreStatement }.count, 1)
        XCTAssertGreaterThanOrEqual(targets.filter { $0.category == .supplementalEssay }.count, 1)
        XCTAssertGreaterThanOrEqual(targets.filter { $0.category == .schoolSpecificEssay }.count, 1)
    }

    func testWritingTargetCatalogIncludesTMDSASSupplementalsForTexasPreMed() {
        let profile = UserProfile(
            preProfessionalTrack: .preMedicine,
            hasSeenOnboarding: true,
            degreeIntent: .md,
            isTexasApplicant: true
        )
        let requirements = [
            makeRequirement(
                id: "tmdsas-2027",
                serviceCode: .tmdsas,
                officialTitle: "Personal Statement",
                promptText: "TMDSAS personal statement.",
                characterLimitMax: 5000
            )
        ]

        let targets = LocalWritingTargetCatalogService().targets(for: profile, requirements: requirements)

        XCTAssertNotNil(targets.first(where: { $0.id == "core.tmdsas" }))
        XCTAssertNotNil(targets.first(where: { $0.id == "supplemental.tmdsas.personalCharacteristics" }))
        XCTAssertNotNil(targets.first(where: { $0.id == "supplemental.tmdsas.optionalEssay" }))
    }

    func testWritingTargetCatalogGatesMDPhDEssaysBehindProfileFlag() {
        let requirements = [
            makeRequirement(
                id: "amcas-2027",
                serviceCode: .amcas,
                officialTitle: "Personal Comments Essay",
                promptText: "Explain why you want to study medicine.",
                characterLimitMax: 5300
            )
        ]

        let standardProfile = UserProfile(
            preProfessionalTrack: .preMedicine,
            hasSeenOnboarding: true,
            degreeIntent: .md,
            isMDPhDApplicant: false
        )
        let mdPhDProfile = UserProfile(
            preProfessionalTrack: .preMedicine,
            hasSeenOnboarding: true,
            degreeIntent: .md,
            isMDPhDApplicant: true
        )

        let standardTargets = LocalWritingTargetCatalogService().targets(for: standardProfile, requirements: requirements)
        let mdPhDTargets = LocalWritingTargetCatalogService().targets(for: mdPhDProfile, requirements: requirements)

        XCTAssertNil(standardTargets.first(where: { $0.id == "supplemental.amcas.mdphdEssay" }))
        XCTAssertNil(standardTargets.first(where: { $0.id == "supplemental.amcas.significantResearch" }))
        XCTAssertNotNil(mdPhDTargets.first(where: { $0.id == "supplemental.amcas.mdphdEssay" }))
        XCTAssertNotNil(mdPhDTargets.first(where: { $0.id == "supplemental.amcas.significantResearch" }))
    }

    func testApplicationEntryCatalogBuildsAMCASWorkAndActivitiesMetadata() {
        let profile = UserProfile(
            preProfessionalTrack: .preMedicine,
            hasSeenOnboarding: true,
            degreeIntent: .md
        )

        let entries = LocalApplicationEntryCatalogService().entries(for: profile)
        let workActivities = entries.first(where: { $0.serviceCode == .amcas })

        XCTAssertEqual(workActivities?.title, "Work and Activities")
        XCTAssertEqual(workActivities?.metadataSummary, "15 entries • 700 characters each • up to 3 Most Meaningful")
    }

    @MainActor
    func testPhase1SplitSchemaInitializesWithSyncedAndLocalConfigurations() throws {
        let syncedUserModelTypes: [any PersistentModel.Type] = [
            UserProfile.self,
            ExamenSession.self,
            StepResponse.self,
            ApplicationExperience.self,
            ExperiencePeriod.self,
            StatementDraft.self,
            StatementSection.self,
            ThemeCluster.self,
            ThemeEntryLink.self,
            ThemeBundle.self,
            InsightNode.self,
            InsightEntryLink.self,
            InsightWorkspaceEntry.self
        ]
        let localAppModelTypes: [any PersistentModel.Type] = [
            PromptTemplate.self,
            SemanticVectorCache.self,
            StatementField.self,
            ApplicationService.self,
            PromptCycle.self,
            BestPractice.self,
            PracticeTheme.self,
            ToneGuidelines.self,
            StructureRecommendations.self
        ]
        let syncedUserSchema = Schema(syncedUserModelTypes)
        let localAppSchema = Schema(localAppModelTypes)
        let fullSchema = Schema(syncedUserModelTypes + localAppModelTypes)

        let container = try ModelContainer(
            for: fullSchema,
            configurations: [
                ModelConfiguration(
                    "Phase1SyncedUserContent",
                    schema: syncedUserSchema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                ),
                ModelConfiguration(
                    "Phase1LocalAppContent",
                    schema: localAppSchema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
            ]
        )

        XCTAssertNotNil(container.mainContext)
    }

    @MainActor
    func testPhase1SyncedToManyRelationshipsMaintainExplicitInverses() throws {
        let container = try ModelContainer(
            for: Schema([
                StatementDraft.self,
                StatementSection.self,
                ThemeCluster.self,
                ThemeEntryLink.self
            ]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let draft = StatementDraft(title: "CloudKit Compatibility Draft")
        let section = StatementSection(source: .manual, content: "A synced section", order: 0)
        draft.sections = [section]
        context.insert(draft)

        let cluster = ThemeCluster(label: "Service")
        let link = ThemeEntryLink(entryID: UUID(), evidenceSnippet: "Evidence", confidence: 0.8)
        cluster.links = [link]
        context.insert(cluster)

        try context.save()

        XCTAssertEqual(section.draft?.id, draft.id)
        XCTAssertEqual(link.cluster?.id, cluster.id)
    }

    @MainActor
    func testPhase2PromptImporterReconcilesLocalSeedDataIdempotently() throws {
        let container = try ModelContainer(
            for: Schema([PromptTemplate.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let promptID = UUID()
        let firstImport = PromptTemplateImport(
            id: promptID.uuidString,
            text: "Notice where grace appeared today.",
            phase: 1,
            stage: "gratitude",
            depth: "standard",
            stepIndex: 0,
            experienceTypes: ["daily"],
            professionTags: ["preMedicine"],
            intent: "gratitude",
            tags: ["daily", "spiritual"]
        )

        let inserted = try PromptImporter.reconcile([firstImport], context: context)
        try context.save()

        XCTAssertEqual(inserted.insertedCount, 1)
        XCTAssertEqual(inserted.updatedCount, 0)
        XCTAssertEqual(inserted.unchangedCount, 0)

        let unchanged = try PromptImporter.reconcile([firstImport], context: context)

        XCTAssertEqual(unchanged.insertedCount, 0)
        XCTAssertEqual(unchanged.updatedCount, 0)
        XCTAssertEqual(unchanged.unchangedCount, 1)
        XCTAssertFalse(unchanged.didMutate)

        let updatedImport = PromptTemplateImport(
            id: promptID.uuidString,
            text: "Notice where grace and courage appeared today.",
            phase: 1,
            stage: "gratitude",
            depth: "standard",
            stepIndex: 0,
            experienceTypes: ["daily"],
            professionTags: ["preMedicine"],
            intent: "gratitude",
            tags: ["daily", "spiritual"]
        )
        let updated = try PromptImporter.reconcile([updatedImport], context: context)
        try context.save()

        XCTAssertEqual(updated.updatedCount, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PromptTemplate>()).first?.text, updatedImport.text)

        let pruned = try PromptImporter.reconcile([], context: context)
        try context.save()

        XCTAssertEqual(pruned.deletedStaleCount, 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PromptTemplate>()), 0)
    }

    func testBackfillLeadershipFromLegacy() {
        let session = ExamenSession(
            sessionType: .daily,
            experienceType: .leadership,
            physician: " Team Lead ",
            facility: " Student Council ",
            specialty: "Should Not Map"
        )

        let didBackfill = session.applyNormalizedMetadataBackfillIfNeeded()

        XCTAssertTrue(didBackfill)
        XCTAssertEqual(session.roleTitle, "Team Lead")
        XCTAssertNil(session.mentorOrSupervisor)
        XCTAssertEqual(session.organizationName, "Student Council")
        XCTAssertNil(session.focusArea)
    }

    func testBackfillDoesNotOverrideExistingNormalizedValues() {
        let session = ExamenSession(
            sessionType: .daily,
            experienceType: .clinical,
            physician: " Legacy Mentor ",
            facility: " Legacy Facility ",
            specialty: " Legacy Focus ",
            mentorOrSupervisor: " Existing Mentor ",
            organizationName: " Existing Organization ",
            focusArea: " Existing Focus "
        )

        let didBackfill = session.applyNormalizedMetadataBackfillIfNeeded()

        XCTAssertFalse(didBackfill)
        XCTAssertEqual(session.mentorOrSupervisor, " Existing Mentor ")
        XCTAssertEqual(session.organizationName, " Existing Organization ")
        XCTAssertEqual(session.focusArea, " Existing Focus ")
    }

    func testPromptSelectorDeepUsesPhaseCaps() {
        assertExtendedModePhaseCaps(for: .deep)
    }

    func testPromptSelectorVocationUsesPhaseCaps() {
        assertExtendedModePhaseCaps(for: .vocation)
    }

    func testPromptSelectorSpiritualUsesPhaseCaps() {
        assertExtendedModePhaseCaps(for: .spiritual)
    }

    func testPromptSelectorQuickModeRemainsSinglePerPhase() {
        let prompts = makeDensePromptPool()
        let selected = PromptSelector.selectPrompts(
            allPrompts: prompts,
            mode: .quick,
            experienceContextTags: ["clinical"],
            professionTags: ["preMedicine"],
            recentPromptIDs: [],
            priorJournalCount: 0
        )

        let counts = Dictionary(grouping: selected, by: \.phase).mapValues(\.count)
        XCTAssertEqual(selected.count, 5)
        for phase in 0...4 {
            XCTAssertEqual(counts[phase], 1, "Quick mode should cap phase \(phase) to 1 prompt.")
        }
    }

    func testPromptSelectorHandlesEmptyProfessionContext() {
        let prompts = makeDensePromptPool()
        let selected = PromptSelector.selectPrompts(
            allPrompts: prompts,
            mode: .deep,
            experienceContextTags: ["clinical"],
            professionTags: [],
            recentPromptIDs: [],
            priorJournalCount: 0
        )

        XCTAssertEqual(selected.count, 19)
    }

    func testPromptSelectorDailyContextPrefersDailyTaggedPromptsInQuickMode() {
        let prompts = makeDailyPreferencePool()
        let selected = PromptSelector.selectPrompts(
            allPrompts: prompts,
            mode: .quick,
            experienceContextTags: ["other", "daily", "dailylife"],
            professionTags: ["preMedicine"],
            recentPromptIDs: [],
            priorJournalCount: 0
        )

        XCTAssertEqual(selected.count, 5)
        for prompt in selected {
            let tags = Set((prompt.tags ?? []).map { $0.lowercased() })
            XCTAssertTrue(tags.contains("dailylife"), "Daily context should prioritize dailylife-tagged prompts.")
        }
    }

    func testPromptSelectorDailyContextAllowsSpiritualPromptsInNonSpiritualMode() {
        let prompts = makeDailyPreferencePool()
        let selected = PromptSelector.selectPrompts(
            allPrompts: prompts,
            mode: .deep, // Non-spiritual mode
            experienceContextTags: ["other", "daily", "dailylife"],
            professionTags: ["preMedicine"],
            recentPromptIDs: [],
            priorJournalCount: 0
        )

        let spiritualCount = selected.filter { Set(($0.tags ?? []).map { $0.lowercased() }).contains("spiritual") }.count
        XCTAssertGreaterThan(spiritualCount, 0, "Daily context should include prayer/spiritual prompts even in non-spiritual mode.")
    }

    func testAIAdvisorPromptIncludesDynamicTrackConstraints() {
        let prompt = AIAdvisorPromptBuilder.buildPrompt(
            essay: "I learned to listen first, then respond with clarity.",
            track: .preMedicine,
            mode: .insights
        )
        let combined = prompt.systemPrompt + "\n" + prompt.userPrompt

        XCTAssertTrue(combined.contains("Portal: AMCAS"))
        XCTAssertTrue(combined.contains("Limit: 5300 chars"))
        XCTAssertTrue(combined.contains("Constraints:"))
        XCTAssertFalse(combined.contains("Technical Constraints:"))
    }

    func testAIAdvisorPromptUsesOpeningScopeLabelAndGuidance() {
        let prompt = AIAdvisorPromptBuilder.buildPrompt(
            essay: "A short opening paragraph about a formative clinical encounter.",
            track: .preMedicine,
            mode: .structure,
            scope: .opening
        )
        let combined = prompt.systemPrompt + "\n" + prompt.userPrompt

        XCTAssertTrue(combined.contains("Scope: Opening Paragraph"))
        XCTAssertTrue(combined.contains("Medical: Opening Paragraph Guidelines"))
        XCTAssertFalse(combined.contains("Body Paragraph Guidelines"))
    }

    func testAIAdvisorPromptBudgetTrimsLongInputsAndPreservesSections() {
        let essay = String(repeating: "Paragraph with detail and reflection. ", count: 500)
        let prompt = AIAdvisorPromptBuilder.buildPrompt(
            essay: essay,
            track: .preDentistry,
            mode: .structure
        )
        let combined = prompt.systemPrompt + "\n" + prompt.userPrompt

        XCTAssertLessThan(combined.count, 11050)
        XCTAssertTrue(combined.contains("Rubric Core:"))
        XCTAssertTrue(combined.contains("Rubric Details:"))
        XCTAssertTrue(combined.contains("Revisions to Consider:"))
    }

    func testAIAdvisorRevisionPromptBudgetIncludesPriorFeedback() {
        let essay = String(repeating: "I revised this paragraph with stronger reflection and evidence. ", count: 420)
        let prior = String(repeating: "- Clarify motivation and connect it to patient interactions. ", count: 220)

        let prompt = AIAdvisorPromptBuilder.buildRevisionPrompt(
            essay: essay,
            track: .prePhysicianAssistant,
            priorFeedback: prior,
            priorModeLabel: "Themes"
        )
        let combined = prompt.systemPrompt + "\n" + prompt.userPrompt

        XCTAssertLessThan(combined.count, 11750)
        XCTAssertTrue(combined.contains("Prior Feedback (Round 1):"))
        XCTAssertTrue(combined.contains("Portal: CASPA"))
        XCTAssertTrue(combined.contains("Still Needs Work:"))
    }

    func testPromptResourceLoaderScopedExcerptForBody() {
        let guidelines = PromptResourceLoader.loadGuidelines(for: .preDentistry, scope: .body)

        XCTAssertTrue(guidelines.contains("Dental: Body Paragraph Guidelines"))
        XCTAssertFalse(guidelines.contains("Opening Paragraph Guidelines"))
        XCTAssertFalse(guidelines.contains("Closing Paragraph Guidelines"))
    }

    func testExamenSessionPersistsExplicitExamenMode() {
        let session = ExamenSession(
            sessionType: .daily,
            examenMode: .spiritual,
            experienceType: .discernment
        )

        XCTAssertEqual(session.examenModeRaw, ExamenMode.spiritual.rawValue)
        XCTAssertEqual(session.examenMode, .spiritual)
    }

    func testExamenSessionFallsBackToVocationForDiscernmentAndDeepOtherwise() {
        let discernment = ExamenSession(
            sessionType: .daily,
            experienceType: .discernment
        )
        let standard = ExamenSession(
            sessionType: .daily,
            experienceType: .clinical
        )

        XCTAssertEqual(discernment.examenMode, .vocation)
        XCTAssertEqual(standard.examenMode, .deep)
    }

    @MainActor
    func testCoreFinalReflectionStillAdvancesThroughNormalCompletionSave() throws {
        let container = try makeExamenModelContainer()
        let context = container.mainContext
        let prompt = PromptTemplate(
            id: UUID(),
            text: "What do you want to keep?",
            phase: 0,
            stage: "closing",
            depth: "standard",
            stepIndex: 0
        )
        let vm = ExamenSessionViewModel(
            draft: ExamenSessionDraft(type: .clinical),
            initialStage: .promptPhase
        )
        vm.setPrompts([prompt])

        vm.continueTapped(answer: "A first pass.", usesSeparateFinalReflection: true)

        XCTAssertEqual(vm.stage, .finalReflection)
        XCTAssertEqual(vm.answerForCurrentPrompt(), "A first pass.")

        vm.continueFromFinalReflection(answer: "A steadier truth to remember.")

        XCTAssertEqual(vm.stage, .details)
        XCTAssertEqual(vm.draft.personalStatement, "A steadier truth to remember.")

        vm.advanceFromDetails(finalDraft: vm.draft)
        vm.saveSession(context: context)

        XCTAssertEqual(vm.stage, .summary)
        let savedID = try XCTUnwrap(vm.lastSavedSessionID)
        let sessions = try context.fetch(FetchDescriptor<ExamenSession>())
        let savedSession = try XCTUnwrap(sessions.first)

        XCTAssertEqual(savedSession.id, savedID)
        XCTAssertEqual(savedSession.personalStatement, "A steadier truth to remember.")
        XCTAssertEqual(savedSession.responses.map(\.answerText), ["A first pass."])
    }

    func testRouteToJournalDetailsClearsConflictingPendingDestinations() {
        let settings = AppSettings()
        let detailsID = UUID()
        let staleJournalID = UUID()
        let staleInsightID = UUID()
        let staleDraftID = UUID()

        settings.pendingJournalEntryID = staleJournalID
        settings.pendingInsightEntryIDs = [staleInsightID]
        settings.pendingInsightsLens = .values
        settings.pendingWritingTargetID = "amcas-personal-statement"
        settings.pendingWritingDraftID = staleDraftID

        settings.routeToJournalDetails(for: detailsID)

        XCTAssertEqual(settings.selectedTab, .journal)
        XCTAssertEqual(settings.pendingJournalDetailsEntryID, detailsID)
        XCTAssertNil(settings.pendingJournalEntryID)
        XCTAssertTrue(settings.pendingInsightEntryIDs.isEmpty)
        XCTAssertNil(settings.pendingInsightsLens)
        XCTAssertNil(settings.pendingWritingTargetID)
        XCTAssertNil(settings.pendingWritingDraftID)
    }

    func testDeferredJournalDetailsRouteWaitsForCoverDismissal() {
        let settings = AppSettings()
        let detailsID = UUID()

        settings.deferJournalDetailsRoute(for: detailsID)

        XCTAssertEqual(settings.deferredJournalDetailsEntryID, detailsID)
        XCTAssertNil(settings.pendingJournalDetailsEntryID)

        settings.routeDeferredJournalDetailsIfNeeded()

        XCTAssertEqual(settings.selectedTab, .journal)
        XCTAssertNil(settings.deferredJournalDetailsEntryID)
        XCTAssertEqual(settings.pendingJournalDetailsEntryID, detailsID)
    }

    func testDelayedDeferredJournalDetailsRouteCancelsWhenAnotherRouteWins() async {
        let settings = AppSettings()
        let detailsID = UUID()

        settings.deferJournalDetailsRoute(for: detailsID)
        settings.routeDeferredJournalDetailsIfNeeded(presentAfterDelay: 25_000_000)
        XCTAssertEqual(settings.selectedTab, .journal)

        settings.routeHome()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(settings.selectedTab, .home)
        XCTAssertNil(settings.deferredJournalDetailsEntryID)
        XCTAssertNil(settings.pendingJournalEntryID)
        XCTAssertNil(settings.pendingJournalDetailsEntryID)
    }

    func testDelayedDeferredJournalDetailsRouteDoesNotPresentAfterDirectTabChange() async {
        let settings = AppSettings()
        let detailsID = UUID()

        settings.deferJournalDetailsRoute(for: detailsID)
        settings.routeDeferredJournalDetailsIfNeeded(presentAfterDelay: 25_000_000)
        XCTAssertEqual(settings.selectedTab, .journal)

        settings.selectedTab = .insights
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(settings.selectedTab, .insights)
        XCTAssertNil(settings.deferredJournalDetailsEntryID)
        XCTAssertNil(settings.pendingJournalEntryID)
        XCTAssertNil(settings.pendingJournalDetailsEntryID)
    }

    func testRouteToJournalEntryQueuesEntryAndClearsOtherHandoffs() {
        let settings = AppSettings()
        let entryID = UUID()

        settings.pendingJournalDetailsEntryID = UUID()
        settings.pendingInsightEntryIDs = [UUID()]
        settings.pendingInsightsLens = .experiences
        settings.pendingWritingTargetID = "tmDSAS-personal-statement"
        settings.pendingWritingDraftID = UUID()

        settings.routeToJournalEntry(entryID)

        XCTAssertEqual(settings.selectedTab, .journal)
        XCTAssertEqual(settings.pendingJournalEntryID, entryID)
        XCTAssertNil(settings.pendingJournalDetailsEntryID)
        XCTAssertTrue(settings.pendingInsightEntryIDs.isEmpty)
        XCTAssertNil(settings.pendingInsightsLens)
        XCTAssertNil(settings.pendingWritingTargetID)
        XCTAssertNil(settings.pendingWritingDraftID)
    }

    func testRouteToInsightsWithEntrySelectionQueuesLensAndClearsWritingHandoff() {
        let settings = AppSettings()
        let entryID = UUID()

        settings.pendingJournalEntryID = UUID()
        settings.pendingJournalDetailsEntryID = UUID()
        settings.pendingWritingTargetID = "aacomas-personal-statement"
        settings.pendingWritingDraftID = UUID()

        settings.routeToInsights(lens: .values, entryIDs: [entryID])

        XCTAssertEqual(settings.selectedTab, .insights)
        XCTAssertEqual(settings.pendingInsightEntryIDs, [entryID])
        XCTAssertEqual(settings.pendingInsightsLens, .values)
        XCTAssertNil(settings.pendingJournalEntryID)
        XCTAssertNil(settings.pendingJournalDetailsEntryID)
        XCTAssertNil(settings.pendingWritingTargetID)
        XCTAssertNil(settings.pendingWritingDraftID)
    }

    func testRouteToInsightsForWritingTargetKeepsTargetWithoutLensHandoff() {
        let settings = AppSettings()
        let targetID = "amcas-personal-statement"

        settings.pendingJournalEntryID = UUID()
        settings.pendingInsightEntryIDs = [UUID()]
        settings.pendingInsightsLens = .why
        settings.pendingWritingDraftID = UUID()

        settings.routeToInsights(writingTargetID: targetID)

        XCTAssertEqual(settings.selectedTab, .insights)
        XCTAssertEqual(settings.pendingWritingTargetID, targetID)
        XCTAssertNil(settings.pendingInsightsLens)
        XCTAssertTrue(settings.pendingInsightEntryIDs.isEmpty)
        XCTAssertNil(settings.pendingJournalEntryID)
        XCTAssertNil(settings.pendingWritingDraftID)
    }

    func testRouteToWritingDraftQueuesDraftAndClearsOtherHandoffs() {
        let settings = AppSettings()
        let draftID = UUID()

        settings.pendingJournalEntryID = UUID()
        settings.pendingInsightEntryIDs = [UUID()]
        settings.pendingInsightsLens = .themes
        settings.pendingWritingTargetID = "amcas-personal-statement"

        settings.routeToWriting(draftID: draftID)

        XCTAssertEqual(settings.selectedTab, .statement)
        XCTAssertEqual(settings.pendingWritingDraftID, draftID)
        XCTAssertNil(settings.pendingWritingTargetID)
        XCTAssertNil(settings.pendingJournalEntryID)
        XCTAssertTrue(settings.pendingInsightEntryIDs.isEmpty)
        XCTAssertNil(settings.pendingInsightsLens)
    }

    func testRouteHomeClearsPendingHandoffs() {
        let settings = AppSettings()

        settings.pendingJournalEntryID = UUID()
        settings.pendingJournalDetailsEntryID = UUID()
        settings.pendingInsightEntryIDs = [UUID()]
        settings.pendingInsightsLens = .values
        settings.pendingWritingTargetID = "amcas-personal-statement"
        settings.pendingWritingDraftID = UUID()

        settings.routeHome()

        XCTAssertEqual(settings.selectedTab, .home)
        XCTAssertNil(settings.pendingJournalEntryID)
        XCTAssertNil(settings.pendingJournalDetailsEntryID)
        XCTAssertTrue(settings.pendingInsightEntryIDs.isEmpty)
        XCTAssertNil(settings.pendingInsightsLens)
        XCTAssertNil(settings.pendingWritingTargetID)
        XCTAssertNil(settings.pendingWritingDraftID)
    }

    func testJournalDetailsDraftRemapsPrimaryAndClearsHiddenFieldsOnTypeChange() {
        let entry = ExamenSession(
            sessionType: .daily,
            experienceType: .clinical,
            location: "Omaha",
            mentorOrSupervisor: "Nurse Ada",
            organizationName: "Mercy Clinic",
            focusArea: "Internal Medicine",
            hours: 8
        )
        var draft = JournalDetailsDraft(entry: entry)

        draft.changeExperience(to: ExperienceType.service)

        XCTAssertEqual(draft.primaryValue, "Nurse Ada")
        XCTAssertEqual(draft.secondaryValue, "Mercy Clinic")
        XCTAssertEqual(draft.location, "Omaha")
        XCTAssertEqual(draft.hoursString, "8")
        XCTAssertEqual(draft.focusValue, "")

        let saved = ExamenSession(sessionType: .daily, experienceType: .clinical)
        draft.apply(to: saved)

        XCTAssertEqual(saved.experienceType, ExperienceType.service)
        XCTAssertEqual(saved.roleTitle, "Nurse Ada")
        XCTAssertNil(saved.mentorOrSupervisor)
        XCTAssertNil(saved.physician)
        XCTAssertEqual(saved.organizationName, "Mercy Clinic")
        XCTAssertEqual(saved.facility, "Mercy Clinic")
        XCTAssertNil(saved.focusArea)
        XCTAssertNil(saved.specialty)
        XCTAssertEqual(saved.location, "Omaha")
        XCTAssertEqual(saved.hours, 8, accuracy: 0.001)
    }

    func testJournalDetailsDraftSaveWritesNormalizedAndLegacyFields() {
        var draft = JournalDetailsDraft()
        draft.changeExperience(to: ExperienceType.service)
        draft.primaryValue = " Pantry Lead "
        draft.secondaryValue = " St. Anne Food Pantry "
        draft.location = " Omaha "
        draft.hoursString = "3.5"
        draft.notes = " Remember the family who needed extra time. "
        draft.tags = ["service", "presence"]

        let entry = ExamenSession(sessionType: .daily, experienceType: .clinical)
        draft.apply(to: entry)

        XCTAssertEqual(entry.experienceType, ExperienceType.service)
        XCTAssertEqual(entry.roleTitle, "Pantry Lead")
        XCTAssertEqual(entry.organizationName, "St. Anne Food Pantry")
        XCTAssertEqual(entry.facility, "St. Anne Food Pantry")
        XCTAssertEqual(entry.location, "Omaha")
        XCTAssertEqual(entry.hours, 3.5, accuracy: 0.001)
        XCTAssertEqual(entry.notes, "Remember the family who needed extra time.")
        XCTAssertEqual(entry.tags, ["service", "presence"])
        XCTAssertNil(entry.mentorOrSupervisor)
        XCTAssertNil(entry.physician)
        XCTAssertNil(entry.focusArea)
        XCTAssertNil(entry.specialty)
    }

    func testJournalDetailsDraftDoesNotMutateEntryUntilApplied() {
        let entry = ExamenSession(
            sessionType: .daily,
            experienceType: .clinical,
            mentorOrSupervisor: "Original Mentor",
            organizationName: "Original Clinic",
            notes: "Original note",
            tags: ["original"],
            hours: 6
        )
        var draft = JournalDetailsDraft(entry: entry)

        draft.changeExperience(to: ExperienceType.service)
        draft.primaryValue = "Changed Role"
        draft.secondaryValue = "Changed Site"
        draft.hoursString = "2"
        draft.notes = "Changed note"
        draft.tags = ["changed"]

        XCTAssertEqual(entry.experienceType, ExperienceType.clinical)
        XCTAssertEqual(entry.mentorOrSupervisor, "Original Mentor")
        XCTAssertEqual(entry.organizationName, "Original Clinic")
        XCTAssertEqual(entry.hours, 6, accuracy: 0.001)
        XCTAssertEqual(entry.notes, "Original note")
        XCTAssertEqual(entry.tags, ["original"])
    }

    @MainActor
    func testInsightNodePersistsRenameHideAndLinkedEvidence() throws {
        let container = try makeInsightsModelContainer()
        let context = container.mainContext

        let session = makeInsightSession(
            title: "Mercy Patient Encounter",
            notes: "I listened carefully to a nervous patient and tried to bring comfort.",
            experienceType: .clinical
        )
        let node = InsightNode(
            kind: .value,
            title: "Empathy",
            status: .accepted,
            confidence: 0.84,
            source: .manual
        )
        let link = InsightEntryLink(
            entryID: session.id,
            evidenceSnippet: "I listened carefully to a nervous patient and tried to bring comfort.",
            confidence: 0.88,
            insightNode: node
        )

        context.insert(session)
        context.insert(node)
        context.insert(link)

        node.rename(to: "Deep Empathy")
        node.isHidden = true

        try context.save()

        let fetchedNodes = try context.fetch(FetchDescriptor<InsightNode>())
        let fetchedNode = try XCTUnwrap(fetchedNodes.first)

        XCTAssertEqual(fetchedNode.title, "Deep Empathy")
        XCTAssertEqual(fetchedNode.normalizedTitle, "deep empathy")
        XCTAssertTrue(fetchedNode.isHidden)
        XCTAssertEqual(fetchedNode.links.count, 1)
        XCTAssertEqual(fetchedNode.links.first?.entryID, session.id)
    }

    @MainActor
    func testInsightWorkspaceEntryPersistsEditsPinningAndDraftContent() throws {
        let container = try makeInsightsModelContainer()
        let context = container.mainContext

        let session = makeInsightSession(
            title: "Discernment of Calling",
            notes: "I kept returning to this call in prayer and conversation.",
            experienceType: .discernment,
            examenMode: .vocation
        )
        let node = InsightNode(
            kind: .motivation,
            title: "Calling",
            status: .accepted,
            confidence: 0.81,
            source: .deterministic
        )
        let workspaceEntry = InsightWorkspaceEntry(
            lens: .why,
            title: "Who I am becoming",
            promptKey: "why-future-self",
            body: "These notes keep making me imagine a steadier, more present way of serving people.",
            isPinned: true,
            sourceEntryIDs: [session.id],
            linkedInsightNode: node
        )

        context.insert(session)
        context.insert(node)
        context.insert(workspaceEntry)
        try context.save()

        workspaceEntry.rename(to: "Future self")
        workspaceEntry.body = "This path keeps asking me to become steadier and more available to suffering."
        workspaceEntry.touch()

        try context.save()

        let fetchedEntries = try context.fetch(FetchDescriptor<InsightWorkspaceEntry>())
        let fetchedEntry = try XCTUnwrap(fetchedEntries.first)

        XCTAssertEqual(fetchedEntry.title, "Future self")
        XCTAssertTrue(fetchedEntry.isPinned)
        XCTAssertEqual(fetchedEntry.sourceEntryIDs, [session.id])
        XCTAssertEqual(fetchedEntry.linkedInsightNode?.title, "Calling")
        XCTAssertTrue(fetchedEntry.draftSourceContent.contains("Brainstorming (Why)"))
        XCTAssertTrue(fetchedEntry.draftSourceContent.contains("Prompt: What future self is emerging?"))
    }

    func testInsightWorkspaceSyncDetectsSameUserICloudOverwriteRisk() {
        let entryID = UUID()
        let openedEntry = InsightWorkspaceEntry(
            id: entryID,
            lens: .why,
            title: "Calling Notes",
            body: "I noticed a quiet pull toward service.",
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        openedEntry.syncRevision = 0
        let openedSnapshot = InsightWorkspaceEntrySyncSnapshot(entry: openedEntry)
        let localFingerprint = InsightWorkspaceEntrySyncSnapshot.contentFingerprint(
            lensRaw: InsightLens.why.rawValue,
            title: "Calling Notes",
            promptKey: nil,
            body: "I noticed a quiet pull toward service, and I want to name it honestly.",
            sourceEntryIDs: [],
            linkedInsightNodeID: nil
        )

        let remoteEntry = InsightWorkspaceEntry(
            id: entryID,
            lens: .why,
            title: "Calling Notes",
            body: "On iPad, I added a sharper note about vocation.",
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        remoteEntry.syncRevision = 1
        let remoteSnapshot = InsightWorkspaceEntrySyncSnapshot(entry: remoteEntry)

        let conflict = remoteSnapshot.remoteConflictIfNeeded(
            openedSnapshot: openedSnapshot,
            currentLocalFingerprint: localFingerprint,
            observedUpdatedAt: openedSnapshot.updatedAt,
            observedSyncRevision: openedSnapshot.syncRevision
        )

        XCTAssertNotNil(conflict)
        XCTAssertEqual(conflict?.remoteModifiedAt, remoteEntry.updatedAt)
        XCTAssertEqual(conflict?.remotePreview, "On iPad, I added a sharper note about vocation.")
    }

    func testInsightWorkspaceSyncDoesNotWarnForMatchingLocalSaveEcho() {
        let entryID = UUID()
        let openedEntry = InsightWorkspaceEntry(
            id: entryID,
            lens: .values,
            title: "Presence",
            body: "I stayed with the family after rounds.",
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        openedEntry.syncRevision = 0
        let openedSnapshot = InsightWorkspaceEntrySyncSnapshot(entry: openedEntry)

        let savedEntry = InsightWorkspaceEntry(
            id: entryID,
            lens: .values,
            title: "Presence",
            body: "I stayed with the family after rounds and listened before speaking.",
            updatedAt: Date(timeIntervalSince1970: 101)
        )
        savedEntry.syncRevision = 1
        let savedSnapshot = InsightWorkspaceEntrySyncSnapshot(entry: savedEntry)

        let conflict = savedSnapshot.remoteConflictIfNeeded(
            openedSnapshot: openedSnapshot,
            currentLocalFingerprint: savedSnapshot.contentFingerprint,
            observedUpdatedAt: openedSnapshot.updatedAt,
            observedSyncRevision: openedSnapshot.syncRevision
        )

        XCTAssertNil(conflict)
    }

    func testInsightWorkspaceEditorDraftSaveIncrementsSyncRevisionAndMarksConflictResolution() {
        let entry = InsightWorkspaceEntry(
            lens: .experiences,
            title: "Clinic",
            body: "Initial version",
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        entry.applyEditorDraft(
            title: "Clinic Reflection",
            body: "I learned to slow down before entering the room.",
            promptKey: "experiences-detail",
            sourceEntryIDs: [UUID()],
            resolvingConflict: true,
            at: Date(timeIntervalSince1970: 300)
        )

        XCTAssertEqual(entry.syncRevision, 1)
        XCTAssertEqual(entry.title, "Clinic Reflection")
        XCTAssertEqual(entry.body, "I learned to slow down before entering the room.")
        XCTAssertEqual(entry.lastConflictDetectedAt, Date(timeIntervalSince1970: 300))
    }

    func testInsightNodeIdentityKeyIncludesExperienceType() {
        let normalizedTitle = InsightNode.normalize("Empathy")

        let clinicalKey = InsightNode.identityKey(
            kind: .value,
            normalizedTitle: normalizedTitle,
            experienceType: .clinical
        )
        let serviceKey = InsightNode.identityKey(
            kind: .value,
            normalizedTitle: normalizedTitle,
            experienceType: .service
        )
        let globalKey = InsightNode.identityKey(
            kind: .value,
            normalizedTitle: normalizedTitle,
            experienceType: nil
        )

        XCTAssertNotEqual(clinicalKey, serviceKey)
        XCTAssertNotEqual(clinicalKey, globalKey)
        XCTAssertNotEqual(serviceKey, globalKey)
    }

    func testInsightsFingerprintChangesWhenRelevantContentChanges() {
        let entryID = UUID()
        let base = InsightAnalysisInput(
            entryID: entryID,
            date: Date(timeIntervalSince1970: 1_000),
            experienceType: .clinical,
            examenMode: .deep,
            text: "patient presence",
            title: "Mercy Clinic",
            secondaryDetail: "Mercy Clinic",
            focusDetail: "Primary Care"
        )
        let edited = InsightAnalysisInput(
            entryID: entryID,
            date: base.date,
            experienceType: base.experienceType,
            examenMode: base.examenMode,
            text: "patient presence and trust",
            title: base.title,
            secondaryDetail: base.secondaryDetail,
            focusDetail: base.focusDetail
        )

        XCTAssertNotEqual(
            InsightsViewSupport.inputFingerprint(for: [base]),
            InsightsViewSupport.inputFingerprint(for: [edited])
        )
    }

    func testInsightsViewSupportGroupsLinkedWorkspaceEntriesByNodeID() {
        let node = InsightNode(kind: .motivation, title: "Calling", status: .accepted, source: .manual)
        let older = InsightWorkspaceEntry(
            lens: .why,
            title: "First reflection",
            body: "Older",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100),
            linkedInsightNode: node
        )
        let newer = InsightWorkspaceEntry(
            lens: .why,
            title: "Updated reflection",
            body: "Newer",
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 300),
            linkedInsightNode: node
        )

        let grouped = InsightsViewSupport.linkedWorkspaceEntriesByNodeID(from: [older, newer])

        XCTAssertEqual(grouped[node.id]?.map(\.id), [newer.id, older.id])
    }

    func testCoreInsightsUsesPatternsAndExperiencesOnly() {
        XCTAssertEqual(InsightsViewSupport.coreDefaultLens, .themes)
        XCTAssertEqual(InsightsViewSupport.coreVisibleLenses, [.themes, .experiences])
        XCTAssertEqual(InsightsViewSupport.CoreMode.allCases.map(\.title), ["Patterns", "Experiences"])
    }

    func testCoreInsightsPromptContextUsesSurfacedSuggestion() {
        let suggestion = makeInsightSuggestion(title: "Patient Presence", lens: .themes, kind: .theme)

        let context = InsightsViewSupport.promptContext(for: suggestion)

        XCTAssertEqual(context.lens, .themes)
        XCTAssertEqual(context.entryCount, suggestion.entries.count)
        XCTAssertTrue(context.signalTitles.contains("Patient Presence"))
        XCTAssertTrue(context.signalSummary.contains("Patient Presence"))
    }

    @MainActor
    func testCoreInsightsBrainstormSaveDoesNotRequireAcceptedInsightNode() throws {
        let container = try makeInsightsModelContainer()
        let context = ModelContext(container)
        let sourceID = UUID()
        let entry = InsightWorkspaceEntry(
            lens: .themes,
            title: "Pattern in patient presence",
            promptKey: "themes.pattern",
            body: "I keep noticing that calm presence matters before explanations.",
            sourceEntryIDs: [sourceID]
        )

        context.insert(entry)
        try context.save()

        let workspaceEntries = try context.fetch(FetchDescriptor<InsightWorkspaceEntry>())
        let nodes = try context.fetch(FetchDescriptor<InsightNode>())

        XCTAssertEqual(workspaceEntries.count, 1)
        XCTAssertEqual(workspaceEntries.first?.lens, .themes)
        XCTAssertEqual(workspaceEntries.first?.promptKey, "themes.pattern")
        XCTAssertEqual(workspaceEntries.first?.sourceEntryIDs, [sourceID])
        XCTAssertTrue(nodes.isEmpty)
    }

    func testInsightsAnalysisValuesSuggestEmpathyFromEvidence() {
        let service = InsightsAnalysisService()
        let session = makeInsightSession(
            title: "Comforting a Patient",
            notes: "patient compassion comfort suffering presence care accompany listen",
            experienceType: .clinical,
            examenMode: .deep
        )
        let profile = UserProfile(preProfessionalTrack: .preMedicine, hasSeenOnboarding: true)

        let suggestions = service.analyzeValues(
            entries: service.makeInputs(from: [session]),
            profile: profile
        )

        let taxonomyTitles = Set(ProfessionalValueTaxonomy.shared.map(\.title))
        let allEntryIDs = Set(suggestions.flatMap { $0.entries.map(\.entryID) })

        XCTAssertTrue(suggestions.allSatisfy { taxonomyTitles.contains($0.title) })
        XCTAssertTrue(allEntryIDs.isSubset(of: Set([session.id])))
    }

    func testInsightsAnalysisExperiencesGroupsRepeatedSiteMoments() {
        let service = InsightsAnalysisService()
        let first = ExamenSession(
            sessionType: .daily,
            examenMode: .deep,
            personalStatement: "Mercy Clinic Rounds",
            title: "Mercy Clinic Rounds",
            experienceType: .clinical,
            organizationName: "Mercy Clinic",
            notes: "I listened to patients in clinic and learned from the way the team stayed calm."
        )
        let second = ExamenSession(
            sessionType: .daily,
            examenMode: .deep,
            personalStatement: "Mercy Clinic Follow-up",
            title: "Mercy Clinic Follow-up",
            experienceType: .clinical,
            organizationName: "Mercy Clinic",
            notes: "The same clinic setting brought up questions about trust, clarity, and presence."
        )

        let suggestions = service.analyzeExperiences(entries: service.makeInputs(from: [first, second]))

        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertEqual(suggestions.first?.lens, .experiences)
        XCTAssertEqual(suggestions.first?.kind, .experience)
        XCTAssertEqual(suggestions.first?.title, "Mercy Clinic")
        XCTAssertEqual(suggestions.first?.entries.count, 2)
    }

    func testInsightsAnalysisWhyBiasesVocationNotesTowardCalling() {
        let service = InsightsAnalysisService()
        let vocationSession = makeInsightSession(
            title: "Discernment of Calling",
            notes: "calling vocation discernment path service healing accompaniment",
            experienceType: .discernment,
            examenMode: .vocation
        )
        let deepSession = makeInsightSession(
            title: "Discernment of Calling",
            notes: "calling vocation discernment path service healing accompaniment",
            experienceType: .discernment,
            examenMode: .deep
        )
        let profile = UserProfile(preProfessionalTrack: .preMedicine, hasSeenOnboarding: true)

        let vocationSuggestions = service.analyzeWhy(
            entries: service.makeInputs(from: [vocationSession]),
            profile: profile
        )
        let deepSuggestions = service.analyzeWhy(
            entries: service.makeInputs(from: [deepSession]),
            profile: profile
        )

        let motivationTitles = Set(MotivationTaxonomy.shared.map(\.title))
        let vocationPeak = vocationSuggestions.map(\.confidence).max() ?? 0
        let deepPeak = deepSuggestions.map(\.confidence).max() ?? 0

        XCTAssertTrue(vocationSuggestions.allSatisfy { motivationTitles.contains($0.title) })
        XCTAssertTrue(deepSuggestions.allSatisfy { motivationTitles.contains($0.title) })
        XCTAssertGreaterThanOrEqual(vocationPeak, deepPeak)
    }

    @MainActor
    func testInsightsRefineWithDisabledAIReturnsDeterministicSuggestions() async {
        let service = InsightsAnalysisService()
        let settings = AppSettings()
        settings.aiEnabled = false

        let suggestions = [makeInsightSuggestion(title: "Empathy", lens: .values, kind: .value)]

        let refined = await service.refineWithOptionalAI(
            suggestions,
            lens: .values,
            settings: settings
        )

        XCTAssertEqual(refined, suggestions)
    }

    @MainActor
    func testInsightsRefineWithUnavailableAIRuntimeReturnsDeterministicSuggestions() async {
        let service = InsightsAnalysisService()
        let settings = AppSettings()
        settings.aiEnabled = true

        let suggestions = [makeInsightSuggestion(title: "Empathy", lens: .values, kind: .value)]

        let refined = await service.refineWithOptionalAI(
            suggestions,
            lens: .values,
            settings: settings
        )

        XCTAssertEqual(refined, suggestions)
    }

    func testInsightsAIRefinementIgnoresProseResponses() {
        let service = InsightsAnalysisService()
        let suggestion = makeInsightSuggestion(title: "Empathy", lens: .values, kind: .value)

        let refined = service.applyAIRefinementResponse(
            "Empathy seems strongest because the note sounds compassionate.",
            to: [suggestion]
        )

        XCTAssertEqual(refined, [suggestion])
    }

    func testInsightsAIRefinementAcceptsStructuredJSONOnly() {
        let service = InsightsAnalysisService()
        let suggestion = makeInsightSuggestion(title: "Empathy", lens: .values, kind: .value)
        let response = """
        {"rankings":[{"id":"\(suggestion.id.uuidString)","confidence":0.94,"keep":true}]}
        """

        let refined = service.applyAIRefinementResponse(response, to: [suggestion])

        XCTAssertEqual(refined.count, 1)
        XCTAssertEqual(refined.first?.source, .aiAssisted)
        XCTAssertEqual(refined.first?.title, suggestion.title)
    }

    @MainActor
    func testAcceptedInsightSuggestionsPersistEvidenceAndConfidence() throws {
        let container = try makeInsightsModelContainer()
        let context = ModelContext(container)
        let entryID = UUID()

        let existingNode = InsightNode(
            kind: .value,
            title: "Empathy",
            normalizedTitle: InsightNode.normalize("Empathy"),
            status: .suggested,
            confidence: 0.35,
            source: .deterministic
        )
        let existingLink = InsightEntryLink(
            entryID: entryID,
            evidenceSnippet: "",
            confidence: 0.22,
            insightNode: existingNode
        )

        context.insert(existingNode)
        context.insert(existingLink)
        try context.save()

        let suggestion = InsightSuggestion(
            id: UUID(),
            lens: .values,
            kind: .value,
            title: "Empathy",
            normalizedTitle: InsightNode.normalize("Empathy"),
            source: .deterministic,
            scope: nil,
            experienceType: nil,
            score: 0.84,
            confidence: 0.88,
            keywordHighlights: ["presence"],
            entries: [
                InsightEntrySuggestion(
                    entryID: entryID,
                    evidenceSnippet: "I stayed present with a patient who was afraid.",
                    confidence: 0.91
                )
            ],
            sourceThemeClusterID: nil,
            taxonomyIdentifier: nil,
            persistedNodeID: nil,
            isAccepted: false
        )

        let acceptedNode = InsightsSuggestionAcceptance.accept(
            suggestion,
            existingNodes: [existingNode],
            entriesByID: [:],
            context: context
        )
        try context.save()

        let nodes = try context.fetch(FetchDescriptor<InsightNode>())
        let links = try context.fetch(FetchDescriptor<InsightEntryLink>())

        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(acceptedNode.id, existingNode.id)
        XCTAssertEqual(acceptedNode.status, .accepted)
        XCTAssertEqual(acceptedNode.confidence, 0.88)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.evidenceSnippet, "I stayed present with a patient who was afraid.")
        XCTAssertEqual(links.first?.confidence, 0.91)
    }

    @MainActor
    func testPersistIfNeededReturnsFalseWhenContextHasNoChanges() throws {
        let container = try ModelContainer(
            for: Schema([UserProfile.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let didSave = try context.persistIfNeeded(for: "save a clean context")

        XCTAssertFalse(didSave)
    }

    @MainActor
    func testPersistIfNeededSavesInsertedModels() throws {
        let container = try ModelContainer(
            for: Schema([UserProfile.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let profile = UserProfile()

        context.insert(profile)
        let didSave = try context.persistIfNeeded(for: "save a new profile")

        XCTAssertTrue(didSave)

        let fetched = try context.fetch(FetchDescriptor<UserProfile>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, profile.id)
    }

    @MainActor
    func testInsightsBackfillAcceptedThemesWithoutDuplicateLinks() throws {
        let container = try makeInsightsModelContainer()
        let context = container.mainContext

        let first = makeInsightSession(
            title: "Steady Presence",
            notes: "I stayed steady with a patient during a difficult moment.",
            experienceType: .clinical
        )
        let second = makeInsightSession(
            title: "Returning to Service",
            notes: "I came back to serve after a difficult week and kept going.",
            experienceType: .service
        )

        let cluster = ThemeCluster(
            label: "Resilience",
            scope: .acrossExperiences,
            confidence: 0.86,
            isAccepted: true
        )
        let firstLink = ThemeEntryLink(
            entryID: first.id,
            evidenceSnippet: "I stayed steady with a patient during a difficult moment.",
            confidence: 0.81,
            cluster: cluster
        )
        let secondLink = ThemeEntryLink(
            entryID: second.id,
            evidenceSnippet: "I came back to serve after a difficult week and kept going.",
            confidence: 0.83,
            cluster: cluster
        )
        let bundle = ThemeBundle(
            title: "Resilience Bundle",
            themeLabel: "Resilience",
            sourceClusterID: cluster.id,
            entryIDs: [first.id, second.id]
        )

        context.insert(first)
        context.insert(second)
        context.insert(cluster)
        context.insert(firstLink)
        context.insert(secondLink)
        context.insert(bundle)
        try context.save()

        InsightsAnalysisService.backfillInsights(in: context)
        InsightsAnalysisService.backfillInsights(in: context)

        let nodes = try context.fetch(FetchDescriptor<InsightNode>())
        let node = try XCTUnwrap(nodes.first)

        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(node.kind, .theme)
        XCTAssertEqual(node.normalizedTitle, "resilience")
        XCTAssertEqual(node.sourceThemeClusterID, cluster.id)
        XCTAssertTrue(node.isPinned)
        XCTAssertEqual(node.links.count, 2)
        XCTAssertEqual(Set(node.links.map(\.entryID)), Set([first.id, second.id]))
    }

    @MainActor
    func testInsightsWorkspacePublisherCreatesLinkedNodeAndAvoidsDuplicates() throws {
        let container = try makeInsightsModelContainer()
        let context = container.mainContext

        let first = makeInsightSession(
            title: "Mercy Clinic",
            notes: "I stayed present with a patient who was anxious about the plan.",
            experienceType: .clinical
        )
        let second = makeInsightSession(
            title: "Pantry Service",
            notes: "I returned to serve families with steadiness and warmth.",
            experienceType: .service
        )
        let workspaceEntry = InsightWorkspaceEntry(
            lens: .why,
            title: "What keeps drawing me back",
            body: "I keep returning to the kind of need that asks for steady presence.",
            sourceEntryIDs: [first.id, second.id]
        )

        context.insert(first)
        context.insert(second)
        context.insert(workspaceEntry)
        try context.save()

        let sessionsByID = [first.id: first, second.id: second]

        let initialNode = InsightsWorkspacePublisher.publish(
            entry: workspaceEntry,
            defaultKind: .motivation,
            experienceType: nil,
            sessionsByID: sessionsByID,
            context: context
        )
        try context.save()

        let republishedNode = InsightsWorkspacePublisher.publish(
            entry: workspaceEntry,
            defaultKind: .motivation,
            experienceType: nil,
            sessionsByID: sessionsByID,
            context: context
        )
        try context.save()

        let nodes = try context.fetch(FetchDescriptor<InsightNode>())
        let links = try context.fetch(FetchDescriptor<InsightEntryLink>())
        let publishedNode = try XCTUnwrap(nodes.first)

        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(initialNode.id, republishedNode.id)
        XCTAssertEqual(workspaceEntry.linkedInsightNode?.id, publishedNode.id)
        XCTAssertEqual(publishedNode.kind, .motivation)
        XCTAssertEqual(publishedNode.status, .accepted)
        XCTAssertEqual(Set(links.map(\.entryID)), Set([first.id, second.id]))
        XCTAssertTrue(links.allSatisfy { !$0.evidenceSnippet.isEmpty })
    }

    private func assertExtendedModePhaseCaps(for mode: ExamenMode) {
        let prompts = makeDensePromptPool()
        let selected = PromptSelector.selectPrompts(
            allPrompts: prompts,
            mode: mode,
            experienceContextTags: ["clinical"],
            professionTags: ["preMedicine"],
            recentPromptIDs: [],
            priorJournalCount: 0
        )

        let counts = Dictionary(grouping: selected, by: \.phase).mapValues(\.count)
        XCTAssertEqual(selected.count, 19, "Expected 19 prompts total for \(mode).")
        XCTAssertEqual(counts[0], 3, "Phase 0 should cap at 3 prompts for \(mode).")
        for phase in 1...4 {
            XCTAssertEqual(counts[phase], 4, "Phase \(phase) should cap at 4 prompts for \(mode).")
        }
    }

    private func makeDensePromptPool() -> [PromptTemplate] {
        var prompts: [PromptTemplate] = []

        for phase in 0...4 {
            for i in 0..<6 {
                prompts.append(
                    PromptTemplate(
                        id: UUID(),
                        text: "Prompt \(phase)-\(i)",
                        phase: phase,
                        stage: phase == 0 ? "opening" : "reflection",
                        depth: i.isMultiple(of: 2) ? "standard" : "deep",
                        stepIndex: i,
                        experienceTypes: ["clinical"],
                        professionTags: ["preMedicine"],
                        tags: ["clinical", "vocation", "reflection"],
                        intent: nil
                    )
                )
            }
        }

        return prompts
    }

    private func makeDailyPreferencePool() -> [PromptTemplate] {
        var prompts: [PromptTemplate] = []
        let broadExp = ["shadowing", "clinical", "service", "leadership", "research", "work"]

        for phase in 0...4 {
            prompts.append(
                PromptTemplate(
                    id: UUID(),
                    text: "Daily prompt \(phase)",
                    phase: phase,
                    stage: phase == 0 ? "opening" : "reflection",
                    depth: "standard",
                    stepIndex: 0,
                    experienceTypes: broadExp,
                    professionTags: ["preMedicine"],
                    tags: ["dailylife", "spiritual", "prayer"],
                    intent: nil
                )
            )
            prompts.append(
                PromptTemplate(
                    id: UUID(),
                    text: "Narrow prompt \(phase)",
                    phase: phase,
                    stage: phase == 0 ? "opening" : "feature-prayer",
                    depth: "standard",
                    stepIndex: 1,
                    experienceTypes: ["shadowing"],
                    professionTags: ["preMedicine"],
                    tags: ["clinical"],
                    intent: nil
                )
            )
        }

        return prompts
    }

    @MainActor
    private func makeExamenModelContainer() throws -> ModelContainer {
        let schema = Schema([
            ExamenSession.self,
            StepResponse.self,
            ApplicationExperience.self,
            ExperiencePeriod.self
        ])

        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @MainActor
    private func makeInsightsModelContainer() throws -> ModelContainer {
        let syncedUserModelTypes: [any PersistentModel.Type] = [
            UserProfile.self,
            ExamenSession.self,
            StepResponse.self,
            ApplicationExperience.self,
            ExperiencePeriod.self,
            StatementDraft.self,
            StatementSection.self,
            ThemeCluster.self,
            ThemeEntryLink.self,
            ThemeBundle.self,
            InsightNode.self,
            InsightEntryLink.self,
            InsightWorkspaceEntry.self
        ]
        let localAppModelTypes: [any PersistentModel.Type] = [
            PromptTemplate.self,
            SemanticVectorCache.self,
            StatementField.self,
            ApplicationService.self,
            PromptCycle.self,
            BestPractice.self,
            ToneGuidelines.self,
            StructureRecommendations.self,
            PracticeTheme.self
        ]
        let syncedUserSchema = Schema(syncedUserModelTypes)
        let localAppSchema = Schema(localAppModelTypes)
        let fullSchema = Schema(syncedUserModelTypes + localAppModelTypes)

        return try ModelContainer(
            for: fullSchema,
            configurations: [
                ModelConfiguration(
                    "InsightsTestUserContent",
                    schema: syncedUserSchema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                ),
                ModelConfiguration(
                    "InsightsTestLocalAppContent",
                    schema: localAppSchema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
            ]
        )
    }

    private func makeInsightSession(
        title: String,
        notes: String,
        experienceType: ExperienceType,
        examenMode: ExamenMode = .deep
    ) -> ExamenSession {
        ExamenSession(
            sessionType: .daily,
            examenMode: examenMode,
            personalStatement: title,
            title: title,
            experienceType: experienceType,
            notes: notes
        )
    }

    private func makeInsightSuggestion(
        title: String,
        lens: InsightLens,
        kind: InsightNodeKind
    ) -> InsightSuggestion {
        InsightSuggestion(
            id: UUID(),
            lens: lens,
            kind: kind,
            title: title,
            normalizedTitle: InsightNode.normalize(title),
            source: .deterministic,
            scope: nil,
            experienceType: nil,
            score: 0.74,
            confidence: 0.71,
            keywordHighlights: ["patient", "care"],
            entries: [
                InsightEntrySuggestion(
                    entryID: UUID(),
                    evidenceSnippet: "Patient care evidence",
                    confidence: 0.71
                )
            ],
            sourceThemeClusterID: nil,
            taxonomyIdentifier: nil,
            persistedNodeID: nil,
            isAccepted: false
        )
    }

    private func makeRequirement(
        id: String,
        serviceCode: RequirementApplicationService,
        officialTitle: String? = nil,
        promptText: String,
        characterLimitMax: Int
    ) -> StatementRequirement {
        StatementRequirement(
            id: id,
            serviceCode: serviceCode,
            officialTitle: officialTitle ?? "\(serviceCode.displayName) Essay",
            cycleYear: 2027,
            effectiveStartDate: Date(timeIntervalSince1970: 0),
            effectiveEndDate: Date(timeIntervalSince1970: 86_400),
            promptText: promptText,
            characterLimitMin: 0,
            characterLimitMax: characterLimitMax,
            wordLimitMin: nil,
            wordLimitMax: nil,
            formattingRules: nil,
            helpfulTip: nil,
            officialLink: nil
        )
    }

}
