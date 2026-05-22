//
//  Fonts.swift
//  IlluminoteSceneDemo
//
//  Created by Tobias on 12/5/25.
//
// DesignSystem/Fonts.swift
import SwiftUI

enum DSFont {
    // MARK: - Semantic Typography Roles
    static let display = Font.system(size: 34, weight: .semibold, design: .serif)
    static let screenTitle = Font.system(size: 28, weight: .semibold, design: .default)
    static let sectionTitle = Font.system(size: 21, weight: .semibold, design: .default)
    static let body = Font.body
    static let supporting = Font.subheadline
    static let meta = Font.caption
    static let eyebrow = Font.system(size: 12, weight: .semibold, design: .rounded)

    // MARK: - Backward-Compatible Aliases
    static let heading1 = screenTitle
    static let heading2 = sectionTitle
    static let subtext = supporting
    static let caption = meta

    // MARK: - Specialized Styles
    static let promptDisplay = Font.system(size: 34, weight: .regular, design: .serif)
    static let sectionHeader = sectionTitle
}
