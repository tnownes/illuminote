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
        guard let url = resourceBundle.url(forResource: "statement_requirements", withExtension: "json") else {
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

    private var resourceBundle: Bundle {
        if let mainURL = Bundle.main.url(forResource: "statement_requirements", withExtension: "json") {
            _ = mainURL
            return .main
        }
        return Bundle(for: LocalStatementRequirementsService.self)
    }
}

final class LocalWritingTargetCatalogService {
    private let decoder = JSONDecoder()
    private var cachedDefinitions: [WritingTargetDefinition]?

    init() {
        decoder.keyDecodingStrategy = .useDefaultKeys
    }

    func targets(
        for profile: UserProfile?,
        requirements: [StatementRequirement]
    ) -> [WritingTargetDefinition] {
        let canonicalTrack = profile?.preProfessionalTrack?.canonical ?? .general
        let includeMDPhDTargets = profile?.isMDPhDApplicant == true
        let activeRequirements = requirements.sorted {
            if $0.serviceCode.displayName == $1.serviceCode.displayName {
                return $0.cycleYear > $1.cycleYear
            }
            return $0.serviceCode.displayName < $1.serviceCode.displayName
        }

        var combined: [WritingTargetDefinition] = activeRequirements.map { requirement in
            WritingTargetDefinition(
                id: "core.\(requirement.serviceCode.rawValue)",
                category: .coreStatement,
                title: requirement.officialTitle,
                summary: "Your main \(requirement.serviceCode.displayName) essay, using the official prompt and limit.",
                promptText: requirement.promptText,
                serviceCodeRaw: requirement.serviceCode.rawValue,
                trackRaw: canonicalTrack.rawValue,
                characterLimitMin: requirement.characterLimitMin,
                characterLimitMax: requirement.characterLimitMax,
                wordLimitMin: requirement.wordLimitMin,
                wordLimitMax: requirement.wordLimitMax,
                officialLink: requirement.officialLink,
                allowsCustomPrompt: false
            )
        }

        let activeServices = Set(activeRequirements.map(\.serviceCode))
        let hasActiveServices = !activeServices.isEmpty
        var definitions = loadDefinitions().filter { definition in
            let matchesTrack = definition.track == nil || definition.track == canonicalTrack
            let matchesService = definition.serviceCode == nil || activeServices.contains(definition.serviceCode!)
            let matchesProgram = !requiresMDPhDTrack(definition: definition) || includeMDPhDTargets
            return matchesTrack && matchesService && matchesProgram
        }

        if hasActiveServices {
            for service in activeServices {
                if !definitions.contains(where: { $0.id == "supplemental.generic.\(service.rawValue)" }) {
                    definitions.append(
                        WritingTargetDefinition(
                            id: "supplemental.generic.\(service.rawValue)",
                            category: .supplementalEssay,
                            title: "Additional \(service.displayName) Responses",
                            summary: "Use this when a verified service-wide response is missing or you want a flexible catch-all for shorter prompts.",
                            promptText: "Use this workspace for shorter prompts that build on your main statement. Paste the exact prompt into each draft when the school asks something specific.",
                            serviceCodeRaw: service.rawValue,
                            trackRaw: canonicalTrack.rawValue,
                            characterLimitMin: nil,
                            characterLimitMax: 3500,
                            wordLimitMin: nil,
                            wordLimitMax: nil,
                            officialLink: nil,
                            allowsCustomPrompt: true
                        )
                    )
                }

                if !definitions.contains(where: { $0.id == "school.generic.\(service.rawValue)" }) {
                    definitions.append(
                        WritingTargetDefinition(
                            id: "school.generic.\(service.rawValue)",
                            category: .schoolSpecificEssay,
                            title: "\(service.displayName) School-Specific Essays",
                            summary: "Keep school-fit, mission-fit, and 'why this program' responses together.",
                            promptText: "Create one draft per school prompt. Keep the prompt text with the draft so your writing stays grounded in the actual question.",
                            serviceCodeRaw: service.rawValue,
                            trackRaw: canonicalTrack.rawValue,
                            characterLimitMin: nil,
                            characterLimitMax: nil,
                            wordLimitMin: nil,
                            wordLimitMax: nil,
                            officialLink: nil,
                            allowsCustomPrompt: true
                        )
                    )
                }
            }
        } else {
            definitions.append(contentsOf: genericFallbackTargets())
        }

        combined.append(contentsOf: uniqueTargets(definitions))
        return combined.sorted { lhs, rhs in
            if lhs.category == rhs.category {
                if lhs.serviceCode?.displayName == rhs.serviceCode?.displayName {
                    return lhs.title < rhs.title
                }
                return (lhs.serviceCode?.displayName ?? lhs.title) < (rhs.serviceCode?.displayName ?? rhs.title)
            }
            return lhs.category.rawValue < rhs.category.rawValue
        }
    }

    func target(
        withID id: String?,
        for profile: UserProfile?,
        requirements: [StatementRequirement]
    ) -> WritingTargetDefinition? {
        guard let id else { return nil }
        return targets(for: profile, requirements: requirements).first(where: { $0.id == id })
    }

    private func requiresMDPhDTrack(definition: WritingTargetDefinition) -> Bool {
        definition.id == "supplemental.amcas.mdphdEssay"
            || definition.id == "supplemental.amcas.significantResearch"
    }

    private func uniqueTargets(_ targets: [WritingTargetDefinition]) -> [WritingTargetDefinition] {
        var seenIDs = Set<String>()
        var unique: [WritingTargetDefinition] = []

        for target in targets {
            if seenIDs.insert(target.id).inserted {
                unique.append(target)
            }
        }

        return unique
    }

    private func loadDefinitions() -> [WritingTargetDefinition] {
        if let cachedDefinitions {
            return cachedDefinitions
        }

        if let url = resourceBundle.url(forResource: "writing_targets", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? decoder.decode([WritingTargetDefinition].self, from: data) {
            cachedDefinitions = decoded
            return decoded
        }

        cachedDefinitions = fallbackDefinitions
        return fallbackDefinitions
    }

    private var resourceBundle: Bundle {
        if let mainURL = Bundle.main.url(forResource: "writing_targets", withExtension: "json") {
            _ = mainURL
            return .main
        }
        return Bundle(for: LocalWritingTargetCatalogService.self)
    }

    private func genericFallbackTargets() -> [WritingTargetDefinition] {
        [
            WritingTargetDefinition(
                id: "core.generic",
                category: .coreStatement,
                title: "Main Personal Essay",
                summary: "Use this for your primary application essay when you do not need a service-specific prompt yet.",
                promptText: "Start here when you want to draft your main personal essay. Add your application profile later if you want Illuminote to show service-specific prompts and limits.",
                serviceCodeRaw: nil,
                trackRaw: nil,
                characterLimitMin: nil,
                characterLimitMax: 5300,
                wordLimitMin: nil,
                wordLimitMax: nil,
                officialLink: nil,
                allowsCustomPrompt: false
            ),
            WritingTargetDefinition(
                id: "supplemental.generic",
                category: .supplementalEssay,
                title: "Supplemental Essay",
                summary: "Use this for shorter prompts that build on your main essay.",
                promptText: "Use this for shorter application essays when you do not need a service-specific prompt yet. Paste the exact prompt into the draft if a school gives you one.",
                serviceCodeRaw: nil,
                trackRaw: nil,
                characterLimitMin: nil,
                characterLimitMax: 3500,
                wordLimitMin: nil,
                wordLimitMax: nil,
                officialLink: nil,
                allowsCustomPrompt: true
            ),
            WritingTargetDefinition(
                id: "school.generic",
                category: .schoolSpecificEssay,
                title: "School-Specific Essay",
                summary: "Use this for why-us, mission-fit, and school-specific prompts.",
                promptText: "Create one draft per school prompt. Keep the prompt text with the draft so your writing stays anchored to the exact question.",
                serviceCodeRaw: nil,
                trackRaw: nil,
                characterLimitMin: nil,
                characterLimitMax: nil,
                wordLimitMin: nil,
                wordLimitMax: nil,
                officialLink: nil,
                allowsCustomPrompt: true
            )
        ]
    }

    private var fallbackDefinitions: [WritingTargetDefinition] {
        [
            WritingTargetDefinition(
                id: "supplemental.generic.amcas",
                category: .supplementalEssay,
                title: "Additional AMCAS Responses",
                summary: "Organize shorter prompts that extend your main medical-school narrative.",
                promptText: "Use this workspace for secondary-style prompts. Paste the specific school question into each draft when needed.",
                serviceCodeRaw: RequirementApplicationService.amcas.rawValue,
                trackRaw: PreProfessionalTrack.preMedicine.rawValue,
                characterLimitMin: nil,
                characterLimitMax: 3500,
                wordLimitMin: nil,
                wordLimitMax: nil,
                officialLink: nil,
                allowsCustomPrompt: true
            ),
            WritingTargetDefinition(
                id: "school.generic.amcas",
                category: .schoolSpecificEssay,
                title: "AMCAS School-Specific Essays",
                summary: "Track school missions, why-us answers, and program-fit responses.",
                promptText: "Create one draft per school prompt. Keep the prompt text with the draft so the writing stays anchored to the actual question.",
                serviceCodeRaw: RequirementApplicationService.amcas.rawValue,
                trackRaw: PreProfessionalTrack.preMedicine.rawValue,
                characterLimitMin: nil,
                characterLimitMax: nil,
                wordLimitMin: nil,
                wordLimitMax: nil,
                officialLink: nil,
                allowsCustomPrompt: true
            ),
            WritingTargetDefinition(
                id: "supplemental.amcas.otherImpactful",
                category: .supplementalEssay,
                title: "Other Impactful Experiences",
                summary: "A distinct AMCAS response for major life context that shaped your path.",
                promptText: "Other impactful experiences are defined as lived experiences that have communicated to you a broader understanding of yourself, others, or the world. This question is intended for applicants who have overcome major challenges or obstacles. Please use this space to describe how these experiences have impacted your journey to medical school.",
                serviceCodeRaw: RequirementApplicationService.amcas.rawValue,
                trackRaw: PreProfessionalTrack.preMedicine.rawValue,
                characterLimitMin: nil,
                characterLimitMax: 1325,
                wordLimitMin: nil,
                wordLimitMax: nil,
                officialLink: "https://students-residents.aamc.org/applying-medical-school-amcas/publication-chapters/other-impactful-experiences",
                allowsCustomPrompt: false
            ),
            WritingTargetDefinition(
                id: "supplemental.amcas.mdphdEssay",
                category: .supplementalEssay,
                title: "MD-PhD Essay",
                summary: "A separate AMCAS response for applicants pursuing the physician-scientist path.",
                promptText: "Why are you interested in pursuing a combined MD-PhD degree, and how do your previous research experiences support this goal?",
                serviceCodeRaw: RequirementApplicationService.amcas.rawValue,
                trackRaw: PreProfessionalTrack.preMedicine.rawValue,
                characterLimitMin: nil,
                characterLimitMax: 3000,
                wordLimitMin: nil,
                wordLimitMax: nil,
                officialLink: "https://students-residents.aamc.org/applying-medical-school-amcas/publication-chapters/md-phd-and-significant-research-essays",
                allowsCustomPrompt: false
            ),
            WritingTargetDefinition(
                id: "supplemental.amcas.significantResearch",
                category: .supplementalEssay,
                title: "Significant Research Experience Essay",
                summary: "A distinct AMCAS research narrative for applicants with substantial research involvement.",
                promptText: "Please specify your research experience, including the total number of hours, and describe the impact of the research on your motivation for a career in medicine and/or research.",
                serviceCodeRaw: RequirementApplicationService.amcas.rawValue,
                trackRaw: PreProfessionalTrack.preMedicine.rawValue,
                characterLimitMin: nil,
                characterLimitMax: 10000,
                wordLimitMin: nil,
                wordLimitMax: nil,
                officialLink: "https://students-residents.aamc.org/applying-medical-school-amcas/publication-chapters/significant-research-experience-essay",
                allowsCustomPrompt: false
            ),
            WritingTargetDefinition(
                id: "supplemental.tmdsas.personalCharacteristics",
                category: .supplementalEssay,
                title: "TMDSAS Personal Characteristics",
                summary: "A distinct TMDSAS essay focused on qualities and lived experience.",
                promptText: "Learning from others is enhanced in educational settings that include individuals from diverse backgrounds and experiences. Please describe any personal qualities, characteristics, and/or lived experiences that would add to the educational experience of others or that would enhance the educational experience of your classmates.",
                serviceCodeRaw: RequirementApplicationService.tmdsas.rawValue,
                trackRaw: PreProfessionalTrack.preMedicine.rawValue,
                characterLimitMin: nil,
                characterLimitMax: 2500,
                wordLimitMin: nil,
                wordLimitMax: nil,
                officialLink: "https://www.tmdsas.com/apply-now/application-handbook.html",
                allowsCustomPrompt: false
            ),
            WritingTargetDefinition(
                id: "supplemental.tmdsas.optionalEssay",
                category: .supplementalEssay,
                title: "TMDSAS Optional Essay",
                summary: "A space for context that does not fit elsewhere in the application.",
                promptText: "Briefly discuss any unique circumstances or life experiences that are relevant to your application which have not previously been presented.",
                serviceCodeRaw: RequirementApplicationService.tmdsas.rawValue,
                trackRaw: PreProfessionalTrack.preMedicine.rawValue,
                characterLimitMin: nil,
                characterLimitMax: 2500,
                wordLimitMin: nil,
                wordLimitMax: nil,
                officialLink: "https://www.tmdsas.com/apply-now/application-handbook.html",
                allowsCustomPrompt: false
            )
        ]
    }
}
