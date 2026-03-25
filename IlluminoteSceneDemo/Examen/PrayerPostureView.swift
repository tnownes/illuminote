import SwiftUI
import AVFoundation

/// A calm, full-screen interstitial shown before Step 1 of the Examen.
/// - Shows a brief breathing cue and a prominent "Begin" action.
/// - Plays a subtle haptic via `sensoryFeedback` when beginning.
/// - Respects Reduce Motion by minimizing/omitting animations.
struct PrayerPostureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppSettings.self) private var settings // Inject settings for theme

    /// Callbacks to continue the prelude.
    let onConfirm: () -> Void
    var onSkip: (() -> Void)? = nil

    /// Triggers the sensory feedback when the user taps Begin.
    @State private var didConfirm = false
    @State private var showExitAlert = false
    
    // Animation state for entrance
    @State private var contentVisible = false

    var body: some View {
        ZStack {
            // Dynamic Theme Background (Restored)
            settings.selectedTheme.anySceneView
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.2)) // Slightly dim background for better contrast
            
            if contentVisible {
                VStack(spacing: DSSpacing.xl) {
                    Spacer(minLength: DSSpacing.xl)
                    
                    // Glass Text Container for Readability
                    VStack(spacing: DSSpacing.md) {
                        // Updated to match ExamenStepView Immersive Style
                        Text("Assume a Prayerful Posture. Center yourself. Slow your breathing.")
                            .font(DSFont.promptDisplay)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)

                        Text("Clear your mind of intrusive thoughts. Tap when ready.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    }
                    .padding(DSSpacing.lg)
                    .padding(DSSpacing.lg)
                    .transition(.opacity)

                    Button {
                        didConfirm.toggle()
                        onConfirm()
                    } label: {
                        Text("Tap to Begin")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 48)
                            .background(
                                Capsule() // Keep it round as requested
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(DSColor.goldLight, lineWidth: 2)
                                            .luminous()
                                    )
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    // Apply distinct breathing pulse to scale AND shadow (light)
                    .phaseAnimator([false, true], trigger: contentVisible) { content, phase in
                        content
                            .scaleEffect(reduceMotion ? 1.0 : (phase ? 1.015 : 0.985))
                            .shadow(
                                color: DSColor.goldLight.opacity(reduceMotion ? 0.25 : (phase ? 0.55 : 0.28)),
                                radius: reduceMotion ? 8 : (phase ? 14 : 8),
                                x: 0, y: 0
                            )
                    } animation: { phase in
                        reduceMotion ? AnimationConfig.examenControl : .easeInOut(duration: 2.4)
                    }
                    .sensoryFeedback(.success, trigger: didConfirm)
                    .transition(.opacity)

                    // Skip option for users who want to proceed without centering
                    Button {
                        onSkip?() ?? onConfirm()
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.top, DSSpacing.sm)
                    .accessibilityLabel("Skip prayerful posture")

                    Spacer(minLength: DSSpacing.xl)
                }
                .padding(DSSpacing.md)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Spacer()
                Button {
                    showExitAlert = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.white.opacity(0.82))
                        .padding(DSSpacing.md)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Exit")
            }
            .padding(.horizontal, DSSpacing.sm)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.32), Color.black.opacity(0.10), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .onAppear {
            // Trigger entrance animation
            withAnimation(AnimationConfig.examenPostureHandoff) {
                contentVisible = true
            }
        }
        .alert("Are you sure you want to Exit?", isPresented: $showExitAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Exit", role: .destructive) {
                dismiss() // Pops the view from the NavigationStack
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(1)
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AnimationConfig.fast, value: configuration.isPressed)
    }
}

#if DEBUG
#Preview {
    PrayerPostureView(onConfirm: {})
        .environment(AppSettings())
}
#endif
