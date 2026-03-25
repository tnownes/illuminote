# Changelog

## [Unreleased]

### Added
- **Custom Examen Experience**: Prompts are now dynamically selected based on User Track and Experience Type.
- **JSON Prompt Engine**: Prompts are loaded from `prompts.json` allowing for easy updates and metadata management.
- **Enhanced Prompt Selection**: Logic to filter prompts by tags, spiritual preference, mode, and history.
- **History Tracking**: The app now remembers recently used prompts to avoid repetition.
- **Profile Management**: New `ProfileView` to edit track and reset data.
- **Metadata in Journal**: Journal entries now display Physician, Facility, and Specialty.
- **Search**: Journal search now includes metadata fields.

### Changed
- **Data Model**: Updated `PromptTemplate` to include `theme`, `depthLevel`, `isSpiritual`, `tags`.
- **Navigation**: Refactored `LandingView` navigation to support dynamic prompt passing.
- **Onboarding**: Updated to support new `UserProfile` structure.

### Fixed
- **Empty Journal Entries**: Fixed issue where "New Note" entries were not displaying in the journal viewer.
- **Settings Crash**: Fixed crash related to `PreProfessionalTrack` enum mismatch.
