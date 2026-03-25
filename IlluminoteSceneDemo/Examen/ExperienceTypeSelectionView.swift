import SwiftUI

struct ExperienceTypeSelectionView: View {
    var onSelect: (ExperienceType) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick your experience type")
                .font(.headline)
                .padding(.top)

            ExperienceTypeGridView(
                types: ExperienceType.allCases,
                counts: [:] // TODO: Connect to real stats if desired
            ) { tapped in
                onSelect(tapped)
            }
            .padding(.horizontal)

            Spacer(minLength: 0)
        }
        .navigationTitle("Before you begin")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    onCancel()
                }
            }
        }
        .background(
            ZStack {
                // Sacred Void Radial Gradient
                RadialGradient(
                    gradient: Gradient(colors: [DSColor.nearBlack, DSColor.deepMaroon]),
                    center: .center,
                    startRadius: 50,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }
        )
        // Ensure white header text for contrast
        .foregroundStyle(.white)
    }
}

#Preview {
    NavigationStack {
        ExperienceTypeSelectionView(onSelect: { _ in }, onCancel: {})
    }
}
