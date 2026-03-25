import SwiftUI

/// A reusable, animated Examen progression button.
/// Uses multiple layered animated rings and a pulsing center,
/// with durations and easing drawn from a centralized AnimationConfig.
struct ExamenActionButton: View {
    let title: String
    let color: Color
    let animation: Animation
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatePulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer Breathing/Reflective Rings
                if !reduceMotion {
                    // Outer ring — breathing, gentle
                    Circle()
                        .stroke(color.opacity(0.18), lineWidth: 12)
                        .scaleEffect(animatePulse ? 1.20 : 0.92)
                        .opacity(animatePulse ? 0.88 : 0.50)
                        .animation(
                            AnimationConfig.breathing.repeatForever(autoreverses: true),
                            value: animatePulse
                        )

                    // Middle ring — slow pace
                    Circle()
                        .stroke(color.opacity(0.12), lineWidth: 8)
                        .scaleEffect(animatePulse ? 1.14 : 0.96)
                        .opacity(animatePulse ? 0.80 : 0.60)
                        .animation(
                            AnimationConfig.breathing.repeatForever(autoreverses: true)
                                .delay(0.4),
                            value: animatePulse
                        )

                    // Inner ring — breathing and calm
                    Circle()
                        .stroke(color.opacity(0.22), lineWidth: 6)
                        .scaleEffect(animatePulse ? 1.08 : 0.98)
                        .opacity(animatePulse ? 0.70 : 0.55)
                        .animation(
                            AnimationConfig.breathing.repeatForever(autoreverses: true)
                                .delay(0.8),
                            value: animatePulse
                        )
                }

                // Main circular button
                Circle()
                    .fill(color)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Text(title)
                            .font(DSFont.body) // design system font
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                    .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 4)
            }
            .frame(width: 170, height: 170)
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(animation.repeatForever(autoreverses: true)) {
                    animatePulse = true
                }
            }
        }
    }
}

#if DEBUG
struct ExamenActionButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            ExamenActionButton(
                title: "Continue",
                color: .blue,
                animation: AnimationConfig.slow
            ) { }
            
            ExamenActionButton(
                title: "Continue",
                color: .green,
                animation: AnimationConfig.medium
            ) { }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
