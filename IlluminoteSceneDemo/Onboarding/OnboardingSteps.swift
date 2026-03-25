import SwiftUI
import SwiftData

// MARK: - Welcome View
struct OnboardingWelcomeView: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image("AppLogo") // Placeholder, or use system icon
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(.tint)
                .opacity(0.8)
            
            VStack(spacing: 12) {
                ThemedText(text: "Welcome to Illuminote", style: .heading1)
                    .multilineTextAlignment(.center)
                
                ThemedText(text: "Capture meaningful reflections, find patterns, and build stronger personal statement drafts.", style: .heading2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button(action: onNext) {
                Text("Get Started")
                    .fontWeight(.bold)
            }
            .buttonStyle(SacredButtonStyle())
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .padding()
    }
}

// MARK: - About Examen View
struct OnboardingAboutView: View {
    let onNext: () -> Void
    let onLearnMore: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundStyle(DSColor.goldLight)
                .luminous()
            
            VStack(spacing: 16) {
                ThemedText(text: "What is the Examen?", style: .heading1)
                    .multilineTextAlignment(.center)
                
                ThemedText(text: "The Examen is a reflective prayer practice. It helps you review your day with gratitude, honesty, and attention to where you are being called.", style: .body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: onLearnMore) {
                    Text("Learn More")
                        .font(.subheadline)
                        .foregroundStyle(DSColor.goldLight)
                        .luminous()
                }
                
                Button(action: onNext) {
                    Text("Next")
                        .fontWeight(.bold)
                }
                .buttonStyle(SacredButtonStyle())
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .padding()
    }
}

// MARK: - Examen Steps View
struct OnboardingExamenStepsView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            ThemedText(text: "How the Examen Works", style: .heading1)
                .multilineTextAlignment(.center)
                .padding(.top, 40)

            VStack(alignment: .leading, spacing: 14) {
                ExamenStepRow(number: 1, title: "First Principle", description: "Begin with openness and ask for clarity.")
                ExamenStepRow(number: 2, title: "Gratitude", description: "Name what was good and life-giving today.")
                ExamenStepRow(number: 3, title: "Presence", description: "Notice where you felt most present and engaged.")
                ExamenStepRow(number: 4, title: "Reflection", description: "Examine tensions, patterns, and what they reveal.")
                ExamenStepRow(number: 5, title: "Commitment", description: "Choose one concrete next step for tomorrow.")
            }
            .padding(.horizontal)

            Spacer()

            Button(action: onNext) {
                Text("Next")
                    .fontWeight(.bold)
            }
            .buttonStyle(SacredButtonStyle())
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .padding()
    }

    private struct ExamenStepRow: View {
        let number: Int
        let title: String
        let description: String

        var body: some View {
            HStack(alignment: .top, spacing: 14) {
                Text("\(number)")
                    .font(DSFont.heading2)
                    .foregroundStyle(DSColor.nearBlack)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(DSColor.goldLight))

                VStack(alignment: .leading, spacing: 4) {
                    ThemedText(text: title, style: .heading2)
                    ThemedText(text: description, style: .subtext)
                }
            }
        }
    }
}

// MARK: - How It Works View
struct OnboardingHowItWorksView: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            ThemedText(text: "How Illuminote Works", style: .heading1)
                .multilineTextAlignment(.center)
                .padding(.top, 40)
            
            VStack(alignment: .leading, spacing: 24) {
                FeatureRow(icon: "play.circle.fill", title: "Start Examen", description: "Use guided prompts to reflect on real experiences.")
                FeatureRow(icon: "square.and.pencil", title: "Capture Notes", description: "Write short reflections during or after each session.")
                FeatureRow(icon: "book.fill", title: "Review in Journal", description: "Search, filter, and organize entries over time.")
                FeatureRow(icon: "doc.text.fill", title: "Build Drafts", description: "Select journal entries to build personal statement drafts.")
                FeatureRow(icon: "tag.fill", title: "Draft Type Tip", description: "New drafts default to Full Draft. You can switch to Opening, Body, or Closing when creating or editing a draft.")
                FeatureRow(icon: "brain.head.profile", title: "Optional AI Advisor", description: "Get on-device feedback in the Statement editor.")
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button(action: onNext) {
                Text("Next")
                    .fontWeight(.bold)
            }
            .buttonStyle(SacredButtonStyle())
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .padding()
    }
    
    private struct FeatureRow: View {
        let icon: String
        let title: String
        let description: String
        
        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 32)
                    .foregroundStyle(DSColor.goldLight)
                
                VStack(alignment: .leading, spacing: 4) {
                    ThemedText(text: title, style: .heading2)
                    ThemedText(text: description, style: .subtext)
                }
            }
        }
    }
}

// MARK: - Setup Experience View
struct OnboardingSetupView: View {
    let onComplete: (UserProfile) -> Void
    
    @State private var selectedTrack: PreProfessionalTrack = .preMedicine
    @State private var degreeIntent: DegreeIntent = .md
    @State private var isTexasApplicant: Bool = false
    @State private var defaultMode: ExamenMode = .deep
    @State private var notificationsEnabled = false
    @State private var notificationTime = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date.now
    
    var body: some View {
        VStack(spacing: 0) {
            ThemedText(text: "Let’s tailor your experience", style: .heading1)
                .multilineTextAlignment(.center)
                .padding(.vertical, 30)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Section
                    VStack(alignment: .leading, spacing: 16) {
                        ThemedText(text: "Who are you?", style: .heading2)
                            .foregroundStyle(DSColor.textSecondary)
                        
                        HStack {
                            ThemedText(text: "Track", style: .body)
                            Spacer()
                            Picker("Track", selection: $selectedTrack) {
                                ForEach(PreProfessionalTrack.selectableCases, id: \.self) { track in
                                    Text(track.displayName).tag(track)
                                }
                            }
                            .tint(DSColor.goldLight)
                        }
                        
                        if selectedTrack == .preMedicine {
                            Divider().background(Color.white.opacity(0.1))
                            HStack {
                                ThemedText(text: "Degree Intent", style: .body)
                                Spacer()
                                Picker("Degree Intent", selection: $degreeIntent) {
                                    ForEach(DegreeIntent.allCases) { intent in
                                        Text(intent.displayName).tag(intent)
                                    }
                                }
                                .tint(DSColor.goldLight)
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            Toggle(isOn: $isTexasApplicant) {
                                ThemedText(text: "Applying to Texas Schools?", style: .body)
                            }
                            .tint(DSColor.goldLight)
                        }
                    }
                    .padding()
                    .glassCardStyle()
                    
                    // Depth Section
                    VStack(alignment: .leading, spacing: 16) {
                        ThemedText(text: "Default Reflection Mode", style: .heading2)
                            .foregroundStyle(DSColor.textSecondary)

                        ForEach(ExamenMode.allCases) { mode in
                            Button {
                                defaultMode = mode
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: defaultMode == mode ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(defaultMode == mode ? DSColor.goldLight : DSColor.textSecondary)

                                    VStack(alignment: .leading, spacing: 4) {
                                        ThemedText(text: mode.displayName, style: .body)
                                        ThemedText(text: modeDescription(mode), style: .subtext)
                                    }

                                    Spacer()
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(DSColor.backgroundSecondary.opacity(0.75))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(defaultMode == mode ? DSColor.goldLight.opacity(0.9) : DSColor.divider.opacity(0.4), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        ThemedText(text: "You can change this anytime in Settings.", style: .caption)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                    .padding()
                    .glassCardStyle()
                    
                    // Notifications Section
                    VStack(alignment: .leading, spacing: 16) {
                        ThemedText(text: "Daily Reminder", style: .heading2)
                            .foregroundStyle(DSColor.textSecondary)
                        
                        Toggle(isOn: $notificationsEnabled) {
                            ThemedText(text: "Remind me to reflect", style: .body)
                        }
                        .tint(DSColor.goldLight)
                        
                        if notificationsEnabled {
                            Divider().background(Color.white.opacity(0.1))
                            DatePicker(selection: $notificationTime, displayedComponents: .hourAndMinute) {
                                ThemedText(text: "Time", style: .body)
                            }
                            .colorScheme(.dark)
                        }
                    }
                    .padding()
                    .glassCardStyle()
                }
                .padding(.horizontal)
            }
            
            Button {
                let profile = UserProfile(
                    preProfessionalTrack: selectedTrack,
                    examenFrequency: .daily, // Explicit default or could rely on init default
                    preferredTimeOfDay: .evening,
                    sessionLength: .medium,
                    defaultMode: defaultMode,
                    notificationsEnabled: notificationsEnabled,
                    notificationTime: notificationTime,
                    hasSeenOnboarding: true,
                    degreeIntent: degreeIntent,
                    isTexasApplicant: isTexasApplicant
                )
                onComplete(profile)
            } label: {
                Text("Save & Continue")
                    .fontWeight(.bold)
            }
            .buttonStyle(SacredButtonStyle())
            .padding()
        }
        .background(Color.clear)
        .colorScheme(.dark) // Force dark mode for form controls to ensure white text
    }

    private func modeDescription(_ mode: ExamenMode) -> String {
        switch mode {
        case .quick:
            return "Shortest reflection for busy days."
        case .deep:
            return "Balanced session with broader reflection."
        case .vocation:
            return "Focuses on pre-professional growth and calling."
        case .spiritual:
            return "Faith-forward reflection emphasizing prayer and presence."
        }
    }
}

// MARK: - Completion View
struct OnboardingCompletionView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(DSColor.goldLight)
                .luminous()
                .symbolEffect(.bounce, value: true)
            
            VStack(spacing: 16) {
                ThemedText(text: "You’re ready to reflect", style: .heading1)
                    .multilineTextAlignment(.center)
                
                ThemedText(text: "Take a moment each day to connect with yourself and your goals.", style: .body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Text("Go to Home")
                    .fontWeight(.bold)
            }
            .buttonStyle(SacredButtonStyle())
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .padding()
    }
}
