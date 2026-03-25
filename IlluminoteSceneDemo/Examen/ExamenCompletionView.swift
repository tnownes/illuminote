import SwiftUI

struct ExamenCompletionView: View {
    var onReturnHome: () -> Void
    @State private var appeared = false
    
    var body: some View {
        ZStack {
            if #available(iOS 18.0, *) {
                SacredVoidBackground()
            } else {
                DSColor.nearBlack.ignoresSafeArea()
            }
            
            VStack(spacing: DSSpacing.xl) {
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(DSColor.goldLight)
                    .luminous()
                    .symbolEffect(.bounce, value: true)
                
                VStack(spacing: DSSpacing.md) {
                    Text("Examen Complete")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("Thank you for taking this time for reflection.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DSSpacing.lg)
                }
                
                Spacer()
                
                Button {
                    onReturnHome()
                } label: {
                    Text("Return Home")
                        .fontWeight(.semibold)
                }
                .buttonStyle(SacredButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, DSSpacing.xl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear { appeared = true }
    }
}

#Preview {
    ExamenCompletionView(onReturnHome: {})
}
