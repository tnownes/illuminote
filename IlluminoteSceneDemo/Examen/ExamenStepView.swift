import SwiftUI

struct ExamenStepView: View {
  let question: String
  var onNext: () -> Void

  var body: some View {
    ZStack {
      // 1) Glass-pane overlay inset from edges
      RoundedRectangle(cornerRadius: 29)
          .fill(Color.black.opacity(0.4))
          .blur(radius: 1)
          .padding(10)

      // 2) Content layer
      VStack(spacing: 24) {
        Text(question)
          .font(.system(size: 24, weight: .semibold))
          .foregroundColor(.white)
          .multilineTextAlignment(.leading)

        Spacer()

        Button("Next") {
          onNext()
        }
        .font(.system(size: 18, weight: .medium))
        .padding()
        .background(Color.white.opacity(0.2))
        .foregroundColor(.white)
        .cornerRadius(12)
      }
      .padding(32)
    }
  }
}

struct ExamenStepView_Previews: PreviewProvider {
  static var previews: some View {
    ExamenStepView(question: "Preview prompt goes here?", onNext: {})
  }
}
