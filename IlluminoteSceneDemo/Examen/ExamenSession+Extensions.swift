
import Foundation

extension ExamenSession {
    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var resolvedPrimaryDetail: String? {
        if let role = nonEmpty(roleTitle) {
            return role
        }
        if let mentor = nonEmpty(mentorOrSupervisor) {
            return mentor
        }
        return nonEmpty(physician)
    }

    var resolvedSecondaryDetail: String? {
        if let organization = nonEmpty(organizationName) {
            return organization
        }
        return nonEmpty(facility)
    }

    var resolvedFocusDetail: String? {
        if let focus = nonEmpty(focusArea) {
            return focus
        }
        return nonEmpty(specialty)
    }

    /// One-time additive migration to hydrate normalized metadata fields from legacy fields.
    /// Safe to run repeatedly; it only fills empty normalized fields.
    @discardableResult
    func applyNormalizedMetadataBackfillIfNeeded() -> Bool {
        let type = (experienceType ?? .other).canonical
        let config = type.detailFieldConfig
        var didChange = false

        if config.showsPrimary, let legacyPrimary = nonEmpty(physician) {
            switch type {
            case .leadership, .service, .work:
                if nonEmpty(roleTitle) == nil {
                    roleTitle = legacyPrimary
                    didChange = true
                }
            case .shadowing, .clinical, .research:
                if nonEmpty(mentorOrSupervisor) == nil {
                    mentorOrSupervisor = legacyPrimary
                    didChange = true
                }
            case .other, .volunteer, .discernment:
                break
            }
        }

        if config.showsFacility, let legacySecondary = nonEmpty(facility), nonEmpty(organizationName) == nil {
            organizationName = legacySecondary
            didChange = true
        }

        if config.showsFocus, let legacyFocus = nonEmpty(specialty), nonEmpty(focusArea) == nil {
            focusArea = legacyFocus
            didChange = true
        }

        return didChange
    }

    func detailMetadataLines() -> [String] {
        let config = (experienceType ?? .other).detailFieldConfig
        var lines: [String] = []
        if let primary = resolvedPrimaryDetail, config.showsPrimary {
            lines.append("\(config.primaryLabel): \(primary)")
        }
        if let facility = resolvedSecondaryDetail, config.showsFacility {
            lines.append("\(config.facilityLabel): \(facility)")
        }
        if let location = nonEmpty(location), config.showsLocation {
            lines.append("Location: \(location)")
        }
        if let focus = resolvedFocusDetail, config.showsFocus {
            lines.append("\(config.focusLabel): \(focus)")
        }
        return lines
    }

    func normalizedResponseTexts() -> [String] {
        let ordered = responses
            .sorted { $0.stepIndex < $1.stepIndex }
            .map(\.answerText)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return ordered.reduce(into: []) { result, answer in
            if result.last != answer {
                result.append(answer)
            }
        }
    }

    /// Builds a single, merged text block representing all relevant journal content.
    func mergedDraftContent() -> String {
        // 1) Step responses (sorted by step index)
        let responsesText = normalizedResponseTexts()
            .joined(separator: "\n\n")
            
        // 2) Experience detail groups
        let experienceDetails = detailMetadataLines()
        
        let detailsText = experienceDetails.joined(separator: "\n")
        
        // 3) Additional notes (if any)
        // Note: We use the session-level notes if present.
        // If step-level additional notes are needed, they should be appended to responsesText or handled here.
        // User requested: "Free-text notes (including additional notes)" and code uses `self.notes`.
        let additionalNotes = self.notes ?? ""
        
        // Combine everything
        let components = [
            responsesText,
            detailsText,
            personalStatement,
            additionalNotes
        ].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        return components.joined(separator: "\n\n")
    }

    /// Flattened entry text used for search/theme extraction.
    func themeAnalysisText() -> String {
        let responseText = normalizedResponseTexts()
            .joined(separator: "\n")

        let metadata = [
            resolvedPrimaryDetail,
            resolvedSecondaryDetail,
            resolvedFocusDetail,
            location,
            notes
        ]
        .compactMap { $0 }
        .joined(separator: "\n")

        let tagsText = tags.joined(separator: " ")

        return [
            responseText,
            personalStatement,
            metadata,
            tagsText
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n\n")
    }
}
