# Phase 3 CloudKit Development Runbook

Use this runbook after Phase 2 split-store validation passes. Phase 3 is development-only until the CloudKit schema has been inspected and real-device sync has been validated.

## Current Phase 3 Gate

- Debug app builds include the CloudKit entitlement file at `IlluminoteSceneDemo/IlluminoteSceneDemo.entitlements`.
- Debug app builds include `ILLUMINOTE_ENABLE_CLOUDKIT_DIAGNOSTICS`, so Settings can query iCloud account status without triggering the earlier missing-entitlement warning.
- SwiftData CloudKit sync is gated behind `ILLUMINOTE_ENABLE_CLOUDKIT_SYNC`.
- `ILLUMINOTE_ENABLE_CLOUDKIT_SYNC` is currently enabled for the main app target's Debug build so development sync testing can begin.
- If `ILLUMINOTE_ENABLE_CLOUDKIT_SYNC` is removed, the user-content store returns to `cloudKitDatabase: .none`.
- Local app/reference content always remains local-only.

## CloudKit Container

- Container identifier: `iCloud.com.tobias.Illuminote`
- Database: private CloudKit database
- Synced SwiftData configuration: `Illuminote`
- Local-only SwiftData configuration: `IlluminoteLocalAppContent`

## Before Enabling Sync

- Confirm the Apple Developer account has an iCloud container named `iCloud.com.tobias.Illuminote`.
- Confirm the app target has iCloud > CloudKit and Background Modes > Remote notifications enabled in Xcode.
- Confirm the Debug build signs with `IlluminoteSceneDemo.entitlements`.
- Confirm Settings diagnostics shows an iCloud account status instead of the missing-entitlement warning.
- Do not promote any CloudKit schema to production.

## First Development Sync Build

`ILLUMINOTE_ENABLE_CLOUDKIT_SYNC` is enabled in the app target Debug `SWIFT_ACTIVE_COMPILATION_CONDITIONS`.

Expected behavior:

- `Illuminote` user-authored content uses `.private("iCloud.com.tobias.Illuminote")`.
- `IlluminoteLocalAppContent` remains `.none`.
- Settings diagnostics reports CloudKit as enabled for development sync.
- CloudKit Console development environment shows record types for synced user-content models only.

## Validation Checklist

- Fresh install on iPhone creates profile, journal note, draft, insight workspace entry, and experience entry.
- Same Apple ID iPad receives those records after sync delay.
- iPad creates or edits user content and iPhone receives it.
- Airplane-mode/offline edit persists locally and syncs after reconnect.
- Delete propagation works for journal entries, drafts, insight workspace entries, and experience records.
- Seeded prompts and knowledge-base records do not appear as user-visible duplicates.
- Disabled or unavailable iCloud still leaves the app usable locally.

## Stop Conditions

- Stop if SwiftData reports CloudKit schema incompatibility.
- Stop if local-only models appear in CloudKit Console.
- Stop if existing local data disappears or onboarding unexpectedly reappears.
- Stop if draft text is silently overwritten during concurrent edits.
- Stop before any production schema promotion.
