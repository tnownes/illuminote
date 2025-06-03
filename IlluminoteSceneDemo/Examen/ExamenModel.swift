//
//  ExamenModel.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 5/24/25.
//

import Foundation
// ExamenModel.swift
struct UserProfile: Codable, Identifiable {
    let id: UUID
    var preProfessionalInterest: PreProfessionalInterest
}

enum PreProfessionalInterest: String, CaseIterable, Codable {
    case preMedicine, preDentistry, preLaw, other
}

struct ExamenSession: Identifiable, Codable {
    let id: UUID
    var sessionType: ExamenType
    var date: Date
    var responses: [StepResponse]
}

enum ExamenType: String, CaseIterable, Codable {
    case daily, retreat, vocation
}

struct StepResponse: Identifiable, Codable {
    let id: UUID
    let stepIndex: Int
    var answerText: String
    var additionalNotes: String?
}
