import SwiftUI
import SwiftData

struct OnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    // State machine for onboarding steps
    enum OnboardingStep: Int, CaseIterable {
        case splash, welcome, aboutExamen, examenSteps, howItWorks, setup, done
    }
    
    @State private var currentStep: OnboardingStep = .splash
    @State private var opacity: Double = 0
    @State private var showSettingsSheet = false // For "Learn More"
    
    var body: some View {
        ZStack {
            // Background: Dynamic Theme
            if settings.selectedTheme == .sacredVoid {
                RadialGradient(
                    gradient: Gradient(colors: [DSColor.nearBlack, DSColor.deepMaroon]),
                    center: .center,
                    startRadius: 50,
                    endRadius: 350
                )
                .ignoresSafeArea()
            } else if settings.selectedTheme == .gradient {
                AnimatedMeshGradientBackground()
            } else {
                 // Fallback/Standard dark theme
                Color.black.ignoresSafeArea()
            }
            
            switch currentStep {
            case .splash:
                splashScreen
            case .welcome:
                OnboardingWelcomeView(onNext: { advance(to: .aboutExamen) })
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .aboutExamen:
                OnboardingAboutView(
                    onNext: { advance(to: .examenSteps) },
                    onLearnMore: { showSettingsSheet = true }
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .examenSteps:
                OnboardingExamenStepsView(onNext: { advance(to: .howItWorks) })
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .howItWorks:
                OnboardingHowItWorksView(onNext: { advance(to: .setup) })
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .setup:
                OnboardingSetupView(onComplete: { profile in
                    saveProfile(profile)
                    advance(to: .done)
                })
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .done:
                OnboardingCompletionView(onDismiss: { dismiss() })
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut, value: currentStep)
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                ExamenExplainerView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showSettingsSheet = false }
                        }
                    }
            }
        }
        .onAppear {
            if currentStep == .splash {
                // Auto-advance splash
                withAnimation(.easeIn(duration: 1.0)) {
                    opacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    advance(to: .welcome)
                }
            }
        }
    }
    
    // MARK: - Splash Screen
    private var splashScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "sun.haze.fill") // Brand icon placeholder
                .font(.system(size: 80))
                .foregroundStyle(DSColor.goldLight)
                .luminous()
                .symbolEffect(.pulse, value: opacity)
            
            Text("Reflect. Connect. Grow.")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.9))
        }
        .opacity(opacity)
    }
    
    // MARK: - Helpers
    private func advance(to step: OnboardingStep) {
        withAnimation {
            currentStep = step
        }
    }
    
    private func saveProfile(_ profile: UserProfile) {
        // If there's an existing profile (re-run case), update it?
        // Or assume single profile.
        // For now, simpler to just insert. SwiftData handles ID conflicts if ID matches, but we created new UUID.
        // We should probably check if one exists and update it, to avoid duplicates if re-running.
        
        let existing = try? modelContext.fetch(FetchDescriptor<UserProfile>())
        let persistedProfile: UserProfile
        
        if let first = existing?.first {
            // Update existing
            first.preProfessionalTrack = profile.preProfessionalTrack
            first.defaultMode = profile.defaultMode
            first.notificationsEnabled = profile.notificationsEnabled
            first.notificationTime = profile.notificationTime
            first.degreeIntent = profile.degreeIntent
            first.isTexasApplicant = profile.isTexasApplicant
            first.hasSeenOnboarding = true
            persistedProfile = first
        } else {
            // Insert new
            modelContext.insert(profile)
            persistedProfile = profile
        }
        try? modelContext.save()
        
        if persistedProfile.notificationsEnabled {
            NotificationManager.shared.requestPermission { granted in
                if granted {
                    NotificationManager.shared.scheduleNotifications(for: persistedProfile)
                } else {
                    persistedProfile.notificationsEnabled = false
                    NotificationManager.shared.cancelNotifications()
                    try? modelContext.save()
                }
            }
        } else {
            NotificationManager.shared.cancelNotifications()
        }
    }
}

/// Targeted explainer for the Examen practice, shown from onboarding "Learn More".
private struct ExamenExplainerView: View {
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
