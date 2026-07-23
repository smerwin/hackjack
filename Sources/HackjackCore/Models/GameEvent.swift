import Foundation

/// Discrete, typed signals for anything that wants to react to "something
/// just happened" without re-deriving it from state. Drained the same
/// way as the narrative log (`GameEngine.drainEvents()`); the App layer
/// uses these to drive haptics.
public enum GameEvent: Sendable, Equatable {
    case cardDealt
    case mobHit(mobID: UUID)
    case mobKilled(mobID: UUID)
    case baseHit
}
