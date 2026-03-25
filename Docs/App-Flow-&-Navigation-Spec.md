# App Flow & Navigation Spec

## Overview
The app uses a `NavigationStack` rooted in the `LandingView` (Dashboard). Flows are managed via a `NavigationPath` and the `ExamenRoute` enum.

## Navigation Hierarchy

### 1. Onboarding Flow (`OnboardingFlowView`)
- **Trigger**: Shown on first launch if no `UserProfile` exists.
- **Steps**:
    1.  Welcome Screen.
    2.  Select Pre-Professional Track.
    3.  Completion -> Creates `UserProfile`.
- **Exit**: Transitions to `LandingView`.

### 2. Dashboard (`LandingView`)
- **Primary View**: Displays user stats, "Start Examen" CTA, "New Note" CTA, and recent history.
- **Navigation Destinations**:
    - `ExamenRoute.selectType` -> `ExperienceTypeSelectionView`
    - `ExamenRoute.details` -> `ExamenDetailsView` (for Quick Note)

### 3. Examen Flow
- **Step 1: Select Type** (`ExperienceTypeSelectionView`)
    - User selects context (Clinical, Shadowing, etc.).
- **Step 2: Posture/Preparation** (`PrayerPostureView`)
    - User prepares for reflection.
    - **Action**: On confirm, prompts are fetched and history is saved.
- **Step 3: Guided Reflection** (`ExamenFlowView`)
    - Displays selected prompts one by one.
    - User types answers.
- **Step 4: Details & Metadata** (`ExamenDetailsView`)
    - User adds Physician, Facility, Specialty, Tags, Personal Statement.
    - **Action**: On save, `ExamenSession` is persisted to SwiftData.
- **Step 5: Completion** (`ExamenCompletionView`)
    - Success message.
    - Returns to Dashboard.

### 4. Journal Flow (`JournalView`)
- **Access**: Tab Bar (if applicable) or via Dashboard history.
- **List**: Shows past sessions.
- **Search**: Filter by text, date, metadata.
- **Detail**: View session content (Q&A + Notes).

### 5. Settings Flow (`SettingsView`)
- **Access**: Tab Bar or Profile Icon.
- **Features**:
    - Edit Profile (Track).
    - App Theme.
    - Notifications (Future).
    - Reset Data (Debug).

## Flow Chart (Textual)

```
[Launch]
   |
   +--> [Onboarding] (if new user) --> [Dashboard]
   |
   +--> [Dashboard]
           |
           +--> [Start Examen] --> [Select Type] --> [Posture] --> [Examen Flow] --> [Details] --> [Completion] --> [Dashboard]
           |
           +--> [New Note] --> [Details] --> [Completion] --> [Dashboard]
           |
           +--> [Journal] --> [Session Detail]
           |
           +--> [Settings] --> [Profile]
```
