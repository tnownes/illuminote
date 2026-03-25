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
        case destructive
    }

    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DSFont.body)
                .foregroundColor(foregroundColor)
                .padding(.vertical, DSSpacing.sm)
                .padding(.horizontal, DSSpacing.md)
                .frame(maxWidth: .infinity)
        }
        .background(backgroundColor)
        .cornerRadius(8)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return DSColor.accentPrimary
        case .secondary:
            return DSColor.surfaceElevated
        case .destructive:
            return DSColor.error
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive:
            return .white
        case .secondary:
            return DSColor.textPrimary
        }
    }
}

struct AppButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DSSpacing.sm) {
            AppButton(title: "Primary", style: .primary, action: {})
            AppButton(title: "Secondary", style: .secondary, action: {})
            AppButton(title: "Destructive", style: .destructive, action: {})
        }
        .padding()
    }
}