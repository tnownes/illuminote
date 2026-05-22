# Illuminote iCloud Sync Plan

## Summary

Illuminote will keep SwiftData and prepare for CloudKit-backed private iCloud sync for user-authored content. The first implementation phases split the model configuration into user content and local app/reference content while keeping CloudKit disabled unless the explicit development sync build flag is enabled.

CloudKit sync should not be enabled until the development schema has been validated on real iPhone and iPad devices using the same Apple ID. CloudKit schemas are additive after production promotion, so schema review must happen before any production rollout.

## Sync Contract

Synced user content:

- `UserProfile`
- `ExamenSession`
- `StepResponse`
- `StatementDraft`
- `StatementSection`
- `ApplicationExperience`
- `ExperiencePeriod`
- `InsightNode`
- `InsightEntryLink`
- `InsightWorkspaceEntry`
- `ThemeCluster`
- `ThemeEntryLink`
- `ThemeBundle`

Local app content:

- `PromptTemplate`
- `SemanticVectorCache`
- `StatementField`
- `ApplicationService`
- `PromptCycle`
- `BestPractice`
- `PracticeTheme`
- `ToneGuidelines`
- `StructureRecommendations`

Local non-model state:

- `AppSettings` and `@AppStorage` coaching flags
- `AdvisorFeedbackStore`
- `MLXManager` diagnostics and runtime state
- `OnDemandModelManager` prepared/download state
- Device notification state and other device-specific preferences

## Schema Rules

- Synced SwiftData models must not use `@Attribute(.unique)`.
- Synced relationships must be optional or backed by optional storage with nonoptional convenience accessors.
- Synced to-many relationships should declare explicit optional inverses so CloudKit mapping is reviewable before development sync is enabled.
- Derived semantic vectors stay local in `SemanticVectorCache`, keyed by journal entry ID.
- Seeded reference content stays in the local configuration to avoid CloudKit duplication and user-visible reference-data churn.

## Phase 1 Status

- `IlluminoteFastUnitTests` is the preferred fast lane for schema, migration, and model-container work because it builds the app with MLX disabled and no model resources copied.
- The split local-only container shape initializes in unit tests with `SyncedUserContent` and `LocalAppContent` model groups.
- `StatementDraft.sections`, `ExamenSession.responses`, `ApplicationExperience.periods`, `ApplicationExperience.linkedSessions`, `InsightNode.links`, and `ThemeCluster.links` are backed by optional relationship storage for CloudKit compatibility.
- `StatementDraft.sections` and legacy `ThemeCluster.links` now have explicit inverse relationships verified by unit tests.
- Remaining CloudKit validation still requires the later entitlements/development-sync phase on real iPhone and iPad devices.

## Phase 2 Status

- The app is running with split local-only model configurations: user-authored content remains in the stable `Illuminote` store and reference/runtime content lives in `IlluminoteLocalAppContent`.
- CloudKit remains disabled by default with `cloudKitDatabase: .none` unless `ILLUMINOTE_ENABLE_CLOUDKIT_SYNC` is present.
- Prompt template seeding now reconciles bundled local reference data in place instead of deleting and recreating all prompts on every launch.
- Knowledge base seeding remains local-only and idempotent by skipping import when `StatementField` records already exist.
- Normalized experience metadata and insights backfills still run during container priming and save only when they mutate existing records.
- Fast unit tests cover split-container initialization, explicit synced relationship inverses, and idempotent prompt reconciliation.
- Phase 2 upgrade and fresh-install validation passed: existing profile, journal, writing draft sections, and experience records survived the split-store upgrade, and local reference data remained in `IlluminoteLocalAppContent`.

## Phase 3 Status

- Debug builds now have a CloudKit entitlement file for `iCloud.com.tobias.Illuminote`.
- Debug builds compile `ILLUMINOTE_ENABLE_CLOUDKIT_DIAGNOSTICS`, allowing Settings to query iCloud account status without the missing-entitlement warning.
- Actual SwiftData CloudKit sync is gated behind `ILLUMINOTE_ENABLE_CLOUDKIT_SYNC`, which is now enabled for the main app target's Debug build so development schema testing can begin.
- The Phase 3 runbook lives at `Docs/Phase3CloudKitDevelopmentRunbook.md`.

## Phase 4 Status

- Phase 3 development validation passed on real iPhone and iPad devices: records appear in the private CloudKit development database, and edits propagate both directions.
- Settings now has a user-facing iCloud Sync panel for account status, sync state, and local-only AI/model caveats.
- Journal and Writing lists support pull-to-refresh as a local SwiftData refresh after CloudKit-delivered changes arrive.
- Writing drafts increment `syncRevision` on save and detect another-device updates while the rich text editor has local edits open.
- Draft conflict recovery offers save-as-copy, keep-local-edits, and reload-iCloud-version paths.
- The Phase 4 runbook lives at `Docs/Phase4SyncAwareUXRunbook.md`.

## Rollout Policy

1. Keep split stores local-only until schema and migration tests pass.
2. Add iCloud and Background Modes entitlements only for internal development builds.
3. Initialize the CloudKit development schema only after enabling `ILLUMINOTE_ENABLE_CLOUDKIT_SYNC` for a deliberate Debug/internal build.
4. Validate on real iPhone and iPad devices before TestFlight.
5. Promote the CloudKit schema to production only after internal sync validation is complete.

## Test Matrix

- Upgrade install preserves existing local journal, writing, insights, profile, and experience data.
- Fresh install seeds prompts and knowledge base into local storage.
- iCloud unavailable still allows local-only app use.
- iPhone creates journal entry, iPad receives it.
- iPad edits writing draft, iPhone receives it.
- Offline edits sync after reconnect.
- Delete propagation works for journal entries, drafts, insight workspace entries, and experience records.
- Concurrent draft edits surface a recoverable conflict path before public rollout.

## Known V1 Limits

- CloudKit sync is not enabled unless `ILLUMINOTE_ENABLE_CLOUDKIT_SYNC` is present.
- Advisor feedback snapshots remain device-local.
- AI model downloads remain device-local.
- Rich merge for long-form writing is planned for the sync-aware UX phase.
