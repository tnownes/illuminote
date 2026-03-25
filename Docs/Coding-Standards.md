# Coding Standards & Best Practices

## General
- **Language**: Swift 5.9+
- **Platform**: iOS 17.0+
- **Architecture**: MVVM (Model-View-ViewModel) where appropriate, or direct View-Model binding for simple SwiftData views.

## Naming Conventions
- **Types**: `PascalCase` (e.g., `UserProfile`, `ExamenFlowView`).
- **Properties/Functions**: `camelCase` (e.g., `fetchPrompts`, `recentPromptIDs`).
- **Files**: Match the primary type name (e.g., `UserProfile.swift`).

## SwiftData
- Use `@Model` for persistent classes.
- Use `@Query` in Views for automatic updates.
- Use `ModelContext` for inserts/deletes.
- **Avoid** performing heavy data logic in `body`. Use `.task` or ViewModels.

## UI / SwiftUI
- Break complex views into smaller subviews or computed properties (e.g., `private var content: some View`).
- Use `NavigationStack` for navigation.
- Use `@Environment` for shared dependencies (e.g., `AppSettings`).

## Error Handling
- Use `do-catch` blocks for throwing functions.
- Log errors to console with meaningful messages (e.g., `print("⚠️ Error importing prompts: \(error)")`).
- Fail gracefully in UI (e.g., show default prompts if fetch fails).

## Concurrency
- Use `async/await` for asynchronous operations.
- Ensure UI updates happen on `@MainActor`.

## Documentation
- Document complex logic with comments.
- Maintain these spec files in `Docs/`.
