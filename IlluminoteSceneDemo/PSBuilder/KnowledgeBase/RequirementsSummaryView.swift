import SwiftUI
import SwiftData

struct RequirementsSummaryView: View {
    @Environment(AppSettings.self) private var settings
    let fieldName: String
    @State private var isExpanded: Bool = false
    
    // In a real app, this would query specifically for the field.
    // Since we don't have a direct link yet, we'll Query all and filter in memory or lookup.
    @Query private var fields: [StatementField]
    
    private var targetField: StatementField? {
        fields.first { $0.name.localizedCaseInsensitiveContains(fieldName) } ?? fields.first
    }

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }
    
    var body: some View {
        Group {
            if useImmersive {
                content
                    .padding()
                    .sacredCardStyle(highlighted: isExpanded)
            } else {
                content
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let field = targetField {
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 16) {
                        Divider()
                            .background(useImmersive ? DSColor.divider : Color(uiColor: .separator))
                        
                        ForEach(Array(field.services).sorted(by: { $0.name < $1.name }), id: \.id) { service in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(service.name)
                                    .font(DSFont.heading2)
                                    .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                                
                                ForEach(Array(service.cyclePrompts).sorted(by: { $0.cycle > $1.cycle }), id: \.id) { prompt in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(prompt.cycle)
                                                .font(DSFont.caption)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(useImmersive ? DSColor.surfaceElevated : Color(uiColor: .tertiarySystemFill))
                                                .clipShape(Capsule())
                                            
                                            Spacer()
                                            
                                            Text("\(prompt.characterLimit) chars")
                                                .font(DSFont.caption)
                                                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                                        }
                                        
                                        Text(prompt.promptText)
                                            .font(DSFont.body)
                                            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                                            .padding(.top, 4)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    .padding(.top, 8)
                    
                } label: {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(useImmersive ? DSColor.goldLight : .yellow)
                        Text(field.name + " Requirements")
                            .font(DSFont.heading2)
                            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                        Spacer()
                    }
                }
                .tint(useImmersive ? DSColor.textPrimary : Color.primary)
            } else {
                Text("No specific requirements loaded.")
                    .font(DSFont.caption)
                    .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
            }
        }
    }
}

#Preview {
    RequirementsSummaryView(fieldName: "Medicine")
        .modelContainer(DataStoreHelper.makeModelContainer())
}
