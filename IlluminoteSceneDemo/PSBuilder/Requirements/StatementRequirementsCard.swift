import SwiftUI

struct StatementRequirementsCard: View {
    @Environment(AppSettings.self) private var settings
    let requirements: [StatementRequirement]
    @State private var isExpanded: Bool = false

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }
    
    var body: some View {
        Group {
            if useImmersive {
                cardBody
                    .padding()
                    .sacredCardStyle(highlighted: isExpanded)
            } else {
                cardBody
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .background(useImmersive ? DSColor.divider : Color(uiColor: .separator))
                    
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
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(useImmersive ? DSColor.goldLight : Color.accentColor)
                    Text("Statement Requirements")
                        .font(DSFont.heading2)
                        .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                    Spacer()
                    if !isExpanded && !requirements.isEmpty {
                        Text("\(requirements.count) Services")
                            .font(DSFont.caption)
                            .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(useImmersive ? DSColor.surfaceElevated : Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(useImmersive ? DSColor.goldLight.opacity(0.65) : Color.clear, lineWidth: 1)
                            )
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
                Text(req.serviceCode.displayName)
                    .font(DSFont.subtext)
                    .fontWeight(.semibold)
                    .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                
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
