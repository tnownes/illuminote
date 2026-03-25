# Data Model Spec

## Overview
Illuminote uses **SwiftData** for local persistence. The data model is designed to support user profiles, guided reflection sessions (Examen), and a library of prompt templates.

## Models

### 1. UserProfile
Represents the user's global settings and identity within the app.

- **id**: `UUID` (Unique)
- **preProfessionalTrack**: `PreProfessionalTrack?` (Enum) - The user's career path (e.g., Pre-Medicine, Pre-Law). Optional.
- **recentPromptIDs**: `[UUID]` - List of IDs of prompts recently shown to the user, used to avoid repetition.

### 2. ExamenSession
Represents a single completed or in-progress reflection session.

- **id**: `UUID` (Unique)
- **date**: `Date` - When the session occurred.
- **sessionType**: `ExamenType` (Enum) - e.g., Daily, Retreat, Vocation.
- **experienceType**: `ExperienceType?` (Enum) - The context of the reflection (e.g., Clinical, Shadowing).
- **responses**: `[StepResponse]` (Relationship, Cascade Delete) - The Q&A pairs for this session.
- **personalStatement**: `String` - Additional free-form notes or personal statement draft.
- **physician**: `String?` - Metadata: Name of physician/mentor.
- **facility**: `String?` - Metadata: Location/Facility.
- **specialty**: `String?` - Metadata: Specialty observed.
- **tags**: `[String]` - User-defined tags.
- **isFavorite**: `Bool` - Whether the user bookmarked this session.

### 3. StepResponse
Represents a single answer to a specific prompt within a session.

- **id**: `UUID` (Unique)
- **stepIndex**: `Int` - The order of the step in the flow.
- **answerText**: `String` - The user's response.
- **additionalNotes**: `String?` - Optional extra notes.
- **session**: `ExamenSession?` (Relationship) - The parent session.

### 4. PromptTemplate
Represents a reusable question/prompt for the Examen flow. Sourced from `prompts.json`.

- **id**: `UUID` (Unique)
- **text**: `String` - The question text.
- **stepIndex**: `Int` - 0 (Opening), 1 (Reflection), 2 (Closing).
- **applicableTracks**: `[PreProfessionalTrack]?` - Filter: Tracks this prompt is relevant for. `nil` = All.
- **applicableExperienceTypes**: `[ExperienceType]?` - Filter: Experiences this prompt is relevant for. `nil` = All.
- **theme**: `String?` - Thematic category (e.g., "gratitude", "ethics").
- **depthLevel**: `Int` - Complexity/depth (0 = Surface, 1 = Deep).
- **isSpiritual**: `Bool` - Whether the prompt is explicitly spiritual.
- **tags**: `[String]?` - Additional tags for filtering.

## Enums

### PreProfessionalTrack
- `preMedicine`, `preDentistry`, `preLaw`, `prePharmacy`, `preOccupationalTherapy`, `prePhysicalTherapy`, `prePhysicianAssistant`, `preVeterinaryMedicine`, `preOptometry`, `medicalOrDentalResidency`, `general`, `other`.

### ExperienceType
- `shadowing`, `volunteer`, `clinical`, `leadership`, `research`, `work`, `service`, `other`.

### ExamenType
- `daily`, `retreat`, `vocation`, `statementDraft`.

### ExamenMode
- `quick`, `deep`, `vocation`, `spiritual`.

## Relationships
- `ExamenSession` 1 <---> Many `StepResponse`
- `UserProfile` (Singleton-like, usually only one exists)

## Migration Strategy
- **Development**: `DataStoreHelper` currently handles schema mismatches by deleting the store (destructive).
- **Production**: Future migrations should use `SchemaMigrationPlan` to map old data to new schemas non-destructively.
