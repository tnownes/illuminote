# Illuminote Development Notes — Remaining Work
_Last updated: 2025-09-03 13:42 (local)_

## 1) Scene Backgrounds (Stained Glass / Rain / Forest)
**Goal:** Backgrounds render correctly with intended layering/animation; no extra draggable sprites in previews or runtime.
- **Stained Glass:** Ensure single fullscreen background (Assets image), remove any extra `SCNNode` sprite planes or camera artifacts; use `SCNFloor`/`background.contents` or a single unlit quad facing camera.
- **Rain:** Background image behind transparent streak overlay; animated normal map drives refraction. Verify draw order and sampling; ensure overlay uses premultiplied alpha. Consider a small `CIFilter`-driven distortion for realism.
- **Forest:** Fullscreen background + lightweight particle-style leaf animation from `leaf.png` sprite sheet. Confirm texture atlas coordinates and blending.

## 2) Examen Text Box UX Polish
**Goal:** Collapsed note field on steps 1–4, auto-expanded on step 5; high-contrast in both Light/Dark mode; keyboard dismiss on tap.
- Keep “Show Note”/“Hide Note” affordance per step.
- Confirm dynamic type spacing and sufficient tappable hit areas.

## 3) Profile Setup Wizard (SwiftData `UserProfile`)
**Goal:** Replace single-sheet picker with a small wizard for future extensibility.
- Step 1: Choose pre‑professional track (e.g., pre‑med, pre‑dental, etc.).
- Step 2 (optional): Any basic preferences we add later (theme, notifications).
- Persist to SwiftData; provide Skip; always editable in Settings later.

## 4) Settings Screen
**Goal:** Central place to edit `UserProfile` (track) and theme preferences.
- SwiftUI `Form` with bindings to SwiftData `UserProfile` and `AppSettings`.
- Add “Reset onboarding” and “Export data” affordances (non-blocking).

## 5) Export to Editable Document (Journal / Statement)
**Goal:** Allow users to export entries or drafts as **editable** files (not PDF).
- Start with `.txt` and/or `.rtf` via `ShareLink` / `UIActivityViewController`.
- For Journal: export single entry or multi-select combined text.
- For Statement: export selected draft content; include minimal header metadata.

## 6) Statement Builder Niceties (Polish)
**Goal:** Improve Statement area usability.
- Inline section headers, better empty states.
- Inline “Rename draft” action and optional duplicate draft.
- Keep import filters + “Clear Filters” (already implemented).

---

## Nice-to-Haves / QA
- Unit tests for `ExamenFlowViewModel` (advance/persist).
- UI test: create session → verify it appears in Journal → add to Statement.
- Accessibility: VoiceOver labels for filter pills, stars, and toolbar actions.
- Performance: Audit heavy filters; prefer lazy views and minimal recompute.

---

### Current Status Snapshot
- Examen note field: ✅ implemented + keyboard dismiss; polish pending.
- Profile picker sheet: ✅; wizard flow planned.
- Experience Type in Prep: ✅; session labeling + post-flow tags in place.
- Journal: ✅ tap-to-view/edit; favorites; date filters; bulk tagging; add-to-statement.
- Export: ⏳ not implemented.
- Settings: ⏳ not implemented.
- Scene backgrounds: ⏳ debugging + final wiring required.

