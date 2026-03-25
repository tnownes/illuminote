//
//  OverallProgressView.swift
//  IlluminoteSceneDemo
//
//  Created by Tobias on 1/2/26.
//


import SwiftUI

struct OverallProgressView: View {
    let currentPhaseIndex: Int
    let totalPhases: Int
    let currentPromptIndex: Int
    let currentPhaseCount: Int

    var body: some View {
        VStack(spacing: 8) {
            Text("Phase \(currentPhaseIndex + 1) of \(totalPhases)")
                .font(.caption2)
                .foregroundColor(.secondary)

            ProgressView(
                value: Double(currentPhaseIndex),
                total: Double(totalPhases)
            )
            .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))

            Text("Prompt \(currentPromptIndex + 1) of \(currentPhaseCount)")
                .font(.caption2)
                .foregroundColor(.secondary)

            ProgressView(
                value: Double(currentPromptIndex + 1),
                total: Double(currentPhaseCount)
            )
            .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
        }
        .padding(.horizontal)
    }
}

struct OverallProgressView_Previews: PreviewProvider {
    static var previews: some View {
        OverallProgressView(
            currentPhaseIndex: 1,
            totalPhases: 5,
            currentPromptIndex: 2,
            currentPhaseCount: 4
        )
        .previewLayout(.sizeThatFits)
    }
}