//
//  ExamenTheme.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 5/8/25.
//

import SwiftUI

enum ExamenTheme: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case gradient
    case canyon
    case forest
    case rain
    case stainedGlass

    var displayName: String {
        switch self {
        case .gradient:      return "Gradient"
        case .canyon:        return "Canyon"
        case .forest:        return "Forest"
        case .rain:          return "Rain"
        case .stainedGlass:  return "Stained Glass"
        }
    }

    @ViewBuilder
    var sceneView: some View {
        switch self {
        case .gradient:
            GradientSceneView(onBegin: {})
        case .canyon:
            StylizedCanyonSceneView()
        case .forest:
            ForestSceneView()
        case .rain:
            RainSceneView()
        case .stainedGlass:
            StainedGlassSceneView()
        }
    }
}

class AppSettings: ObservableObject {
    @AppStorage("selectedTheme") var selectedThemeRaw: String = ExamenTheme.gradient.rawValue
    var selectedTheme: ExamenTheme {
        get { ExamenTheme(rawValue: selectedThemeRaw) ?? .gradient }
        set { selectedThemeRaw = newValue.rawValue }
    }
}
