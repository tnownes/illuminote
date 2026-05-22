//
//  DataStoreHelper.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 12/1/25.
//

import Foundation
import SwiftData

enum CloudKitSyncConfiguration {
    static let containerIdentifier = "iCloud.com.tobias.Illuminote"

    static var isSyncEnabledInThisBuild: Bool {
        #if ILLUMINOTE_ENABLE_CLOUDKIT_SYNC
        true
        #else
        false
        #endif
    }

    static var userContentDatabase: ModelConfiguration.CloudKitDatabase {
        guard isSyncEnabledInThisBuild else { return .none }
        return .private(containerIdentifier)
    }

    static var statusText: String {
        isSyncEnabledInThisBuild ? "Enabled for development sync" : "Disabled (.none)"
    }
}

/// Helper to manage SwiftData container initialization and potential migrations/resets.
/// Useful during development when schema changes frequently.
enum DataStoreHelper {
    private static let syncedUserModelTypes: [any PersistentModel.Type] = [
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

    private static let localAppModelTypes: [any PersistentModel.Type] = [
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

    private static var processArguments: Set<String> {
        Set(ProcessInfo.processInfo.arguments)
    }

    private static var isRunningUITests: Bool {
        processArguments.contains("-ui-testing")
    }

    private static var shouldSeedInsightsUITestData: Bool {
        processArguments.contains("-ui-testing-seed-insights")
    }

    private static var shouldUseGeneralProfileUITestData: Bool {
        processArguments.contains("-ui-testing-general-profile")
    }

    private static var shouldResetPersistentStoresAfterFailure: Bool {
        processArguments.contains("-allow-debug-store-reset")
    }
    
    @MainActor
    static func makeModelContainer() -> ModelContainer {
        let syncedUserSchema = Schema(syncedUserModelTypes)
        let localAppSchema = Schema(localAppModelTypes)
        let fullSchema = Schema(syncedUserModelTypes + localAppModelTypes)

        // Keep the user-content store name stable so existing local data remains eligible
        // for one-time split migration before CloudKit-backed sync is explicitly enabled.
        let syncedUserConfiguration = ModelConfiguration(
            isRunningUITests ? "IlluminoteUITests" : "Illuminote",
            schema: syncedUserSchema,
            isStoredInMemoryOnly: isRunningUITests,
            cloudKitDatabase: isRunningUITests ? .none : CloudKitSyncConfiguration.userContentDatabase
        )

        let localAppConfiguration = ModelConfiguration(
            isRunningUITests ? "IlluminoteLocalUITests" : "IlluminoteLocalAppContent",
            schema: localAppSchema,
            isStoredInMemoryOnly: isRunningUITests,
            cloudKitDatabase: .none
        )
        
        if let migratedPersistent = migrateLegacySingleStoreIfNeeded(
            fullSchema: fullSchema,
            syncedUserSchema: syncedUserSchema,
            localAppSchema: localAppSchema,
            syncedUserConfiguration: syncedUserConfiguration,
            localAppConfiguration: localAppConfiguration
        ) {
            return migratedPersistent
        }

        if let persistent = createContainer(
            schema: fullSchema,
            configurations: [syncedUserConfiguration, localAppConfiguration],
            label: "split persistent"
        ) {
            return persistent
        }
        
        if shouldResetPersistentStoresAfterFailure {
            print("⚠️ Attempting to reset persistent data store because -allow-debug-store-reset was provided.")
            resetPersistentStoreFiles()

            if let resetPersistent = createContainer(
                schema: fullSchema,
                configurations: [syncedUserConfiguration, localAppConfiguration],
                label: "split persistent after explicit reset"
            ) {
                return resetPersistent
            }
        } else {
            print("⚠️ Persistent store reset skipped. Add -allow-debug-store-reset only for disposable development data.")
        }
        
        print("⚠️ Falling back to in-memory SwiftData store.")
        let inMemorySyncedUserConfiguration = ModelConfiguration(
            "IlluminoteInMemoryUserFallback",
            schema: syncedUserSchema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let inMemoryLocalAppConfiguration = ModelConfiguration(
            "IlluminoteInMemoryLocalFallback",
            schema: localAppSchema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        
        if let inMemory = createContainer(
            schema: fullSchema,
            configurations: [inMemorySyncedUserConfiguration, inMemoryLocalAppConfiguration],
            label: "split in-memory fallback"
        ) {
            return inMemory
        }
        
        preconditionFailure("Could not initialize a SwiftData container in persistent or in-memory mode.")
    }
    
    @MainActor
    private static func createContainer(
        schema: Schema,
        configurations: [ModelConfiguration],
        label: String,
        shouldPrime: Bool = true
    ) -> ModelContainer? {
        do {
            let container = try ModelContainer(for: schema, configurations: configurations)
            if shouldPrime {
                prime(container: container)
            }
            return container
        } catch {
            print("⚠️ Failed to create \(label) ModelContainer: \(error)")
            return nil
        }
    }

    @MainActor
    private static func migrateLegacySingleStoreIfNeeded(
        fullSchema: Schema,
        syncedUserSchema: Schema,
        localAppSchema: Schema,
        syncedUserConfiguration: ModelConfiguration,
        localAppConfiguration: ModelConfiguration
    ) -> ModelContainer? {
        guard !isRunningUITests else { return nil }
        guard shouldAttemptLegacySplitMigration(
            localAppSchema: localAppSchema,
            localAppConfiguration: localAppConfiguration
        ) else { return nil }

        print("⚠️ Detected legacy single-store layout. Attempting one-time split-store migration.")

        let readStoreName = "IlluminoteLegacyRead"
        do {
            try prepareLegacyReadStore(named: readStoreName)
            let legacyConfiguration = ModelConfiguration(
                readStoreName,
                schema: fullSchema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            let legacyContainer = try ModelContainer(for: fullSchema, configurations: [legacyConfiguration])
            let snapshot = try LegacyStoreSnapshot.capture(from: legacyContainer.mainContext)
            try archiveLegacyStoreFiles()
            cleanupLegacyReadStore(named: readStoreName)

            guard let splitContainer = createContainer(
                schema: fullSchema,
                configurations: [syncedUserConfiguration, localAppConfiguration],
                label: "split persistent after legacy migration archive",
                shouldPrime: false
            ) else {
                return nil
            }

            try snapshot.restore(into: splitContainer.mainContext)
            prime(container: splitContainer)
            print("✅ Migrated legacy single-store user content into split local stores.")
            return splitContainer
        } catch {
            cleanupLegacyReadStore(named: readStoreName)
            print("⚠️ Legacy split-store migration failed: \(error)")
            return nil
        }
    }
    
    @MainActor
    private static func prime(container: ModelContainer) {
        if isRunningUITests {
            seedUITestDataIfNeeded(in: container.mainContext)
            return
        }

        // Import prompts synchronously so prompt selection is available immediately.
        PromptImporter.importIfNeeded(context: container.mainContext)
        backfillExperienceMetadata(in: container.mainContext)
        InsightsAnalysisService.backfillInsights(in: container.mainContext)
        
        // Knowledge base import can remain async as it is not required for first paint.
        Task { @MainActor in
            try? await importKnowledgeBaseSeed(to: container.mainContext)
        }
    }

    @MainActor
    private static func backfillExperienceMetadata(in context: ModelContext) {
        do {
            let sessions = try context.fetch(FetchDescriptor<ExamenSession>())
            var didMutate = false
            for session in sessions {
                if session.applyNormalizedMetadataBackfillIfNeeded() {
                    didMutate = true
                }
            }
            if didMutate {
                try context.save()
                print("✅ Backfilled normalized experience metadata for existing sessions.")
            }
        } catch {
            print("⚠️ Failed to backfill normalized experience metadata: \(error)")
        }
    }

    @MainActor
    private static func seedUITestDataIfNeeded(in context: ModelContext) {
        guard shouldSeedInsightsUITestData else { return }

        do {
            let existingProfiles = try context.fetch(FetchDescriptor<UserProfile>())
            guard existingProfiles.isEmpty else { return }

            let profileTrack: PreProfessionalTrack = shouldUseGeneralProfileUITestData ? .general : .preMedicine
            let profile = UserProfile(
                preProfessionalTrack: profileTrack,
                defaultMode: .vocation,
                hasSeenOnboarding: true,
                degreeIntent: .md
            )
            context.insert(profile)

            let mercyEncounter = ExamenSession(
                sessionType: .daily,
                date: Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now,
                examenMode: .deep,
                personalStatement: "Mercy Patient Encounter",
                title: "Mercy Patient Encounter",
                experienceType: .clinical,
                notes: "I listened carefully to a nervous patient and tried to bring comfort while the team explained the plan."
            )
            let discernment = ExamenSession(
                sessionType: .daily,
                date: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
                examenMode: .vocation,
                personalStatement: "Discernment of Calling",
                title: "Discernment of Calling",
                experienceType: .discernment,
                notes: "This calling toward medicine keeps returning in prayer and discernment when I accompany people in suffering."
            )
            let pantryService = ExamenSession(
                sessionType: .daily,
                date: .now,
                examenMode: .deep,
                personalStatement: "Service Pantry Shift",
                title: "Service Pantry Shift",
                experienceType: .service,
                notes: "Our team collaborated to serve families with steadiness, empathy, and practical help."
            )

            context.insert(mercyEncounter)
            context.insert(discernment)
            context.insert(pantryService)

            let experience = ApplicationExperience(
                title: "Mercy Clinic Service",
                category: .clinical,
                organizationName: "Mercy Clinic",
                roleTitle: "Volunteer Assistant",
                location: "Omaha",
                applicationDescription: "Seeded application-ready experience for UI tests."
            )
            let period = ExperiencePeriod(
                startDate: Calendar.current.date(byAdding: .month, value: -2, to: .now) ?? .now,
                endDate: .now,
                totalHours: 24,
                experience: experience
            )

            context.insert(experience)
            context.insert(period)
            mercyEncounter.applicationExperience = experience

            let assignedDraft = StatementDraft(
                title: "Seeded AMCAS Draft",
                draftScope: .full,
                writingTargetID: "core.amcas",
                writingTargetCategory: .coreStatement
            )
            assignedDraft.sections.append(
                StatementSection(
                    source: .journalEntry,
                    content: mercyEncounter.mergedDraftContent(),
                    order: 0,
                    sourceID: mercyEncounter.id
                )
            )
            context.insert(assignedDraft)

            let legacyDraft = StatementDraft(
                title: "Legacy Snapshot",
                draftScope: .opening
            )
            legacyDraft.isSnapshot = true
            legacyDraft.isLocked = true
            legacyDraft.sections.append(
                StatementSection(
                    source: .manual,
                    content: "A legacy draft should still open and remain editable in Writing.",
                    order: 0
                )
            )
            context.insert(legacyDraft)

            let empathyNode = InsightNode(
                kind: .theme,
                title: "Empathy",
                status: .accepted,
                confidence: 0.92,
                source: .deterministic,
                isPinned: true
            )
            let empathyLink = InsightEntryLink(
                entryID: mercyEncounter.id,
                evidenceSnippet: "I listened carefully to a nervous patient and tried to bring comfort.",
                confidence: 0.92,
                insightNode: empathyNode
            )

            context.insert(empathyNode)
            context.insert(empathyLink)

            try context.save()
        } catch {
            print("⚠️ Failed to seed UI test data: \(error)")
        }
    }

    private static var legacyStoreExists: Bool {
        FileManager.default.fileExists(atPath: storeURL(named: "Illuminote", suffix: "store").path)
    }

    private static var localAppStoreExists: Bool {
        FileManager.default.fileExists(atPath: storeURL(named: "IlluminoteLocalAppContent", suffix: "store").path)
    }

    @MainActor
    private static func shouldAttemptLegacySplitMigration(
        localAppSchema: Schema,
        localAppConfiguration: ModelConfiguration
    ) -> Bool {
        guard legacyStoreExists else { return false }
        guard localAppStoreExists else { return true }

        do {
            let localContainer = try ModelContainer(for: localAppSchema, configurations: [localAppConfiguration])
            let context = localContainer.mainContext
            let promptCount = try context.fetchCount(FetchDescriptor<PromptTemplate>())
            let statementFieldCount = try context.fetchCount(FetchDescriptor<StatementField>())
            let serviceCount = try context.fetchCount(FetchDescriptor<ApplicationService>())
            return promptCount == 0 && statementFieldCount == 0 && serviceCount == 0
        } catch {
            print("⚠️ Could not inspect local split store before legacy migration: \(error)")
            return true
        }
    }

    private static func storeURL(named name: String, suffix: String) -> URL {
        URL.applicationSupportDirectory.appending(path: "\(name).\(suffix)")
    }

    private static func prepareLegacyReadStore(named readStoreName: String) throws {
        cleanupLegacyReadStore(named: readStoreName)
        for suffix in ["store", "store-shm", "store-wal"] {
            let source = storeURL(named: "Illuminote", suffix: suffix)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            try FileManager.default.copyItem(at: source, to: storeURL(named: readStoreName, suffix: suffix))
        }
    }

    private static func cleanupLegacyReadStore(named readStoreName: String) {
        for suffix in ["store", "store-shm", "store-wal"] {
            try? FileManager.default.removeItem(at: storeURL(named: readStoreName, suffix: suffix))
        }
    }

    private static func archiveLegacyStoreFiles() throws {
        let archiveStamp = ISO8601DateFormatter()
            .string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let archiveName = "IlluminotePreSplit-\(archiveStamp)"

        for suffix in ["store", "store-shm", "store-wal"] {
            let source = storeURL(named: "Illuminote", suffix: suffix)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let destination = storeURL(named: archiveName, suffix: suffix)
            try FileManager.default.moveItem(at: source, to: destination)
        }

        for suffix in ["store", "store-shm", "store-wal"] {
            try? FileManager.default.removeItem(at: storeURL(named: "IlluminoteLocalAppContent", suffix: suffix))
        }
    }

    private struct LegacyStoreSnapshot {
        var profiles: [UserProfileSnapshot]
        var experiences: [ApplicationExperienceSnapshot]
        var sessions: [ExamenSessionSnapshot]
        var drafts: [StatementDraftSnapshot]
        var insightNodes: [InsightNodeSnapshot]
        var workspaceEntries: [InsightWorkspaceEntrySnapshot]
        var themeClusters: [ThemeClusterSnapshot]
        var themeBundles: [ThemeBundleSnapshot]

        @MainActor
        static func capture(from context: ModelContext) throws -> LegacyStoreSnapshot {
            LegacyStoreSnapshot(
                profiles: try context.fetch(FetchDescriptor<UserProfile>()).map(UserProfileSnapshot.init),
                experiences: try context.fetch(FetchDescriptor<ApplicationExperience>()).map(ApplicationExperienceSnapshot.init),
                sessions: try context.fetch(FetchDescriptor<ExamenSession>()).map(ExamenSessionSnapshot.init),
                drafts: try context.fetch(FetchDescriptor<StatementDraft>()).map(StatementDraftSnapshot.init),
                insightNodes: try context.fetch(FetchDescriptor<InsightNode>()).map(InsightNodeSnapshot.init),
                workspaceEntries: try context.fetch(FetchDescriptor<InsightWorkspaceEntry>()).map(InsightWorkspaceEntrySnapshot.init),
                themeClusters: try context.fetch(FetchDescriptor<ThemeCluster>()).map(ThemeClusterSnapshot.init),
                themeBundles: try context.fetch(FetchDescriptor<ThemeBundle>()).map(ThemeBundleSnapshot.init)
            )
        }

        @MainActor
        func restore(into context: ModelContext) throws {
            for profile in profiles {
                context.insert(profile.model())
            }

            var experiencesByID: [UUID: ApplicationExperience] = [:]
            for snapshot in experiences {
                let experience = snapshot.model()
                experiencesByID[snapshot.id] = experience
                context.insert(experience)

                for periodSnapshot in snapshot.periods {
                    let period = periodSnapshot.model(experience: experience)
                    context.insert(period)
                    experience.periods.append(period)
                }
            }

            var sessionsByID: [UUID: ExamenSession] = [:]
            for snapshot in sessions {
                let session = snapshot.model(applicationExperience: snapshot.applicationExperienceID.flatMap { experiencesByID[$0] })
                sessionsByID[snapshot.id] = session
                context.insert(session)

                for responseSnapshot in snapshot.responses {
                    let response = responseSnapshot.model(session: session)
                    context.insert(response)
                    session.responses.append(response)
                }
            }

            for snapshot in experiences {
                guard let experience = experiencesByID[snapshot.id] else { continue }
                experience.linkedSessions = snapshot.linkedSessionIDs.compactMap { sessionsByID[$0] }
            }

            for snapshot in drafts {
                let draft = snapshot.model()
                context.insert(draft)

                for sectionSnapshot in snapshot.sections {
                    let section = sectionSnapshot.model(draft: draft)
                    context.insert(section)
                    draft.sections.append(section)
                }
            }

            var insightNodesByID: [UUID: InsightNode] = [:]
            for snapshot in insightNodes {
                let node = snapshot.model()
                insightNodesByID[snapshot.id] = node
                context.insert(node)

                for linkSnapshot in snapshot.links {
                    let link = linkSnapshot.model(insightNode: node)
                    context.insert(link)
                    node.links.append(link)
                }
            }

            for snapshot in workspaceEntries {
                let entry = snapshot.model(linkedInsightNode: snapshot.linkedInsightNodeID.flatMap { insightNodesByID[$0] })
                context.insert(entry)
            }

            for snapshot in themeClusters {
                let cluster = snapshot.model()
                context.insert(cluster)

                for linkSnapshot in snapshot.links {
                    let link = linkSnapshot.model(cluster: cluster)
                    context.insert(link)
                    cluster.links.append(link)
                }
            }

            for snapshot in themeBundles {
                context.insert(snapshot.model())
            }

            try context.save()
        }
    }

    private struct UserProfileSnapshot {
        var id: UUID
        var preProfessionalTrack: PreProfessionalTrack?
        var recentPromptIDs: [UUID]
        var examenFrequency: ExamenFrequency
        var preferredTimeOfDay: PreferredTimeOfDay
        var sessionLength: SessionLength
        var defaultMode: ExamenMode
        var notificationsEnabled: Bool
        var notificationTime: Date
        var hasSeenOnboarding: Bool
        var degreeIntent: DegreeIntent
        var isTexasApplicant: Bool
        var isMDPhDApplicant: Bool

        init(_ profile: UserProfile) {
            id = profile.id
            preProfessionalTrack = profile.preProfessionalTrack
            recentPromptIDs = profile.recentPromptIDs
            examenFrequency = profile.examenFrequency
            preferredTimeOfDay = profile.preferredTimeOfDay
            sessionLength = profile.sessionLength
            defaultMode = profile.defaultMode
            notificationsEnabled = profile.notificationsEnabled
            notificationTime = profile.notificationTime
            hasSeenOnboarding = profile.hasSeenOnboarding
            degreeIntent = profile.degreeIntent
            isTexasApplicant = profile.isTexasApplicant
            isMDPhDApplicant = profile.isMDPhDApplicant
        }

        func model() -> UserProfile {
            UserProfile(
                id: id,
                preProfessionalTrack: preProfessionalTrack,
                recentPromptIDs: recentPromptIDs,
                examenFrequency: examenFrequency,
                preferredTimeOfDay: preferredTimeOfDay,
                sessionLength: sessionLength,
                defaultMode: defaultMode,
                notificationsEnabled: notificationsEnabled,
                notificationTime: notificationTime,
                hasSeenOnboarding: hasSeenOnboarding,
                degreeIntent: degreeIntent,
                isTexasApplicant: isTexasApplicant,
                isMDPhDApplicant: isMDPhDApplicant
            )
        }
    }

    private struct ApplicationExperienceSnapshot {
        var id: UUID
        var title: String
        var category: ApplicationExperienceCategory
        var organizationName: String?
        var roleTitle: String?
        var location: String?
        var contactName: String?
        var contactTitle: String?
        var contactEmail: String?
        var contactPhone: String?
        var contactPermissionAuthorized: Bool?
        var applicationDescription: String
        var highlightServiceCodes: [String]
        var dateCreated: Date
        var dateModified: Date
        var periods: [ExperiencePeriodSnapshot]
        var linkedSessionIDs: [UUID]

        init(_ experience: ApplicationExperience) {
            id = experience.id
            title = experience.title
            category = experience.category
            organizationName = experience.organizationName
            roleTitle = experience.roleTitle
            location = experience.location
            contactName = experience.contactName
            contactTitle = experience.contactTitle
            contactEmail = experience.contactEmail
            contactPhone = experience.contactPhone
            contactPermissionAuthorized = experience.contactPermissionAuthorized
            applicationDescription = experience.applicationDescription
            highlightServiceCodes = experience.highlightServiceCodes
            dateCreated = experience.dateCreated
            dateModified = experience.dateModified
            periods = experience.periods.map(ExperiencePeriodSnapshot.init)
            linkedSessionIDs = experience.linkedSessions.map(\.id)
        }

        func model() -> ApplicationExperience {
            ApplicationExperience(
                id: id,
                title: title,
                category: category,
                organizationName: organizationName,
                roleTitle: roleTitle,
                location: location,
                contactName: contactName,
                contactTitle: contactTitle,
                contactEmail: contactEmail,
                contactPhone: contactPhone,
                contactPermissionAuthorized: contactPermissionAuthorized,
                applicationDescription: applicationDescription,
                highlightServiceCodes: highlightServiceCodes,
                dateCreated: dateCreated,
                dateModified: dateModified
            )
        }
    }

    private struct ExperiencePeriodSnapshot {
        var id: UUID
        var startDate: Date
        var endDate: Date?
        var isOngoing: Bool
        var isPlanned: Bool
        var totalHours: Double
        var averageHoursPerWeek: Double?

        init(_ period: ExperiencePeriod) {
            id = period.id
            startDate = period.startDate
            endDate = period.endDate
            isOngoing = period.isOngoing
            isPlanned = period.isPlanned
            totalHours = period.totalHours
            averageHoursPerWeek = period.averageHoursPerWeek
        }

        func model(experience: ApplicationExperience) -> ExperiencePeriod {
            ExperiencePeriod(
                id: id,
                startDate: startDate,
                endDate: endDate,
                isOngoing: isOngoing,
                isPlanned: isPlanned,
                totalHours: totalHours,
                averageHoursPerWeek: averageHoursPerWeek,
                experience: experience
            )
        }
    }

    private struct ExamenSessionSnapshot {
        var id: UUID
        var sessionType: ExamenType
        var date: Date
        var examenModeRaw: String?
        var personalStatement: String
        var title: String
        var experienceType: ExperienceType?
        var hours: Double
        var physician: String?
        var facility: String?
        var specialty: String?
        var location: String?
        var mentorOrSupervisor: String?
        var roleTitle: String?
        var organizationName: String?
        var focusArea: String?
        var notes: String?
        var tags: [String]
        var referencedEntryIDs: [UUID]
        var applicationExperienceID: UUID?
        var isFavorite: Bool
        var responses: [StepResponseSnapshot]

        init(_ session: ExamenSession) {
            id = session.id
            sessionType = session.sessionType
            date = session.date
            examenModeRaw = session.examenModeRaw
            personalStatement = session.personalStatement
            title = session.title
            experienceType = session.experienceType
            hours = session.hours
            physician = session.physician
            facility = session.facility
            specialty = session.specialty
            location = session.location
            mentorOrSupervisor = session.mentorOrSupervisor
            roleTitle = session.roleTitle
            organizationName = session.organizationName
            focusArea = session.focusArea
            notes = session.notes
            tags = session.tags
            referencedEntryIDs = session.referencedEntryIDs
            applicationExperienceID = session.applicationExperience?.id
            isFavorite = session.isFavorite
            responses = session.responses.map(StepResponseSnapshot.init)
        }

        func model(applicationExperience: ApplicationExperience?) -> ExamenSession {
            let session = ExamenSession(
                id: id,
                sessionType: sessionType,
                date: date,
                responses: [],
                personalStatement: personalStatement,
                title: title,
                experienceType: experienceType,
                physician: physician,
                facility: facility,
                specialty: specialty,
                location: location,
                mentorOrSupervisor: mentorOrSupervisor,
                roleTitle: roleTitle,
                organizationName: organizationName,
                focusArea: focusArea,
                notes: notes,
                tags: tags,
                referencedEntryIDs: referencedEntryIDs,
                applicationExperience: applicationExperience,
                isFavorite: isFavorite,
                hours: hours
            )
            session.examenModeRaw = examenModeRaw
            return session
        }
    }

    private struct StepResponseSnapshot {
        var id: UUID
        var stepIndex: Int
        var answerText: String
        var additionalNotes: String?
        var promptID: UUID
        var stage: String

        init(_ response: StepResponse) {
            id = response.id
            stepIndex = response.stepIndex
            answerText = response.answerText
            additionalNotes = response.additionalNotes
            promptID = response.promptID
            stage = response.stage
        }

        func model(session: ExamenSession) -> StepResponse {
            StepResponse(
                id: id,
                stepIndex: stepIndex,
                answerText: answerText,
                additionalNotes: additionalNotes,
                session: session,
                promptID: promptID,
                stage: stage
            )
        }
    }

    private struct StatementDraftSnapshot {
        var id: UUID
        var title: String
        var version: Int
        var draftScopeRaw: String?
        var writingTargetID: String?
        var writingTargetCategoryRaw: String?
        var customPromptText: String?
        var isFinal: Bool
        var isLocked: Bool
        var dateCreated: Date
        var dateModified: Date
        var richTextData: Data?
        var syncRevision: Int
        var lastSyncedAt: Date?
        var lastConflictDetectedAt: Date?
        var sections: [StatementSectionSnapshot]

        init(_ draft: StatementDraft) {
            id = draft.id
            title = draft.title
            version = draft.version
            draftScopeRaw = draft.draftScopeRaw
            writingTargetID = draft.writingTargetID
            writingTargetCategoryRaw = draft.writingTargetCategoryRaw
            customPromptText = draft.customPromptText
            isFinal = draft.isFinal
            isLocked = draft.isLocked
            dateCreated = draft.dateCreated
            dateModified = draft.dateModified
            richTextData = draft.richTextData
            syncRevision = draft.syncRevision ?? 0
            lastSyncedAt = draft.lastSyncedAt
            lastConflictDetectedAt = draft.lastConflictDetectedAt
            sections = draft.sections.map(StatementSectionSnapshot.init)
        }

        func model() -> StatementDraft {
            let draft = StatementDraft(
                title: title,
                version: version,
                richTextData: richTextData,
                draftScope: StatementDraftScope(rawValue: draftScopeRaw ?? "") ?? .full,
                writingTargetID: writingTargetID,
                writingTargetCategory: writingTargetCategoryRaw.flatMap(WritingTargetCategory.init(rawValue:)),
                customPromptText: customPromptText
            )
            draft.id = id
            draft.draftScopeRaw = draftScopeRaw
            draft.writingTargetCategoryRaw = writingTargetCategoryRaw
            draft.isFinal = isFinal
            draft.isLocked = isLocked
            draft.dateCreated = dateCreated
            draft.dateModified = dateModified
            draft.syncRevision = syncRevision
            draft.lastSyncedAt = lastSyncedAt
            draft.lastConflictDetectedAt = lastConflictDetectedAt
            return draft
        }
    }

    private struct StatementSectionSnapshot {
        var id: UUID
        var order: Int
        var source: SectionSource
        var content: String
        var date: Date
        var sourceID: UUID?

        init(_ section: StatementSection) {
            id = section.id
            order = section.order
            source = section.source
            content = section.content
            date = section.date
            sourceID = section.sourceID
        }

        func model(draft: StatementDraft) -> StatementSection {
            let section = StatementSection(source: source, content: content, order: order, sourceID: sourceID)
            section.id = id
            section.date = date
            section.draft = draft
            return section
        }
    }

    private struct InsightNodeSnapshot {
        var id: UUID
        var kind: InsightNodeKind
        var title: String
        var normalizedTitle: String
        var status: InsightNodeStatus
        var confidence: Double
        var source: InsightNodeSource
        var experienceType: ExperienceType?
        var createdAt: Date
        var updatedAt: Date
        var isPinned: Bool
        var isHidden: Bool
        var sourceThemeClusterID: UUID?
        var links: [InsightEntryLinkSnapshot]

        init(_ node: InsightNode) {
            id = node.id
            kind = node.kind
            title = node.title
            normalizedTitle = node.normalizedTitle
            status = node.status
            confidence = node.confidence
            source = node.source
            experienceType = node.experienceType
            createdAt = node.createdAt
            updatedAt = node.updatedAt
            isPinned = node.isPinned
            isHidden = node.isHidden
            sourceThemeClusterID = node.sourceThemeClusterID
            links = node.links.map(InsightEntryLinkSnapshot.init)
        }

        func model() -> InsightNode {
            InsightNode(
                id: id,
                kind: kind,
                title: title,
                normalizedTitle: normalizedTitle,
                status: status,
                confidence: confidence,
                source: source,
                experienceType: experienceType,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isPinned: isPinned,
                isHidden: isHidden,
                sourceThemeClusterID: sourceThemeClusterID
            )
        }
    }

    private struct InsightEntryLinkSnapshot {
        var id: UUID
        var entryID: UUID
        var evidenceSnippet: String
        var confidence: Double
        var createdAt: Date

        init(_ link: InsightEntryLink) {
            id = link.id
            entryID = link.entryID
            evidenceSnippet = link.evidenceSnippet
            confidence = link.confidence
            createdAt = link.createdAt
        }

        func model(insightNode: InsightNode) -> InsightEntryLink {
            InsightEntryLink(
                id: id,
                entryID: entryID,
                evidenceSnippet: evidenceSnippet,
                confidence: confidence,
                createdAt: createdAt,
                insightNode: insightNode
            )
        }
    }

    private struct InsightWorkspaceEntrySnapshot {
        var id: UUID
        var lens: InsightLens
        var title: String
        var promptKey: String?
        var body: String
        var createdAt: Date
        var updatedAt: Date
        var isPinned: Bool
        var sourceEntryIDs: [UUID]
        var linkedInsightNodeID: UUID?
        var syncRevision: Int
        var lastSyncedAt: Date?
        var lastConflictDetectedAt: Date?

        init(_ entry: InsightWorkspaceEntry) {
            id = entry.id
            lens = entry.lens
            title = entry.title
            promptKey = entry.promptKey
            body = entry.body
            createdAt = entry.createdAt
            updatedAt = entry.updatedAt
            isPinned = entry.isPinned
            sourceEntryIDs = entry.sourceEntryIDs
            linkedInsightNodeID = entry.linkedInsightNode?.id
            syncRevision = entry.syncRevision ?? 0
            lastSyncedAt = entry.lastSyncedAt
            lastConflictDetectedAt = entry.lastConflictDetectedAt
        }

        func model(linkedInsightNode: InsightNode?) -> InsightWorkspaceEntry {
            let entry = InsightWorkspaceEntry(
                id: id,
                lens: lens,
                title: title,
                promptKey: promptKey,
                body: body,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isPinned: isPinned,
                sourceEntryIDs: sourceEntryIDs,
                linkedInsightNode: linkedInsightNode
            )
            entry.syncRevision = syncRevision
            entry.lastSyncedAt = lastSyncedAt
            entry.lastConflictDetectedAt = lastConflictDetectedAt
            return entry
        }
    }

    private struct ThemeClusterSnapshot {
        var id: UUID
        var label: String
        var normalizedLabel: String
        var scope: ThemeClusterScope
        var labelSource: ThemeLabelSource
        var experienceType: ExperienceType?
        var score: Double
        var confidence: Double
        var isAccepted: Bool
        var isHidden: Bool
        var createdAt: Date
        var updatedAt: Date
        var links: [ThemeEntryLinkSnapshot]

        init(_ cluster: ThemeCluster) {
            id = cluster.id
            label = cluster.label
            normalizedLabel = cluster.normalizedLabel
            scope = cluster.scope
            labelSource = cluster.labelSource
            experienceType = cluster.experienceType
            score = cluster.score
            confidence = cluster.confidence
            isAccepted = cluster.isAccepted
            isHidden = cluster.isHidden
            createdAt = cluster.createdAt
            updatedAt = cluster.updatedAt
            links = cluster.links.map(ThemeEntryLinkSnapshot.init)
        }

        func model() -> ThemeCluster {
            ThemeCluster(
                id: id,
                label: label,
                normalizedLabel: normalizedLabel,
                scope: scope,
                labelSource: labelSource,
                experienceType: experienceType,
                score: score,
                confidence: confidence,
                isAccepted: isAccepted,
                isHidden: isHidden,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    private struct ThemeEntryLinkSnapshot {
        var id: UUID
        var entryID: UUID
        var evidenceSnippet: String
        var confidence: Double

        init(_ link: ThemeEntryLink) {
            id = link.id
            entryID = link.entryID
            evidenceSnippet = link.evidenceSnippet
            confidence = link.confidence
        }

        func model(cluster: ThemeCluster) -> ThemeEntryLink {
            ThemeEntryLink(
                id: id,
                entryID: entryID,
                evidenceSnippet: evidenceSnippet,
                confidence: confidence,
                cluster: cluster
            )
        }
    }

    private struct ThemeBundleSnapshot {
        var id: UUID
        var title: String
        var themeLabel: String
        var sourceClusterID: UUID?
        var entryIDs: [UUID]
        var createdAt: Date
        var updatedAt: Date

        init(_ bundle: ThemeBundle) {
            id = bundle.id
            title = bundle.title
            themeLabel = bundle.themeLabel
            sourceClusterID = bundle.sourceClusterID
            entryIDs = bundle.entryIDs
            createdAt = bundle.createdAt
            updatedAt = bundle.updatedAt
        }

        func model() -> ThemeBundle {
            ThemeBundle(
                id: id,
                title: title,
                themeLabel: themeLabel,
                sourceClusterID: sourceClusterID,
                entryIDs: entryIDs,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }
    
    private static func resetPersistentStoreFiles() {
        try? FileManager.default.removeItem(at: URL.applicationSupportDirectory.appending(path: "Illuminote.store"))
        try? FileManager.default.removeItem(at: URL.applicationSupportDirectory.appending(path: "Illuminote.store-shm"))
        try? FileManager.default.removeItem(at: URL.applicationSupportDirectory.appending(path: "Illuminote.store-wal"))
        try? FileManager.default.removeItem(at: URL.applicationSupportDirectory.appending(path: "IlluminoteLocalAppContent.store"))
        try? FileManager.default.removeItem(at: URL.applicationSupportDirectory.appending(path: "IlluminoteLocalAppContent.store-shm"))
        try? FileManager.default.removeItem(at: URL.applicationSupportDirectory.appending(path: "IlluminoteLocalAppContent.store-wal"))
    }
}
