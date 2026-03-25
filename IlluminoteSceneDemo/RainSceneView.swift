import SwiftUI

struct RainSceneView: View {
    // Use the provided image as a background
    private let backgroundImage = Image("Rain-Reference-Design2")
    
    var body: some View {
        ZStack {
            // Background Image
            backgroundImage
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            // Procedural Rain Canvas
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    
                    // Draw rain drops
                    for i in 0..<100 {
                        let x = (Double(i * 13 + Int(time * 50)) * 7.0).truncatingRemainder(dividingBy: size.width)
                        let y = (Double(i * 7 + Int(time * 400)) * 5.0).truncatingRemainder(dividingBy: size.height)
                        
                        let rect = CGRect(x: x, y: y, width: 2, height: 15)
                        context.opacity = Double.random(in: 0.3...0.7)
                        context.fill(Path(rect), with: .color(.white.opacity(0.5)))
                    }
                }
            }
            .ignoresSafeArea()
            
            // Glass Overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.3)
                .ignoresSafeArea()
        }
    }
}

#Preview {
    RainSceneView()
}
