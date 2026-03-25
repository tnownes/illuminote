import Foundation

enum AdvisorGuidelineScope: String, CaseIterable, Identifiable {
    case full
    case opening
    case body
    case closing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .full: return "Full Draft"
        case .opening: return "Opening Paragraph"
        case .body: return "Body Paragraphs"
        case .closing: return "Closing Paragraph"
        }
    }
}

struct PromptResourceLoader {
    /// Loads the markdown guidelines for a specific pre-professional track.
    /// Falls back to `General_Guidelines.md` if a track-specific file is not found.
    static func loadGuidelines(for track: PreProfessionalTrack, scope: AdvisorGuidelineScope = .full) -> String {
        for filename in candidateFilenames(for: track.canonical, scope: scope) {
            if let specificContent = loadFile(named: filename) {
                return specificContent
            }
        }

        // If scoped files do not exist, derive a scoped excerpt from the canonical full guideline.
        if scope != .full {
            if let fullContent = loadPrimaryTrackGuideline(for: track.canonical),
               let excerpt = scopedExcerpt(from: fullContent, scope: scope) {
                return excerpt
            }

            return fallbackGeneralGuidelines(for: scope)
        }

        return fallbackGeneralGuidelines(for: .full)
    }

    private static func candidateFilenames(for track: PreProfessionalTrack, scope: AdvisorGuidelineScope) -> [String] {
        let scopePrefix: String
        switch scope {
        case .full: scopePrefix = ""
        case .opening: scopePrefix = "opening_"
        case .body: scopePrefix = "body_"
        case .closing: scopePrefix = "closing_"
        }

        switch track {
        case .preMedicine:
            if scope == .full {
                return ["preMedicine_Guidelines", "Medical_Guidelines"]
            }
            return ["\(scopePrefix)preMedicine_Guidelines", "\(scopePrefix)Medical_Guidelines"]
        case .preDentistry:
            if scope == .full {
                return ["preDentistry_Guidelines", "dental_guidelines"]
            }
            return ["\(scopePrefix)preDentistry_Guidelines", "\(scopePrefix)dental_guidelines"]
        case .general, .other:
            return scope == .full ? ["General_Guidelines"] : ["\(scopePrefix)General_Guidelines"]
        default:
            return scope == .full
                ? ["\(track.rawValue)_Guidelines"]
                : ["\(scopePrefix)\(track.rawValue)_Guidelines"]
        }
    }

    private static func loadPrimaryTrackGuideline(for track: PreProfessionalTrack) -> String? {
        for filename in candidateFilenames(for: track, scope: .full) {
            if let content = loadFile(named: filename) {
                return content
            }
        }
        return loadFile(named: "General_Guidelines")
    }

    private static func scopedExcerpt(from text: String, scope: AdvisorGuidelineScope) -> String? {
        let sectionTitle: String
        switch scope {
        case .opening:
            sectionTitle = "**Opening Paragraph**"
        case .body:
            sectionTitle = "**Body Paragraphs**"
        case .closing:
            sectionTitle = "**Closing Paragraph**"
        case .full:
            return text
        }

        guard let range = text.range(of: sectionTitle) else { return nil }
        let suffix = text[range.lowerBound...]
        guard let nextSectionRange = suffix.dropFirst(sectionTitle.count).range(of: "\n**", options: .literal) else {
            return String(suffix).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let end = nextSectionRange.lowerBound
        return String(suffix[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fallbackGeneralGuidelines(for scope: AdvisorGuidelineScope) -> String {
        if scope == .full, let generalContent = loadFile(named: "General_Guidelines") {
            return generalContent
        }

        switch scope {
        case .opening:
            return """
            **Opening Paragraph**
            * Establish a specific, credible hook tied to lived experience.
            * Avoid generic motivation statements unless immediately grounded in concrete detail.
            * Set a clear narrative direction that the rest of the draft actually develops.
            """
        case .body:
            return """
            **Body Paragraphs**
            * Prioritize reflection over activity listing.
            * Use concrete evidence to connect experiences to growth, values, and readiness.
            * Keep progression coherent: each paragraph should add distinct value to the core narrative.
            """
        case .closing:
            return """
            **Closing Paragraph**
            * Synthesize key insights rather than repeating earlier claims.
            * Signal professional readiness with grounded confidence and specificity.
            * Avoid grandiose language or abstract mission statements without evidence.
            """
        case .full:
            return "You are an admissions advisor. Provide clear, objective feedback on this personal statement."
        }
    }

    private static func loadFile(named filename: String) -> String? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "md"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return contents
    }
}
