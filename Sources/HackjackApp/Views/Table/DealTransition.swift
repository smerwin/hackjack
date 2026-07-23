import SwiftUI

/// Bubbles named views' on-screen frames (in the shared "table" coordinate
/// space `TableView` declares) up to wherever they're needed — used here
/// so the deal-in transition can compute a real shoe-to-hand vector
/// instead of a fixed guess.
struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Reports this view's frame under `key` without affecting its own
    /// layout size (the `GeometryReader` lives in `.background`, which
    /// sizes to the content, not the other way around).
    func reportFrame(_ key: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: FramePreferenceKey.self, value: [key: proxy.frame(in: .named("table"))])
            }
        )
    }
}

/// A card's entrance transition, styled to read as "flew in from the
/// shoe." `origin` is the real shoe → hand-row vector computed by
/// `TableView.dealOrigin(for:)` from frames reported via `reportFrame`,
/// not a fixed offset guessed relative to the card's own destination.
///
/// This still isn't a `matchedGeometryEffect` tracking each card's own
/// exact resting frame (§6) — `matchedGeometryEffect` assumes a source
/// view that gets removed as a same-id destination is inserted, which
/// doesn't fit a shoe that stays mounted on screen and spawns many cards
/// over the course of a hand. Using the *row's* frame rather than each
/// card's own is a deliberate approximation on top of that: every card in
/// a hand shares one origin vector rather than each one converging
/// exactly on the shoe's point. A truly per-card vector has its own
/// circularity problem anyway — a newly-inserted card can't have its own
/// frame measured in time to drive its own insertion transition — so the
/// row-level vector, combined with the existing per-card stagger delay in
/// `HandRowView`, is the practical fix: real, live geometry instead of a
/// constant, without chasing per-card precision that SwiftUI can't
/// deliver for a first-appearance transition anyway.
private struct DealModifier: ViewModifier {
    let isActive: Bool
    let origin: CGSize

    func body(content: Content) -> some View {
        content
            .offset(x: isActive ? origin.width : 0, y: isActive ? origin.height : 0)
            .scaleEffect(isActive ? 0.3 : 1)
            .opacity(isActive ? 0 : 1)
            .rotationEffect(.degrees(isActive ? -14 : 0))
    }
}

extension AnyTransition {
    /// Insertion only — pair with a plain removal transition for cards
    /// leaving the hand (e.g. a hand reset at the start of a new deal).
    static func dealt(from origin: CGSize) -> AnyTransition {
        .modifier(active: DealModifier(isActive: true, origin: origin), identity: DealModifier(isActive: false, origin: origin))
    }
}
