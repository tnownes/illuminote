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

struct PersistenceAlertContext: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String

    static func saveFailure(for operation: String, details: String? = nil) -> PersistenceAlertContext {
        let trimmedOperation = operation.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseMessage: String
        if trimmedOperation.isEmpty {
            baseMessage = "Illuminote couldn't save your latest changes. Please try again."
        } else {
            baseMessage = "Illuminote couldn't \(trimmedOperation). Please try again."
        }

        if let details, !details.isEmpty {
            return PersistenceAlertContext(
                title: "Couldn't Save Changes",
                message: "\(baseMessage)\n\n\(details)"
            )
        }

        return PersistenceAlertContext(
            title: "Couldn't Save Changes",
            message: baseMessage
        )
    }
}

struct PersistenceOperationError: LocalizedError {
    let operation: String
    let underlyingError: Error

    var alertContext: PersistenceAlertContext {
        PersistenceAlertContext.saveFailure(for: operation, details: underlyingError.localizedDescription)
    }

    var errorDescription: String? {
        alertContext.message
    }
}

extension ModelContext {
    @discardableResult
    func persistIfNeeded(for operation: String) throws -> Bool {
        guard hasChanges else { return false }

        do {
            try save()
            return true
        } catch {
            throw PersistenceOperationError(operation: operation, underlyingError: error)
        }
    }
}

extension View {
    func persistenceFailureAlert(_ context: Binding<PersistenceAlertContext?>) -> some View {
        let isPresented = Binding(
            get: { context.wrappedValue != nil },
            set: { isPresented in
                if !isPresented {
                    context.wrappedValue = nil
                }
            }
        )

        return alert(
            context.wrappedValue?.title ?? "Couldn't Save Changes",
            isPresented: isPresented
        ) {
            Button("OK", role: .cancel) {
                context.wrappedValue = nil
            }
        } message: {
            Text(context.wrappedValue?.message ?? "Please try again.")
        }
    }
}
