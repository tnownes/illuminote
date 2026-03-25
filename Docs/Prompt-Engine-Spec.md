# Prompt System Spec — JSON-Driven Prompt Templates for Examen

## Overview

We store prompt templates for guided Examen in a JSON file (`prompts.json`) inside the app bundle. On first launch (or whenever import is triggered) we decode this JSON into Swift objects and persist them to SwiftData (`PromptTemplate` model).  

### Goals

- Decouple prompt content from code — easier maintenance, editing, content updates, and localization.  
- Support metadata on prompts (theme, depth, tags, spiritual vs general) — enabling more nuanced prompt selection, randomization, and avoid repetition.  
- Provide track & experience-type filtering, fallback for general prompts, and flexible prompt-selection logic.  
- Maintain data integrity: unique IDs, avoid duplicates, allow prompt metadata updates on bundle updates.  
- Provide a foundation for future dynamic prompt management (remote updates, user-added prompts, analytics, localization).  

---

## Data Model: PromptTemplate

```swift
@Model
final class PromptTemplate {
    var id: UUID
    var text: String
    var stepIndex: Int
    var applicableTracks: [PreProfessionalTrack]?    // nil = all tracks
    var applicableExperienceTypes: [ExperienceType]?  // nil = all types
    var theme: String?
    var depthLevel: Int
    var isSpiritual: Bool
    var tags: [String]?
    // optional future fields: locale, lastUsed, isDisabled, customUserCreated, etc.
}
```

### Semantics

- `id`: stable unique identifier — used for dedupe, versioning, updates.  
- `text`: prompt question / instruction.  
- `stepIndex`: ordering / grouping index (optional, may influence order in Examen flow).
    - 0 → opening / awareness / presence / setting the tone
    - 1 → review / deeper reflection / emotions / ethical / experiential
    - 2 → resolution / integration / discernment / memory / future orientation
- `applicableTracks` / `applicableExperienceTypes`: filters; if `nil`, prompt applies to all.  
- `theme`, `depthLevel`, `isSpiritual`, `tags`: metadata for grouping, filtering, UI logic, or analytics.  

---

## JSON Format: `prompts.json`

- Array of prompt objects.  
- `null` for `applicableTracks` or `applicableExperienceTypes` → no filtering (available broadly).  
- Human-readable, easy to edit or expand.  
- New prompts or updates can be shipped via app update by updating JSON.  

Example prompt object:

```json
{
  "id": "some-uuid",
  "text": "What are you grateful for today?",
  "stepIndex": 0,
  "theme": "gratitude",
  "depthLevel": 0,
  "isSpiritual": true,
  "applicableTracks": null,
  "applicableExperienceTypes": null,
  "tags": ["gratitude","general"]
}
```

---

## Import Logic — PromptImporter.importIfNeeded(context:)

1.  Load JSON from bundle.
2.  Decode into `PromptTemplateImport` structs (using Swift’s Codable).  
3.  For each imported prompt:
    - Fetch in SwiftData by `id`.
    - If not found → insert new prompt.
    - If found → optionally update metadata (text, tags, etc.).
    - On success → `context.save()` to persist.

### Why This Approach
- Prevents duplicates.
- Allows prompt metadata to evolve while preserving existing prompts and user session data.
- Does not rely on text matching (text may change) — uses id for identity stability.

---

## Prompt-Selection Logic

When user starts an Examen:

1.  **Load Context**: Get user’s profile (`preProfessionalTrack`) and selected `ExperienceType`.
2.  **Filter**: Query `PromptTemplate` where:
    - `applicableTracks` is nil or contains user’s track.
    - `applicableExperienceTypes` is nil or contains selected experience type.
3.  **Enhanced Filtering**:
    - **Context Tags**: Filter by tags matching the experience (e.g., "clinical", "shadowing").
    - **Spiritual**: Include/exclude based on user preference.
    - **Mode**: Filter by mode (Quick, Deep, Vocation) using tags or depth level.
4.  **History**: Exclude prompts recently used (stored in `UserProfile.recentPromptIDs`).
5.  **Sampling**:
    - Select 1 Opening (`stepIndex` 0).
    - Select N Middle (`stepIndex` 1).
    - Select 1 Closing (`stepIndex` 2/3).
6.  **Result**: Use the resulting list to drive the Examen flow.

If filtered pool is empty → fallback to general prompts.

---

## Implementation Recommendations & Caveats

- **Bundle JSON only for now** — treat it as “default prompt library.”
- **Make id required & unique**; consider adding `@Attribute(.unique)` to id.
- **Perform import on background thread** or at app launch — avoid UI blocking if JSON is large.
- **Robust error handling** — if JSON fails to load / decode, log error and fallback gracefully, do not crash app.
- **Migration strategy** — if prompt schema evolves (metadata fields change), ensure importer and model code handle optionality, default values, or migrations. SwiftData supports schema changes over time.  
- **Avoid duplication** — rely on id rather than text to dedupe or update prompts.
- **Localization / future expansion** — if you later support multiple languages, prompts JSON can be localized or versioned per locale.
