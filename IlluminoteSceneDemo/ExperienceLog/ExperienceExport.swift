import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ApplicationExperienceCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var csvText: String

    init(csvText: String) {
        self.csvText = csvText
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.csvText = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(csvText.utf8))
    }
}

extension ApplicationExperience {
    var dateRangeSummary: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let ranges = periods.sorted { $0.startDate < $1.startDate }.map { period in
            let start = formatter.string(from: period.startDate)
            let end: String
            if period.isPlanned {
                end = period.endDate.map { formatter.string(from: $0) } ?? "Planned"
            } else if period.isOngoing {
                end = "Present"
            } else {
                end = period.endDate.map { formatter.string(from: $0) } ?? formatter.string(from: period.startDate)
            }
            return "\(start) - \(end)"
        }
        return ranges.isEmpty ? "No date ranges added" : ranges.joined(separator: "; ")
    }

    var plainTextSummary: String {
        var lines: [String] = []
        lines.append("Experience Title: \(exportTitle)")
        lines.append("Category: \(category.displayName)")
        if let organizationName, !organizationName.isEmpty {
            lines.append("Organization/Site: \(organizationName)")
        }
        if let roleTitle, !roleTitle.isEmpty {
            lines.append("Role/Title: \(roleTitle)")
        }
        if let location, !location.isEmpty {
            lines.append("Location: \(location)")
        }
        lines.append("Date Ranges: \(dateRangeSummary)")
        lines.append("Completed Hours: \(totalCompletedHours.formattedHours)")
        if totalPlannedHours > 0 {
            lines.append("Planned Hours: \(totalPlannedHours.formattedHours)")
        }
        lines.append("Linked Note Hours Logged in Illuminote: \(totalLoggedSessionHours.formattedHours)")
        if let contactName, !contactName.isEmpty {
            lines.append("Contact: \(contactName)")
        }
        if let contactTitle, !contactTitle.isEmpty {
            lines.append("Contact Title: \(contactTitle)")
        }
        if let contactEmail, !contactEmail.isEmpty {
            lines.append("Contact Email: \(contactEmail)")
        }
        if let contactPhone, !contactPhone.isEmpty {
            lines.append("Contact Phone: \(contactPhone)")
        }
        if let contactPermissionAuthorized {
            lines.append("Permission to Contact: \(contactPermissionAuthorized ? "Yes" : "No")")
        }
        if !applicationDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("")
            lines.append("Application Description")
            lines.append(applicationDescription.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if !relevantTagSummary.isEmpty {
            lines.append("")
            lines.append("Themes from Linked Notes: \(relevantTagSummary.joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    func copyReadyBreakdown(for requirements: [ExperienceEntryRequirement]) -> String {
        var blocks: [String] = [plainTextSummary]

        for requirement in requirements {
            var lines: [String] = []
            lines.append(requirement.serviceCode.displayName)
            if let limit = requirement.descriptionCharacterLimit {
                lines.append("Recommended description limit: \(limit) characters")
            }
            if let maxHighlights = requirement.maxHighlights,
               let highlightLabel = requirement.highlightLabel {
                lines.append("Highlight guidance: up to \(maxHighlights) \(highlightLabel.lowercased())")
            }
            requirement.guidanceNotes.forEach { lines.append("- \($0)") }
            blocks.append(lines.joined(separator: "\n"))
        }

        return blocks.joined(separator: "\n\n")
    }

    static func csvExport(for experiences: [ApplicationExperience]) -> String {
        let header = [
            "Title",
            "Category",
            "Organization",
            "Role",
            "Location",
            "Completed Hours",
            "Planned Hours",
            "Logged Note Hours",
            "Date Ranges",
            "Contact Name",
            "Contact Email",
            "Contact Phone",
            "Permission To Contact",
            "Description",
            "Linked Note Tags"
        ]

        let rows = experiences.sorted { $0.dateModified > $1.dateModified }.map { experience in
            [
                experience.exportTitle,
                experience.category.displayName,
                experience.organizationName ?? "",
                experience.roleTitle ?? "",
                experience.location ?? "",
                experience.totalCompletedHours.formattedHours,
                experience.totalPlannedHours.formattedHours,
                experience.totalLoggedSessionHours.formattedHours,
                experience.dateRangeSummary,
                experience.contactName ?? "",
                experience.contactEmail ?? "",
                experience.contactPhone ?? "",
                experience.contactPermissionAuthorized.map { $0 ? "Yes" : "No" } ?? "",
                experience.applicationDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                experience.relevantTagSummary.joined(separator: "; ")
            ]
        }

        return ([header] + rows)
            .map { row in
                row.map(csvEscape).joined(separator: ",")
            }
            .joined(separator: "\n")
    }
}

private func csvEscape(_ value: String) -> String {
    if value.contains(",") || value.contains("\n") || value.contains("\"") {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    return value
}

private extension Double {
    var formattedHours: String {
        if self == 0 { return "0" }
        return String(format: "%.1f", self)
    }
}
