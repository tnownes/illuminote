import Foundation

enum RequirementApplicationService: String, Codable {
    case amcas
    case aacomas
    case tmdsas
    case aadsas
    case pharmcas
    case otcas
    case ptcas
    case caspa
    case vmcas
    case optomcas
    case lsac
    case eras
    case other
    
    var displayName: String {
        switch self {
        case .amcas: return "AMCAS (MD)"
        case .aacomas: return "AACOMAS (DO)"
        case .tmdsas: return "TMDSAS (Texas MD/DO/Dental)"
        case .aadsas: return "ADEA AADSAS (Dental)"
        case .pharmcas: return "PharmCAS (Pharmacy)"
        case .otcas: return "OTCAS (Occupational Therapy)"
        case .ptcas: return "PTCAS (Physical Therapy)"
        case .caspa: return "CASPA (Physician Assistant)"
        case .vmcas: return "VMCAS (Veterinary Medicine)"
        case .optomcas: return "OptomCAS (Optometry)"
        case .lsac: return "LSAC (Law)"
        case .eras: return "ERAS (Residency)"
        case .other: return "Other"
        }
    }
}

enum DegreeIntent: String, Codable, CaseIterable, Identifiable {
    case md
    case doDetail // "do" is a keyword
    case both
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .md: return "MD Only"
        case .doDetail: return "DO Only"
        case .both: return "MD & DO"
        }
    }
}

struct StatementRequirement: Identifiable, Codable {
    let id: String
    let serviceCode: RequirementApplicationService
    let cycleYear: Int
    let effectiveStartDate: Date
    let effectiveEndDate: Date
    let promptText: String
    let characterLimitMin: Int
    let characterLimitMax: Int
    let wordLimitMin: Int?
    let wordLimitMax: Int?
    let formattingRules: String?
    let helpfulTip: String?
    let officialLink: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case serviceCode = "service_code"
        case cycleYear = "cycle_year"
        case effectiveStartDate = "effective_start_date"
        case effectiveEndDate = "effective_end_date"
        case promptText = "prompt_text"
        case characterLimitMin = "character_limit_min"
        case characterLimitMax = "character_limit_max"
        case wordLimitMin = "word_limit_min"
        case wordLimitMax = "word_limit_max"
        case formattingRules = "formatting_rules"
        case helpfulTip = "helpful_tip"
        case officialLink = "official_link"
    }
}
