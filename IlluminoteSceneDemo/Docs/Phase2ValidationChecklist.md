# Phase 2 Simulator Validation Checklist

Use this checklist before moving from Phase 2 local-only split storage into Phase 3 CloudKit entitlements and development sync.

## Goal

Prove that an existing local-only Illuminote install can upgrade into the split local SwiftData configuration without losing user-authored data or duplicating local reference data.

## Debug Diagnostics Location

Run a Debug/development build, then open:

`Settings` -> `Advanced / Internal` -> `Diagnostics` -> `Phase 2 store validation`

Tap `Refresh Store Diagnostics` after the app has been open for a few seconds.

Expected diagnostics:

- `Synced user store`: `Illuminote`
- `Local app store`: `IlluminoteLocalAppContent`
- `CloudKit`: `Disabled (.none)`
- `PromptTemplate.id`, `StatementField.id`, and `ApplicationService.id` show no duplicate warnings.
- `Semantic cache` can be `0`; it is local derived state and is not required for pass/fail.

## Upgrade-Install Rehearsal

1. Choose a dedicated simulator.
2. Optional clean start: erase that simulator before creating the baseline.
3. Check out or otherwise run a known pre-Phase-2 build using the normal `IlluminoteSceneDemo` scheme.
4. Create representative local data in the baseline build:
   - One completed profile/onboarding state.
   - At least two journal/Examen entries with responses.
   - One writing draft with at least one section.
   - One accepted insight or insight workspace entry.
   - One application experience with period/hour data.
5. Record the visible baseline counts manually.
6. Do not delete the app.
7. Switch back to the current Phase 2 build and run/install over the existing simulator app.
8. Open each main area and confirm the baseline data is still visible:
   - Journal entries.
   - Writing drafts and sections.
   - Insights or workspace entries.
   - Experience log records and periods.
   - Profile/onboarding state.
9. Open the Phase 2 diagnostics panel and refresh it.
10. Confirm the diagnostics counts agree with your baseline data and show no duplicate warnings.
11. Edit one upgraded record, save it, force quit, reopen, and confirm the edit persisted.

## Fresh-Install Rehearsal

1. Delete the app from the same simulator.
2. Run the current Phase 2 build cleanly.
3. Wait a few seconds for local seed/backfill work.
4. Open the Phase 2 diagnostics panel and refresh it.
5. Confirm prompt and knowledge-base counts are nonzero after seeding.
6. Force quit and reopen the app.
7. Refresh diagnostics again and confirm prompt and knowledge-base counts do not duplicate.

## Pass Criteria

- Existing user-authored data survives upgrade install.
- Prompt templates and knowledge-base records remain local and do not duplicate after relaunch.
- Diagnostics show CloudKit remains disabled.
- Diagnostics show no duplicate prompt, statement field, or application service IDs.
- Fresh install seeds local reference content successfully.
- The app still works locally with iCloud disabled/not involved.

## Fail Conditions

- Any upgraded journal, draft, insight, profile, or experience record disappears.
- Prompt or knowledge-base counts increase unexpectedly after relaunch.
- Diagnostics show duplicate warnings.
- The app falls back to an empty in-memory store during the upgrade rehearsal.
- A save/edit after upgrade does not persist across force quit and relaunch.
