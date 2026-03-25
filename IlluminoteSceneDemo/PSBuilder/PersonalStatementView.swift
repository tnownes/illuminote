//
//  PersonalStatementView.swift
//  IlluminoteSceneDemo
//
//  Updated by ChatGPT on 8/19/25.
//

import SwiftUI
import SwiftData

/// A simple, beginner-friendly editor for the user's Personal Statement.
/// Edits are kept in local state while typing to avoid excessive writes; saving
/// happens when the user taps Save (and we also sync on view disappear).
struct PersonalStatementView: View {
    @Environment(\.modelContext) private var modelContext

    /// Pass in the active session whose statement we're editing.
    /// NOTE: Ensure `ExamenSession` has a `personalStatement: String` property.
    @Bindable var session: ExamenSession

    /// Local draft to prevent saving on every keystroke.
    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Personal Statement")
                    .font(.title2).bold()

                Text("Write your reflection below and tap Save when you're ready. You can format it more richly later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $draft)
                    .frame(minHeight: 220)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                    .accessibilityLabel("Personal statement text editor")

                Button("Save") {
                    session.personalStatement = draft
                    do { try modelContext.save() } catch { print("Save failed: \(error)") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft == session.personalStatement)

                Spacer()
            }
            .padding()
            .navigationTitle("Statement")
        }
        .onAppear {
            // Initialize the draft from the saved value
            draft = session.personalStatement
        }
        .onDisappear {
            // Gentle autosave if user navigates away with unsaved changes
            if draft != session.personalStatement {
                session.personalStatement = draft
                try? modelContext.save()
            }
        }
    }
}

#if DEBUG
struct PersonalStatementView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview placeholder to avoid requiring a concrete ExamenSession initializer.
        // Replace with a real sample session if desired.
        Text("PersonalStatementView Preview")
            .padding()
    }
}
#endif
