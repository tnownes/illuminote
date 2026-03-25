import Foundation

struct AIAdvisorPromptPayload {
    let systemPrompt: String
    let userPrompt: String
}

struct AIAdvisorPromptBuilder {
    enum AnalysisStyle {
        case stable
        case richer
    }

    private struct AdvisorTrackPolicy {
        let portalName: String
        let maxCharacters: Int
        let trackFocus: String
    }

    private struct RubricPack {
        let core: String
        let details: String
    }

    private static func compactContext(
        track: PreProfessionalTrack,
        scope: AdvisorGuidelineScope,
        trackPolicy: AdvisorTrackPolicy,
        styleDirective: String,
        activeLens: String? = nil
    ) -> String {
        var parts = [
            "Track: \(track.displayName)",
            "Scope: \(scope.displayName)",
            "Portal: \(trackPolicy.portalName)",
            "Limit: \(trackPolicy.maxCharacters) chars",
            "Format: plain text",
            "Focus: \(trackPolicy.trackFocus)",
            "Style: \(styleDirective)"
        ]
        if let activeLens {
            parts.append("Lens: \(activeLens)")
        }
        return parts.joined(separator: " | ")
    }

    private static func reviewRules(
        style: AnalysisStyle,
        includeStrengthRule: Bool
    ) -> String {
        var lines = [
            "- Critique only. No rewrites, replacement lines, or copy-ready phrasing.",
            "- No prompt/model/system talk or hidden reasoning.",
            "- Every bullet must use concrete draft evidence; quote <= 8 words when helpful.",
            "- If evidence is missing, say what is missing."
        ]
        if includeStrengthRule {
            lines.append("- What Works is optional and needs a short quote; otherwise write exactly \"No reliable strengths yet.\"")
        }
        if style == .richer {
            lines.append("- In Revisions, explain admissions impact in the second sentence.")
        }
        return lines.joined(separator: "\n")
    }

    private static func revisionRules(style: AnalysisStyle) -> String {
        var lines = [
            "- Compare current draft against prior feedback only.",
            "- No rewrites, replacement lines, or copy-ready phrasing.",
            "- Every bullet must use concrete draft evidence; quote <= 8 words when helpful.",
            "- If evidence is missing, say what is missing.",
            "- No prompt/model/system talk or hidden reasoning."
        ]
        if style == .richer {
            lines.append("- In Still Needs Work, explain why the issue matters for admissions readers.")
        }
        return lines.joined(separator: "\n")
    }

    private static func followUpRules() -> String {
        [
            "- Answer only the user's follow-up question.",
            "- Assume the writer already read the full critique; do not restate or summarize it.",
            "- Reference only the minimum prior-feedback context needed to answer the question.",
            "- No rewrites, replacement lines, or copy-ready phrasing.",
            "- Use concrete draft evidence; quote <= 8 words when helpful.",
            "- If evidence is missing, say exactly what is missing.",
            "- No prompt/model/system talk or hidden reasoning."
        ].joined(separator: "\n")
    }

    static func buildPrompt(
        essay: String,
        track: PreProfessionalTrack,
        mode: AIAdvisorPanel.AdvisorMode,
        scope: AdvisorGuidelineScope = .full,
        profile: AIModelProfile = AIModelRuntimePolicy.defaultProfile,
        style: AnalysisStyle = .stable,
        diagnosticSummary: String? = nil
    ) -> AIAdvisorPromptPayload {
        let normalizedTrack = track.canonical
        let trackPolicy = policy(for: normalizedTrack)
        let budget = profile.promptBudget
        let styleDirective = styleDirective(for: style)

        let wrapper = """
        Role: admissions personal statement reviewer.
        Task: critique only the \(mode.rawValue.lowercased()) dimension of the draft.
        Context: \(compactContext(track: normalizedTrack, scope: scope, trackPolicy: trackPolicy, styleDirective: styleDirective, activeLens: mode.rawValue))
        Rules:
        \(reviewRules(style: style, includeStrengthRule: true))
        """

        let rubric = rubricText(for: mode)
        var rubricDetails = String(rubric.details.prefix(budget.defaultRubricDetailCharacters))
        var guidelines = String(condensedGuidelines(for: normalizedTrack, scope: scope).prefix(budget.defaultGuidelineCharacters))
        var essaySlice = String(normalizedEssay(essay).prefix(budget.maxEssayCharacters))

        let outputFormat = """
        Output Format (plain text):
        Critical Risks:
        - 2 to 5 bullets
        What Works (if any):
        - 0 to 2 bullets
        Revisions to Consider:
        - 3 to 5 bullets
        Questions for the Writer:
        - 2 to 4 bullets
        """

        let constraints = """
        Constraints:
        - Critical Risks and Questions: 12 to 30 words per bullet.
        - Revisions: \(style == .richer ? "34 to 76" : "26 to 55") words, 2 concise sentences.
        - Revisions must follow: issue -> why it matters -> practical next step.
        - Avoid repeating the same issue across bullets.
        - No intro or outro paragraph.
        """

        let fewShot = profile.fewShotExample ?? ""
        let diagnosticBlock = diagnosticSummary.map { "\nInternal Diagnostic:\n\($0)" } ?? ""

        enforceStandardBudget(
            budget: budget,
            wrapper: wrapper,
            rubricCore: rubric.core,
            outputFormat: outputFormat,
            constraints: constraints,
            fewShot: fewShot + diagnosticBlock,
            rubricDetails: &rubricDetails,
            guidelines: &guidelines,
            essay: &essaySlice
        )

        let systemPrompt = """
        \(wrapper)

        Rubric Core:
        \(rubric.core)

        Rubric Details:
        \(rubricDetails)

        Domain Guidelines:
        \(guidelines)
        \(diagnosticBlock)
        \(fewShot.isEmpty ? "" : "\n\nFew-Shot Example:\n\(fewShot)")

        \(outputFormat)

        \(constraints)
        """

        let userPrompt = """
        Review the following draft and return feedback in the required format.

        Draft:
        \(essaySlice)
        """

        print(
            "AI Advisor prompt chars system=\(systemPrompt.count), user=\(userPrompt.count), " +
            "essay=\(essaySlice.count), guidelines=\(guidelines.count), rubricDetails=\(rubricDetails.count), " +
            "mode=\(mode.rawValue), scope=\(scope.rawValue), track=\(normalizedTrack.rawValue), profile=\(profile.displayName)"
        )

        return AIAdvisorPromptPayload(systemPrompt: systemPrompt, userPrompt: userPrompt)
    }

    private static func rubricText(for mode: AIAdvisorPanel.AdvisorMode) -> RubricPack {
        switch mode {
        case .clarity:
            return RubricPack(
                core: "Clarity and readability only: sentence logic, local flow, and ambiguity reduction.",
                details: "Prioritize edits that improve first-read comprehension for a busy admissions reader. Flag vague references, overloaded clauses, pronoun ambiguity, and abrupt transitions that force re-reading. Reward concrete verbs, precise subjects, and sentence progression that makes cause-and-effect easy to follow. Focus on clarity gains that preserve the applicant's voice rather than stylistic over-polishing."
            )
        case .insights:
            return RubricPack(
                core: "Insights and motivation only: depth of reflection, self-awareness, and vocational maturity.",
                details: "Evaluate whether the writer demonstrates real insight into what they observed, how their understanding changed, and why those observations shaped motivation for this profession. Reward specific moments where the writer interprets experience into values, limitations, and growth. Flag superficial takeaways, generic inspiration language, borrowed mission statements, and claims of readiness that are not grounded in concrete evidence. Prioritize guidance that increases reflective maturity and shows the writer can learn from complexity, not just describe events."
            )
        case .tone:
            return RubricPack(
                core: "Professional and personal tone only: authenticity, humility, and maturity.",
                details: "Prefer grounded, reflective tone over performative or exaggerated language. Flag arrogance, defensiveness, melodrama, savior framing, and emotionally manipulative phrasing that reduces trust. Reward confident claims only when anchored to lived evidence and measured self-assessment. Emphasize mature professionalism: accountable voice, service orientation, and respect for team-based care."
            )
        case .structure:
            return RubricPack(
                core: "Structure only: opening hook quality, body progression, and conclusion cohesion.",
                details: "Evaluate whether paragraph order builds momentum from motivation to evidence to readiness. Flag resume-style sequencing with weak reflection, repetitive middle paragraphs, and conclusions that merely restate earlier claims. Recommend reorganizations that improve narrative arc, reduce redundancy, and make transitions explicit between key experiences. Prefer structural changes that increase coherence without expanding length."
            )
        case .revision:
            return RubricPack(
                core: "Revision follow-up only: compare prior feedback against current draft changes.",
                details: "Compare prior recommendations against concrete changes in the current draft. Classify each major issue as addressed, partially addressed, or unresolved, then prioritize unresolved items that still affect admissions readiness. Identify any regressions or new weaknesses introduced by revisions. Keep follow-up guidance specific, concise, and linked to observable draft evidence."
            )
        }
    }

    static func buildRevisionPrompt(
        essay: String,
        track: PreProfessionalTrack,
        priorFeedback: String,
        priorModeLabel: String?,
        scope: AdvisorGuidelineScope = .full,
        profile: AIModelProfile = AIModelRuntimePolicy.defaultProfile,
        style: AnalysisStyle = .stable
    ) -> AIAdvisorPromptPayload {
        let normalizedTrack = track.canonical
        let trackPolicy = policy(for: normalizedTrack)
        let rubric = rubricText(for: .revision)
        let budget = profile.promptBudget
        let styleDirective = styleDirective(for: style)

        let wrapper = """
        Role: admissions personal statement reviewer.
        Task: revision follow-up only.
        Context: \(compactContext(track: normalizedTrack, scope: scope, trackPolicy: trackPolicy, styleDirective: styleDirective, activeLens: "Revision Follow-up"))
        Rules:
        \(revisionRules(style: style))
        """

        var rubricDetails = String(rubric.details.prefix(budget.defaultRubricDetailCharacters))
        var guidelines = String(condensedGuidelines(for: normalizedTrack, scope: scope).prefix(budget.defaultGuidelineCharacters))
        var priorFeedbackSlice = String(condensedPriorFeedback(priorFeedback).prefix(budget.defaultPriorFeedbackCharacters))
        var essaySlice = String(normalizedEssay(essay).prefix(budget.maxEssayCharacters))
        let previousMode = (priorModeLabel?.isEmpty == false ? priorModeLabel! : "General")

        let outputFormat = """
        Output Format (plain text):
        Addressed:
        - 2 to 4 bullets
        Still Needs Work:
        - 3 to 5 bullets
        New Issues:
        - 0 to 3 bullets
        Questions for the Writer:
        - 2 to 3 bullets
        """

        let constraints = """
        Constraints:
        - Each bullet \(style == .richer ? "16 to 34" : "12 to 28") words.
        - Avoid repeating the same issue across sections.
        - No intro or outro paragraph.
        """

        enforceRevisionBudget(
            budget: budget,
            wrapper: wrapper,
            rubricCore: rubric.core,
            outputFormat: outputFormat,
            constraints: constraints,
            priorModeLabel: previousMode,
            priorFeedback: &priorFeedbackSlice,
            guidelines: &guidelines,
            rubricDetails: &rubricDetails,
            essay: &essaySlice
        )

        let systemPrompt = """
        \(wrapper)

        Rubric Core:
        \(rubric.core)

        Rubric Details:
        \(rubricDetails)

        Prior Feedback Focus:
        \(previousMode)

        Domain Guidelines:
        \(guidelines)

        \(outputFormat)

        \(constraints)
        """

        let userPrompt = """
        Prior Feedback (Round 1):
        \(priorFeedbackSlice)

        Current Draft:
        \(essaySlice)

        Compare this draft against the prior feedback and return the required sections.
        """

        print(
            "AI Advisor revision prompt chars system=\(systemPrompt.count), user=\(userPrompt.count), " +
            "essay=\(essaySlice.count), priorFeedback=\(priorFeedbackSlice.count), " +
            "guidelines=\(guidelines.count), scope=\(scope.rawValue), track=\(normalizedTrack.rawValue), profile=\(profile.displayName)"
        )

        return AIAdvisorPromptPayload(systemPrompt: systemPrompt, userPrompt: userPrompt)
    }

    static func buildFollowUpPrompt(
        essay: String,
        track: PreProfessionalTrack,
        mode: AIAdvisorPanel.AdvisorMode,
        priorFeedback: String,
        followUpQuestion: String,
        scope: AdvisorGuidelineScope = .full,
        profile: AIModelProfile = AIModelRuntimePolicy.defaultProfile,
        style: AnalysisStyle = .stable
    ) -> AIAdvisorPromptPayload {
        let normalizedTrack = track.canonical
        let trackPolicy = policy(for: normalizedTrack)
        let budget = profile.promptBudget
        let styleDirective = styleDirective(for: style)

        var guidelines = String(condensedGuidelines(for: normalizedTrack, scope: scope).prefix(budget.defaultGuidelineCharacters))
        var priorFeedbackSlice = String(condensedPriorFeedback(priorFeedback).prefix(budget.defaultPriorFeedbackCharacters))
        var essaySlice = String(normalizedEssay(essay).prefix(budget.maxEssayCharacters))
        var questionSlice = String(normalizedEssay(followUpQuestion).prefix(500))

        let wrapper = """
        Role: admissions personal statement reviewer.
        Task: answer one follow-up question about prior feedback.
        Context: \(compactContext(track: normalizedTrack, scope: scope, trackPolicy: trackPolicy, styleDirective: styleDirective, activeLens: mode.rawValue))
        Rules:
        \(followUpRules())
        """

        let outputFormat = """
        Output Format (plain text):
        Direct Answer:
        - 2 to 4 bullets
        Evidence Check:
        - 1 to 3 bullets
        Next Step:
        - 1 to 2 bullets
        """

        let constraints = """
        Constraints:
        - Direct Answer bullets: 16 to 36 words.
        - Evidence Check / Next Step bullets: 10 to 26 words.
        - Do not repeat the original critique's full sections or headings.
        - No intro or outro paragraph.
        """

        let fixedCount = wrapper.count + outputFormat.count + constraints.count + 180
        var overflow = fixedCount + guidelines.count + priorFeedbackSlice.count + essaySlice.count + questionSlice.count - budget.maxPromptCharactersRevision
        if overflow > 0 {
            trimSegment(&priorFeedbackSlice, overflow: &overflow, minimum: budget.minimumPriorFeedbackCharacters)
            trimSegment(&guidelines, overflow: &overflow, minimum: budget.minimumGuidelineCharacters)
            trimSegment(&essaySlice, overflow: &overflow, minimum: budget.minimumEssayCharacters)
            trimSegment(&questionSlice, overflow: &overflow, minimum: 120)
        }

        let systemPrompt = """
        \(wrapper)

        Domain Guidelines:
        \(guidelines)

        \(outputFormat)

        \(constraints)
        """

        let userPrompt = """
        User Follow-up Question:
        \(questionSlice)

        Prior Feedback:
        \(priorFeedbackSlice)

        Current Draft:
        \(essaySlice)

        Answer the question directly without restating the full prior critique.
        """

        print(
            "AI Advisor follow-up prompt chars system=\(systemPrompt.count), user=\(userPrompt.count), " +
            "essay=\(essaySlice.count), priorFeedback=\(priorFeedbackSlice.count), mode=\(mode.rawValue), " +
            "scope=\(scope.rawValue), track=\(normalizedTrack.rawValue), profile=\(profile.displayName)"
        )

        return AIAdvisorPromptPayload(systemPrompt: systemPrompt, userPrompt: userPrompt)
    }

    static func buildDiagnosticPrompt(
        essay: String,
        track: PreProfessionalTrack,
        mode: AIAdvisorPanel.AdvisorMode,
        scope: AdvisorGuidelineScope = .full,
        profile: AIModelProfile = AIModelRuntimePolicy.defaultProfile
    ) -> AIAdvisorPromptPayload {
        let normalizedTrack = track.canonical
        let trackPolicy = policy(for: normalizedTrack)
        let rubric = rubricText(for: mode)
        let budget = profile.promptBudget

        var rubricDetails = String(rubric.details.prefix(max(220, budget.minimumRubricDetailCharacters)))
        var guidelines = String(condensedGuidelines(for: normalizedTrack, scope: scope).prefix(max(500, budget.minimumGuidelineCharacters)))
        var essaySlice = String(normalizedEssay(essay).prefix(min(3200, budget.maxEssayCharacters)))

        let wrapper = """
        Role: admissions personal statement reviewer.
        Task: produce a short hidden diagnostic for a second-pass critique.
        Context: \(compactContext(track: normalizedTrack, scope: scope, trackPolicy: trackPolicy, styleDirective: "internal planning", activeLens: mode.rawValue))
        Rules:
        - Return only the three labeled lines below.
        - No rewrites, replacement lines, or copy-ready phrasing.
        - No prompt/model/system talk or hidden reasoning tags.
        - Use draft evidence when possible; otherwise state what is missing.
        """

        let outputFormat = """
        Output Format (plain text):
        Primary issue: 1 short sentence
        Evidence gap: 1 short sentence
        Most important next move: 1 short sentence
        """

        let constraints = """
        Constraints:
        - Each line 8 to 18 words.
        - No bullets, quotes, or extra commentary.
        """

        let fixedCount = wrapper.count + rubric.core.count + outputFormat.count + constraints.count + 120
        var overflow = fixedCount + rubricDetails.count + guidelines.count + essaySlice.count - 5200
        if overflow > 0 {
            trimSegment(&guidelines, overflow: &overflow, minimum: 320)
            trimSegment(&rubricDetails, overflow: &overflow, minimum: 180)
            trimSegment(&essaySlice, overflow: &overflow, minimum: 1000)
        }

        let systemPrompt = """
        \(wrapper)

        Rubric:
        \(rubric.core)
        \(rubricDetails)

        Guidelines:
        \(guidelines)

        \(outputFormat)

        \(constraints)
        """

        let userPrompt = """
        Draft:
        \(essaySlice)
        """

        return AIAdvisorPromptPayload(systemPrompt: systemPrompt, userPrompt: userPrompt)
    }

    static func buildGuardrailRepairPrompt(
        mode: AIAdvisorPanel.AdvisorMode,
        invalidFeedback: String,
        violations: [String],
        style: AnalysisStyle = .stable
    ) -> AIAdvisorPromptPayload {
        let isRevisionMode = mode == .revision
        let outputFormat: String = isRevisionMode
            ? """
            Output Format (plain text):
            Addressed:
            - 2 to 4 bullets
            Still Needs Work:
            - 3 to 5 bullets
            New Issues:
            - 0 to 3 bullets
            Questions for the Writer:
            - 2 to 3 bullets
            """
            : """
            Output Format (plain text):
            Critical Risks:
            - 2 to 5 bullets
            What Works (if any):
            - 0 to 2 bullets
            Revisions to Consider:
            - 3 to 5 bullets
            Questions for the Writer:
            - 2 to 4 bullets
            """

        let styleConstraint = style == .richer
            ? "Prefer fuller revision rationale while keeping section structure strict."
            : "Prefer concise deterministic bullets."
        let whatWorksConstraint = isRevisionMode
            ? ""
            : "- If What Works lacks quoted evidence, write exactly: \"No reliable strengths yet.\""

        let systemPrompt = """
        Role: compliance editor for admissions feedback.
        Task: repair the candidate feedback so it obeys the schema and guardrails.
        Rules:
        - Keep the critique intent, but remove non-compliant lines.
        - Keep plain-text section headings and bullet layout.
        - No rewrites, copy-ready lines, unsupported praise, or meta/system/model talk.

        \(outputFormat)

        Constraints:
        - Keep section headings exactly as shown.
        - Bullets must start with "- ".
        - Remove any meta-commentary.
        - If evidence is missing, state what evidence is missing.
        \(whatWorksConstraint)
        - \(styleConstraint)
        """

        let violationSummary = violations.isEmpty
            ? "- schema/guardrail mismatch detected"
            : violations.map { "- \($0)" }.joined(separator: "\n")
        let feedbackSlice = String(condensedPriorFeedback(invalidFeedback).prefix(3200))

        let userPrompt = """
        Violations detected:
        \(violationSummary)

        Candidate Feedback To Repair:
        \(feedbackSlice)
        """

        return AIAdvisorPromptPayload(systemPrompt: systemPrompt, userPrompt: userPrompt)
    }

    private static func policy(for track: PreProfessionalTrack) -> AdvisorTrackPolicy {
        switch track {
        case .preMedicine:
            return AdvisorTrackPolicy(
                portalName: "AMCAS",
                maxCharacters: 5300,
                trackFocus: "Readiness for patient-centered medicine, reflective growth, and professional humility"
            )
        case .preDentistry:
            return AdvisorTrackPolicy(
                portalName: "ADEA AADSAS",
                maxCharacters: 4500,
                trackFocus: "Readiness for patient care, manual/procedural commitment, and service orientation"
            )
        case .prePhysicianAssistant:
            return AdvisorTrackPolicy(
                portalName: "CASPA",
                maxCharacters: 5000,
                trackFocus: "Readiness for team-based care, clinical judgment, and responsibility under supervision"
            )
        case .prePharmacy:
            return AdvisorTrackPolicy(
                portalName: "PharmCAS",
                maxCharacters: 4500,
                trackFocus: "Readiness for medication stewardship, counseling clarity, and safety-oriented decision making"
            )
        case .preOccupationalTherapy:
            return AdvisorTrackPolicy(
                portalName: "OTCAS",
                maxCharacters: 7500,
                trackFocus: "Readiness for functional, client-centered care and interdisciplinary collaboration"
            )
        case .prePhysicalTherapy:
            return AdvisorTrackPolicy(
                portalName: "PTCAS",
                maxCharacters: 4500,
                trackFocus: "Readiness for movement-focused care, communication, and ethical professionalism"
            )
        case .preLaw:
            return AdvisorTrackPolicy(
                portalName: "LSAC",
                maxCharacters: 5000,
                trackFocus: "Readiness for rigorous analysis, ethical judgment, and service-oriented advocacy"
            )
        case .preVeterinaryMedicine:
            return AdvisorTrackPolicy(
                portalName: "VMCAS",
                maxCharacters: 5000,
                trackFocus: "Readiness for animal care, client communication, and scientific responsibility"
            )
        case .preOptometry:
            return AdvisorTrackPolicy(
                portalName: "OptomCAS",
                maxCharacters: 4500,
                trackFocus: "Readiness for patient communication, visual health care, and professionalism"
            )
        case .medicalOrDentalResidency:
            return AdvisorTrackPolicy(
                portalName: "Residency Application",
                maxCharacters: 5300,
                trackFocus: "Readiness for specialty training, service, and professional formation"
            )
        case .general, .other:
            return AdvisorTrackPolicy(
                portalName: "Application Portal",
                maxCharacters: 5000,
                trackFocus: "Clear motivation, reflective depth, and ethical maturity"
            )
        }
    }

    private static func condensedGuidelines(for track: PreProfessionalTrack, scope: AdvisorGuidelineScope) -> String {
        let raw = PromptResourceLoader.loadGuidelines(for: track, scope: scope)
        return raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedEssay(_ essay: String) -> String {
        essay
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func condensedPriorFeedback(_ feedback: String) -> String {
        normalizedEssay(feedback)
            .replacingOccurrences(of: "Strengths:", with: "")
            .replacingOccurrences(of: "Critical Risks:", with: "")
            .replacingOccurrences(of: "What Works (if any):", with: "")
            .replacingOccurrences(of: "Revision Priorities:", with: "")
            .replacingOccurrences(of: "Revisions to Consider:", with: "")
            .replacingOccurrences(of: "Questions for the Writer:", with: "")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func enforceStandardBudget(
        budget: AIModelProfile.PromptBudget,
        wrapper: String,
        rubricCore: String,
        outputFormat: String,
        constraints: String,
        fewShot: String,
        rubricDetails: inout String,
        guidelines: inout String,
        essay: inout String
    ) {
        let fixedCount = wrapper.count + rubricCore.count + outputFormat.count + constraints.count + 120
        var overflow = fixedCount + rubricDetails.count + guidelines.count + essay.count + fewShot.count - budget.maxPromptCharactersStandard
        guard overflow > 0 else { return }

        trimSegment(&rubricDetails, overflow: &overflow, minimum: budget.minimumRubricDetailCharacters)
        trimSegment(&guidelines, overflow: &overflow, minimum: budget.minimumGuidelineCharacters)
        trimSegment(&essay, overflow: &overflow, minimum: budget.minimumEssayCharacters)

        if overflow > 0 {
            trimSegment(&essay, overflow: &overflow, minimum: 1200)
        }
    }

    private static func enforceRevisionBudget(
        budget: AIModelProfile.PromptBudget,
        wrapper: String,
        rubricCore: String,
        outputFormat: String,
        constraints: String,
        priorModeLabel: String,
        priorFeedback: inout String,
        guidelines: inout String,
        rubricDetails: inout String,
        essay: inout String
    ) {
        let fixedCount = wrapper.count + rubricCore.count + outputFormat.count + constraints.count + priorModeLabel.count + 140
        var overflow = fixedCount + priorFeedback.count + guidelines.count + rubricDetails.count + essay.count - budget.maxPromptCharactersRevision
        guard overflow > 0 else { return }

        trimSegment(&priorFeedback, overflow: &overflow, minimum: budget.minimumPriorFeedbackCharacters)
        trimSegment(&guidelines, overflow: &overflow, minimum: budget.minimumGuidelineCharacters)
        trimSegment(&rubricDetails, overflow: &overflow, minimum: budget.minimumRubricDetailCharacters)
        trimSegment(&essay, overflow: &overflow, minimum: budget.minimumEssayCharacters)

        if overflow > 0 {
            trimSegment(&essay, overflow: &overflow, minimum: 1200)
        }
    }

    private static func trimSegment(_ text: inout String, overflow: inout Int, minimum: Int) {
        guard overflow > 0 else { return }
        let floor = max(0, minimum)
        let available = max(0, text.count - floor)
        guard available > 0 else { return }

        let trimCount = min(available, overflow)
        let keepCount = max(0, text.count - trimCount)
        text = String(text.prefix(keepCount))
        overflow -= trimCount
    }

    private static func styleDirective(for style: AnalysisStyle) -> String {
        switch style {
        case .stable:
            return "concise and deterministic; prioritize consistency"
        case .richer:
            return "slightly deeper interpretation; prioritize actionable nuance"
        }
    }
}
