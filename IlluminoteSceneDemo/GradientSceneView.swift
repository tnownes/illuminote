import SwiftUI

struct GradientSceneView: View {
    @State private var gradientColors: [Color] = [
        Color(#colorLiteral(red: 0.3, green: 0.5, blue: 0.9, alpha: 1)), // Deep blue
        Color(#colorLiteral(red: 0.4, green: 0.6, blue: 1.0, alpha: 1)), // Sky blue
        Color(#colorLiteral(red: 0.5, green: 0.4, blue: 1.0, alpha: 1)), // Purple-blue
        Color(#colorLiteral(red: 0.2, green: 0.7, blue: 0.8, alpha: 1))  // Teal
    ]
    @State private var gradientStart: UnitPoint = .topLeading
    @State private var gradientEnd: UnitPoint = .bottomTrailing
    
    @State private var messageOpacity: Double = 0
    @State private var tapToBeginOpacity: Double = 0
    @State private var gradientAnimating: Bool = false
    
    var onBegin: () -> Void
    
    var highlightColor: Color? = nil
    
    // Animate gradient and text
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Animated Gradient Background
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: gradientStart,
                endPoint: gradientEnd
            )
            .edgesIgnoringSafeArea(.all)
            
                    }
                    .onAppear {
                        // Start gradient animation smoothly
                        gradientAnimating = true

                        // Animate text and tap circle
                        withAnimation(.easeInOut(duration: 2).delay(0.5)) {
                            messageOpacity = 1
                        }

                        withAnimation(.easeInOut(duration: 2).delay(1.5)) {
                            tapToBeginOpacity = 1
                        }

                        // Smoothly transition gradient colors
                        withAnimation(Animation.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                            gradientColors = gradientColors.shuffled() // Gradual color shifting
                        }
                    }

        }
    }

#Preview {
    GradientSceneView(onBegin: {})
}
