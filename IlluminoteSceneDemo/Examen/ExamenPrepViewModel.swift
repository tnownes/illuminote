//
//  ExamenPrepViewModel.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 5/24/25.
//


import SwiftUI

/// ViewModel for the Examen preparation screen
class ExamenPrepViewModel: ObservableObject {
    /// Gradient color stops (e.g. theme highlight color and its opacities)
    @Published var gradientColors: [Color]
    /// Gradient start and end points for direction
    @Published var gradientStart: UnitPoint = .topLeading
    @Published var gradientEnd:   UnitPoint = .bottomTrailing
    /// Controls whether the gradient is shown (for fade-in transition)
    @Published var showGradient: Bool = false

    /// Initialize with a base color (e.g. provided by the selected theme)
    init(baseColor: Color) {
        // Set up the gradient stops
        self.gradientColors = [
            baseColor,
            baseColor.opacity(0.7),
            baseColor.opacity(0.5)
        ]
    }

    /// Call this from the view's onAppear to trigger the fade-in
    func onAppearAnimate() {
        withAnimation(.easeInOut(duration: 2.0)) {
            self.showGradient = true
        }
    }
}
