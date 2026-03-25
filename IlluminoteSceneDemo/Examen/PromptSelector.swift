import Foundation

struct PromptSelector {

    private static let crossoverTags: Set<String> = [
        "vocation", "clinical", "service", "shadowing", "leadership", "research", "work", "dailylife", "compassion", "discernment"
    ]

    private static let dailyContextTags: Set<String> = [
        "other", "daily", "dailylife"
    ]

    private static let dailyPromptTags: Set<String> = [
        "dailylife", "daily", "prayer", "gratitude", "presence", "reflection", "compassion", "closing"
    ]

    private static func isDailyContext(_ expLower: Set<String>) -> Bool {
        !expLower.isDisjoint(with: dailyContextTags)
    }

    private static func phaseCap(for mode: ExamenMode, phase: Int) -> Int {
        switch mode {
        case .quick:
            return 1
        case .deep, .vocation, .spiritual:
            return phase == 0 ? 3 : 4
        }
    }

    private static func isFirstPrinciplePrompt(_ prompt: PromptTemplate) -> Bool {
        prompt.phase == 0 && prompt.stage.lowercased() == "first-principle"
    }

    private static func requiresPriorJournalHistory(_ prompt: PromptTemplate) -> Bool {
        let tagsLower = Set((prompt.tags ?? []).map { $0.lowercased() })
        if tagsLower.contains("requires-history")
            || tagsLower.contains("requires_history")
            || tagsLower.contains("history-required") {
            return true
        }

        // Backward-compatible guard for legacy prompt text before tags are added.
        let textLower = prompt.text.lowercased()
        if textLower.contains("earlier notes") {
            return true
        }

        return false
    }

    private static func passesBaseGuards(
        prompt: PromptTemplate,
        includeDeep: Bool,
        allowSpiritualPrompts: Bool,
        priorJournalCount: Int
    ) -> Bool {
        let depthLower = prompt.depth.lowercased()
        if depthLower == "deep" && !includeDeep {
            return false
        }

        if requiresPriorJournalHistory(prompt) && priorJournalCount < 1 {
            return false
        }

        let promptTagsLower = Set((prompt.tags ?? []).map { $0.lowercased() })
        if !allowSpiritualPrompts && promptTagsLower.contains("spiritual") {
            if promptTagsLower.isDisjoint(with: crossoverTags) {
                return false
            }
        }

        return true
    }

    private static func passesContextFilters(
        prompt: PromptTemplate,
        expLower: Set<String>,
        profLower: Set<String>,
        enforceProfession: Bool,
        enforceExperience: Bool
    ) -> Bool {
        if enforceProfession, !profLower.isEmpty, let pTags = prompt.professionTags, !pTags.isEmpty {
            let promptProfLower = Set(pTags.map { $0.lowercased() })
            if promptProfLower.isDisjoint(with: profLower) {
                return false
            }
        }

        if enforceExperience, !expLower.isEmpty {
            if isDailyContext(expLower) {
                let promptExpLower = Set((prompt.experienceTypes ?? []).map { $0.lowercased() })
                let promptTagLower = Set((prompt.tags ?? []).map { $0.lowercased() })

                if !promptExpLower.isDisjoint(with: expLower) {
                    return true
                }

                // Treat broadly-applicable prompts as valid for Daily context.
                if promptExpLower.count >= 5 {
                    return true
                }

                if !promptTagLower.isDisjoint(with: dailyPromptTags) {
                    return true
                }
            }

            if let expTypes = prompt.experienceTypes, !expTypes.isEmpty {
                let promptExpLower = Set(expTypes.map { $0.lowercased() })
                if promptExpLower.isDisjoint(with: expLower) {
                    return false
                }
            } else if let tagList = prompt.tags, !tagList.isEmpty {
                let promptTagLower = Set(tagList.map { $0.lowercased() })
                if promptTagLower.isDisjoint(with: expLower) {
                    return false
                }
            }
        }

        return true
    }

    private static func score(
        prompt: PromptTemplate,
        mode: ExamenMode,
        includeDeep: Bool,
        modeTagsLower: Set<String>,
        expLower: Set<String>,
        recentPromptIDs: Set<UUID>
    ) -> Int {
        let promptTagsLower = Set((prompt.tags ?? []).map { $0.lowercased() })
        var score = promptTagsLower.intersection(modeTagsLower).count * 10
        let promptExpLower = Set((prompt.experienceTypes ?? []).map { $0.lowercased() })

        if includeDeep && prompt.depth.lowercased() == "deep" {
            score += 5
        }

        if prompt.depth.lowercased() == "standard" && prompt.phase == 0 {
            score += 5
        }

        if (mode == .vocation || mode == .deep) && prompt.stage.lowercased() == "first-principle" && prompt.phase == 0 {
            score += 15
        }

        if prompt.phase == 3 {
            if promptExpLower.count <= 2 && !promptExpLower.isEmpty && !expLower.isDisjoint(with: promptExpLower) {
                score += 20
            }
        }

        if isDailyContext(expLower) {
            if !promptTagsLower.isDisjoint(with: dailyPromptTags) {
                score += 18
            }

            if promptTagsLower.contains("spiritual") {
                score += 12
            }

            if !promptExpLower.isDisjoint(with: dailyContextTags) {
                score += 24
            } else if promptExpLower.count >= 5 {
                score += 6
            }

            // Avoid over-selecting narrow, profession-specific prompts in Daily mode.
            if promptExpLower.count <= 2 && promptExpLower.isDisjoint(with: dailyContextTags) {
                score -= 20
            }
        }

        if recentPromptIDs.contains(prompt.id) {
            score -= 100
        }

        return score
    }

    private static func selectWithPhaseZeroAnchor(
        scoredPrompts: [(PromptTemplate, Int)],
        cap: Int
    ) -> [PromptTemplate] {
        guard cap > 0 else { return [] }

        let firstPrinciple = scoredPrompts.filter { isFirstPrinciplePrompt($0.0) }
        let nonFirstPrinciple = scoredPrompts.filter { !isFirstPrinciplePrompt($0.0) }

        var selected: [PromptTemplate] = []
        var usedIDs = Set<UUID>()

        if let anchor = firstPrinciple.first {
            selected.append(anchor.0)
            usedIDs.insert(anchor.0.id)
        }

        for candidate in nonFirstPrinciple where selected.count < cap {
            guard !usedIDs.contains(candidate.0.id) else { continue }
            selected.append(candidate.0)
            usedIDs.insert(candidate.0.id)
        }

        // Fallback: if we still need prompts for this phase, allow additional first-principle prompts.
        for candidate in firstPrinciple where selected.count < cap {
            guard !usedIDs.contains(candidate.0.id) else { continue }
            selected.append(candidate.0)
            usedIDs.insert(candidate.0.id)
        }

        if selected.isEmpty {
            return scoredPrompts.prefix(cap).map { $0.0 }
        }

        return selected
    }

    static func selectPrompts(
        allPrompts: [PromptTemplate],
        mode: ExamenMode,
        experienceContextTags: [String],
        professionTags: [String],
        recentPromptIDs: Set<UUID>,
        priorJournalCount: Int
    ) -> [PromptTemplate] {

        let includeDeep = (mode != .quick)
        let modeTagsLower = Set(mode.emphasizedTags.map { $0.lowercased() })
        let expLower = Set(experienceContextTags.map { $0.lowercased() })
        let allowSpiritualPrompts = mode.allowSpiritualPrompts || isDailyContext(expLower)

        print("🔍 Phase-based PromptSelector DEBUG")
        print("  Total prompts available: \(allPrompts.count)")
        print("  Mode: \(mode) (includeDeep: \(includeDeep))")
        print("  Experience context: \(experienceContextTags)")
        print("  Profession tags: \(professionTags)")
        print("  Prior journal entries: \(priorJournalCount)")
        print("  Mode tags: \(modeTagsLower)")
        print("  Allow spiritual prompts: \(allowSpiritualPrompts)")

        // Normalize tags
        let profLower = Set(professionTags.map { $0.lowercased() })

        var result: [PromptTemplate] = []
        let phases = [0, 1, 2, 3, 4]

        for phase in phases {
            let cap = phaseCap(for: mode, phase: phase)
            guard cap > 0 else { continue }

            let phasePool = allPrompts.filter {
                $0.phase == phase && passesBaseGuards(
                    prompt: $0,
                    includeDeep: includeDeep,
                    allowSpiritualPrompts: allowSpiritualPrompts,
                    priorJournalCount: priorJournalCount
                )
            }

            print("\n➡ Processing phase: \(phase) with \(phasePool.count) base-eligible prompts (cap: \(cap))")

            let strictCandidates = phasePool.filter {
                passesContextFilters(
                    prompt: $0,
                    expLower: expLower,
                    profLower: profLower,
                    enforceProfession: true,
                    enforceExperience: true
                )
            }
            print("   • Pass strict: \(strictCandidates.count) candidates")

            let relaxProfessionCandidates = phasePool.filter {
                passesContextFilters(
                    prompt: $0,
                    expLower: expLower,
                    profLower: profLower,
                    enforceProfession: false,
                    enforceExperience: true
                )
            }
            print("   • Pass relax-profession: \(relaxProfessionCandidates.count) candidates")

            let generalPhaseCandidates = phasePool.filter {
                passesContextFilters(
                    prompt: $0,
                    expLower: expLower,
                    profLower: profLower,
                    enforceProfession: false,
                    enforceExperience: false
                )
            }
            print("   • Pass general-phase: \(generalPhaseCandidates.count) candidates")

            var candidates: [PromptTemplate] = []
            var seen = Set<UUID>()

            func appendUnique(_ prompts: [PromptTemplate]) {
                for prompt in prompts where !seen.contains(prompt.id) {
                    seen.insert(prompt.id)
                    candidates.append(prompt)
                }
            }

            appendUnique(strictCandidates)
            if candidates.count < cap {
                appendUnique(relaxProfessionCandidates)
            }
            if candidates.count < cap {
                appendUnique(generalPhaseCandidates)
            }

            guard !candidates.isEmpty else {
                print("   • No candidates selected for phase \(phase)")
                continue
            }

            var scoredPrompts = candidates.map { prompt -> (PromptTemplate, Int) in
                (
                    prompt,
                    score(
                        prompt: prompt,
                        mode: mode,
                        includeDeep: includeDeep,
                        modeTagsLower: modeTagsLower,
                        expLower: expLower,
                        recentPromptIDs: recentPromptIDs
                    )
                )
            }

            scoredPrompts.shuffle()
            scoredPrompts.sort { $0.1 > $1.1 }

            let selected: [PromptTemplate]
            if phase == 0 && mode != .quick {
                selected = selectWithPhaseZeroAnchor(scoredPrompts: scoredPrompts, cap: cap)
            } else {
                selected = scoredPrompts.prefix(cap).map { $0.0 }
            }
            for p in selected {
                let score = scoredPrompts.first(where: { $0.0.id == p.id })?.1 ?? 0
                print("   • Selected: \(p.stage) [Score: \(score)]")
            }

            result.append(contentsOf: selected)
        }

        print("\n📋 Final result: \(result.count) prompts selected")
        return result
    }
}
