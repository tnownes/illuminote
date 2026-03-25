import Foundation

protocol StatementRequirementsService {
    func requirements(for profile: UserProfile) async -> [StatementRequirement]
}

class LocalStatementRequirementsService: StatementRequirementsService {
    
    private let decoder: JSONDecoder
    private var allRequirements: [StatementRequirement]?
    
    init() {
        self.decoder = JSONDecoder()
        // Custom date handling if needed, but ISO8601 is default for newer JSONDecoder strategies or can be set
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        self.decoder.dateDecodingStrategy = .formatted(formatter)
    }
    
    func requirements(for profile: UserProfile) async -> [StatementRequirement] {
        // Lazy load
        if allRequirements == nil {
            allRequirements = loadRequirements()
        }
        
        guard let all = allRequirements else { return [] }
        
        // Filter logic based on profile
        var filtered: [StatementRequirement] = []
        
        // 1. Filter by Cycle (For MVP we just assume current 2026 cycle, or we could add logic to check date)
        // For simplicity, let's grab all 2026 for now, or assume the JSON only has relevant ones.
        // As per spec: "Display cycle-specific rules".
        
        // 2. Filter by Service based on Profile
        // - MD -> AMCAS
        // - DO -> AACOMAS
        // - Texas -> TMDSAS
        
        for req in all {
            if shouldInclude(req, for: profile) {
                filtered.append(req)
            }
        }
        
        return filtered
    }
    
    private func shouldInclude(_ req: StatementRequirement, for profile: UserProfile) -> Bool {
        // If track is explicitly set, use it.
        if let track = profile.preProfessionalTrack?.canonical {
            switch track {
            case .preMedicine:
                if profile.isTexasApplicant {
                    return req.serviceCode == .tmdsas || req.serviceCode == .amcas || req.serviceCode == .aacomas // Often applicants use both in Texas
                } else if profile.degreeIntent == .md {
                    return req.serviceCode == .amcas
                } else if profile.degreeIntent == .doDetail {
                    return req.serviceCode == .aacomas
                } else {
                    return req.serviceCode == .amcas || req.serviceCode == .aacomas
                }
            case .preDentistry:
                if profile.isTexasApplicant {
                    return req.serviceCode == .tmdsas || req.serviceCode == .aadsas
                }
                return req.serviceCode == .aadsas
            case .prePharmacy:
                return req.serviceCode == .pharmcas
            case .preOccupationalTherapy:
                return req.serviceCode == .otcas
            case .prePhysicalTherapy:
                return req.serviceCode == .ptcas
            case .prePhysicianAssistant:
                return req.serviceCode == .caspa
            case .preVeterinaryMedicine:
                if profile.isTexasApplicant && req.serviceCode == .tmdsas {
                    return true // TMDSAS covers vet in Texas
                }
                return req.serviceCode == .vmcas
            case .preOptometry:
                return req.serviceCode == .optomcas
            case .preLaw:
                return req.serviceCode == .lsac
            case .medicalOrDentalResidency:
                return req.serviceCode == .eras
            case .general, .other:
                return false // Doesn't map cleanly to a primary application service usually
            }
        }
        
        // Fallback to legacy degreeIntent behavior if no track is set
        if req.serviceCode == .tmdsas {
            return profile.isTexasApplicant
        }
        
        switch profile.degreeIntent {
        case .md:
            return req.serviceCode == .amcas
        case .doDetail:
            return req.serviceCode == .aacomas
        case .both:
            return req.serviceCode == .amcas || req.serviceCode == .aacomas
        }
    }
    
    private func loadRequirements() -> [StatementRequirement] {
        guard let url = Bundle.main.url(forResource: "statement_requirements", withExtension: "json") else {
            print("⚠️ statement_requirements.json not found in Bundle.")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let reqs = try decoder.decode([StatementRequirement].self, from: data)
            return reqs
        } catch {
            print("❌ Failed to decode statement requirements: \(error)")
            return []
        }
    }
}
