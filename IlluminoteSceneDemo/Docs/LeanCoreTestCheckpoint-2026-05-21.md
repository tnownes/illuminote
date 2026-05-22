# Lean Core Test Checkpoint - 2026-05-21

## Current Goal

Continue evaluating the lean TestFlight-default experience without losing the current implementation state.

The intended core journey remains:

`Choose an experience -> Reflect -> Save to Journal -> Notice Patterns -> Write`

## Current Branch

`codex-lean-core-worktree-hygiene`

## Current Implementation State

- `IlluminoteExperienceMode` and `IlluminoteFeaturePolicy` are implemented in `Settings/AppSettings.swift`.
- Development builds default to `full`.
- TestFlight/App Store style channels default to `core`.
- Local simulator testing can force core mode with `-illuminote-core` or `ILLUMINOTE_EXPERIENCE_MODE=core`.
- A debug-only Settings panel confirms active mode, build channel, and Advisor availability.

## Lean Core Behavior Implemented

- Core Examen keeps `ExperienceTypeSelectionView` and reimagines it as a quiet focusing step.
- Core Examen hides prompt-level write controls, mic/transcription, prompt speech controls, and Examen-time Application Record creation.
- Core Examen uses a save-first Journal landing with `Save to Journal` and `Add details later`.
- Core completion emphasizes `View Journal`, `Notice Patterns`, and `Return Home`.
- Core Home hides Application Record/hour prompts.
- Core Journal reduces bulk/management actions and keeps reading plus contextual next steps.
- Core Insights uses simpler language such as `Patterns`, `Values`, and `Calling`.
- Core Writing hides Advisor entry points and exposes a non-AI `Guidance` menu with reputable external links.
- Core Settings hides AI controls and prompt speech settings.
- Onboarding copy has been shortened around the core journey.

## Verification So Far

- `git diff --check` passed for the lean-core files.
- `IlluminoteFastUnitTests` passed on iPhone 17 / iOS 26.5.
- New unit tests cover core/full policy defaults and feature availability.
- New UI smoke tests cover core Home and the core Examen experience-focus entry.

## Simulator Notes

To force core mode from Xcode:

1. Select the `IlluminoteSceneDemo` scheme.
2. Open `Product > Scheme > Edit Scheme...`.
3. Choose `Run > Arguments`.
4. Add/check `-illuminote-core`.

If the app still appears full, open Settings and check the debug panel:

- Expected: `Experience: Core`
- Expected: `Advisor allowed: No`

If Settings says core but the app still feels full, continue by tightening the visible surface rather than changing launch settings.

## Next Product Review Steps

1. Run the simulator in core mode.
2. Start Examen and confirm the experience picker feels like a focusing step, not a decision-heavy setup screen.
3. Walk through a complete reflection and confirm no mic, transcription, prompt note-taking, or Application Record choices appear.
4. Save to Journal and confirm the post-Examen path does not feel like forms or application administration.
5. Review Writing and Settings for any remaining Advisor/full-mode affordances.

## Important Cleanup Context

Before this checkpoint, the worktree contained a broad set of unrelated modifications. Those broader workspace updates were committed separately as:

`52e198a Checkpoint broader workspace updates`

The lean-core implementation is intended to live in the next commit after that checkpoint.
