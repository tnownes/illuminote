//
//  PersonalStatementView.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 5/23/25.
//


import SwiftUI

struct PersonalStatementView: View {
    var body: some View {
        NavigationView {
            Text("Personal Statement Screen")
                .font(.title)
                .navigationTitle("Statement")
        }
    }
}

#if DEBUG
struct PersonalStatementView_Previews: PreviewProvider {
    static var previews: some View {
        PersonalStatementView()
    }
}
#endif
