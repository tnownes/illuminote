import SwiftUI

struct ContentView: View {
    @StateObject private var settings = AppSettings()

    var body: some View {
        TabView {
            // Guided Examen flow
            ExamenFlowView()
                .tabItem {
                    Label("Examen", systemImage: "circle.grid.cross")
                }

            // Journal screen
            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book")
                }

            // Personal Statement screen
            PersonalStatementView()
                .tabItem {
                    Label("Statement", systemImage: "pencil")
                }
        }
        .environmentObject(settings)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppSettings())
    }
}
#endif
