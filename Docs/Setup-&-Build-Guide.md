# Setup & Build Guide

## Prerequisites
- **Mac**: macOS Sonoma or later.
- **Xcode**: Xcode 15.0 or later.
- **iOS SDK**: iOS 17.0+.

## Getting Started
1.  **Clone the Repository**:
    ```bash
    git clone <repository-url>
    cd IlluminoteSceneDemo
    ```
2.  **Open Project**:
    Double-click `IlluminoteSceneDemo.xcodeproj`.

## Building & Running
1.  Select the `IlluminoteSceneDemo` scheme.
2.  Select a Simulator (e.g., iPhone 15 Pro) or a connected device.
3.  Press `Cmd + R` to build and run.

## Data Seeding
- On first launch, the app will automatically run `PromptImporter` to populate the SwiftData database from `Resources/prompts.json`.
- Check the debug console for "PromptImporter — import complete".

## Troubleshooting
- **Build Errors**: Ensure you are on the correct Xcode version. Clean build folder (`Cmd + Shift + K`) if strange errors persist.
- **Crash on Launch**: If the data model has changed significantly, the app might crash due to schema mismatch.
    - **Fix**: Delete the app from the simulator/device and reinstall. The `DataStoreHelper` is also configured to reset the store in debug builds if initialization fails.

## Running Tests
- Press `Cmd + U` to run unit tests (if configured).
