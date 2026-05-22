import SwiftUI

enum DSScreenPresentation {
    case immersive
    case supporting
}

/// Shared sacred-void background used across Home, Journal, and Statement surfaces.
struct SacredScreenBackground: View {
    let settings: AppSettings

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [DSColor.appBackground, DSColor.appBackgroundSecondary, DSColor.appBackgroundTertiary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                gradient: Gradient(colors: [
                    (settings.selectedTheme == .sacredVoid ? DSColor.deepMaroon : DSColor.brandAccentMuted).opacity(0.26),
                    .clear
                ]),
                center: .topTrailing,
                startRadius: 40,
                endRadius: 340
            )

            RadialGradient(
                gradient: Gradient(colors: [DSColor.overlaySoft, .clear]),
                center: .bottomLeading,
                startRadius: 80,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
    }
}

private struct AppSurfaceModifier: ViewModifier {
    let role: DSSurfaceRole
    let highlighted: Bool

    private var backgroundColor: Color {
        switch role {
        case .reading:
            return DSColor.readingSurface
        case .interactive:
            return DSColor.interactiveSurface
        case .quiet:
            return DSColor.quietSurface
        }
    }

    private var strokeColor: Color {
        highlighted ? DSColor.brandAccent.opacity(0.38) : DSColor.dividerSoft
    }

    private var shadowColor: Color {
        highlighted ? DSColor.brandAccent.opacity(0.18) : Color.black.opacity(0.18)
    }

    func body(content: Content) -> some View {
        content
            .background(backgroundColor.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(strokeColor, lineWidth: highlighted ? 1.2 : 1)
            )
            .shadow(
                color: shadowColor,
                radius: highlighted ? 16 : 12,
                x: 0,
                y: highlighted ? 8 : 6
            )
    }
}

extension View {
    func appSurfaceStyle(role: DSSurfaceRole = .interactive, highlighted: Bool = false) -> some View {
        modifier(AppSurfaceModifier(role: role, highlighted: highlighted))
    }

    /// Sacred card shell that mirrors Landing's glass panels and optional gold-highlight state.
    func sacredCardStyle(highlighted: Bool = false) -> some View {
        modifier(AppSurfaceModifier(role: .interactive, highlighted: highlighted))
    }

    /// Conditionally applies a transform while preserving fluent modifier chains.
    @ViewBuilder
    func `if`<Transformed: View>(_ condition: Bool, transform: (Self) -> Transformed) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
