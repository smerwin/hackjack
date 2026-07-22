import SwiftUI

/// A card's entrance transition, styled to read as "flew in from the
/// shoe" — the shoe sits top-trailing in `TableView`, so newly-dealt cards
/// start offset up-and-right, small, faded, and slightly rotated, then
/// spring to their resting position.
///
/// This is deliberately *not* a `matchedGeometryEffect` tracking the
/// shoe's exact on-screen frame. That's the textbook technique (§6), but
/// verifying it in this environment means round-tripping through
/// `xcodebuild` + `simctl` + a static screenshot each time — no live
/// preview loop to catch a subtly-wrong anchor or axis. This stylized
/// version is far lower-risk to get right blind and still reads clearly
/// as "dealt from the shoe."
private struct DealModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: isActive ? -60 : 0, y: isActive ? -70 : 0)
            .scaleEffect(isActive ? 0.3 : 1)
            .opacity(isActive ? 0 : 1)
            .rotationEffect(.degrees(isActive ? -14 : 0))
    }
}

extension AnyTransition {
    /// Insertion only — pair with a plain removal transition for cards
    /// leaving the hand (e.g. a hand reset at the start of a new deal).
    static var dealt: AnyTransition {
        .modifier(active: DealModifier(isActive: true), identity: DealModifier(isActive: false))
    }
}
