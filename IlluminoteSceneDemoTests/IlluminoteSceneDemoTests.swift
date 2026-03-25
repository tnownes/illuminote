//
//  IlluminoteSceneDemoTests.swift
//  IlluminoteSceneDemoTests
//
//  Created by Nownes, Tobias on 5/2/25.
//

import XCTest
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
            mode: .themes
        )

        XCTAssertTrue(prompt.contains("Portal Context: AMCAS"))
        XCTAssertTrue(prompt.contains("Character Limit Target: 5300 characters including spaces"))
        XCTAssertTrue(prompt.contains("Application Constraints:"))
        XCTAssertFalse(prompt.contains("Technical Constraints:"))
    }

    func testAIAdvisorPromptUsesOpeningScopeLabelAndGuidance() {
        let prompt = AIAdvisorPromptBuilder.buildPrompt(
            essay: "A short opening paragraph about a formative clinical encounter.",
            track: .preMedicine,
            mode: .structure,
            scope: .opening
        )

        XCTAssertTrue(prompt.contains("Draft Scope: Opening Paragraph"))
        XCTAssertTrue(prompt.contains("Medical: Opening Paragraph Guidelines"))
        XCTAssertFalse(prompt.contains("Body Paragraph Guidelines"))
    }

    func testAIAdvisorPromptBudgetTrimsLongInputsAndPreservesSections() {
        let essay = String(repeating: "Paragraph with detail and reflection. ", count: 500)
        let prompt = AIAdvisorPromptBuilder.buildPrompt(
            essay: essay,
            track: .preDentistry,
            mode: .structure
        )

        XCTAssertLessThan(prompt.count, 11050)
        XCTAssertTrue(prompt.contains("Rubric Core:"))
        XCTAssertTrue(prompt.contains("Rubric Details:"))
        XCTAssertTrue(prompt.contains("Revisions to Consider:"))
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

        XCTAssertLessThan(prompt.count, 11750)
        XCTAssertTrue(prompt.contains("Prior Feedback (Round 1):"))
        XCTAssertTrue(prompt.contains("Portal Context: CASPA"))
        XCTAssertTrue(prompt.contains("Still Needs Work:"))
    }

    func testPromptResourceLoaderScopedExcerptForBody() {
        let guidelines = PromptResourceLoader.loadGuidelines(for: .preDentistry, scope: .body)

        XCTAssertTrue(guidelines.contains("Dental: Body Paragraph Guidelines"))
        XCTAssertFalse(guidelines.contains("Opening Paragraph Guidelines"))
        XCTAssertFalse(guidelines.contains("Closing Paragraph Guidelines"))
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

}
