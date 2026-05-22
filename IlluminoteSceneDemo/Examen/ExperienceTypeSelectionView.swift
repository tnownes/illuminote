import SwiftUI

struct ExperienceTypeSelectionView: View {
    var onSelect: (ExperienceType) -> Void
    var onCancel: () -> Void

    @State private var selectedType: ExperienceType?

    private var isCoreMode: Bool {
        AppSettings.featurePolicy.mode == .core
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    if isCoreMode {
                        AppSectionHeader(
                            eyebrow: "Begin",
                            title: "What are you bringing today?",
                            subtitle: nil
                        )
                    } else {
                        AppSectionHeader(
                            eyebrow: "Before you begin",
                            title: "What kind of experience are you reflecting on?",
                            subtitle: "Choose the closest fit. The prompts will adapt from there."
                        )
                    }

                    AppPanel(role: .reading) {
                        ExperienceTypeGridView(
                            types: ExperienceType.allCases,
                            counts: [:],
                            selectedType: selectedType,
                            showsHints: isCoreMode
                        ) { tapped in
                            if isCoreMode {
                                selectedType = tapped
                            } else {
                                onSelect(tapped)
                            }
                        }
                    }

                    if isCoreMode {
                        VStack(spacing: DSSpacing.md) {
                            if let selectedType {
                                Button {
                                    onSelect(selectedType)
                                } label: {
                                    Label("Begin", systemImage: "chevron.right")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(SacredButtonStyle())
                                .accessibilityIdentifier("examen.type.begin")
                            }

                            Button("Not sure yet") {
                                onSelect(.other)
                            }
                            .buttonStyle(.appSecondary)
                            .accessibilityIdentifier("examen.type.notSure")
                        }
                        .frame(maxWidth: 328)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.md)
                .padding(.bottom, DSSpacing.xl)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .appCircleControl()
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        ExperienceTypeSelectionView(onSelect: { _ in }, onCancel: {})
    }
    .environment(AppSettings())
}
