# Phase 4 Sync-Aware UX Runbook

Use this runbook after Phase 3 development CloudKit validation passes on real iPhone and iPad devices.

## Goal

Phase 4 makes sync understandable and safe for ordinary use. CloudKit remains system-driven, so Illuminote should avoid implying that users can force immediate server sync. Instead, the app should show clear status, provide familiar refresh affordances, and protect long-form writing from silent overwrite.

## Implemented Slice

- Settings now includes a user-facing iCloud Sync panel outside internal diagnostics.
- Journal and Writing lists support pull-to-refresh as a local SwiftData snapshot refresh after CloudKit changes land.
- Writing drafts increment `syncRevision` on save.
- The draft editor detects when a draft changes through iCloud while local edits are open after the remote change has landed in the local SwiftData store.
- The draft editor offers three recovery paths: save local edits as a copy, keep local edits in the current draft, or reload the iCloud version.
- Rich text saves mirror plain text into a synced draft section so receiving devices have a visible fallback if rich-text payload delivery/rendering lags.
- Draft editors avoid updating `dateModified` when a user opens and leaves without changing content.
- Long-form `InsightWorkspaceEntry` brainstorming entries increment `syncRevision` on save and track an opened editor snapshot.
- The Insights brainstorming editor detects when an entry changes through iCloud while local edits are open after the remote change has landed in the local SwiftData store.
- The Insights brainstorming editor offers three recovery paths: save local edits as a copy, keep local edits in the current entry, or reload the iCloud version.

## Known V1 Boundary

Live in-editor remote updates are not reliable enough to promise real-time collaboration. During testing, iPad changes did not consistently arrive in an already-open iPhone editor until the app or view refreshed. Treat iCloud sync as same-user continuity, not Google Docs-style live co-editing.

Product behavior should therefore favor:

- Pull-to-refresh and foreground/view refresh checks for newly arrived iCloud changes.
- Save-as-copy recovery when a conflict is detected after remote data lands locally.
- Clear support language that draft updates may take a moment to appear on another device.
- Continued iPad UX work without blocking on live in-editor conflict detection.

## Validation Checklist

### Writing Drafts

- Confirm Settings shows iCloud account status, sync state, and CloudKit container.
- Open the same draft on iPhone and iPad.
- Edit and save on iPad while the iPhone editor remains open with unsaved local edits.
- Confirm the iPhone shows the "Updated on another device" recovery banner.
- Test "Save My Edits as a Copy" and confirm the copy syncs to the other device.
- Test "Keep My Edits Here" and confirm it overwrites intentionally, not silently.
- Test "Reload iCloud Version" and confirm the remote version replaces local unsaved text.
- Confirm normal single-device saves do not show conflict warnings.

### Insights Brainstorming Entries

- Open the same saved Insights brainstorming entry on iPhone and iPad.
- Edit and save on iPad while the iPhone brainstorming editor remains open with unsaved local edits.
- Confirm the iPhone shows the "Newer iCloud version available" recovery card after the iCloud version lands locally.
- Test "Save These Edits as a Copy" and confirm the copied brainstorming entry syncs to the other device.
- Test "Keep My Edits Here" and confirm it overwrites intentionally, not silently.
- Test "Open iCloud Version" and confirm the remote version replaces local unsaved text.
- Confirm normal single-device saves increment `syncRevision` without showing conflict warnings.

## Remaining Phase 4 Work

- Validate `InsightWorkspaceEntry` conflict recovery on real iPhone and iPad devices using the same Apple ID.
- Add calmer empty/delay copy for second-device first launch when synced data may still be arriving.
- Add support FAQ copy for iCloud storage, private database sync, and local-only AI/model state.
- Re-run offline edit and delete propagation checks after conflict recovery has settled.
