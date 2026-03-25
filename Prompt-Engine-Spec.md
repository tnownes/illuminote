# Prompt-Engine Spec  

> Specification for the prompt-pool JSON and selection engine used in the Examen / reflection flow.

## Overview

This document describes the data model and selection logic for the “Prompt Engine” — the part of the app that loads a pool of reflection prompts (from `prompts.json` or similar), filters them according to user context & mode, and selects a small set (e.g. 4–6) to present to the user during an Examen session.  

It covers:

- Prompt schema (fields, meaning)  
- Tags / metadata design (context, theme, spirituality, etc.)  
- Selection rules & “modes” (quick, deep, vocation, spiritual, etc.)  
- Example pseudocode for selection algorithm  
- Guidance for developers: integration, edge cases, maintenance  

---

## Prompt Schema: JSON Format

Each prompt is represented as a JSON object with the following fields:

| Field | Type | Description |
|-------|------|-------------|
| `id` | String (UUID) | Unique identifier for the prompt. Used for deduplication / tracking / history. |
| `text` | String | The actual prompt text to present to the user. |
| `stepIndex` | Integer (0, 1, 2) | Indicates the “phase” of the Examen this prompt is aligned with:<br> - `0`: opening / awareness / presence / invitation<br> - `1`: reflection / review / emotional-ethical-experiential review<br> - `2`: resolution / integration / discernment / memory / future orientation |
| `theme` | String | A categorical tag describing the conceptual theme (e.g. `"gratitude"`, `"vocation-reflection"`, `"disquiet"`, `"calling"`, etc.). Useful for filtering or analytics. |
| `depthLevel` | Integer (e.g. 0–2) | Indicates prompt “depth” — 0 = light / surface, 1 = moderate reflection, 2 = deep / contemplative / integrative. Helps in choosing prompts based on user mode (quick vs deep). |
| `isSpiritual` | Boolean | `true` if the prompt includes explicitly spiritual language or orientation (faith, prayer, meaning, spiritual dryness, etc.). `false` if the prompt is more neutral / secular / general reflection. This supports user preference for spiritual vs non-spiritual reflection. |
| `applicableTracks` | *nullable* Array&lt;String&gt; | (Optional) List of user pre-professional track identifiers for which this prompt is relevant (e.g. `"pre-medicine"`, `"pre-law"`, etc.). `null` means it applies to all tracks. |
| `applicableExperienceTypes` | *nullable* Array&lt;String&gt; | (Optional) List of experience-type identifiers (e.g. `"clinical"`, `"volunteer_service"`, `"daily_life"`, `"shadowing"`). `null` means the prompt applies to all experience types. |
| `tags` | Array&lt;String&gt; | Free-form tags combining **context tags** (experience type: e.g. `"clinical"`, `"shadowing"`, `"service"`, `"dailyLife"`, etc.) with **theme / emotional / conceptual tags** (e.g. `"emotion"`, `"gratitude"`, `"vocation"`, `"ethics"`, `"compassion"`, `"spiritual"`, etc.). Used for filtering and advanced selection logic. |

---

## Tags & Context Metadata

### Context Tags (experience type)

Use these to indicate where this prompt makes sense: e.g.:

- `clinical` — for hospital / clinical shadowing / rotations  
- `shadowing` — for observation / shadow-experiences  
- `service` — for volunteer / service work  
- `volunteer` — similar to service, perhaps with distinction if needed  
- `dailyLife` — for ordinary days / non-professional / personal life  
- `leadership` / `research` / custom tags — as needed for expanded categories  

### Theme / Emotional / Concept Tags

These help classify prompts by what kind of reflection they encourage:

Examples:  
`emotion`, `gratitude`, `presence`, `meaning`, `disquiet`, `conscience`, `vocation`, `ethics`, `compassion`, `growth`, `hope`, `challenge`, `calling`, `reflection`, `memory`, `resolution`, `spiritual`, `introspection`, `justice`, etc.

Prompts may include multiple tags (e.g. a prompt could have both `"clinical"` and `"vocation"` and `"ethics"` tags).

---

## Selection Logic & Modes

The prompt-engine should support different “modes,” depending on user preference and context. Modes influence how many prompts are selected, which kinds of prompts (depth/spirituality), and filtering criteria.

### Example Modes

- **Quick / Daily** — For a brief, low-friction Examen.  
- **Deep / Reflective** — For contemplative, longer reflections.  
- **Vocation / Profession** — Focused on growth, calling, ethics, professional insight.  
- **Spiritual / Faith-oriented** — Allows / encourages explicitly spiritual prompts, prayer/reflection tone.  
- **Service / Volunteer** — Focused on service-related experiences and reflections.  

A mode might combine multiple aspects (e.g. “Deep + Vocation” or “Quick + Daily”).

### Session Prompt Selection Rules

1. **Number of prompts per session** — configurable, e.g. 4–6 (based on mode).  
2. **Flow structure constraint** — ideally: one opening (stepIndex 0) → 1–3 reflection(s) (stepIndex 1) → one closing/resolution (stepIndex 2).  
3. **Context filtering** — include only prompts whose tags or applicable fields match the user’s current experience context (e.g. clinical, service, dailyLife), or general prompts (no context restriction).  
4. **Spiritual filter** — if user opts out of spirituality, exclude prompts where `isSpiritual == true`.  
5. **Mode-based theming / tag filtering** — e.g. for “Vocation” mode, preferentially include prompts tagged with `vocation`, `pre-professional`, `ethics`, `growth`, etc.; for “Service” mode include `service`, `compassion`, `justice`, etc.  
6. **Avoid repetition** — keep a history of recently used prompt `id`s for each user (e.g. last N sessions), and exclude them when picking new prompts.  
7. **Fallback logic** — if filters result in insufficient prompts, fall back to general prompts (less restrictive) to ensure session still yields enough prompts.  

---

## Example Pseudocode (Swift-style)

```swift
struct PromptSelectionConfig {
    enum Mode {
        case quick
        case deep
        case vocation
        case spiritual
        case service
        // combine with bitmask or flags if you want multiple aspects
    }

    let mode: Mode
    let experienceContextTags: [String]   // e.g. ["clinical","shadowing"]
    let userAllowsSpiritual: Bool
    let maxPrompts: Int                    // e.g. 4–6
}

func selectPrompts(
    from allPrompts: [Prompt],
    using config: PromptSelectionConfig,
    excluding recentIDs: Set<String>
) -> [Prompt] {
    // 1. Filter by context
    let contextFiltered = allPrompts.filter { prompt in
        // include if prompt.tags intersects config.experienceContextTags
        // or if prompt has no context-type tags (general)
        return prompt.tags.contains(where: config.experienceContextTags.contains) ||
               !prompt.tags.contains(where: isContextTag)
    }

    // 2. Spiritual filter
    let spiritualFiltered = contextFiltered.filter { prompt in
        config.userAllowsSpiritual || !prompt.isSpiritual
    }

    // 3. Mode-based tag filtering (optional, depending on mode)
    let modeFiltered: [Prompt]
    switch config.mode {
    case .vocation:
        modeFiltered = spiritualFiltered.filter { prompt in
            prompt.tags.contains("vocation") ||
            prompt.tags.contains("pre-professional") ||
            prompt.tags.contains("clinical") ||
            prompt.tags.contains("service")
        }
    case .service:
        modeFiltered = spiritualFiltered.filter { prompt in
            prompt.tags.contains("service") ||
            prompt.tags.contains("compassion") ||
            prompt.tags.contains("justice")
        }
    default:
        modeFiltered = spiritualFiltered
    }

    // 4. Remove recently used
    let fresh = modeFiltered.filter { !recentIDs.contains($0.id) }

    // 5. Group by stepIndex
    let openings = fresh.filter { $0.stepIndex == 0 }
    let middles = fresh.filter { $0.stepIndex == 1 }
    let closings = fresh.filter { $0.stepIndex == 2 }

    var session: [Prompt] = []

    // 6. Pick one opening if available
    if let o = openings.randomElement() {
        session.append(o)
    }

    // 7. Pick 1–(maxPrompts–2) middles
    let middleCount = max(1, config.maxPrompts - 2)
    session += middles.shuffled().prefix(middleCount)

    // 8. Pick one closing if available
    if let c = closings.randomElement() {
        session.append(c)
    }

    return session
}