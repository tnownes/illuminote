import SwiftUI

struct GradientSceneView: View {
    // MARK: - Inputs
    var highlightColor: Color? = nil

    // MARK: - Gradient state
    @State private var gradientColors: [Color] = [
        Color(red: 0.30, green: 0.50, blue: 0.90), // Deep blue
        Color(red: 0.40, green: 0.60, blue: 1.00), // Sky blue
        Color(red: 0.50, green: 0.40, blue: 1.00), // Purple-blue
        Color(red: 0.20, green: 0.70, blue: 0.80)  // Teal
    ]
    @State private var startPoint: UnitPoint = .topLeading
    @State private var endPoint: UnitPoint = .bottomTrailing

    // Animate by toggling the start/end points instead of shuffling colors
    @State private var moveGradient = false

    var body: some View {
        ZStack {
            // Animated Gradient Background
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: moveGradient ? .bottomTrailing : .topLeading,
                endPoint:   moveGradient ? .topLeading : .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: moveGradient)
        }
        .onAppear {
            // If a highlight is provided, bias the palette toward it
            if let c = highlightColor {
                gradientColors = [c, c.opacity(0.8), c.opacity(0.6), gradientColors.last!]
            }

            // Start animations
            moveGradient.toggle()
        }
    }
}

#Preview {
    GradientSceneView(highlightColor: .blue)
}
