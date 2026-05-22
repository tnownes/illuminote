import SwiftUI

struct StatementRequirementsCard: View {
    @Environment(AppSettings.self) private var settings
    let requirements: [StatementRequirement]
    var compact: Bool = false
    @State private var isExpanded: Bool = false

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }

    private var requirementCountText: String {
        "\(requirements.count) prompt\(requirements.count == 1 ? "" : "s")"
    }

    private var tightestCharacterLimit: Int? {
        requirements.map(\.characterLimitMax).min()
    }
    
    var body: some View {
        cardBody
            .padding(compact ? DSSpacing.md : DSSpacing.lg)
            .appSurfaceStyle(role: isExpanded ? .reading : .quiet, highlighted: isExpanded && useImmersive)
    }

    @ViewBuilder
    private var cardBody: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .background(useImmersive ? DSColor.divider : Color(uiColor: .separator))

                    if !requirements.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DSSpacing.sm) {
                                AppInfoChip(
                                    text: requirementCountText,
                                    icon: "number"
                                )
                                if let tightestCharacterLimit {
                                    AppInfoChip(
                                        text: "\(tightestCharacterLimit) char limit",
                                        icon: "textformat",
                                        emphasized: true
                                    )
                                }
                            }
                        }
                    }
                    
                    if requirements.isEmpty {
                        Text("No specific requirements found for your profile settings.")
                            .font(DSFont.subtext)
                            .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(requirements) { req in
                            RequirementRow(req: req, useImmersive: useImmersive)
                            if req.id != requirements.last?.id {
                                Divider()
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            } label: {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    HStack(alignment: .center, spacing: DSSpacing.sm) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundStyle(useImmersive ? DSColor.goldLight : Color.accentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Application requirements")
                                .font(DSFont.heading2)
                                .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                            if !compact {
                                Text("Keep the prompt, limits, and official notes close by without crowding the draft list.")
                                    .font(DSFont.supporting)
                                    .foregroundStyle(useImmersive ? DSColor.quietText : .secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .tint(useImmersive ? DSColor.textPrimary : Color.primary)
        }
    }
}

struct RequirementRow: View {
    let req: StatementRequirement
    let useImmersive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(req.officialTitle)
                        .font(DSFont.subtext)
                        .fontWeight(.semibold)
                        .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)

                    Text(req.serviceCode.displayName)
                        .font(DSFont.caption)
                        .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                }
                
                Spacer()
                
                Text(String(req.cycleYear) + " Cycle")
                    .font(DSFont.caption)
                    .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(useImmersive ? DSColor.surfaceElevated : Color(UIColor.tertiarySystemFill))
                    .clipShape(Capsule())
            }
            
            Text("Prompt")
                .font(DSFont.caption)
                .foregroundStyle(useImmersive ? DSColor.textTertiary : .secondary)
                .textCase(.uppercase)
            
            Text(req.promptText)
                .font(DSFont.body)
                .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 16) {
                LimitBadge(icon: "textformat", label: "\(req.characterLimitMax) chars", useImmersive: useImmersive)
                if let words = req.wordLimitMax {
                    LimitBadge(icon: "doc.text", label: "\(words) words", useImmersive: useImmersive)
                }
            }
            .padding(.top, 4)
            
            if req.formattingRules != nil || req.helpfulTip != nil || req.officialLink != nil {
                VStack(alignment: .leading, spacing: 8) {
                    if let tip = req.helpfulTip {
                        HStack(alignment: .top) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(useImmersive ? DSColor.goldLight : .orange)
                            Text(tip)
                                .font(DSFont.caption)
                                .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                        }
                    }
                    
                    if let rules = req.formattingRules {
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .yellow)
                            Text(rules)
                                .font(DSFont.caption)
                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                        }
                    }
                    
                    if let stringLink = req.officialLink, let url = URL(string: stringLink) {
                        Link(destination: url) {
                            HStack {
                                Text("Official Application Manual")
                                    .font(DSFont.caption)
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.up.right.square")
                            }
                            .foregroundStyle(useImmersive ? DSColor.goldLight : .accentColor)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(useImmersive ? DSColor.surfaceElevated : Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.top, 4)
            }
        }
    }
}

struct LimitBadge: View {
    let icon: String
    let label: String
    let useImmersive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(DSFont.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
    }
}

#Preview {
    ZStack {
        Color(UIColor.systemGroupedBackground)
            .ignoresSafeArea()
        
        StatementRequirementsCard(requirements: [
            StatementRequirement(
                id: "amcas_2026",
                serviceCode: .amcas,
                officialTitle: "Personal Comments Essay",
                cycleYear: 2026,
                effectiveStartDate: Date(),
                effectiveEndDate: Date(),
                promptText: "Use the space provided to explain why you want to go to medical school.",
                characterLimitMin: 0,
                characterLimitMax: 5300,
                wordLimitMin: nil,
                wordLimitMax: nil,
                formattingRules: nil,
                helpfulTip: nil,
                officialLink: nil
            ),
            StatementRequirement(
                id: "tmdsas_2026",
                serviceCode: .tmdsas,
                officialTitle: "Personal Statement",
                cycleYear: 2026,
                effectiveStartDate: Date(),
                effectiveEndDate: Date(),
                promptText: "Explain your motivation to seek a career in medicine. Be sure to include the value of your experiences that prepare you to be a physician.",
                characterLimitMin: 0,
                characterLimitMax: 5000,
                wordLimitMin: nil,
                wordLimitMax: nil,
                formattingRules: nil,
                helpfulTip: nil,
                officialLink: nil
            )
        ])
        .padding()
    }
}
