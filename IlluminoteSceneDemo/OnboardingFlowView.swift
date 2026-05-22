import SwiftUI
import SwiftData

struct OnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    enum OnboardingStep: Int, CaseIterable {
        case welcome, appMap, setup, done

        var progressIndex: Int? {
            switch self {
            case .welcome:
                return 1
            case .appMap:
                return 2
            case .setup:
                return 3
            case .done:
                return nil
            }
        }
    }
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var persistenceAlert: PersistenceAlertContext?
    
    var body: some View {
        ZStack {
            SacredScreenBackground(settings: settings)

            VStack(spacing: 0) {
                if let progressIndex = currentStep.progressIndex {
                    OnboardingProgressHeader(
                        stepIndex: progressIndex,
                        totalSteps: 3,
                        onSkip: completeWithDefaultsAndDismiss
                    )
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.top, DSSpacing.md)
                }

                Group {
                    switch currentStep {
                    case .welcome:
                        OnboardingWelcomeView(onNext: { advance(to: .appMap) })
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    case .appMap:
                        OnboardingAppMapView(onNext: { advance(to: .setup) })
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    case .setup:
                        OnboardingSetupView(onComplete: { profile in
                            saveProfile(profile)
                            advance(to: .done)
                        })
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    case .done:
                        OnboardingCompletionView(onDismiss: finishAndDismiss)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(AnimationConfig.screenTransition, value: currentStep)
        .persistenceFailureAlert($persistenceAlert)
        .interactiveDismissDisabled()
    }
    
    private func advance(to step: OnboardingStep) {
        withAnimation(AnimationConfig.screenTransition) {
            currentStep = step
        }
    }

    private func finishAndDismiss() {
        settings.selectedTab = .home
        dismiss()
    }

    private func completeWithDefaultsAndDismiss() {
        let existing = try? modelContext.fetch(FetchDescriptor<UserProfile>())
        if let first = existing?.first {
            first.hasSeenOnboarding = true
            do {
                try modelContext.persistIfNeeded(for: "save your onboarding progress")
            } catch let error as PersistenceOperationError {
                persistenceAlert = error.alertContext
                return
            } catch {
                persistenceAlert = PersistenceAlertContext.saveFailure(
                    for: "save your onboarding progress",
                    details: error.localizedDescription
                )
                return
            }
        } else {
            let profile = UserProfile(hasSeenOnboarding: true)
            modelContext.insert(profile)
            do {
                try modelContext.persistIfNeeded(for: "save your onboarding defaults")
            } catch let error as PersistenceOperationError {
                persistenceAlert = error.alertContext
                return
            } catch {
                persistenceAlert = PersistenceAlertContext.saveFailure(
                    for: "save your onboarding defaults",
                    details: error.localizedDescription
                )
                return
            }
        }

        finishAndDismiss()
    }
    
    private func saveProfile(_ profile: UserProfile) {
        let existing = try? modelContext.fetch(FetchDescriptor<UserProfile>())
        let persistedProfile: UserProfile
        
        if let first = existing?.first {
            first.preProfessionalTrack = profile.preProfessionalTrack
            first.defaultMode = profile.defaultMode
            first.notificationsEnabled = profile.notificationsEnabled
            first.notificationTime = profile.notificationTime
            first.degreeIntent = profile.degreeIntent
            first.isTexasApplicant = profile.isTexasApplicant
            first.hasSeenOnboarding = true
            persistedProfile = first
        } else {
            modelContext.insert(profile)
            persistedProfile = profile
        }
        do {
            try modelContext.persistIfNeeded(for: "save your onboarding profile")
        } catch let error as PersistenceOperationError {
            persistenceAlert = error.alertContext
            return
        } catch {
            persistenceAlert = PersistenceAlertContext.saveFailure(
                for: "save your onboarding profile",
                details: error.localizedDescription
            )
            return
        }
        
        if persistedProfile.notificationsEnabled {
            NotificationManager.shared.requestPermission { granted in
                if granted {
                    NotificationManager.shared.scheduleNotifications(for: persistedProfile)
                } else {
                    persistedProfile.notificationsEnabled = false
                    NotificationManager.shared.cancelNotifications()
                    do {
                        try modelContext.persistIfNeeded(for: "update your onboarding notification preference")
                    } catch let error as PersistenceOperationError {
                        persistenceAlert = error.alertContext
                    } catch {
                        persistenceAlert = PersistenceAlertContext.saveFailure(
                            for: "update your onboarding notification preference",
                            details: error.localizedDescription
                        )
                    }
                }
            }
        } else {
            NotificationManager.shared.cancelNotifications()
        }
    }
}

private struct OnboardingProgressHeader: View {
    let stepIndex: Int
    let totalSteps: Int
    let onSkip: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Step \(stepIndex) of \(totalSteps)")
                    .font(DSFont.meta.weight(.semibold))
                    .foregroundStyle(DSColor.quietTextMuted)

                ProgressView(value: Double(stepIndex), total: Double(totalSteps))
                    .tint(DSColor.brandAccent)
                    .frame(maxWidth: 160)
            }

            Spacer()

            Button(action: onSkip) {
                Text("Skip for now")
                    .font(DSFont.meta.weight(.semibold))
                    .foregroundStyle(DSColor.quietText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(DSColor.quietSurface.opacity(0.78))
                    )
                    .overlay(
                        Capsule()
                            .stroke(DSColor.dividerSoft, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Uses default settings and opens the app.")
        }
    }
}

/// Targeted explainer for the Examen practice, replayable from Home and Settings.
struct ExamenExplainerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text("The Examen")
                    .font(DSFont.heading1)
                    .foregroundStyle(DSColor.textPrimary)

                Text("The Examen is a reflective prayer practice that helps you review your day with honesty, gratitude, and clarity.")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)

                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    ExplainerRow(icon: "sparkles", title: "Purpose", description: "Notice where you felt alive, challenged, grateful, or called in your real experiences.")
                    ExplainerRow(icon: "book.closed.fill", title: "Practice", description: "The app guides you through short prompts and saves your notes in your journal.")
                    ExplainerRow(icon: "doc.text.fill", title: "Application", description: "Use your notes to build clearer personal statement drafts grounded in real moments.")
                }
                .padding(.top, DSSpacing.sm)

                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    Text("The 5 Steps")
                        .font(DSFont.heading2)
                        .foregroundStyle(DSColor.textPrimary)

                    ExplainerStepRow(number: 1, title: "First Principle", description: "Begin with openness and ask for clarity before reviewing your day.")
                    ExplainerStepRow(number: 2, title: "Gratitude", description: "Identify moments, people, or gifts you are thankful for.")
                    ExplainerStepRow(number: 3, title: "Presence", description: "Notice where you felt most present, engaged, or moved.")
                    ExplainerStepRow(number: 4, title: "Reflection", description: "Examine tensions, patterns, and what they may be teaching you.")
                    ExplainerStepRow(number: 5, title: "Commitment", description: "Choose one concrete next step for tomorrow.")
                }
            }
            .padding(DSSpacing.lg)
        }
        .background(DSColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("About the Examen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ExplainerStepRow: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Text("\(number)")
                .font(DSFont.heading2)
                .foregroundStyle(DSColor.nearBlack)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(DSColor.goldLight)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DSFont.heading2)
                    .foregroundStyle(DSColor.textPrimary)
                Text(description)
                    .font(DSFont.subtext)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
    }
}

private struct ExplainerRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(DSColor.goldLight)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DSFont.heading2)
                    .foregroundStyle(DSColor.textPrimary)
                Text(description)
                    .font(DSFont.subtext)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
    }
}

#Preview {
    OnboardingFlowView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
