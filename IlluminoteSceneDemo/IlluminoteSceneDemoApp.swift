//
//  IlluminoteSceneDemoApp.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 5/2/25.
//

import SwiftUI
import SwiftData

@main
struct IlluminoteSceneDemoApp: App {
    @State private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appSettings)
        }
        .modelContainer(DataStoreHelper.makeModelContainer())
    }
}
