# Contribution Guidelines

## Workflow
1.  **Branching**: Create a new branch for your feature or fix (e.g., `feature/custom-examen`, `fix/journal-crash`).
2.  **Commits**: Write clear, descriptive commit messages.
3.  **Pull Requests**: Open a PR against `main`. Describe your changes and link to relevant issues.

## Adding Prompts
To add new prompts to the app:
1.  Open `Resources/prompts.json`.
2.  Add a new JSON object to the array.
3.  **Requirements**:
    - `id`: Must be a new, unique UUID.
    - `text`: The prompt text.
    - `stepIndex`: 0, 1, or 2.
    - `tags`: Add relevant tags.
4.  Run the app to verify the importer picks up the new prompt.

## Modifying Models
If you modify `ExamenModel.swift`:
1.  Ensure you understand SwiftData migration implications.
2.  For development, deleting the app is acceptable.
3.  For production, create a `SchemaMigrationPlan`.

## Code Review
- All code must be reviewed before merging.
- Ensure code follows the [Coding Standards](Coding-Standards.md).
