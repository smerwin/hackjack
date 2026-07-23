/// Discrete, typed signals for anything that wants to react to "something
/// just happened" without re-deriving it from card state or parsing log
/// text (§5.2's "single source of truth" principle, extended to timing
/// rather than state). Drained the same way as the narrative log
/// (`GameEngine.drainEvents()`), but consumers act on these instead of
/// scanning `Card.sparkTell` deltas — the App layer uses this to drive
/// haptics, including for hidden dealer hacks, which otherwise have no
/// tell at all in the SwiftUI target (§5.2, §0).
public enum GameEvent: Sendable, Equatable {
    case cardDealt
    /// `visible: true` for a player hack or a dealer hack landing on an
    /// on-screen card — the App layer can strike that exact `CardView`,
    /// since `Card.rank`/`.suit` changing in place is itself the signal
    /// (no extra payload needed here). `visible: false` is a dealer
    /// hidden hack, which has no on-screen card to point at — the App
    /// layer instead fires an ambient, location-less cue (§5.2's "hidden
    /// hacks get no visual tell pinned to a card" carried into this
    /// event, not just into rendering).
    case hackTriggered(visible: Bool)
}
