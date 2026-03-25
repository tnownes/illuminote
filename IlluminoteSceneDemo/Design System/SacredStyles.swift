import SwiftUI

// MARK: - Luminous Effect
struct Luminous: ViewModifier {
    @State private var glow: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
                .shadow(color: .white.opacity(0.3), radius: 8)
        } else {
            content
                .shadow(color: .white.opacity(0.4 * glow), radius: 4 * glow)
                .shadow(color: .white.opacity(0.2 * glow), radius: 12 * glow)
                .shadow(color: .white.opacity(0.1 * glow), radius: 30 * glow)
                .blendMode(.plusLighter)
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
            .background(Color.black.opacity(0.3))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .modifier(ConditionalLuminous(isEnabled: luminous))
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
    @State private var glow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
        }
        .font(.title3)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DSColor.goldLight, lineWidth: 2)
                        .luminous()
                )
        )
        .shadow(color: DSColor.goldLight.opacity(0.6), radius: 15, x: 0, y: 6)
        .scaleEffect(configuration.isPressed ? 0.98 : (reduceMotion ? 1.0 : (glow ? 1.02 : 1.0)))
        .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glow.toggle()
            }
        }
    }
}
