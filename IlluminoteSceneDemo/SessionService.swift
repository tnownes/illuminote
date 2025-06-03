import Foundation
import SwiftUI
class UserSettings: ObservableObject {
    @AppStorage("preProfessionalInterest")
    var interestRaw: String = PreProfessionalInterest.preMedicine.rawValue

    var interest: PreProfessionalInterest {
        get { PreProfessionalInterest(rawValue: interestRaw)! }
        set { interestRaw = newValue.rawValue }
    }
}

protocol SessionServiceProtocol {
    func loadSessions() -> [ExamenSession]
    func save(session: ExamenSession)
    func delete(session: ExamenSession)
}
