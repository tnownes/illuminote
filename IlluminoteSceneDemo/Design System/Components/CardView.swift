//
//  CardView.swift
//  IlluminoteSceneDemo
//
//  Created by Tobias on 12/5/25.
//


// DesignSystem/Components/CardView.swift
import SwiftUI

struct CardView<Content: View>: View {
    let backgroundColor: Color
    let content: Content

    init(backgroundColor: Color = DSColor.surfaceElevated, @ViewBuilder content: () -> Content) {
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            content
        }
        .padding(DSSpacing.md)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DSColor.divider, lineWidth: 0.5)
        )
    }
}

struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        CardView {
            Text("Card Title")
                .font(DSFont.heading2)
                .foregroundColor(DSColor.textPrimary)
            Text("Some descriptive text for the card — this is a card view example.")
                .font(DSFont.body)
                .foregroundColor(DSColor.textSecondary)
        }
        .padding()
    }
}