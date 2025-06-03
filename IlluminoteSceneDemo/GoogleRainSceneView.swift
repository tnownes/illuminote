//
//  GoogleRainSceneView.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 5/28/25.
//

import SwiftUI

// MARK: - Raindrop View

struct Raindrop: View {
    // State to control the vertical position of the raindrop
    @State private var yOffset: CGFloat = -200 // Start above the screen
    // State to control the opacity, making it fade out as it falls
    @State private var opacity: Double = 1.0
    // Random delay for each raindrop to make the effect less uniform
    let animationDelay: Double

    var body: some View {
        // A simple line representing a raindrop
        Rectangle()
            .fill(Color.blue.opacity(opacity)) // Blue color, with fading opacity
            .frame(width: 2, height: 20) // Thin, vertical shape
            .offset(y: yOffset) // Animate vertical position
            .onAppear {
                // Trigger the animation when the raindrop appears
                DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        // Move the raindrop down past the screen and fade it out
                        yOffset = UIScreen.main.bounds.height + 200 // End far below the screen
                        opacity = 0.0 // Fade out
                    }
                }
            }
            // Reset the raindrop when it disappears (optional, for continuous loop if not using repeatForever)
            .onChange(of: yOffset) { oldValue, newValue in
                if newValue > UIScreen.main.bounds.height + 100 {
                    // If it falls off screen, reset its position and opacity for a new cycle
                    yOffset = -200
                    opacity = 1.0
                }
            }
    }
}

// MARK: - RainView

struct RainView: View {
    // Number of raindrops to generate
    let numberOfDrops: Int = 100

    var body: some View {
        ZStack {
            // Background for the rain effect
            Color.black.edgesIgnoringSafeArea(.all)

            // Generate multiple raindrops
            ForEach(0..<numberOfDrops, id: \.self) { _ in
                Raindrop(animationDelay: Double.random(in: 0...2)) // Random delay for each drop
                    .position(x: CGFloat.random(in: 0...UIScreen.main.bounds.width), y: -100) // Random horizontal start position
            }
        }
    }
}

// MARK: - Preview Provider

#Preview {
    RainView()
}
