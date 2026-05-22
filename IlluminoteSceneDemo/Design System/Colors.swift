//
//  Colors.swift
//  IlluminoteSceneDemo
//
//  Created by Tobias on 12/5/25.
//
// DesignSystem/Colors.swift
import SwiftUI

enum DSColor {
    // MARK: - Brand Foundation
    static let nearBlack = Color(hex: "#120B10")
    static let deepMaroon = Color(hex: "#3D1624")
    static let goldLight = Color(hex: "#E3B464")
    static let silverBlue = Color(hex: "#A8B6C8")

    // MARK: - Semantic Surface Tokens
    static let appBackground = Color(hex: "#130D11")
    static let appBackgroundSecondary = Color(hex: "#1A1318")
    static let appBackgroundTertiary = Color(hex: "#21181E")
    static let backgroundPrimary = appBackground
    static let backgroundSecondary = Color(hex: "#23191F")
    static let surfaceElevated = Color(hex: "#2D2128")
    static let readingSurface = Color(hex: "#1D161A")
    static let interactiveSurface = Color(hex: "#281E24")
    static let quietSurface = Color(hex: "#171115")
    static let immersiveOverlay = Color.black.opacity(0.30)
    static let overlaySoft = Color.black.opacity(0.18)

    // MARK: - Semantic Text Tokens
    static let textPrimary = Color(hex: "#F7F1EC")
    static let textSecondary = Color(hex: "#D8CCC4")
    static let textTertiary = Color(hex: "#A99B94")
    static let quietText = Color(hex: "#C3B5AD")
    static let quietTextMuted = Color(hex: "#8E7F79")

    // MARK: - Accent Colors
    static let accentPrimary = Color(hex: "#4A90E2")
    static let accentPrimaryLight = Color(hex: "#DCEEFF")
    static let accentPrimaryDark = Color(hex: "#357ABD")
    static let brandAccent = goldLight
    static let brandAccentSoft = goldLight.opacity(0.18)
    static let brandAccentMuted = Color(hex: "#8B6B39")
    static let textOnBrandAccent = nearBlack

    // MARK: - Dividers & Borders
    static let divider = Color.white.opacity(0.10)
    static let dividerSoft = Color.white.opacity(0.07)
    static let dividerStrong = Color.white.opacity(0.16)

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

    // MARK: - Light Context (for forms/settings that need light backgrounds)
    static let lightBackground = Color(hex: "#F7F4F0")
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
