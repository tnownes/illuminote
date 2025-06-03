import SwiftUI
import SceneKit

struct ExamenFlowView: View {
    @StateObject private var settings = AppSettings()
    @State private var showThemePicker = false
    @StateObject private var flowVM = ExamenFlowViewModel()

    var body: some View {
        ZStack {
            settings.selectedTheme.sceneView
                .ignoresSafeArea()

            // Glass‐pane overlay
            Color.black.opacity(0.4)
                .blur(radius: 15)
                .ignoresSafeArea()

            // Examen step content
            ExamenStepView(
                question: flowVM.questions[flowVM.currentStepIndex],
                onNext: { flowVM.advance() }
            )

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showThemePicker = true
                    } label: {
                        Image(systemName: "paintpalette")
                            .foregroundColor(.white)
                            .padding()
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showThemePicker) {
            NavigationView {
                ThemePickerView()
                    .environmentObject(settings)
            }
        }
        .environmentObject(settings)
    }
}

#if DEBUG
struct ExamenFlowView_Previews: PreviewProvider {
    static var previews: some View {
        ExamenFlowView()
            .environmentObject(AppSettings())
    }
}
#endif
