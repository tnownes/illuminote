import SwiftUI
import SwiftData

struct ToolsVerificationSheet: View {
    @Environment(AppSettings.self) private var settings
    @Query private var fields: [StatementField]
    @State private var selectedField: StatementField?
    @State private var showingBestPractices = false

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if useImmersive {
                    SacredScreenBackground(settings: settings)
                }
                List {
                    Section(
                        header: Group {
                            if useImmersive {
                                DarkSectionHeader(title: "Data Status")
                            } else {
                                Text("Data Status")
                            }
                        }
                    ) {
                        LabeledContent("Imported Fields", value: "\(fields.count)")
                        if fields.isEmpty {
                            Text("No fields found. Check import logic.")
                                .foregroundStyle(useImmersive ? DSColor.error : .red)
                        }
                    }
                    
                    if !fields.isEmpty {
                        Section(
                            header: Group {
                                if useImmersive {
                                    DarkSectionHeader(title: "Select Field for Preview")
                                } else {
                                    Text("Select Field for Preview")
                                }
                            }
                        ) {
                            ForEach(fields) { field in
                                Button(field.name) {
                                    selectedField = field
                                }
                                .foregroundStyle(
                                    selectedField == field
                                        ? (useImmersive ? DSColor.goldLight : .blue)
                                        : (useImmersive ? DSColor.textPrimary : .primary)
                                )
                                .checkmark(selectedField == field)
                            }
                        }
                        
                        if let field = selectedField {
                            Section(
                                header: Group {
                                    if useImmersive {
                                        DarkSectionHeader(title: "Components")
                                    } else {
                                        Text("Components")
                                    }
                                }
                            ) {
                                NavigationLink("Requirements Summary") {
                                    ScrollView {
                                        RequirementsSummaryView(fieldName: field.name)
                                    }
                                    .navigationTitle("Requirements")
                                }
                                
                                Button("Best Practice Sidebar") {
                                    showingBestPractices = true
                                }
                                
                                #if DEBUG
                                NavigationLink("AI Advisor Panel") {
                                    AIAdvisorPanel(draftContent: "Test content")
                                        .navigationTitle("Advisor")
                                }
                                #endif
                            }
                        }
                    }
                }
                .listRowBackground(useImmersive ? Color.clear : Color(uiColor: .secondarySystemGroupedBackground))
                .listRowSeparatorTint(useImmersive ? .clear : Color(uiColor: .separator))
                .darkListStyle(enabled: useImmersive, baseBackground: nil)
                .background(Color.clear)
                .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
                .navigationTitle("KB Verification")
                .sheet(isPresented: $showingBestPractices) {
                    if let field = selectedField {
                        BestPracticeSidebarView(fieldName: field.name, isPresented: $showingBestPractices)
                    }
                }
            }
        }
    }
}

extension View {
    func checkmark(_ condition: Bool) -> some View {
        HStack {
            self
            Spacer()
            if condition {
                Image(systemName: "checkmark").foregroundStyle(DSColor.goldLight)
            }
        }
    }
}
