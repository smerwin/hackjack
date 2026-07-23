import SwiftUI

/// The tell for a dealer *hidden* hack (§5.4) — deliberately not pinned
/// to any card, since the whole point of "hidden" is that the player
/// shouldn't know which one just got hit; a per-card strike (`CardView`)
/// would leak exactly the information this hack is supposed to withhold.
/// A double-flicker edge glow reads as "muffled, at the edge of the
/// screen" (§5.2/§6's original, never-built spec for this), paired with
/// the haptic `GameViewModel` already fires alongside it.
struct HiddenHackFlashView: View {
    @State private var opacity: Double = 0

    var body: some View {
        Rectangle()
            .strokeBorder(Term.corruptionPurple, lineWidth: 14)
            .blur(radius: 18)
            .opacity(opacity)
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeOut(duration: 0.08)) { opacity = 0.9 }
                withAnimation(.easeIn(duration: 0.12).delay(0.1)) { opacity = 0.15 }
                withAnimation(.easeOut(duration: 0.08).delay(0.22)) { opacity = 0.75 }
                withAnimation(.easeIn(duration: 0.25).delay(0.3)) { opacity = 0 }
            }
    }
}
