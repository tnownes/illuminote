import SwiftUI
import SwiftData

struct OnboardingWelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        OnboardingStageScaffold {
            AppSectionHeader(
                eyebrow: "Welcome",
                title: "Welcome to Illuminote",
                subtitle: "Reflect on an experience. Save what matters. Write when ready."
            )

            OnboardingHeroCard()

            AppPanel(
                title: "Designed for thoughtful, busy days",
                subtitle: "Start with one reflection.",
                role: .quiet
            ) {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("You can revisit this introduction later in Settings.")
                        .font(DSFont.supporting)
                        .foregroundStyle(DSColor.quietText)
                        .fixedSize(horizontal: false, vertical: true)

                    AppInfoChip(text: "Home is the starting place", icon: "house", emphasized: true)
                }
            }
        } footer: {
            Button(action: onNext) {
                Text("Get Started")
            }
            .buttonStyle(SacredButtonStyle())
        }
    }
}

struct OnboardingAppMapView: View {
    let onNext: () -> Void

    var body: some View {
        OnboardingStageScaffold {
            AppSectionHeader(
                eyebrow: "App Map",
                title: "Choose. Reflect. Save. Notice. Write.",
                subtitle: nil
            )

            AppPanel(
                title: "One flow",
                subtitle: nil,
                role: .interactive,
                highlighted: true
            ) {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    OnboardingFeatureCard(
                        index: "01",
                        icon: "house.fill",
                        title: "Home",
                        description: "Begin an Examen or capture a quick note."
                    )
                    OnboardingPanelDivider()
                    OnboardingFeatureCard(
                        index: "02",
                        icon: "book.closed.fill",
                        title: "Journal",
                        description: "Return to saved reflections."
                    )
                    OnboardingPanelDivider()
                    OnboardingFeatureCard(
                        index: "03",
                        icon: "square.grid.2x2.fill",
                        title: "Insights",
                        description: "Notice patterns across reflections."
                    )
                    OnboardingPanelDivider()
                    OnboardingFeatureCard(
                        index: "04",
                        icon: "square.and.pencil",
                        title: "Writing",
                        description: "Shape draft material when ready."
                    )
                    OnboardingPanelDivider()
                    OnboardingFeatureCard(
                        index: "05",
                        icon: "gearshape.fill",
                        title: "Settings",
                        description: "Adjust defaults and reminders."
                    )
                }
            }
        } footer: {
            Button(action: onNext) {
                Text("Continue")
            }
            .buttonStyle(SacredButtonStyle())
        }
    }
}

extension PreProfessionalTrack {
    var systemIcon: String {
        switch self {
        case .preMedicine: return "stethoscope"
        case .preDentistry: return "mouth.fill"
        case .prePharmacy: return "pills.fill"
        case .preOccupationalTherapy: return "figure.walk"
        case .prePhysicalTherapy: return "figure.walk.motion"
        case .prePhysicianAssistant: return "person.fill.checkmark"
        case .preLaw: return "gavel.fill"
        case .preVeterinaryMedicine: return "pawprint.fill"
        case .preOptometry: return "eye.fill"
        case .medicalOrDentalResidency: return "briefcase.fill"
        case .general, .other: return "person.fill"
        }
    }
    
    var trackDescription: String {
        switch self {
        case .preMedicine: return "Fulfilling requirements for medical school admission."
        case .preDentistry: return "Preparing for dental school and oral healthcare careers."
        case .prePharmacy: return "Pursuing chemistry, patient care, and pharmaceutical paths."
        case .preOccupationalTherapy: return "Enabling rehabilitation and everyday living therapy."
        case .prePhysicalTherapy: return "Focusing on movement, strength, and physical recovery."
        case .prePhysicianAssistant: return "Preparing for team-based medical practice and licensing."
        case .preLaw: return "Discerning legal analysis, justice, and jurisprudence."
        case .preVeterinaryMedicine: return "Caring for animal health, husbandry, and medicine."
        case .preOptometry: return "Focusing on vision science, diagnostics, and eye care."
        case .medicalOrDentalResidency: return "Navigating clinical training after graduation."
        case .general, .other: return "Grounded personal reflection for everyday growth."
        }
    }
}

struct OnboardingTrackSelectionView: View {
    @Binding var selectedTrack: PreProfessionalTrack
    let onNext: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 155), spacing: DSSpacing.md)
    ]

    var body: some View {
        OnboardingStageScaffold {
            AppSectionHeader(
                eyebrow: "Step 3 of 4",
                title: "Choose your focus",
                subtitle: "Select the track that aligns with your current educational or career path to personalize your reflection prompts."
            )

            LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                ForEach(PreProfessionalTrack.selectableCases, id: \.self) { track in
                    Button {
                        selectedTrack = track
                    } label: {
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            HStack {
                                Image(systemName: track.systemIcon)
                                    .font(.title3)
                                    .foregroundStyle(selectedTrack == track ? DSColor.brandAccent : DSColor.quietText)
                                Spacer()
                                if selectedTrack == track {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(DSColor.brandAccent)
                                        .font(.subheadline)
                                }
                            }
                            
                            Text(track.displayName)
                                .font(DSFont.sectionTitle)
                                .foregroundStyle(DSColor.textPrimary)
                                .multilineTextAlignment(.leading)
                            
                            Text(track.trackDescription)
                                .font(DSFont.meta)
                                .foregroundStyle(DSColor.quietText)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(DSSpacing.md)
                        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(selectedTrack == track ? DSColor.brandAccentSoft.opacity(0.12) : DSColor.interactiveSurface.opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(selectedTrack == track ? DSColor.brandAccent : DSColor.dividerSoft, lineWidth: selectedTrack == track ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(track.displayName) track")
                    .accessibilityValue(selectedTrack == track ? "Selected" : "Not selected")
                    .accessibilityHint(track.trackDescription)
                }
            }
            .padding(.vertical, DSSpacing.sm)
        } footer: {
            Button(action: onNext) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SacredButtonStyle())
        }
    }
}

struct OnboardingPreferencesView: View {
    let selectedTrack: PreProfessionalTrack
    @Binding var degreeIntent: DegreeIntent
    @Binding var isTexasApplicant: Bool
    @Binding var notificationsEnabled: Bool
    @Binding var notificationTime: Date
    let onComplete: (UserProfile) -> Void

    var body: some View {
        OnboardingStageScaffold {
            AppSectionHeader(
                eyebrow: "Step 4 of 4",
                title: "Refine & Remind",
                subtitle: "Set up details to structure your workspace and keep your reflective practice steady."
            )

            if selectedTrack == .preMedicine {
                AppPanel(
                    title: "Medical Track Customization",
                    subtitle: "Personalize prompts for your specific application requirements.",
                    role: .reading
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
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

                        OnboardingPanelDivider()

                        Toggle(isOn: $isTexasApplicant) {
                            ThemedText(text: "Applying to Texas Schools?", style: .body)
                        }
                        .tint(DSColor.goldLight)
                    }
                }
            }

            AppPanel(
                title: "Gentle Reminder",
                subtitle: "A silent, high-contrast prompt to anchor your daily reflection without administrative noise.",
                role: .interactive
            ) {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    Toggle(isOn: $notificationsEnabled) {
                        ThemedText(text: "Daily Reflection Reminder", style: .body)
                    }
                    .tint(DSColor.goldLight)

                    if notificationsEnabled {
                        OnboardingPanelDivider()

                        DatePicker(selection: $notificationTime, displayedComponents: .hourAndMinute) {
                            ThemedText(text: "Reminder Time", style: .body)
                        }
                        .colorScheme(.dark)
                    }
                }
            }
        } footer: {
            Button {
                let profile = UserProfile(
                    preProfessionalTrack: selectedTrack,
                    examenFrequency: .daily,
                    preferredTimeOfDay: .evening,
                    sessionLength: .medium,
                    defaultMode: .deep,
                    notificationsEnabled: notificationsEnabled,
                    notificationTime: notificationTime,
                    hasSeenOnboarding: true,
                    degreeIntent: degreeIntent,
                    isTexasApplicant: isTexasApplicant
                )
                onComplete(profile)
            } label: {
                Text("Save & Complete")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SacredButtonStyle())
        }
        .background(Color.clear)
        .colorScheme(.dark)
    }
}

struct OnboardingCompletionView: View {
    let onDismiss: () -> Void

    var body: some View {
        OnboardingStageScaffold {
            AppPanel(
                title: "Illuminote begins with The Examen",
                subtitle: "Choose an experience, then slow down with it.",
                role: .reading,
                highlighted: true
            ) {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    OnboardingCompletionRow(
                        title: "What it is",
                        detail: "A guided reflective practice rooted in the Ignatian Examen."
                    )
                    OnboardingPanelDivider()
                    OnboardingCompletionRow(
                        title: "Why it matters here",
                        detail: "Writing becomes stronger when it begins in reflection."
                    )
                    OnboardingPanelDivider()
                    OnboardingCompletionRow(
                        title: "Where to begin",
                        detail: "Home starts the Examen. Quick Note catches a moment."
                    )
                }
            }
        } footer: {
            Button(action: onDismiss) {
                Text("Go to Home")
            }
            .buttonStyle(SacredButtonStyle())
        }
    }
}

private struct OnboardingStageScaffold<Content: View, Footer: View>: View {
    let content: Content
    let footer: Footer

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.xl) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.xl)
                .padding(.bottom, DSSpacing.lg)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: DSSpacing.sm) {
                footer
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.top, DSSpacing.md)
            .padding(.bottom, 40)
            .background(
                LinearGradient(
                    colors: [
                        DSColor.backgroundPrimary.opacity(0),
                        DSColor.backgroundPrimary.opacity(0.94),
                        DSColor.backgroundPrimary
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}

private struct OnboardingHeroCard: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DSColor.interactiveSurface.opacity(0.96),
                            DSColor.quietSurface.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            DSColor.brandAccent.opacity(0.45),
                            DSColor.dividerSoft
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            Circle()
                .fill(DSColor.brandAccent.opacity(0.20))
                .frame(width: 220, height: 220)
                .blur(radius: 28)
                .offset(x: 110, y: -70)

            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                AppInfoChip(text: "A guided beginning", icon: "sparkles", emphasized: true)

                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Notice the day.\nCarry it forward.")
                        .font(DSFont.display)
                        .foregroundStyle(DSColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Illuminote helps you reflect with honesty, gather what matters, and build writing from lived experience instead of from memory alone.")
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.quietText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    OnboardingHeroPoint(
                        title: "Reflect first",
                        detail: "Start at Home to reflect on your experiences through a guided Examen."
                    )
                    OnboardingHeroPoint(
                        title: "Note what surfaces",
                        detail: "Journal holds the moments and insights you've recorded."
                    )
                    OnboardingHeroPoint(
                        title: "Draft from there",
                        detail: "Insights and Writing offer a way to brainstorm and write from your reflections."
                    )
                }
            }
            .padding(DSSpacing.xl)
        }
        .frame(maxWidth: .infinity, minHeight: 340, alignment: .leading)
        .shadow(color: DSColor.brandAccent.opacity(0.12), radius: 24, x: 0, y: 16)
    }
}

private struct OnboardingHeroPoint: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Circle()
                .fill(DSColor.brandAccent.opacity(0.9))
                .frame(width: 7, height: 7)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DSFont.supporting.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                Text(detail)
                    .font(DSFont.supporting)
                    .foregroundStyle(DSColor.quietText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct OnboardingPanelDivider: View {
    var body: some View {
        Rectangle()
            .fill(DSColor.dividerSoft)
            .frame(height: 1)
    }
}

private struct OnboardingCompletionRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(DSFont.eyebrow)
                .foregroundStyle(DSColor.quietTextMuted)
            Text(detail)
                .font(DSFont.supporting)
                .foregroundStyle(DSColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct OnboardingFeatureCard: View {
    let index: String
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text(index)
                    .font(DSFont.meta.weight(.bold))
                    .foregroundStyle(DSColor.brandAccent)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(DSColor.brandAccent)
            }
            .frame(width: 30, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DSFont.sectionTitle)
                    .foregroundStyle(DSColor.textPrimary)
                Text(description)
                    .font(DSFont.supporting)
                    .foregroundStyle(DSColor.quietText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
