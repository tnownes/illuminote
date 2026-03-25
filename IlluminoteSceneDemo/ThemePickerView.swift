//
//  ThemePickerView.swift
//  IlluminoteSceneDemo
//
//  Updated by ChatGPT on 2025-08-31
//

import SwiftUI

struct ThemePickerView: View {
    // Observation-style environment injection (iOS 17+)
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var flash = false
    private var themes: [ExamenTheme] {
        ExamenTheme.availableThemes(for: AppSettings.buildPolicy)
    }

    var body: some View {
        ZStack {
            List {
                ForEach(themes, id: \.self) { theme in
                    ThemeRow(
                        theme: theme,
                        isSelected: settings.selectedTheme == theme,
                        onTap: { selectTheme(theme) }
                    )
                }
            }

            // Flashing overlay checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .opacity(flash ? 1 : 0)
                .scaleEffect(flash ? 1.0 : 0.85)
                .animation(.easeInOut(duration: 0.18), value: flash)
        }
        .navigationTitle("Choose a Theme")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func selectTheme(_ theme: ExamenTheme) {
        settings.selectedTheme = theme
        withAnimation(.easeInOut(duration: 0.18)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.easeInOut(duration: 0.18)) { flash = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { dismiss() }
        }
    }
}

private struct ThemeRow: View {
    let theme: ExamenTheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
            Text(theme.displayName)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

#Preview {
    NavigationStack {
        ThemePickerView()
    }
    .environment(AppSettings())
}
