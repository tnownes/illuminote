//
//  PhaseTitleView.swift
//  IlluminoteSceneDemo
//
//  Created by Tobias on 1/2/26.
//

import SwiftUI

struct ExamenHeaderState: Equatable {
    let phase: Int
    let totalPhases: Int
    let currentPromptIndex: Int
    let promptCount: Int
    let timerProgress: CGFloat

    var titleText: String {
        switch phase {
        case 0: return "Opening & Centering"
        case 1: return "Review the Day with Gratitude"
        case 2: return "Pay Attention to Your Emotions"
        case 3: return "Choose a Feature & Pray from It"
        case 4: return "Look Toward Tomorrow"
        default: return "Insight"
        }
    }

    var phaseText: String {
        "Step \(phase + 1) of \(totalPhases)"
    }

    var showsPromptProgress: Bool {
        promptCount > 1
    }
}

struct PhaseTitleView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let state: ExamenHeaderState

    private var prefersStackedLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            if prefersStackedLayout {
                stackedTitleRow
            } else {
                ViewThatFits(in: .horizontal) {
                    inlineTitleRow
                    stackedTitleRow
                }
            }

            if state.showsPromptProgress {
                PillProgressView(
                    current: state.currentPromptIndex,
                    total: state.promptCount,
                    progress: state.timerProgress,
                    horizontalPadding: 0
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(state.titleText). \(state.phaseText)")
    }

    private var inlineTitleRow: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            titleText(lineLimit: 2)

            phaseBadge
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stackedTitleRow: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            titleText(lineLimit: 3)

            phaseBadge
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func titleText(lineLimit: Int) -> some View {
        Text(state.titleText)
            .font(DSFont.sectionTitle)
            .multilineTextAlignment(.leading)
            .foregroundStyle(DSColor.textPrimary)
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.78)
            .allowsTightening(true)
            .layoutPriority(1)
    }

    private var phaseBadge: some View {
        Text(state.phaseText)
            .font(DSFont.meta.weight(.medium))
            .foregroundStyle(DSColor.quietText)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(DSColor.quietSurface)
                    .overlay(
                        Capsule()
                            .stroke(DSColor.dividerSoft, lineWidth: 1)
                    )
            )
            .lineLimit(1)
    }
}

#Preview("Header Compact") {
    ZStack {
        Color.black
        PhaseTitleView(
            state: ExamenHeaderState(
                phase: 0,
                totalPhases: 5,
                currentPromptIndex: 1,
                promptCount: 3,
                timerProgress: 0.55
            )
        )
        .padding()
    }
    .frame(width: 320, height: 180)
}

#Preview("Header Wide") {
    ZStack {
        Color.black
        PhaseTitleView(
            state: ExamenHeaderState(
                phase: 2,
                totalPhases: 5,
                currentPromptIndex: 0,
                promptCount: 2,
                timerProgress: 0.2
            )
        )
        .padding()
    }
    .frame(width: 430, height: 180)
}

#Preview("Header Accessibility") {
    ZStack {
        Color.black
        PhaseTitleView(
            state: ExamenHeaderState(
                phase: 3,
                totalPhases: 5,
                currentPromptIndex: 2,
                promptCount: 4,
                timerProgress: 0.9
            )
        )
        .padding()
    }
    .frame(width: 320, height: 220)
    .environment(\.dynamicTypeSize, .accessibility2)
}
