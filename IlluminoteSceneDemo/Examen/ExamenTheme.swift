//
//  ExamenTheme.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 5/8/25.
//

import SwiftUI
import Observation

enum ExamenTheme: String, CaseIterable, Identifiable, Hashable {
    var id: String { rawValue }

    case gradient
    case gradient2 // New iOS 18 Mesh Gradient
    case canyon
    case forest
    case rain
    case stainedGlass
    case sacredVoid // New Sacred Void Theme
    var displayName: String {
        switch self {
        case .gradient:      return "Gradient"
        case .gradient2:     return "Gradient 2"
        case .canyon:        return "Canyon"
        case .forest:        return "Forest"
        case .rain:          return "Rain"
        case .stainedGlass:  return "Stained Glass"
        case .sacredVoid:    return "Sacred Void"
        }
    }

    @ViewBuilder
    var sceneView: some View {
        switch self {
        case .gradient:
            GradientSceneView()
        case .gradient2:
            if #available(iOS 18.0, *) {
                AnimatedMeshGradientBackground()
            } else {
                GradientSceneView()
            }
        case .canyon:
            StylizedCanyonSceneView()
        case .forest:
            ForestSceneView()
        case .rain:
            RainSceneView()
        case .stainedGlass:
            StainedGlassSceneView()
        case .sacredVoid:
            if #available(iOS 18.0, *) {
                SacredVoidBackground()
            } else {
                GradientSceneView() // Fallback
            }
        }
    }

    /// Type-erased scene view for callers that need a stable return type
    var anySceneView: AnyView {
        AnyView(sceneView)
    }
    
    /// Returns a theme-appropriate button color for the given step index.
    static func buttonColor(for step: Int) -> Color {
        // For now, return accent color. Could vary by step based on logic.
        return DSColor.accentPrimary
    }

    var isRestrictedToInternalBuilds: Bool {
        switch self {
        case .gradient, .canyon, .rain:
            return true
        case .gradient2, .forest, .stainedGlass, .sacredVoid:
            return false
        }
    }

    static func availableThemes(for policy: AppBuildPolicy = .current) -> [ExamenTheme] {
        switch policy.channel {
        case .development, .internalTestFlight:
            return allCases
        case .alphaExternal, .appStore:
            return allCases.filter { !$0.isRestrictedToInternalBuilds }
        }
    }
}




