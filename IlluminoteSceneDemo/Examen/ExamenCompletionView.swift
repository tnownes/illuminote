import SwiftUI

struct ExamenCompletionView: View {
    var hasSavedReflection: Bool = true
    var applicationRecordOutcomeText: String? = nil
    var onViewJournal: () -> Void
    var onOpenInsights: () -> Void
    var onGoToWriting: () -> Void
    var onReturnHome: () -> Void
    @State private var appeared = false
    
    var body: some View {
        ZStack {
            ExamenBackgroundHost(presentation: .completion)
            
            VStack(spacing: DSSpacing.xl) {
                Spacer()

                AppPanel(
                    title: "Reflection saved",
                    subtitle: AppSettings.featurePolicy.mode == .core ? nil : "Choose the next step that fits this moment.",
                    role: .reading,
                    highlighted: true
                ) {
                    VStack(spacing: DSSpacing.lg) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 76))
                            .foregroundStyle(DSColor.brandAccent)
                            .frame(maxWidth: .infinity)

                        if !completionMessage.isEmpty {
                            Text(completionMessage)
                                .font(DSFont.supporting)
                                .foregroundStyle(DSColor.quietText)
                                .multilineTextAlignment(.center)
                        }

                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            Label("Saved to Journal", systemImage: "checkmark.circle")
                            if let applicationRecordOutcomeText {
                                Label(applicationRecordOutcomeText, systemImage: "briefcase")
                            }
                        }
                        .font(DSFont.caption.weight(.semibold))
                        .foregroundStyle(DSColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DSSpacing.sm)
                        .background(DSColor.surfaceElevated.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(spacing: DSSpacing.sm) {
                            if AppSettings.featurePolicy.mode == .core {
                                journalButton
                                    .buttonStyle(.appPrimary)
                                insightsButton
                                    .buttonStyle(.appSecondary)
                            } else {
                                insightsButton
                                    .buttonStyle(.appPrimary)
                                journalButton
                                    .buttonStyle(.appSecondary)

                                Button {
                                    onGoToWriting()
                                } label: {
                                    Label("Go to Writing", systemImage: "square.and.pencil")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.appSecondary)
                                .accessibilityIdentifier("completion.goToWriting")
                            }
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
                
                Spacer()
                
                Button {
                    onReturnHome()
                } label: {
                    Text("Return Home")
                }
                .buttonStyle(.appQuiet)
                .accessibilityIdentifier("completion.returnHome")
                .padding(.horizontal, 40)
                .padding(.bottom, DSSpacing.xl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear { appeared = true }
    }

    private var journalButton: some View {
        Button {
            onViewJournal()
        } label: {
            Label("View in Journal", systemImage: "book")
                .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("completion.viewJournal")
    }

    private var insightsButton: some View {
        Button {
            onOpenInsights()
        } label: {
            Label(insightsActionTitle, systemImage: "sparkles.rectangle.stack")
                .frame(maxWidth: .infinity)
        }
        .disabled(!hasSavedReflection)
        .accessibilityIdentifier("completion.openInsights")
    }

    private var completionMessage: String {
        if AppSettings.featurePolicy.mode == .core {
            return ""
        }

        if hasSavedReflection {
            return "Your reflection is saved. Choose the next step that fits this moment."
        }
        return "Your reflection is complete. Return home when you are ready, then check Journal to confirm it saved."
    }

    private var insightsActionTitle: String {
        AppSettings.featurePolicy.mode == .core ? "Notice Patterns" : "Open Insights"
    }
}

#Preview {
    ExamenCompletionView(
        onViewJournal: {},
        onOpenInsights: {},
        onGoToWriting: {},
        onReturnHome: {}
    )
    .environment(AppSettings())
}
