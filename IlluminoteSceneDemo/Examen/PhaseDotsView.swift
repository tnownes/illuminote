//
//  PhaseDotsView.swift
//  IlluminoteSceneDemo
//
//  Created by Tobias on 1/3/26.
//

import SwiftUI

// MARK: - Phase dot indicator

struct PhaseDotsView: View {
    let current: Int
    let total: Int
    var onDotTapped: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) { // Increased spacing
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundColor(
                        index == current ? .accentColor : .secondary.opacity(0.4)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onDotTapped?(index)
                    }
                    .accessibilityLabel("Phase \(index + 1) of \(total)")
                    .accessibilityAddTraits(index == current ? .isSelected : [])
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Prompt dot indicator

// MARK: - Pill Progress Indicator
struct PillProgressView: View {
    let current: Int
    let total: Int
    let progress: CGFloat
    var horizontalPadding: CGFloat = 40
    private let segmentSpacing: CGFloat = 6
    
    var body: some View {
        GeometryReader { geometry in
            let totalSegments = max(total, 1)
            let totalSpacing = CGFloat(max(totalSegments - 1, 0)) * segmentSpacing
            let segmentWidth = max((geometry.size.width - totalSpacing) / CGFloat(totalSegments), 0)

            HStack(spacing: segmentSpacing) {
                ForEach(0..<total, id: \.self) { index in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))

                        if index < current {
                            Capsule()
                                .fill(Color.white)
                        } else if index == current {
                            Capsule()
                                .fill(Color.white)
                                .frame(width: segmentWidth * max(min(progress, 1), 0))
                        }
                    }
                    .frame(width: segmentWidth, height: 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 4)
        .padding(.vertical, 8)
        .padding(.horizontal, horizontalPadding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Prompt \(current + 1) of \(total)")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}
