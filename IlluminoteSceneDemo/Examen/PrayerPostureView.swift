import SwiftUI
import AVFoundation

/// A calm, full-screen interstitial shown before Step 1 of the Examen.
/// - Shows a brief breathing cue and a prominent "Begin" action.
/// - Plays a subtle haptic via `sensoryFeedback` when beginning.
/// - Respects Reduce Motion by minimizing/omitting animations.
struct PrayerPostureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            if contentVisible {
                VStack(spacing: DSSpacing.xl) {
                    Spacer(minLength: DSSpacing.xl)

                    AppPanel(
                        title: nil,
                        subtitle: nil,
                        role: .reading,
                        highlighted: true
                    ) {
                        VStack(spacing: DSSpacing.md) {
                            Text("Settle into a prayerful posture.")
                                .font(DSFont.display)
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)
                                .foregroundStyle(DSColor.textPrimary)

                            Text("Slow your breathing. Let the noise of the day quiet down. When you are ready, begin with honesty and attention.")
                                .font(DSFont.supporting)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(DSColor.quietText)
                        }
                    }
                    .transition(.opacity)

                    Button {
                        didConfirm.toggle()
                        onConfirm()
                    } label: {
                        Text("Begin")
                    }
                    .buttonStyle(SacredButtonStyle())
                    .phaseAnimator([false, true], trigger: contentVisible) { content, phase in
                        content
                            .scaleEffect(reduceMotion ? 1.0 : (phase ? 1.01 : 0.99))
                            .shadow(
                                color: DSColor.brandAccent.opacity(reduceMotion ? 0.14 : (phase ? 0.22 : 0.12)),
                                radius: reduceMotion ? 6 : (phase ? 12 : 8),
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
                        Text("Skip for now")
                    }
                    .buttonStyle(.appQuiet)
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
                        .font(.headline)
                        .appCircleControl()
                }
                .accessibilityLabel("Exit")
            }
            .padding(.horizontal, DSSpacing.sm)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.28), Color.black.opacity(0.08), .clear],
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
