# Illuminote — Examen & Reflection App

A guided Examen / journaling / reflection app aimed at pre-professional and professional students, combining spiritual growth, ethical reflection, and vocational discernment.  

## 🚀 What This Project Does

- Provides a structured, guided Examen experience — drawing on the tradition of Ignatian spirituality — to help users reflect on their day, experiences (clinical, volunteer, shadowing, daily life), and calling.  
- Offers customizable flows based on user track (pre-med, pre-law, etc.), experience type, and user preference (quick vs deep, spiritual vs secular).  
- Supports journaling and storage of reflection sessions, with SwiftData for persistence, optional iCloud syncing, and future extensibility.  
- Includes a prompt-engine backed by a JSON-driven prompt-pool with thematic / contextual metadata, allowing dynamic prompt selection, rotation, and filtering.  
- Allows user settings, profile management (pre-professional track, background/theme settings), and supports a clean, intuitive SwiftUI interface (iOS 17+).  

## 📦 Tech Stack & Architecture

| Layer / Component | Technology / Approach |
|------------------|----------------------|
| UI | SwiftUI (iOS 17+) |
| Data Persistence | SwiftData |
| Dependency Injection / Architecture | MVVM — separation of Models, ViewModels, Views |
| Prompt Storage & Template Engine | JSON-driven prompt pool (e.g. `prompts.json`) → mapped to SwiftData `PromptTemplate` model |
| Navigation / Flows | `NavigationStack`, clean separation of Examen flow, Settings, Journal, Onboarding |
| Configuration & Settings | `UserProfile`, `AppSettings`, environment or `@Observable` state |

## 📁 Project Structure (Suggested)
```
Sources/
Models/
    UserProfile.swift
    PromptTemplate.swift
    ExamenSession.swift
    PromptResponse.swift
Views/
    ContentView.swift
    OnboardingView.swift
    SettingsView.swift
    JournalView.swift
    ExamenFlowView.swift
    PrayerPostureView.swift
    // … etc …
Services/
    PromptImporter.swift
    DataStoreHelper.swift
    // … other service / data logic …
ViewModels/
    // MVVM ViewModels as needed
Resources/
    prompts.json    ← prompt-pool JSON file
    // other asset files (images, localization, etc.)
Docs/
    README.md
    Prompt-Engine-Spec.md
    // other documentation files …
```

## 📚 Important Documentation

- **Prompt-Engine-Spec** — defines prompt schema, tags, selection logic, modes (quick / deep / vocation / spiritual / service), best practices for prompt maintenance.  
- **Data Model Spec** — documentation of SwiftData models, relationships, versioning / migration guidance.  
- **Architecture & Flow Overview** — outlines navigation and screen-flow (Onboarding → Dashboard / Home → Examen flow → Journal / History → Settings), dependency structure, state management conventions.  
- **Coding Style & Conventions** — naming conventions, SwiftLint / code-style guidelines, test structure, error handling, concurrency rules.  
- **Setup / Build / Contribution Guide** — how to build the project, manage dependencies, run on simulator and real devices, how to contribute new features or prompts, testing instructions.  

## 🧑‍💻 Getting Started (Development)

1. Clone the repository.  
2. Ensure Xcode 15+ is installed (or minimum required for iOS 17+).  
3. Open `IlluminoteSceneDemo.xcodeproj` (or workspace).  
4. Ensure `Resources/prompts.json` is included in the target build resources.  
5. Run the app — initial launch should trigger onboarding; confirm `PromptImporter.importIfNeeded(...)` runs (or seed logic triggered).  
6. To run tests / previews, ensure mock data (if applicable) or SwiftData test container is configured.  

## ✅ Contribution / Maintenance Guidelines

- When adding new prompts — use valid UUIDs, include appropriate tags/context/theme, and follow prompt schema exactly.  
- When updating models — consider SwiftData migration needs; version changes carefully and include migration logic if schema changes.  
- Avoid hard-coding prompt text in code; add new prompts via JSON + metadata system.  
- Use MVVM architecture and dependency injection; avoid tight coupling between Views and data logic.  
- Document any new features in the Docs folder; keep README and spec docs up to date.  

## 🚧 Known Limitations & Future Work

- Prompt pool currently stored in-bundle JSON — future work: support remote updates / localization / user-added prompt editing.  
- Prompt-selection logic is deterministic/randomized but not yet “smart” — no adaptive learning or deep analytics present.  
- iCloud syncing and multi-device data merge logic still in planning — requires careful conflict resolution.  
- No formal prompt-editing UI yet — adding that would require more UI + permissions + sync logic.  

## 🙋‍♂️ Contact & Collaboration

For questions, feature requests, or contributions — contact the project lead / core team.  
Please reference documentation in `Docs/` before raising issues, and follow coding / commit / style guidelines.
