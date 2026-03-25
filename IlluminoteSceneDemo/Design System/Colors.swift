//
//  Colors.swift
//  IlluminoteSceneDemo
//
//  Created by Tobias on 12/5/25.
//
// DesignSystem/Colors.swift
import SwiftUI

enum DSColor {
    // MARK: - Semantic Surface Tokens (dark-first, matching app aesthetic)
    static let backgroundPrimary = Color(hex: "#1A0108")     // Near-black (Sacred Void base)
    static let backgroundSecondary = Color(hex: "#2A1018")    // Slightly lighter dark
    static let surfaceElevated = Color(hex: "#3A1828")        // Cards and elevated surfaces

    // MARK: - Semantic Text Tokens
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)

    // MARK: - Accent Colors
    static let accentPrimary = Color(hex: "#4A90E2")
    static let accentPrimaryLight = Color(hex: "#DCEEFF")
    static let accentPrimaryDark = Color(hex: "#357ABD")

    // MARK: - Dividers & Borders
    static let divider = Color.white.opacity(0.1)

    // MARK: - Status Colors
    static let success = Color(hex: "#2ECC71")
    static let warning = Color(hex: "#E67E22")
    static let error = Color(hex: "#E74C3C")

    // MARK: - Reflective / Examen Palette
    static let reflectiveBackgroundLight = Color(hex: "#FAFAFB")
    static let reflectiveBackgroundDark = Color(hex: "#1E1E1E")
    static let reflectiveTextPrimaryLight = Color(hex: "#0F0F0F")
    static let reflectiveTextPrimaryDark = Color(hex: "#EAEAEA")
    static let reflectiveTextSecondary = Color(hex: "#A0A0A0")
    static let reflectiveAccentSoft = Color(hex: "#6D9FB8")
    static let reflectiveAccentSubtle = Color(hex: "#B0C9D9")
    static let reflectiveDivider = Color(hex: "#2A2A2A")

    // MARK: - Sacred Void Aesthetic
    static let nearBlack = Color(hex: "#1A0108")
    static let deepMaroon = Color(hex: "#4A041A")
    static let goldLight = Color(hex: "#EAAA00")
    static let silverBlue = Color(hex: "#A0A0B0")

    // MARK: - Light Context (for forms/settings that need light backgrounds)
    static let lightBackground = Color(hex: "#FFFFFF")
    static let lightText = Color(hex: "#1F1F1F")
    static let lightTextSecondary = Color(hex: "#666666")
    static let lightDivider = Color(hex: "#E5E5E5")
}

extension Color {
    // Optional: helper initializer for hex strings
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
