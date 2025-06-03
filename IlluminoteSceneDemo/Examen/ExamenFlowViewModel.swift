import Foundation
import Combine

class ExamenFlowViewModel: ObservableObject {
  @Published var currentStepIndex = 0
  let questions: [String] = [
    "What are you grateful for?",
    "Where did you feel God’s presence?",
    // … etc …
  ]

  func advance() {
    guard currentStepIndex < questions.count - 1 else { return }
    currentStepIndex += 1
  }
}
