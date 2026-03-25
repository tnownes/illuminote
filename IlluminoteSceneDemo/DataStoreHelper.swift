//
//  DataStoreHelper.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 12/1/25.
//

import Foundation
import SwiftData

/// Helper to manage SwiftData container initialization and potential migrations/resets.
/// Useful during development when schema changes frequently.
enum DataStoreHelper {
    
    @MainActor
    static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            UserProfile.self,
            ExamenSession.self,
            StepResponse.self,
            PromptTemplate.self,
            ApplicationExperience.self,
            ExperiencePeriod.self,
            StatementDraft.self,
            StatementSection.self,
            ThemeCluster.self,
            ThemeEntryLink.self,
            ThemeBundle.self,
            // Knowledge Base Models
            StatementField.self,
            ApplicationService.self,
            PromptCycle.self,
            BestPractice.self,
            PracticeTheme.self,
            ToneGuidelines.self,
            StructureRecommendations.self
        ])
        
        let persistentConfiguration = ModelConfiguration("Illuminote", schema: schema, isStoredInMemoryOnly: false)
        
        if let persistent = createContainer(schema: schema, configuration: persistentConfiguration, label: "persistent") {
            return persistent
        }
        
        #if DEBUG
        print("⚠️ Attempting to reset persistent data store (DEBUG only).")
        resetPersistentStoreFiles()
        
        if let resetPersistent = createContainer(schema: schema, configuration: persistentConfiguration, label: "persistent after reset") {
            return resetPersistent
        }
        #endif
        
        print("⚠️ Falling back to in-memory SwiftData store.")
        let inMemoryConfiguration = ModelConfiguration("IlluminoteInMemoryFallback", schema: schema, isStoredInMemoryOnly: true)
        
        if let inMemory = createContainer(schema: schema, configuration: inMemoryConfiguration, label: "in-memory fallback") {
            return inMemory
        }
        
        preconditionFailure("Could not initialize a SwiftData container in persistent or in-memory mode.")
    }
    
    @MainActor
    private static func createContainer(
        schema: Schema,
        configuration: ModelConfiguration,
        label: String
    ) -> ModelContainer? {
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            prime(container: container)
            return container
        } catch {
            print("⚠️ Failed to create \(label) ModelContainer: \(error)")
            return nil
        }
    }
    
    @MainActor
    private static func prime(container: ModelContainer) {
        // Import prompts synchronously so prompt selection is available immediately.
        PromptImporter.importIfNeeded(context: container.mainContext)
        backfillExperienceMetadata(in: container.mainContext)
        
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
    
    private static func resetPersistentStoreFiles() {
        try? FileManager.default.removeItem(at: URL.applicationSupportDirectory.appending(path: "Illuminote.store"))
        try? FileManager.default.removeItem(at: URL.applicationSupportDirectory.appending(path: "Illuminote.store-shm"))
        try? FileManager.default.removeItem(at: URL.applicationSupportDirectory.appending(path: "Illuminote.store-wal"))
    }
}
