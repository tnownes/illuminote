//
//  ThemePickerView.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 5/8/25.
//

import Foundation
import SwiftUI

struct ThemePickerView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(ExamenTheme.allCases) { theme in
                HStack {
                    Text(theme.displayName)
                    Spacer()
                    if settings.selectedTheme == theme {
                        Image(systemName: "checkmark")
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    settings.selectedTheme = theme
                }
            }
        }
        .navigationTitle("Choose a Theme")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

#if DEBUG
struct ThemePickerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ThemePickerView()
                .environmentObject(AppSettings())
        }
    }
}
#endif
