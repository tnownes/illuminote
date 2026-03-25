import SwiftUI
import SwiftData

// NOTE:
// This file previously re-declared @Model types (StepResponse, ExamenSession),
// which conflicted with the canonical models in ExamenModel.swift and caused
// “Invalid redeclaration” / “ambiguous for type lookup” errors.
//
// Keep all @Model definitions in **ExamenModel.swift** (single source of truth).
// This file now contains only thin helper functions for optional use.

// MARK: - Optional helpers for ExamenSession operations
struct SessionHelpers {
    /// Load sessions with a given sort order. Default: by date ascending.
    static func loadSessions(
        from context: ModelContext,
        order: SortOrder = .forward
    ) throws -> [ExamenSession] {
        let fetch = FetchDescriptor<ExamenSession>(
            sortBy: [SortDescriptor(\ExamenSession.date, order: order)]
        )
        return try context.fetch(fetch)
    }

    /// Insert if needed and persist the session.
    static func save(_ session: ExamenSession, in context: ModelContext) throws {
        // SwiftData registers the model with the context; safe to call even if already registered.
        context.insert(session)
        if context.hasChanges {
            try context.save()
        }
    }

    /// Delete a session and persist the change.
    static func delete(_ session: ExamenSession, in context: ModelContext) throws {
        context.delete(session)
        if context.hasChanges {
            try context.save()
        }
    }
}
