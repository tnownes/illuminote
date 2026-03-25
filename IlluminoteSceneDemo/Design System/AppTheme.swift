//
//  AppTheme.swift
//  IlluminoteSceneDemo
//
//  Created by Tobias on 12/5/25.
//


// DesignSystem/Themes.swift
import SwiftUI

enum AppTheme {
    case core
    case reflective
}

@MainActor
class ThemeManager: ObservableObject {
    @Published var current: AppTheme = .core

    // Maybe later: implement persistence, user settings, time-of-day based switching, etc.
}