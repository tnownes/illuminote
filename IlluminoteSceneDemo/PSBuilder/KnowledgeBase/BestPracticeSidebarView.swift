import SwiftUI
import SwiftData

struct BestPracticeSidebarView: View {
    @Environment(AppSettings.self) private var settings
    let fieldName: String
    @Binding var isPresented: Bool
    
    @Query private var fields: [StatementField]
    
    private var targetField: StatementField? {
        fields.first { $0.name.localizedCaseInsensitiveContains(fieldName) } ?? fields.first
    }

    private var useImmersive: Bool {
        settings.appThemeMode == .core
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if useImmersive {
                    SacredScreenBackground(settings: settings)
                }
                ScrollView {
                    if let bestPractice = targetField?.bestPractice {
                        VStack(alignment: .leading, spacing: 20) {
                        // Overview
                        SectionHeader(title: "Overview", icon: "book.fill", color: useImmersive ? DSColor.goldLight : .blue, useImmersive: useImmersive)
                        Text(bestPractice.overview)
                            .font(DSFont.body)
                            .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                        
                        Divider()
                        
                        // Themes
                        SectionHeader(title: "Common Themes", icon: "sparkles", color: useImmersive ? DSColor.goldLight : .purple, useImmersive: useImmersive)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(Array(bestPractice.commonThemes), id: \.id) { theme in
                                    ThemeCard(theme: theme, useImmersive: useImmersive)
                                }
                            }
                        }
                        
                        Divider()
                        

                        // Structure
                        if let structure = bestPractice.structure {
                            SectionHeader(title: "Structure Guide", icon: "square.stack.3d.down.right.fill", color: useImmersive ? DSColor.goldLight : .orange, useImmersive: useImmersive)
                            StructureStep(title: "Introduction", content: structure.introduction, useImmersive: useImmersive)
                            StructureStep(title: "Body Paragraphs", content: structure.body, useImmersive: useImmersive)
                            StructureStep(title: "Conclusion", content: structure.conclusion, useImmersive: useImmersive)
                            Divider()
                        }
                        
                        // Tone
                        if let tone = bestPractice.toneGuidelines {
                            SectionHeader(title: "Tone & Voice", icon: "waveform.path.ecg", color: useImmersive ? DSColor.goldLight : .green, useImmersive: useImmersive)
                            Text("Recommended: \(tone.recommendedTone)")
                                .font(DSFont.subtext)
                                .fontWeight(.medium)
                                .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                            
                            if !tone.avoidList.isEmpty {
                                Text("Avoid: " + tone.avoidList.joined(separator: ", "))
                                    .font(DSFont.caption)
                                    .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                            }
                        }
                        }
                        .padding()
                        .background(Color.clear)
                    } else {
                        ContentUnavailableView("No Guidance Found", systemImage: "books.vertical")
                    }
                }
            }
            .background(useImmersive ? Color.clear : Color(uiColor: .systemGroupedBackground))
            .toolbarColorScheme(useImmersive ? .dark : nil, for: .navigationBar)
            .navigationTitle("Best Practices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    let useImmersive: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(DSFont.sectionHeader)
                .fontWeight(.bold)
                .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
        }
    }
}

private struct ThemeCard: View {
    let theme: PracticeTheme
    let useImmersive: Bool
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(theme.title)
                    .font(DSFont.heading2)
                    .lineLimit(isExpanded ? nil : 2)
                    .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
                
                Spacer(minLength: 4)
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .padding(.top, 4)
            }
            
            Text(theme.themeDescription)
                .font(DSFont.caption)
                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
                .lineLimit(isExpanded ? nil : 3)
                .fixedSize(horizontal: false, vertical: isExpanded)
        }
        .frame(width: isExpanded ? 240 : 160, alignment: .topLeading)
        .padding()
        .contentShape(Rectangle())
        .if(useImmersive) { view in
            view.sacredCardStyle(highlighted: false)
        }
        .background(useImmersive ? Color.clear : Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(useImmersive ? Color.clear : Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
    }
}

private struct StructureStep: View {
    let title: String
    let content: String
    let useImmersive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DSFont.subtext)
                .fontWeight(.bold)
                .foregroundStyle(useImmersive ? DSColor.textPrimary : .primary)
            Text(content)
                .font(DSFont.caption)
                .foregroundStyle(useImmersive ? DSColor.textSecondary : .secondary)
        }
    }
}

#Preview {
    Text("Sidebar Preview")
        .sheet(isPresented: .constant(true)) {
            BestPracticeSidebarView(fieldName: "Medicine", isPresented: .constant(true))
                .modelContainer(DataStoreHelper.makeModelContainer())
        }
}
