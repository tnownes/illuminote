import SwiftUI

/// Centralized animation configuration for Examen transitions.
/// Changing durations here will adjust the pace of Examen animations app-wide.
enum AnimationConfig {

    /// Slow, reflective, gentle animation for immersive transitions.
    static let slow: Animation = .easeInOut(duration: 0.85)

    /// Medium pace animation — good for prompt transitions.
    static let medium: Animation = .easeInOut(duration: 0.45)

    /// Fast animation for controls, taps, and lightweight feedback.
    static let fast: Animation = .easeInOut(duration: 0.20)

    /// Spring effect for interactive elements (optional)
    static let spring: Animation = .spring(response: 0.45, dampingFraction: 0.75, blendDuration: 0.25)
    
    /// Very slow, deep breathing animation (4 seconds).
    static let breathing: Animation = .easeInOut(duration: 4.0)
    
    /// Standard transition for entering views (slow and meditative).
    static let transitionIn: Animation = .easeInOut(duration: 3.2)
    
    /// Standard transition for exiting views.
    static let transitionOut: Animation = .easeInOut(duration: 2.0)

    /// Calm handoff for Examen interstitials and screen changes.
    static let examenScreenChange: Animation = .easeInOut(duration: 0.30)

    /// Slightly quicker animation for moving between prompts.
    static let examenPromptAdvance: Animation = .easeInOut(duration: 0.22)

    /// Lightweight feedback animation for small control state changes.
    static let examenControl: Animation = .easeInOut(duration: 0.18)

    /// Calm handoff from prayer posture into the first reflective prompt.
    static let examenPostureHandoff: Animation = .easeInOut(duration: 1.0)

    /// Gentle crossfade for prompt-to-prompt changes.
    static let examenPromptCrossfade: Animation = .easeInOut(duration: 0.9)

    /// Fixed quiet dwell between prompts to encourage reflection without extending the motion itself.
    static let examenReflectiveHoldDuration: TimeInterval = 8.0

    /// Lead-in delay so the hold begins after the prompt has visually settled.
    static let examenReflectiveLeadInDuration: TimeInterval = 0.9
    
    /// Returns the appropriate animation for the given Examen step.
    static func forStep(_ step: Int) -> Animation {
        // Use breathing animation for deeper reflection steps (e.g. middle steps)
        // Adjust logic as needed.
        if step > 0 && step < 4 {
            return breathing
        }
        return medium
    }

    static func examenScreenTransition(reduceMotion: Bool) -> AnyTransition {
        .opacity
    }

    static func examenPromptTransition(reduceMotion: Bool) -> AnyTransition {
        .opacity
    }
}

extension View {
    
    /// Applies a "fade-like" navigation transition using iOS 18's .zoom if a source is valid,
    /// or falls back to standard behavior.
    ///
    /// Since iOS 18 does not nominally support a plain `.fade` navigation transition,
    /// we use `.zoom` where meaningful, or rely on standard transitions with customized `AnimationConfig` durations.
    @ViewBuilder
    func compat_navigationFade() -> some View {
        // In a real iOS 18 app, .zoom is the primary custom transition.
        // We will placeholder this to simply return self for now,
        // relying on .animation(...) modifiers applied alongside this to control timing.
        // If specific sources are available, use compat_zoomTransition instead.
        self
    }
    
    /// A compatibility wrapper for `matchedTransitionSource(id:in:)` that safely checks for iOS 18 availability.
    /// If the OS is older than iOS 18, this modifier does nothing.
    @ViewBuilder
    func compat_matchedTransitionSource(id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// A compatibility wrapper for `.navigationTransition(.zoom(...))` that safely checks for iOS 18 availability.
    /// If the OS is older than iOS 18, this applies a default/automatic transition.
    @ViewBuilder
    func compat_zoomTransition(sourceID: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }
}
