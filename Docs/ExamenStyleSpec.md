# Examen Flow Specification

This document defines the visual design, transitions, behavior, theming, layout, and accessibility requirements for the Examen flow. It serves as the single source of truth for maintainability and alignment with the overall design language and UX goals.

## 1. Theming & Layout Tokens

| Token Category | Purpose / Usage | Notes |
| :--- | :--- | :--- |
| **Color Palette** | Use semantic colors rather than hard-coded hex or system-default. | Core theme vs Reflective (Examen) theme must be separate. All backgrounds, cards, text, buttons should reference `DSColor.*` tokens. |
| **Typography** | Use `DSFont` / `ThemedText` for all textual UI. | Maintain hierarchy: headings, body, subtext, caption. Support dynamic type / user font scaling. |
| **Spacing / Grid** | Use `DSSpacing` tokens for margins, padding, spacing. | No hard-coded "magic numbers". Maintain consistent 8-pt rhythm across UI. |
| **Components** | Use shared components (`CardView`, `AppButton`, `ThemedText`, etc.). | Ensures consistency; easier maintenance; avoids style drift. |

### Theme Behavior
*   **Core Theme**: Neutral background, standard contrast, minimal background effects — used in main app UI.
*   **Reflective / Examen Theme**: Soft backgrounds (flat or gentle gradients), calm tone, subtle accent — used during Prayerful Posture and Examen steps.
*   **Implementation Note**: Developer must ensure switching between themes updates background, card surfaces, text color, button styling, etc.

## 2. Navigation / UI-Chrome Behavior

| Behavior | Specification |
| :--- | :--- |
| **Tab Bar** | **Visible** during "core app" screens (Home, Dashboard, Journal, Settings). <br> **Hidden** (slides down) when entering Examen (Prayerful Posture or Examen flow). <br> **Reappears** (slides up) only upon exit or completion. |
| **Nav Controls** | Provide minimal UI chrome during Examen — only necessary controls: "Exit / Cancel (X)", navigation ("Next", "Back"), "Finish". No tab bar, no unrelated chrome. |
| **Transitions** | Transitions between screens/states should be smooth, subtle, and use eased animations (e.g., `.easeInOut`). |

## 3. Animation & Transition Guidelines

*   **API**: Use native SwiftUI / iOS animation APIs (`withAnimation`, `.transition`, `.opacity`, `.move`) rather than heavy custom frame-by-frame animations.
*   **Duration**:
    *   Standard transitions (tab-bar hide/show, screen level): **0.25 – 0.35s**
    *   Prompt-to-prompt transitions: **0.20 – 0.25s** (fast but gentle)
    *   Avoid > 0.5s (sluggish) or < 0.1s (jarring).
*   **Easing**: Default to `.easeInOut`. Use spring for "feeling of softness/calm" when appropriate.
*   **Accessibility**: Respect "Reduce Motion". Disable or simplify animations if set.
*   **Density**: Do not combine more than 1–2 distinct animated effects at once (e.g., slide + fade is fine; slide + scale + background movement is too much).

## 4. UI Flow & Screen Definitions

| Screen / State | Purpose | UI / Layout Description |
| :--- | :--- | :--- |
| **Experience Type Selection** | Entry point | Nav bar + Tab bar visible. Grid of "cards" (Design System styling). |
| **Transition to Examen** | Mode switch | Animate tab-bar hide; fade out grid; transition to Prayerful Posture. |
| **Prayerful Posture** | Preparation | Full-screen; theme-aware background; centered heading + instruction; "Begin" button. Minimal chrome. |
| **Examen Prompt Step** | Reflection | Full-screen; background per theme; prompt text in card; nav controls (Next, Back, Exit); optional progress. |
| **Completion / Exit** | Wrap-up | Simple summary or confirmation; "Save / Return Home"; animate tab bar back in. |

## 5. State, Data & Navigation Handling

*   **State Management**: Use centralized state (e.g., `AppState`, `EnvironmentObject`) for Examen flow state (`currentStep`, `isInExamen`, `isTabBarVisible`).
*   **Cleanup**: On exit/completion, ensure state is reset or persisted.
*   **Edge Cases**: Handle backgrounding, rotation, memory warnings gracefully. Ensure re-entry behaves correctly.
*   **Persistence**: Save data (journal content, selections) to SwiftData/CoreData before exit or interruption.

## 6. Accessibility & Adaptivity Requirements

*   **Dynamic Type**: Text must scale with user preferences.
*   **Reduce Motion**: Simplify/disable animations based on system setting.
*   **Contrast**: Meet WCAG / HIG standards for text vs background (especially in Reflective theme).
*   **Touch Targets**: Minimum 44x44 pt.
*   **Alternative Exit**: Provide button + optional gesture; do not rely solely on swipe/dismiss gestures (for users with limited dexterity).

## 7. Performance & Device Compatibility

*   **Low-End Devices**: Avoid heavy animations (continuous loops, large blurs). Provide flat/static fallbacks.
*   **Efficiency**: Leverage SwiftUI rendering; avoid expensive per-frame operations.
*   **Testing**: Test on multiple performance profiles and battery-saving modes.

## 8. QA & Testing Checklist

*   [ ] **Entry**: Tap type -> Tab bar hides -> Correct first screen.
*   [ ] **Exit**: Completion/Exit -> Tab bar returns -> UI stable.
*   [ ] **Dynamic Type**: Increase font size -> No layout breaks/truncation.
*   [ ] **Reduce Motion**: Functional with animations disabled/minimized.
*   [ ] **Contrast**: Text readable in Light/Dark/Reflective themes.
*   [ ] **Orientation**: Portrait/Landscape functionality (if supported).
*   [ ] **Performance**: Smooth transitions, no lag.
*   [ ] **Persistence**: Background app mid-flow -> Resume -> State preserved.

## 9. Animation Configuration (Reference)

```yaml
transition:
  tabBarHide:
    type: slide
    edge: bottom
    animation:
      easing: easeInOut
      duration: 0.30s

  tabBarShow:
    type: slide
    edge: bottom
    animation:
      easing: easeInOut
      duration: 0.30s

  screenChange:
    type: opacity + slide
    animation:
      easing: easeInOut
      duration: 0.25s
```