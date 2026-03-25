import SwiftUI

struct ExperienceSuggestionReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let candidates: [ExperienceSuggestionCandidate]
    let onAccept: (ExperienceSuggestionCandidate) -> Void

    @State private var acceptedCandidateIDs: Set<String> = []

    private var visibleCandidates: [ExperienceSuggestionCandidate] {
        candidates.filter { !acceptedCandidateIDs.contains($0.id) }
    }

    var body: some View {
        List {
            Section {
                Text("Review suggested groupings based on existing notes. Nothing converts automatically; each suggestion becomes a new application experience only if you accept it.")
                    .font(DSFont.body)
                    .foregroundStyle(.secondary)
            }

            if visibleCandidates.isEmpty {
                Text("No remaining suggestions in this review pass.")
                    .font(DSFont.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleCandidates) { candidate in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(candidate.title)
                            .font(.headline)
                        Text(candidate.category.displayName)
                            .font(DSFont.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Label("\(candidate.linkedSessionIDs.count) notes", systemImage: "note.text")
                            Label("\(candidate.totalSessionHours.formattedOneDecimal)h", systemImage: "clock")
                        }
                        .font(DSFont.caption)
                        .foregroundStyle(.secondary)

                        if let organization = candidate.organizationName, !organization.isEmpty {
                            Text(organization)
                                .font(DSFont.body)
                        }

                        Button(acceptedCandidateIDs.contains(candidate.id) ? "Added" : "Create Experience") {
                            guard !acceptedCandidateIDs.contains(candidate.id) else { return }
                            acceptedCandidateIDs.insert(candidate.id)
                            onAccept(candidate)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DSColor.goldLight)
                        .disabled(acceptedCandidateIDs.contains(candidate.id))
                        .accessibilityLabel(acceptedCandidateIDs.contains(candidate.id) ? "Experience added" : "Create experience from suggestion")
                        .accessibilityHint("Creates a new application experience using this suggested grouping.")
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle("Suggested Groupings")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private extension Double {
    var formattedOneDecimal: String {
        String(format: "%.1f", self)
    }
}
