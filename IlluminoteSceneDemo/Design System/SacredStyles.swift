import SwiftUI

// MARK: - Luminous Effect
struct Luminous: ViewModifier {
    @State private var glow: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
                .shadow(color: DSColor.brandAccent.opacity(0.22), radius: 6)
        } else {
            content
                .shadow(color: DSColor.brandAccent.opacity(0.22 * glow), radius: 4 * glow)
                .shadow(color: DSColor.brandAccent.opacity(0.12 * glow), radius: 12 * glow)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        glow = 1
                    }
                }
        }
    }
}

extension View {
    func luminous() -> some View {
        modifier(Luminous())
    }
    
    /// Glass card with optional luminous glow. Luminous is off by default to reduce visual noise and GPU load.
    func glassCardStyle(luminous: Bool = false) -> some View {
        self
            .background(DSColor.interactiveSurface.opacity(0.92))
            .background(.ultraThinMaterial.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(DSColor.dividerSoft, lineWidth: 1)
            )
            .modifier(ConditionalLuminous(isEnabled: luminous))
    }

    func appCircleControl(active: Bool = false, emphasized: Bool = false) -> some View {
        self
            .foregroundStyle(active ? DSColor.textOnBrandAccent : DSColor.textPrimary)
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(active ? DSColor.brandAccent : DSColor.interactiveSurface.opacity(0.95))
            )
            .overlay(
                Circle()
                    .stroke(active || emphasized ? DSColor.brandAccent.opacity(0.35) : DSColor.dividerSoft, lineWidth: 1)
            )
            .shadow(
                color: active ? DSColor.brandAccent.opacity(0.22) : Color.black.opacity(0.16),
                radius: active ? 10 : 8,
                x: 0,
                y: 4
            )
    }
}

private struct ConditionalLuminous: ViewModifier {
    let isEnabled: Bool
    func body(content: Content) -> some View {
        if isEnabled {
            content.luminous()
        } else {
            content
        }
    }
}

// MARK: - Sacred Button Style
struct SacredButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .font(DSFont.body.weight(.semibold))
        .foregroundStyle(DSColor.textOnBrandAccent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.md)
        .padding(.horizontal, DSSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DSColor.brandAccent.opacity(configuration.isPressed ? 0.90 : 0.98),
                            DSColor.brandAccent.opacity(configuration.isPressed ? 0.82 : 0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DSColor.brandAccent.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: DSColor.brandAccent.opacity(configuration.isPressed ? 0.14 : 0.24), radius: configuration.isPressed ? 8 : 14, x: 0, y: configuration.isPressed ? 3 : 8)
        .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
        .animation(AnimationConfig.confirmation, value: configuration.isPressed)
    }
}
