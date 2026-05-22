//
//  DarkListModifier.swift
//  IlluminoteSceneDemo
//

import SwiftUI

// MARK: - Dark List Modifier

/// Reusable modifier that applies the dark immersive aesthetic to any List or Form.
/// Hides the default scroll background, applies the Sacred Void background,
/// sets dark toolbar chrome, and forces dark color scheme.
struct DarkListModifier: ViewModifier {
    let enabled: Bool
    let baseBackground: Color?

    func body(content: Content) -> some View {
        if enabled {
            let styled = content
                .scrollContentBackground(.hidden)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .preferredColorScheme(.dark)
            if let baseBackground {
                styled.background(baseBackground)
            } else {
                styled
            }
        } else {
            content
        }
    }
}

extension View {
    /// Applies the app's dark immersive list styling in one call.
    func darkListStyle(enabled: Bool, baseBackground: Color? = DSColor.appBackground) -> some View {
        modifier(DarkListModifier(enabled: enabled, baseBackground: baseBackground))
    }

    func darkListStyle() -> some View {
        modifier(DarkListModifier(enabled: true, baseBackground: DSColor.appBackground))
    }
}

// MARK: - Dark Section Header

/// A themed section header that matches the dark aesthetic.
/// Use in place of `Section("Title")` for consistent styling.
struct DarkSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textTertiary)
            .textCase(.uppercase)
    }
}

// MARK: - Dark Empty State

/// A themed empty-state view with optional action button.
/// Replaces `ContentUnavailableView` with dark-themed styling and gold accent CTA.
struct DarkEmptyState: View {
    let title: String
    let systemImage: String
    let description: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var fillBackground: Bool = true

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(DSColor.quietTextMuted)

            VStack(spacing: DSSpacing.sm) {
                Text(title)
                    .font(DSFont.heading2)
                    .foregroundStyle(DSColor.textPrimary)

                Text(description)
                    .font(DSFont.subtext)
                    .foregroundStyle(DSColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.xl)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(DSFont.body.weight(.semibold))
                        .foregroundStyle(DSColor.textOnBrandAccent)
                        .padding(.horizontal, DSSpacing.xl)
                        .padding(.vertical, DSSpacing.md)
                        .background(DSColor.brandAccent)
                        .clipShape(Capsule())
                }
                .padding(.top, DSSpacing.sm)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if fillBackground {
                DSColor.appBackground
            }
        }
    }
}
