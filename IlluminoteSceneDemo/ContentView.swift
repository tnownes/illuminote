// ContentView.swift
// Illuminote
// Updated for @Observable usage and iOS 17+

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var settings = AppSettings()
    @Query(sort: \UserProfile.id) private var profiles: [UserProfile]
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            LandingView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book")
                }

            StatementListView()
                .tabItem {
                    Label("Statement", systemImage: "square.and.pencil")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .environment(settings)  // <— Using @Observable pattern
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView()
                .interactiveDismissDisabled()
        }
        .task {
            if let profile = profiles.first {
                if !profile.hasSeenOnboarding {
                    showOnboarding = true
                }
            } else if profiles.isEmpty {
                showOnboarding = true
            }
        }
        .onChange(of: profiles.count, initial: false) { _, newCount in
            if newCount == 0 {
                showOnboarding = true
            }
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let container = try! ModelContainer(
            for: UserProfile.self,
            ExamenSession.self,
            StepResponse.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let sample = ExamenSession(sessionType: .daily, date: Date.now)
        context.insert(sample)
        let settings = AppSettings()
        return ContentView()
            .modelContainer(container)
            .environment(settings)
    }
}
#endif
