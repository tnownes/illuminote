//
//  PromptProgressView.swift
//  IlluminoteSceneDemo
//
//  Created by Tobias on 1/2/26.
//


import SwiftUI

struct PromptProgressView: View {
    let currentIndex: Int
    let count: Int
    
    var body: some View {
        VStack(spacing: 3) {
            ProgressView(value: Double(currentIndex + 1), total: Double(count))
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
            Text("Prompt \(currentIndex + 1) of \(count)")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
    }
}