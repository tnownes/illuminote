import SwiftUI

@available(iOS 18.0, *)
struct AnimatedMeshGradientBackground: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppSettings.self) private var settings
    var motionPolicy: ReflectiveMotionPolicy? = nil

    // Smaller numbers = slower animation
    var pointSpeed: Double = 0.25
    var colorSpeed: Double = 0.15

    private var effectiveMotionPolicy: ReflectiveMotionPolicy {
        motionPolicy ?? ReflectiveMotionPolicy(
            scenePhase: scenePhase,
            reduceMotion: reduceMotion,
            backgroundAnimationEnabled: settings.backgroundAnimationEnabled
        )
    }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: effectiveMotionPolicy.isPaused)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            MeshGradient(
                width: 3,
                height: 3,
                points: animatedPoints(phase: phase * pointSpeed),
                colors: animatedColors(phase: phase * colorSpeed),
                background: .black.opacity(0.15),
                smoothsColors: true,
                colorSpace: .perceptual
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
    
    private func animatedColors(phase: TimeInterval) -> [Color] {
        // Base hues roughly matching a rainbow across 9 points
        let baseHues: [Double] = [
            0.0,   // red
            0.08,  // orange
            0.16,  // yellow
            0.33,  // green
            0.45,  // mint
            0.52,  // cyan
            0.60,  // blue
            0.69,  // indigo
            0.77   // purple
        ]
        return baseHues.enumerated().map { index, hue in
            let shift = cos(phase + Double(index) * 0.3) * 0.10
            let newHue = hue + shift
            let wrappedHue = newHue - floor(newHue)
            return Color(hue: wrappedHue, saturation: 0.95, brightness: 0.95, opacity: 1.0)
        }
    }

    // Animate a few inner grid points
    private func animatedPoints(phase: TimeInterval) -> [SIMD2<Float>] {
        let centerX = Float((sin(phase) + 1) / 2)

        return [
            .init(0, 0), .init(0.5, 0), .init(1, 0),
            .init(0, 0.5), .init(centerX, 0.5), .init(1, 0.5),
            .init(0, 1), .init(0.5, 1), .init(1, 1)
        ]
    }
}

#Preview("Animated Mesh Gradient Background") {
    Group {
        if #available(iOS 18.0, *) {
            AnimatedMeshGradientBackground()
        } else {
            Text("Requires iOS 18")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .foregroundStyle(.white)
        }
    }
}
