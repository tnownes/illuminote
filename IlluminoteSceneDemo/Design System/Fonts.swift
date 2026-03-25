//
//  Fonts.swift
//  IlluminoteSceneDemo
//
//  Created by Tobias on 12/5/25.
//
// DesignSystem/Fonts.swift
import SwiftUI

enum DSFont {
    // Uses TextStyle-relative sizing for Dynamic Type support
    static let heading1 = Font.system(.title, weight: .bold)
    static let heading2 = Font.system(.title3, weight: .semibold)
    static let body     = Font.body
    static let subtext  = Font.subheadline
    static let caption  = Font.caption

    // Specialized styles
    static let promptDisplay = Font.system(.largeTitle, weight: .light)
    static let sectionHeader = Font.system(.title2, weight: .semibold)
}
