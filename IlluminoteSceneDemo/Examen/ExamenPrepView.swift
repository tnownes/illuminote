import SwiftUI

struct ExamenPrepView: View {
    var onBegin: () -> Void
    var highlightColor: Color?

    @StateObject private var vm: ExamenPrepViewModel

    init(onBegin: @escaping () -> Void, highlightColor: Color? = nil) {
        self.onBegin = onBegin
        self.highlightColor = highlightColor
        _vm = StateObject(wrappedValue: ExamenPrepViewModel(baseColor: highlightColor ?? .blue))
    }
    
    var body: some View {
        ZStack {
            // Animated Gradient Background
            LinearGradient(
                gradient: Gradient(colors: vm.gradientColors),
                startPoint: vm.gradientStart,
                endPoint: vm.gradientEnd
            )
            .edgesIgnoringSafeArea(.all)
            .opacity(vm.showGradient ? 1 : 0) // fade in when showGradient toggles
            .animation(.easeInOut(duration: 2), value: vm.showGradient)
            
        }
        .onAppear {
            vm.onAppearAnimate()
        }
    }
}

#Preview {
    ExamenPrepView(onBegin: {}, highlightColor: Color.blue)
}
