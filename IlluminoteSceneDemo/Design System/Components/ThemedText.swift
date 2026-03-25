//
//  ThemedText.swift
//  IlluminoteSceneDemo
//
//  Created by Tobias on 12/5/25.
//


// DesignSystem/Components/ThemedText.swift
import SwiftUI

struct ThemedText: View {
    enum Style {
        case heading1
        case heading2
        case body
        case subtext
        case caption
    }

    enum Context {
        case onDark
        case onLight
        case onGlass
    }

    let text: String
    let style: Style
    var context: Context = .onDark

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(textColor)
    }

    private var font: Font {
        switch style {
        case .heading1:
            return DSFont.heading1
        case .heading2:
            return DSFont.heading2
        case .body:
            return DSFont.body
        case .subtext:
            return DSFont.subtext
        case .caption:
            return DSFont.caption
        }
    }

    private var textColor: Color {
        switch context {
        case .onDark:
            return DSColor.textPrimary
        case .onLight:
            return DSColor.lightText
        case .onGlass:
            return Color.white.opacity(0.9)
        }
    }
}

struct ThemedText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            ThemedText(text: "Heading 1", style: .heading1)
            ThemedText(text: "Heading 2", style: .heading2)
            ThemedText(text: "Body – regular text goes here", style: .body)
            ThemedText(text: "Subtext / metadata", style: .subtext)
            ThemedText(text: "Caption / fine print", style: .caption)
        }
        .padding()
    }
}