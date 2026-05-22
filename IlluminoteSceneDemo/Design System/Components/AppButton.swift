//
//  AppButton.swift
//  IlluminoteSceneDemo
//
//  Created by Tobias on 12/5/25.
//


// DesignSystem/Components/AppButton.swift
import SwiftUI

struct AppButton: View {
    enum Style {
        case primary
        case secondary
        case quiet
        case destructive
    }

    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DSFont.body)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(AppChromeButtonStyle(role: style))
    }
}

struct AppChromeButtonStyle: ButtonStyle {
    let role: AppButton.Style

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .padding(.vertical, DSSpacing.md)
            .padding(.horizontal, DSSpacing.md)
            .background(background(configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(
                color: role == .primary ? DSColor.brandAccent.opacity(configuration.isPressed ? 0.12 : 0.28) : .clear,
                radius: configuration.isPressed ? 8 : 14,
                x: 0,
                y: configuration.isPressed ? 1 : 6
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(AnimationConfig.confirmation, value: configuration.isPressed)
    }

    private func background(_ isPressed: Bool) -> AnyShapeStyle {
        switch role {
        case .primary:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        DSColor.brandAccent.opacity(isPressed ? 0.90 : 0.98),
                        DSColor.brandAccent.opacity(isPressed ? 0.80 : 0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .secondary:
            return AnyShapeStyle(DSColor.interactiveSurface.opacity(isPressed ? 0.92 : 0.98))
        case .quiet:
            return AnyShapeStyle(DSColor.quietSurface.opacity(isPressed ? 0.90 : 0.98))
        case .destructive:
            return AnyShapeStyle(DSColor.error.opacity(isPressed ? 0.82 : 0.92))
        }
    }

    private var foregroundColor: Color {
        switch role {
        case .primary:
            return DSColor.textOnBrandAccent
        case .secondary, .quiet:
            return DSColor.textPrimary
        case .destructive:
            return .white
        }
    }

    private var borderColor: Color {
        switch role {
        case .primary:
            return DSColor.brandAccent.opacity(0.28)
        case .secondary:
            return DSColor.dividerStrong
        case .quiet:
            return DSColor.dividerSoft
        case .destructive:
            return DSColor.error.opacity(0.35)
        }
    }

    private var borderWidth: CGFloat {
        switch role {
        case .primary, .destructive:
            return 0
        case .secondary:
            return 1
        case .quiet:
            return 1
        }
    }
}

extension ButtonStyle where Self == AppChromeButtonStyle {
    static var appPrimary: AppChromeButtonStyle { AppChromeButtonStyle(role: .primary) }
    static var appSecondary: AppChromeButtonStyle { AppChromeButtonStyle(role: .secondary) }
    static var appQuiet: AppChromeButtonStyle { AppChromeButtonStyle(role: .quiet) }
    static var appDestructive: AppChromeButtonStyle { AppChromeButtonStyle(role: .destructive) }
}

struct AppButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DSSpacing.sm) {
            AppButton(title: "Primary", style: .primary, action: {})
            AppButton(title: "Secondary", style: .secondary, action: {})
            AppButton(title: "Quiet", style: .quiet, action: {})
            AppButton(title: "Destructive", style: .destructive, action: {})
        }
        .padding()
    }
}
