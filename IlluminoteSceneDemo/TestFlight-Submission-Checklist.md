# Illuminote TestFlight Submission Checklist

Last updated: March 18, 2026

## Build & Packaging
- [x] Debug build succeeds locally.
- [x] Release build succeeds locally.
- [x] `Info.plist` includes:
  - `NSMicrophoneUsageDescription`
  - `NSSpeechRecognitionUsageDescription`
  - `ITSAppUsesNonExemptEncryption = NO`
- [x] `PrivacyInfo.xcprivacy` exists in app resources.
- [x] App icon configured in `Assets.xcassets/AppIcon.appiconset`.

## Must Verify Before Next Upload
- [x] Hide `KB Verification` from the alpha/release-facing build channel.
  - Current gate: `PSBuilder/StatementListView.swift` -> `AppSettings.knowledgeBaseVerificationAllowedInThisBuild`.
- [x] Confirm AI posture for the external alpha build is intentional.
  - Current gate: `Settings/AppSettings.swift` -> `AppBuildPolicy`.
  - Alpha posture: AI on, `Qwen3.5-2B` only, no experimental 4B controls.
- [ ] Confirm deployment scope is intentional.
  - Current build settings indicate iPhone + iPad and iOS deployment target 18.6.
- [ ] Run Archive -> Validate and clear any privacy manifest / Required Reason API warnings.
- [ ] Confirm app size and install experience are acceptable for external testers.
  - Current release app contains on-device model and is large.

## External Alpha Build Channel
- [x] `Debug` maps to `development` and keeps internal tooling for local testing.
- [x] `Release` maps to `alpha_external` and hides developer-facing surfaces by default.
- [x] External alpha hides:
  - Internal AI diagnostics
  - Examen debug labels
  - Experimental 4B controls
  - KB Verification entry point
- [ ] Verify an archived Release/TestFlight build still hides those surfaces even if the device previously had developer toggles enabled.
- [ ] Confirm the app falls back to `Qwen3.5-2B` if a tester previously downloaded 4B during internal evaluation.

## App Store Connect (Manual)
- [ ] Privacy Policy URL is set and reachable.
- [ ] App Privacy Nutrition Labels match actual behavior.
- [ ] Age Rating questionnaire complete and accurate.
- [ ] Export Compliance answers align with current binary.
- [ ] TestFlight Beta Review info complete:
  - [ ] What to Test
  - [ ] Contact info
  - [ ] Reviewer notes:
    - No login required
    - No payments/subscriptions required
    - Microphone and speech permissions are only for audio capture/transcription and Examen prompt speech
    - AI Advisor runs on-device in the alpha build
  - [ ] Use an email-invite external tester group for the alpha

## Functional Regression Pass (Recommended)
- [ ] Onboarding flow runs start-to-finish with updated copy and mode setup.
- [ ] Examen prompt flow:
  - [ ] Phase 0 starts with first-principle in non-quick modes.
  - [ ] History-gated prompt does not appear for first-time users.
- [ ] Statement editor + AI Advisor:
  - [ ] No crash on realistic long drafts in tested range.
  - [ ] Revision Follow-up path works when prior feedback exists.
- [ ] Journal to PSBuilder handoff still works with current navigation.

## Deferred Scope (Track Separately)
- [ ] CloudKit/iCloud sync refactor (post-TestFlight milestone).
