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
            SacredScreenBackground(settings: settings)

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    AppSectionHeader(
                        eyebrow: "Appearance",
                        title: "Choose the reflective atmosphere",
                        subtitle: "Sacred Void is the default house style. Alternate scenes remain available as personalization for reflective moments without changing the structure of the flow."
                    )

                    AppPanel(
                        title: "Sacred Void is the house style",
                        subtitle: "Use it as the default atmosphere for Examen and other guided reflective moments. It carries the most coherent expression of Illuminote's tone: contemplative, trustworthy, and luminous.",
                        role: .reading,
                        highlighted: settings.selectedTheme == .sacredVoid
                    ) {
                        HStack(spacing: DSSpacing.sm) {
                            AppInfoChip(text: "Recommended", icon: "checkmark.seal", emphasized: true)
                            AppInfoChip(text: "Reflective flow", icon: "sparkles")
                        }
                    }

                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Recommended")
                            .font(DSFont.eyebrow)
                            .foregroundStyle(DSColor.quietTextMuted)

                        ForEach(themes.filter { $0 == .sacredVoid }, id: \.self) { theme in
                            ThemeRow(
                                theme: theme,
                                isSelected: settings.selectedTheme == theme,
                                onTap: { selectTheme(theme) }
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("Alternate scenes")
                            .font(DSFont.eyebrow)
                            .foregroundStyle(DSColor.quietTextMuted)

                        ForEach(themes.filter { $0 != .sacredVoid }, id: \.self) { theme in
                            ThemeRow(
                                theme: theme,
                                isSelected: settings.selectedTheme == theme,
                                onTap: { selectTheme(theme) }
                            )
                        }
                    }
                }
                .padding(DSSpacing.lg)
            }

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(DSColor.brandAccent)
                .opacity(flash ? 1 : 0)
                .scaleEffect(flash ? 1.0 : 0.85)
                .animation(.easeInOut(duration: 0.18), value: flash)
        }
        .navigationTitle("Examen Theme")
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

    private var description: String {
        switch theme {
        case .sacredVoid:
            return "The primary Illuminote atmosphere: contemplative, luminous, and quiet."
        case .forest:
            return "Soft natural depth with a calmer organic feel."
        case .stainedGlass:
            return "More radiant and devotional without changing the structure of the flow."
        case .gradient2:
            return "A smoother modern gradient for a lighter reflective mood."
        case .gradient:
            return "A classic gradient scene kept for continuity."
        case .canyon:
            return "A dramatic landscape backdrop with more visual weight."
        case .rain:
            return "A darker, more cinematic reflective scene."
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ThemePalettePreview(theme: theme)

                HStack {
                    Text(theme.displayName)
                        .font(DSFont.sectionTitle)
                        .foregroundStyle(DSColor.textPrimary)
                    Spacer()
                    HStack(spacing: DSSpacing.sm) {
                        if theme == .sacredVoid {
                            AppInfoChip(text: "House style", icon: "sparkles", emphasized: true)
                        }
                        if isSelected {
                            AppInfoChip(text: "Selected", icon: "checkmark", emphasized: true)
                        }
                    }
                }

                Text(description)
                    .font(DSFont.supporting)
                    .foregroundStyle(DSColor.quietText)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSSpacing.lg)
            .appSurfaceStyle(role: isSelected ? .reading : .interactive, highlighted: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct ThemePalettePreview: View {
    let theme: ExamenTheme

    private var colors: [Color] {
        switch theme {
        case .sacredVoid:
            return [Color(hex: "#3D1624"), Color(hex: "#130D11"), DSColor.goldLight.opacity(0.85)]
        case .forest:
            return [Color(hex: "#1D2E22"), Color(hex: "#314D37"), Color(hex: "#9DB48A")]
        case .stainedGlass:
            return [Color(hex: "#43204C"), Color(hex: "#7B3C61"), Color(hex: "#D8A04D")]
        case .gradient2:
            return [Color(hex: "#553A31"), Color(hex: "#9A6A53"), Color(hex: "#E6C1A1")]
        case .gradient:
            return [Color(hex: "#3B2E46"), Color(hex: "#785F82"), Color(hex: "#C7B5CF")]
        case .canyon:
            return [Color(hex: "#4E2E1F"), Color(hex: "#A45F39"), Color(hex: "#D7A26B")]
        case .rain:
            return [Color(hex: "#18212D"), Color(hex: "#3E5668"), Color(hex: "#9AA9B6")]
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 72)
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(colors.first ?? DSColor.brandAccent)
                    Circle()
                        .fill(colors.dropFirst().first ?? DSColor.brandAccentMuted)
                    Circle()
                        .fill(colors.last ?? DSColor.brandAccentSoft)
                }
                .frame(height: 8)
                .padding(12)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DSColor.dividerSoft, lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        ThemePickerView()
    }
    .environment(AppSettings())
}
