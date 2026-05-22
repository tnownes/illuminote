//
//  IlluminoteSceneDemoUITests.swift
//  IlluminoteSceneDemoUITests
//
//  Created by Nownes, Tobias on 5/2/25.
//

import XCTest

final class IlluminoteSceneDemoUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testRootTabOrderIncludesInsightsBetweenJournalAndWriting() throws {
        let app = launchSeededApp()
        let labels = app.tabBars.buttons.allElementsBoundByIndex.map(\.label)

        XCTAssertGreaterThanOrEqual(labels.count, 5)
        XCTAssertEqual(Array(labels.prefix(5)), ["Home", "Journal", "Insights", "Writing", "Settings"])
    }

    func testCoreModeHomeShowsLeanReflectionActions() throws {
        let app = launchSeededApp(extraArguments: ["-illuminote-core"])

        XCTAssertTrue(app.buttons["home.startExamen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.quickNote"].exists)
        XCTAssertFalse(app.buttons["examen.details.applicationRecord.toggle"].exists)
        XCTAssertFalse(app.buttons["AI Advisor"].exists)
    }

    func testCoreModeExamenStartsWithExperienceFocus() throws {
        let app = launchSeededApp(extraArguments: ["-illuminote-core"])

        let startExamenButton = app.buttons["home.startExamen"]
        XCTAssertTrue(startExamenButton.waitForExistence(timeout: 5))
        startExamenButton.tap()

        XCTAssertTrue(app.staticTexts["What are you bringing today?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["examen.type.notSure"].exists)
        XCTAssertFalse(app.buttons["examen.type.begin"].exists)

        app.buttons["examen.type.clinical"].tap()

        XCTAssertTrue(app.buttons["examen.type.begin"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["AI Advisor"].exists)
    }

    func testInsightsSupportsLensSwitchingAndGuidedWorkspace() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Insights"].tap()

        let valuesButton = app.buttons["insights.lens.values"]
        XCTAssertTrue(valuesButton.waitForExistence(timeout: 5))
        valuesButton.tap()
        XCTAssertTrue(app.buttons["insights.chooseNotes"].waitForExistence(timeout: 5))

        let closeButton = app.buttons["insights.studio.close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()
        let whyButton = app.buttons["insights.lens.why"]
        XCTAssertTrue(whyButton.waitForExistence(timeout: 5))
        whyButton.tap()
        XCTAssertTrue(app.buttons["insights.prompt.why-drawing-back"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["insights.workspace.blank"].waitForExistence(timeout: 5))

        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()
        let experiencesButton = app.buttons["insights.lens.experiences"]
        XCTAssertTrue(experiencesButton.waitForExistence(timeout: 5))
        experiencesButton.tap()

        XCTAssertTrue(app.staticTexts["Brainstorming"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["insights.workspace.blank"].waitForExistence(timeout: 5))
    }

    func testCompletionFlowRoutesIntoInsights() throws {
        let app = launchSeededApp(extraArguments: ["-ui-testing-show-completion"])

        let openInsightsButton = app.buttons["completion.openInsights"]
        XCTAssertTrue(openInsightsButton.waitForExistence(timeout: 5))
        openInsightsButton.tap()

        XCTAssertTrue(app.buttons["insights.chooseNotes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Themes Studio"].waitForExistence(timeout: 5))
    }

    func testInsightsChooseNotesPresentsEntryPicker() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Insights"].tap()

        let chooseNotesButton = app.buttons["insights.chooseNotes"]
        XCTAssertTrue(chooseNotesButton.waitForExistence(timeout: 5))
        chooseNotesButton.tap()

        XCTAssertTrue(app.navigationBars["Choose Notes"].waitForExistence(timeout: 5))
    }

    func testJournalContextActionRoutesEntryToInsightsSelection() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Journal"].tap()

        let selectButton = app.buttons["journal.selection.toggle"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 5))
        selectButton.tap()

        let rowButton = app.buttons["journal.entryButton"].firstMatch
        XCTAssertTrue(rowButton.waitForExistence(timeout: 5))
        rowButton.tap()

        let addToInsightsButton = app.buttons["journal.selection.primaryAddToInsights"]
        XCTAssertTrue(addToInsightsButton.waitForExistence(timeout: 5))
        XCTAssertTrue(addToInsightsButton.isEnabled)
        addToInsightsButton.tap()

        XCTAssertTrue(app.buttons["insights.chooseNotes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Selected Reflections (1)"].waitForExistence(timeout: 5))
    }

    func testJournalViewerRoutesDirectlyIntoEditSheet() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Journal"].tap()

        let entryRow = app.descendants(matching: .any).matching(identifier: "journal.entryRow").firstMatch
        XCTAssertTrue(entryRow.waitForExistence(timeout: 5))
        entryRow.tap()

        let editButton = app.buttons["journal.viewer.edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["journal.viewer.close"].exists)

        editButton.tap()

        XCTAssertTrue(app.buttons["journal.editText.save"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["journal.editText.cancel"].exists)
    }

    func testWritingDashboardShowsTargetSectionsAndNeedsAssignment() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Writing"].tap()

        XCTAssertTrue(app.staticTexts["Core Statements"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Supplemental Essays"].exists)
        XCTAssertTrue(app.staticTexts["School-Specific Essays"].exists)
        XCTAssertTrue(app.staticTexts["Application Entries"].exists)
        XCTAssertTrue(app.buttons["writing.applicationEntry.entry.amcas"].exists)
        XCTAssertTrue(app.staticTexts["Needs Assignment"].exists)
    }

    func testWritingTargetDetailShowsPromptAndActions() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Writing"].tap()

        let targetButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'writing.target.core.'")).firstMatch
        XCTAssertTrue(targetButton.waitForExistence(timeout: 5))
        targetButton.tap()

        XCTAssertTrue(app.navigationBars["Personal Comments Essay"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["writing.target.prompt"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["writing.target.create"].exists)
        XCTAssertTrue(app.buttons["writing.target.addJournal"].exists)
        XCTAssertTrue(app.buttons["writing.target.addInsights"].exists)
    }

    func testJournalUseInWritingPromptsForTargetChoice() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Journal"].tap()

        let entryRow = app.descendants(matching: .any).matching(identifier: "journal.entryRow").firstMatch
        XCTAssertTrue(entryRow.waitForExistence(timeout: 5))
        entryRow.tap()

        let useInWritingButton = app.buttons["journal.viewer.useInDraft"]
        XCTAssertTrue(useInWritingButton.waitForExistence(timeout: 5))
        useInWritingButton.tap()

        XCTAssertTrue(app.navigationBars["Essay Type"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["writing.destination.target"].exists)
        XCTAssertTrue(app.staticTexts["Select essay type"].exists)
        XCTAssertFalse(app.buttons["writing.destination.create"].isEnabled)
    }

    func testEssayTypePickerShowsGenericFallbackOptionsForGeneralProfile() throws {
        let app = launchSeededApp(extraArguments: ["-ui-testing-general-profile"])

        app.tabBars.buttons["Journal"].tap()

        let entryRow = app.descendants(matching: .any).matching(identifier: "journal.entryRow").firstMatch
        XCTAssertTrue(entryRow.waitForExistence(timeout: 5))
        entryRow.tap()

        let useInWritingButton = app.buttons["journal.viewer.useInDraft"]
        XCTAssertTrue(useInWritingButton.waitForExistence(timeout: 5))
        useInWritingButton.tap()

        let selectEssayTypeButton = app.buttons["writing.destination.target"]
        XCTAssertTrue(selectEssayTypeButton.waitForExistence(timeout: 5))
        selectEssayTypeButton.tap()

        XCTAssertTrue(app.navigationBars["Select Essay Type"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["writing.picker.guidance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["writing.picker.target.core.generic"].exists)
        XCTAssertTrue(app.buttons["writing.picker.target.supplemental.generic"].exists)
        XCTAssertTrue(app.buttons["writing.picker.target.school.generic"].exists)
    }

    func testApplicationEntryCardRoutesToExperienceLog() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Writing"].tap()

        let experienceSupportButton = app.buttons["writing.applicationEntry.entry.amcas"]
        XCTAssertTrue(experienceSupportButton.waitForExistence(timeout: 5))
        experienceSupportButton.tap()

        XCTAssertTrue(app.staticTexts["Experience Log"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Application-ready experiences"].waitForExistence(timeout: 5))
    }

    func testLegacySnapshotDraftStillOpensAndAllowsEditing() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Writing"].tap()

        let legacyDraft = app.staticTexts["Legacy Snapshot"]
        XCTAssertTrue(legacyDraft.waitForExistence(timeout: 5))
        legacyDraft.tap()

        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Needs Assignment"].exists)
    }

    func testWhyWorkspaceAllowsSavingAndReopeningBrainstormEntry() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Insights"].tap()

        let whyButton = app.buttons["insights.lens.why"]
        XCTAssertTrue(whyButton.waitForExistence(timeout: 5))
        whyButton.tap()

        let promptButton = app.buttons["insights.prompt.why-drawing-back"]
        XCTAssertTrue(promptButton.waitForExistence(timeout: 5))
        promptButton.tap()

        let thoughtView = app.textViews.firstMatch
        XCTAssertTrue(thoughtView.waitForExistence(timeout: 5))
        thoughtView.tap()
        thoughtView.typeText("I keep returning to the kind of patient encounter that asks for presence.")

        let saveButton = app.buttons["insights.workspace.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["What keeps drawing me back"].waitForExistence(timeout: 5))

        let editButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'insights.workspace.edit.'")).firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        XCTAssertTrue(app.navigationBars["Brainstorm"].waitForExistence(timeout: 5))
    }

    func testPublishingArchivesWorkspaceEntryAndKeepsLinkedReflectionEditable() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Insights"].tap()

        let whyButton = app.buttons["insights.lens.why"]
        XCTAssertTrue(whyButton.waitForExistence(timeout: 5))
        whyButton.tap()

        let promptButton = app.buttons["insights.prompt.why-drawing-back"]
        XCTAssertTrue(promptButton.waitForExistence(timeout: 5))
        promptButton.tap()

        let thoughtView = app.textViews.firstMatch
        XCTAssertTrue(thoughtView.waitForExistence(timeout: 5))
        thoughtView.tap()
        thoughtView.typeText("The need for steady presence keeps drawing me back.")

        let saveButton = app.buttons["insights.workspace.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        let publishButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'insights.workspace.publish.'")).firstMatch
        XCTAssertTrue(publishButton.waitForExistence(timeout: 5))
        publishButton.tap()

        let openReflectionButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'insights.node.openReflection.'")).firstMatch
        XCTAssertTrue(openReflectionButton.waitForExistence(timeout: 5))

        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'insights.workspace.publish.'")).firstMatch.exists)

        openReflectionButton.tap()
        XCTAssertTrue(app.navigationBars["Brainstorm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["insights.workspace.save"].exists)
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                launchSeededApp()
            }
        }
    }

    @discardableResult
    private func launchSeededApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-seed-insights"] + extraArguments
        app.launch()
        return app
    }
}
