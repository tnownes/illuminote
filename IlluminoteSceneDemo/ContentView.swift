// ContentView.swift
// Illuminote
// Updated for @Observable usage and iOS 17+

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Query(sort: \UserProfile.id) private var profiles: [UserProfile]
    @State private var showOnboarding = false
    @State private var showUITestCompletion = ProcessInfo.processInfo.arguments.contains("-ui-testing-show-completion")

    var body: some View {
        @Bindable var bindableSettings = settings

        TabView(selection: $bindableSettings.selectedTab) {
            LandingView()
                .tag(AppRootTab.home)
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            JournalView()
                .tag(AppRootTab.journal)
                .tabItem {
                    Label("Journal", systemImage: "book")
                }

            InsightsView()
                .tag(AppRootTab.insights)
                .tabItem {
                    Label("Insights", systemImage: "sparkles.rectangle.stack")
                }

            StatementListView()
                .tag(AppRootTab.statement)
                .tabItem {
                    Label("Writing", systemImage: "square.and.pencil")
                }

            SettingsView()
                .tag(AppRootTab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView()
                .interactiveDismissDisabled()
        }
        .fullScreenCover(isPresented: $showUITestCompletion) {
            ExamenCompletionView(
                onViewJournal: {
                    settings.selectedTab = .journal
                    showUITestCompletion = false
                },
                onOpenInsights: {
                    settings.selectedTab = .insights
                    showUITestCompletion = false
                },
                onGoToWriting: {
                    settings.selectedTab = .statement
                    showUITestCompletion = false
                },
                onReturnHome: {
                    settings.selectedTab = .home
                    showUITestCompletion = false
                }
            )
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
            ApplicationExperience.self,
            ExperiencePeriod.self,
            InsightNode.self,
            InsightEntryLink.self,
            InsightWorkspaceEntry.self,
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
