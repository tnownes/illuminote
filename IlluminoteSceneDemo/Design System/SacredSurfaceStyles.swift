import SwiftUI

/// Shared sacred-void background used across Home, Journal, and Statement surfaces.
struct SacredScreenBackground: View {
    let settings: AppSettings

    var body: some View {
        Group {
            if settings.selectedTheme == .sacredVoid {
                RadialGradient(
                    gradient: Gradient(colors: [DSColor.nearBlack, DSColor.deepMaroon]),
                    center: .center,
                    startRadius: 50,
                    endRadius: 350
                )
                .ignoresSafeArea()
            } else if settings.selectedTheme == .gradient {
                AnimatedMeshGradientBackground()
            } else {
                Color.black.ignoresSafeArea()
            }
        }
    }
}

private struct SacredCardModifier: ViewModifier {
    let highlighted: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let strokeColor = highlighted ? DSColor.goldLight : Color.white.opacity(0.12)
        let lineWidth: CGFloat = highlighted ? 2 : 1

        content
            .glassCardStyle()
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(strokeColor, lineWidth: lineWidth)
            )
            .shadow(
                color: highlighted ? DSColor.goldLight.opacity(reduceMotion ? 0.28 : 0.45) : .clear,
                radius: highlighted ? (reduceMotion ? 8 : 14) : 0,
                x: 0,
                y: 4
            )
    }
}

extension View {
    /// Sacred card shell that mirrors Landing's glass panels and optional gold-highlight state.
    func sacredCardStyle(highlighted: Bool = false) -> some View {
        modifier(SacredCardModifier(highlighted: highlighted))
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
