import Foundation

/// One enemy in the parade marching on the base. Wraps a `Card` rather
/// than inventing a parallel identity — "mobs are a parade of cards" is
/// literal, and it means mob rendering can reuse `CardView` directly.
public struct Mob: Identifiable, Sendable {
    public let id: UUID
    public let card: Card
    public var hp: Int
    /// Ticks (player actions) remaining until this mob reaches the base.
    public var stepsRemaining: Int

    public init(card: Card, hp: Int, stepsRemaining: Int) {
        self.id = card.id
        self.card = card
        self.hp = hp
        self.stepsRemaining = stepsRemaining
    }

    public var isDead: Bool { hp <= 0 }
    public var hasReachedBase: Bool { stepsRemaining <= 0 }
}
