//
//  ModePickerView.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 12/3/25.
//

import SwiftUI

struct ModePickerView: View {
    @Binding var selectedMode: ExamenMode
    var onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            ThemedText(text: "Choose Examen Style", style: .heading1)
                .padding(.top, DSSpacing.lg)
            
            ScrollView {
                VStack(spacing: DSSpacing.md) {
                    ForEach(ExamenMode.allCases) { mode in
                        Button(action: {
                            selectedMode = mode
                        }) {
                            ModeCard(mode: mode, isSelected: selectedMode == mode)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DSSpacing.md)
            }
            
            AppButton(
                title: "Continue",
                style: .primary,
                action: onConfirm
            )
            .padding(DSSpacing.md)
        }
        .background(DSColor.backgroundPrimary)
    }
}

private struct ModeCard: View {
    let mode: ExamenMode
    let isSelected: Bool
    
    var body: some View {
        CardView(backgroundColor: isSelected ? DSColor.accentPrimary : DSColor.backgroundSecondary) {
            HStack {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    ThemedText(
                        text: mode.displayName,
                        style: .heading2
                    )
                    .foregroundColor(isSelected ? .white : DSColor.textPrimary)
                    
                    ThemedText(
                        text: mode.description,
                        style: .caption
                    )
                    .foregroundColor(isSelected ? .white.opacity(0.8) : DSColor.textSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? DSColor.accentPrimary.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    ModePickerView(selectedMode: .constant(.deep), onConfirm: {})
}
