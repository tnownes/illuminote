# UI Migration Guide — Adopting DesignSystem

## Purpose  

This document outlines a recommended approach for migrating existing UI code (views, screens, components) in **Illuminote** to the new **DesignSystem**: a shared, theme-aware set of design tokens (colors, fonts, spacing) and reusable UI components (buttons, cards, text wrappers, etc.).  
The goal is to improve consistency, maintainability, accessibility, and support a distinct “core app” UI and “Examen-flow / reflective” UI theme.  

---

## Migration Strategy  

Use a **gradual, incremental** migration rather than a full rewrite. This reduces risk, allows testing in stages, and keeps the app functioning while UI evolves.  

Adopt a “from leaves → root” strategy:  

1. **Migrate simple UI atoms/components first** (colors, fonts, small standalone views)  
2. **Refactor individual screens** that use these elements  
3. **Refactor full flows / features** by composing updated screens and components  
4. **If needed — update root navigation / app-wide UI** (themes, global wrappers, environment objects)  

This aligns with widely recommended design-system migration best practices in SwiftUI and other UI frameworks.  [oai_citation:0‡Vlad Khambir](https://www.vladkhambir.com/posts/migrate-from-UIKit-to-SwiftUI/?utm_source=chatgpt.com)  

---

## Pre-Migration Preparations  

- [ ] Add the `DesignSystem` folder/module (or Swift Package) to the codebase.  
- [ ] Ensure core files (`Colors.swift`, `Fonts.swift`, `Spacing.swift`, basic components) compile correctly and are available globally.  
- [ ] Optionally, add a `ThemeManager` (or equivalent) to support switching between “Core” and “Reflective/Examen” themes.  
- [ ] Run UI / snapshot tests (if available) on existing views to record baseline — helps catch regressions after migration.  

---

## Step-By-Step Migration Process  

### Step 1: Replace Hard-coded Colors / Fonts / Spacing  

- Search for literal color values (hex codes, `Color(red:green:blue:)`, `.foregroundColor(.white)` / `.black`, etc.) and replace with semantic tokens — e.g. `DSColor.textPrimary`, `DSColor.backgroundSecondary`, etc.  
- Replace font modifiers (e.g. `.font(.system(size: ..., weight: ...))`) with typography tokens — e.g. `.font(DSFont.body)`.  
- Replace hard-coded padding / margin / spacing values with spacing constants — e.g. `.padding(DSSpacing.md)` instead of `.padding(16)`.  

**Why first:** this refactors the “atoms” — smallest building blocks — without touching logic or layout structure, minimizing risk.  

### Step 2: Swap in Reusable Components  

- Identify places in the UI where custom styling or layout is repeated: buttons, cards, text blocks, container backgrounds, etc.  
- Replace them with shared components from `DesignSystem.Components` — e.g. `AppButton`, `CardView`, `ThemedText`, etc.  
- For container or background-heavy views (e.g. list rows, cards, panels), wrap content inside `CardView` rather than manual styling.  

**Benefits:** ensures consistent styling across screens, reduces duplication, and centralizes UI logic.  

### Step 3: Introduce Theme-Aware Layouts (Core vs Reflective / Examen)  

- For screens/features that belong to the Examen flow (prayer posture, prompt screens, reflection, etc.), wrap or embed content in a themed view — e.g. a wrapper that selects background / accent / text colors based on theme (core or reflexive).  
- Use design tokens for all colors, fonts, spacing — so switching theme only requires changing the theme config (e.g. in `ThemeManager`).  

This allows the Examen experience to have a distinct “mood layer” while keeping code DRY and maintainable.  

### Step 4: Refactor Full Screens and Flows  

- Once atoms and small components are refactored, update full screens to use the design system building blocks.  
- This includes views like Settings, Journal List, Onboarding, Home, and eventually Examen screens.  
- Ensure navigation, data flow, and existing logic remain intact.  

### Step 5: Clean Up & Consolidate  

- Remove deprecated ad-hoc styling (hard-coded colors/fonts/spacings)  
- Consolidate duplicated styles into shared components or styling (avoid “style drift”)  
- Add documentation comments / guidelines for when and how to use `DesignSystem` components in new views  

---

## Testing & Validation Guidelines  

After each major migration step, run through the following tests:  

- **Visual consistency** — screens should look the same (or better) than before, no unintended layout shifts or mis-styling  
- **Accessibility / Dynamic Type** — text scales appropriately, layout adapts without clipping or overlap; verify on small/large type sizes  
- **Dark Mode / Theme Switching (if applicable)** — if device or user toggles dark mode or theme switches between core/reflective — UI remains readable, contrast good, no visual glitches  
- **Behavior & Interaction** — buttons, lists, forms, navigation, data flows — all function as before  
- **Performance (if applicable)** — ensure new styling/components don’t degrade performance; especially if any background effects or gradients are used  

---

## Developer Guidelines & Best Practices  

- Use **semantic tokens** (`DSColor`, `DSFont`, `DSSpacing`) rather than hard-coded literals. This ensures design decisions are centralized.  
- Build UI **compositionally**, using small reusable components rather than large monolithic views — aligns with atomic / component-based design system methodology.  [oai_citation:1‡think-it.io](https://think-it.io/insights/Atomic-Design-System-in-SwiftUI?utm_source=chatgpt.com)  
- For new UI work — **prefer using `DesignSystem` components from the start**. Avoid introducing new ad-hoc styles unless absolutely necessary.  
- Keep **theme-specific UI logic isolated** — ideally only Examen flow screens use reflective theme; core app screens stay on core theme. Avoid mixing heavily inside the same screen.  
- Maintain **documentation** — whenever a component is added or updated, update design-system docs (code comments or markdown) to reflect usage, limitations, accessibility notes, etc.  
- Leverage **SwiftUI previews** for components, both for core and reflective themes — this helps catch styling issues early and speeds development.  

---

## Example Migration — “SettingsView”  

Suppose you have an existing `SettingsView.swift` that uses hard-coded colors and paddings. Here is a mini checklist to migrate it:  

1. Replace color literals — e.g. `.background(Color(white: 0.95))` → `.background(DSColor.backgroundSecondary)`  
2. Replace font modifiers — e.g. `.font(.system(size: 16, weight: .medium))` → `.font(DSFont.body)` (or `subtext`, `caption`)  
3. Replace padding/margins — e.g. `.padding(16)` → `.padding(DSSpacing.md)`  
4. Wrap repeated styled elements (cards, forms, rows) in `CardView`, `FormRow`, or other shared components instead of custom views  
5. Test for dark mode / dynamic type / layout across devices — ensure readability and spacing remain good  

Once complete, commit the refactor as a separate PR (e.g. `feature/migrate-settings-ui`) — easier to review, test, and rollback if needed.  

---

## When Not to Migrate (or Migrate Later)  

- Features or screens undergoing major logic or data changes — avoid coupling UI refactor with business-logic refactor in same commit.  
- Very complex custom UI views that require special behavior or rendering (for now) — refactor only once stable, or gradually.  
- If performance concerns — especially for devices with lower resources — defer use of heavy background effects, large images, shaders, etc. until after core UI migration is stable.  

---

## Further Reading / References  

- “How to Build a Robust Design System With SwiftUI” — practical guide for component-based SwiftUI design systems.  [oai_citation:2‡Expert Beacon](https://expertbeacon.com/how-to-build-a-robust-design-system-with-swiftui/?utm_source=chatgpt.com)  
- Tutorials on building reusable SwiftUI components and refactoring UI code for maintainability.  [oai_citation:3‡peterfriese.github.io](https://peterfriese.github.io/Building-SwiftUI-Components-Tutorial/tutorials/buildingreusablecomponentstutorial/03-refactoring/?utm_source=chatgpt.com)  
- Best practices in atomic design and component-based UI architecture, applicable in SwiftUI context.  [oai_citation:4‡think-it.io](https://think-it.io/insights/Atomic-Design-System-in-SwiftUI?utm_source=chatgpt.com)  

---

## Summary  

Migrating to the new `DesignSystem` should be approached **incrementally and intentionally**: begin with foundational tokens (colors, fonts, spacing), then swap in shared components, then refactor screens and flows.  

This approach — guided by component-based design principles and SwiftUI strengths — will help maintain stability, improve UI consistency, and gradually shift the codebase toward a maintainable, scalable design architecture.  

Use this guide as a reference checklist for migration work, and encourage all developers to follow these principles when writing or refactoring UI code.  