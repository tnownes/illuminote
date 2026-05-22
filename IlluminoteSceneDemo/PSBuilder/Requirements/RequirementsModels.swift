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

enum WritingTargetCategory: String, Codable, CaseIterable, Identifiable {
    case coreStatement
    case supplementalEssay
    case schoolSpecificEssay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .coreStatement:
            return "Core Statements"
        case .supplementalEssay:
            return "Supplemental Essays"
        case .schoolSpecificEssay:
            return "School-Specific Essays"
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
    let officialTitle: String
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
        case officialTitle = "official_title"
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

struct ApplicationEntryDefinition: Identifiable, Hashable {
    let id: String
    let serviceCode: RequirementApplicationService
    let title: String
    let summary: String
    let maxEntries: Int?
    let entryCharacterLimit: Int?
    let maxHighlights: Int?
    let highlightLabel: String?

    var serviceLabel: String {
        serviceCode.displayName
    }

    var metadataSummary: String {
        var parts: [String] = []
        if let maxEntries {
            parts.append("\(maxEntries) entries")
        }
        if let entryCharacterLimit {
            parts.append("\(entryCharacterLimit) characters each")
        }
        if let maxHighlights, let highlightLabel {
            parts.append("up to \(maxHighlights) \(highlightLabel)")
        }
        return parts.joined(separator: " • ")
    }
}

struct WritingTargetDefinition: Identifiable, Codable, Hashable {
    let id: String
    let category: WritingTargetCategory
    let title: String
    let summary: String
    let promptText: String
    let serviceCodeRaw: String?
    let trackRaw: String?
    let characterLimitMin: Int?
    let characterLimitMax: Int?
    let wordLimitMin: Int?
    let wordLimitMax: Int?
    let officialLink: String?
    let allowsCustomPrompt: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case title
        case summary
        case promptText = "prompt_text"
        case serviceCodeRaw = "service_code"
        case trackRaw = "track"
        case characterLimitMin = "character_limit_min"
        case characterLimitMax = "character_limit_max"
        case wordLimitMin = "word_limit_min"
        case wordLimitMax = "word_limit_max"
        case officialLink = "official_link"
        case allowsCustomPrompt = "allows_custom_prompt"
    }

    var serviceCode: RequirementApplicationService? {
        guard let serviceCodeRaw else { return nil }
        return RequirementApplicationService(rawValue: serviceCodeRaw)
    }

    var track: PreProfessionalTrack? {
        guard let trackRaw else { return nil }
        return PreProfessionalTrack(rawValue: trackRaw)?.canonical
    }

    var limitSummary: String {
        if let characterLimitMax {
            return "\(characterLimitMax) chars"
        }
        if let wordLimitMax {
            return "\(wordLimitMax) words"
        }
        return "Flexible length"
    }

    var writingDisplayTitle: String {
        guard category == .coreStatement,
              serviceCode == .amcas,
              title == "Personal Comments Essay" else {
            return title
        }

        return "Personal Statement"
    }

    var officialTitleSupportingText: String? {
        guard writingDisplayTitle != title,
              let serviceCode else {
            return nil
        }

        return "\(serviceCode.displayName) official title: \(title)"
    }
}
