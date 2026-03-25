//
//  SacredVoidBackground.swift
//  IlluminoteSceneDemo
//
//  Created for Sacred Void Aesthetic
//

import SwiftUI

@available(iOS 18.0, *)
struct SacredVoidBackground: View {
    // Smaller numbers = slower animation
    var pointSpeed: Double = 0.25
    var colorSpeed: Double = 0.15
    
    var body: some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            
            MeshGradient(
                width: 3,
                height: 3,
                points: animatedPoints(phase: phase * pointSpeed),
                colors: animatedColors(phase: phase * colorSpeed),
                background: .black,
                smoothsColors: true,
                colorSpace: .perceptual
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
    
    private func animatedPoints(phase: TimeInterval) -> [SIMD2<Float>] {
        let centerX = Float((sin(phase) + 1) / 2)

        return [
            .init(0, 0), .init(0.5, 0), .init(1, 0),
            .init(0, 0.5), .init(centerX, 0.5), .init(1, 0.5),
            .init(0, 1), .init(0.5, 1), .init(1, 1)
        ]
    }
    
    private func animatedColors(phase: TimeInterval) -> [Color] {
        // Oscillate opacities to create a shimmering effect
        // Gold: 0.3 to 0.6
        let goldOpacity = 0.3 + (sin(phase) + 1) * 0.15
        
        // Silver: 0.2 to 0.4 (slightly out of phase)
        let silverOpacity = 0.2 + (cos(phase) + 1) * 0.1
        
        return [
            DSColor.nearBlack,
            DSColor.deepMaroon,
            DSColor.nearBlack,
            
            DSColor.deepMaroon,
            DSColor.nearBlack,
            DSColor.goldLight.opacity(goldOpacity),
            
            DSColor.nearBlack,
            DSColor.silverBlue.opacity(silverOpacity),
            DSColor.deepMaroon
        ]
    }
}
