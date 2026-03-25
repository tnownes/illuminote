import SwiftUI

// MARK: - Filters Row Helper
struct FiltersRow: View {
    @Binding var selectedExperience: ExperienceType?
    @Binding var selectedTag: String?
    @Binding var datePreset: JournalView.DatePreset
    @Binding var showDateRangeSheet: Bool
    @Binding var onlyFavorites: Bool
    let allTags: [String]
    let datePresetLabel: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSSpacing.sm) {
                // Experience Filter
                Menu {
                    Button("All Experiences") { selectedExperience = nil }
                    Divider()
                    ForEach(ExperienceType.allCases, id: \.self) { kind in
                        Button(kind.displayName) { selectedExperience = kind }
                    }
                } label: {
                    FilterChip(
                        title: selectedExperience?.displayName ?? "Experience",
                        icon: "line.3.horizontal.decrease.circle",
                        isActive: selectedExperience != nil
                    )
                }

                // Tag Filter
                Menu {
                    Button("All Tags") { selectedTag = nil }
                    Divider()
                    ForEach(allTags, id: \.self) { tag in
                        Button(tag) { selectedTag = tag }
                    }
                } label: {
                    FilterChip(
                        title: selectedTag ?? "Tags",
                        icon: "tag",
                        isActive: selectedTag != nil
                    )
                }

                // Date Filter
                Menu {
                    Picker("Date Range", selection: $datePreset) {
                        Text("All Time").tag(JournalView.DatePreset.all)
                        Text("Last 7 Days").tag(JournalView.DatePreset.last7)
                        Text("Last 30 Days").tag(JournalView.DatePreset.last30)
                        Text("Last Year").tag(JournalView.DatePreset.last365)
                        Text("Custom…").tag(JournalView.DatePreset.custom)
                    }
                    if datePreset == .custom {
                        Button("Choose Dates…") { showDateRangeSheet = true }
                    }
                } label: {
                    FilterChip(
                        title: datePreset == .all ? "Date" : datePresetLabel.replacingOccurrences(of: "Date: ", with: ""),
                        icon: "calendar",
                        isActive: datePreset != .all
                    )
                }

                // Favorites Filter
                Button { onlyFavorites.toggle() } label: {
                    FilterChip(
                        title: "Favorites",
                        icon: onlyFavorites ? "star.fill" : "star",
                        isActive: onlyFavorites
                    )
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.xs)
        }
    }
}

// MARK: - Filter Chip Component
struct FilterChip: View {
    let title: String
    let icon: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(isActive ? DSColor.goldLight : DSColor.textPrimary)
            Text(title)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(isActive ? DSColor.goldLight : DSColor.divider, lineWidth: isActive ? 2 : 1)
        )
        .shadow(color: isActive ? DSColor.goldLight.opacity(0.35) : .clear, radius: isActive ? 10 : 0, x: 0, y: 2)
    }
}

// MARK: - Filter Pill (Active State)
struct FilterPill: View {
    let text: String
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.small)
                    .foregroundStyle(DSColor.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear \(text)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(DSColor.goldLight, lineWidth: 1.5)
        )
        .shadow(color: DSColor.goldLight.opacity(0.28), radius: 8, x: 0, y: 2)
    }
}
