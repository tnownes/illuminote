//
//  ExamenPrepViewModel.swift
//  IlluminoteSceneDemo
//
//  Modern Observation-based ViewModel (iOS 17+)
//

import SwiftUI
import Observation

/// ViewModel for the Examen preparation screen.
/// Uses the Observation framework's `@Observable` (iOS 17+) instead of Combine's `ObservableObject`.
@MainActor
@Observable
final class ExamenPrepViewModel {
    /// Gradient color stops (e.g. theme highlight color and its opacities)
    var gradientColors: [Color]
    /// Gradient start and end points for direction
    var gradientStart: UnitPoint = .topLeading
    var gradientEnd:   UnitPoint = .bottomTrailing
    /// Controls whether the gradient is shown (for fade-in transition)
    var showGradient: Bool = false

    /// Initialize with a base color (e.g. provided by the selected theme)
    init(baseColor: Color) {
        self.gradientColors = Self.colors(for: baseColor)
    }

    /// Call this from the view's onAppear to trigger the fade-in
    func onAppearAnimate() {
        withAnimation(.easeInOut(duration: 2.0)) {
            self.showGradient = true
        }
    }

    /// Update the gradient if the theme's base color changes at runtime.
    func updateBaseColor(_ baseColor: Color) {
        self.gradientColors = Self.colors(for: baseColor)
    }

    private static func colors(for base: Color) -> [Color] {
        [
            base,
            base.opacity(0.7),
            base.opacity(0.5)
        ]
    }
}
