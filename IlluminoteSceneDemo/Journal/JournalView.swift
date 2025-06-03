//
//  JournalView.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 5/23/25.
//


import SwiftUI

struct JournalView: View {
    var body: some View {
        NavigationView {
            Text("Journal Screen")
                .font(.title)
                .navigationTitle("Journal")
        }
    }
}

#if DEBUG
struct JournalView_Previews: PreviewProvider {
    static var previews: some View {
        JournalView()
    }
}
#endif
