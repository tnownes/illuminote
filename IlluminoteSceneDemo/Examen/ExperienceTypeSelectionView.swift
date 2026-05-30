import SwiftUI

struct ExperienceTypeSelectionView: View {
    var onSelect: (ExperienceType) -> Void
    var onCancel: () -> Void

    @State private var selectedType: ExperienceType?
    @State private var selectionAdvanceTask: Task<Void, Never>?

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
                                selectCoreType(tapped)
                            } else {
                                onSelect(tapped)
                            }
                        }
                    }

                    if isCoreMode {
                        VStack(spacing: DSSpacing.md) {
                            Button("Not sure yet") {
                                selectionAdvanceTask?.cancel()
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
        .onDisappear {
            selectionAdvanceTask?.cancel()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    selectionAdvanceTask?.cancel()
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

    private func selectCoreType(_ type: ExperienceType) {
        selectionAdvanceTask?.cancel()

        withAnimation(AnimationConfig.examenControl) {
            selectedType = type
        }

        selectionAdvanceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 240_000_000)
            guard !Task.isCancelled else { return }
            onSelect(type)
        }
    }
}

#Preview {
    NavigationStack {
        ExperienceTypeSelectionView(onSelect: { _ in }, onCancel: {})
    }
    .environment(AppSettings())
}
