import Foundation

public struct Hand: Identifiable, Sendable {
    public let id: UUID
    public var cards: [Card]
    public var isSplitChild: Bool
    /// Split-cluster neighbors, for lateral infection (§5.5). Unused until
    /// splits ship — left in place so Hand's shape doesn't change later.
    public var adjacentHandIDs: [UUID]
    public var isStood: Bool
    /// Set only by `GameEngine.acceptBust()` — a bust no longer finalizes a
    /// hand by itself, so the player gets a real window to hack a card back
    /// under 21 before the loss locks in (see `isResolved`).
    public var bustLocked: Bool

    public init(id: UUID = UUID(), cards: [Card] = [], isSplitChild: Bool = false, adjacentHandIDs: [UUID] = []) {
        self.id = id
        self.cards = cards
        self.isSplitChild = isSplitChild
        self.adjacentHandIDs = adjacentHandIDs
        self.isStood = false
        self.bustLocked = false
    }

    /// Best total under standard soft-ace rules.
    public var bestValue: Int {
        var total = cards.reduce(0) { $0 + $1.rank.blackjackValue }
        var softAces = cards.filter { $0.rank == .ace }.count
        while total > 21 && softAces > 0 {
            total -= 10
            softAces -= 1
        }
        return total
    }

    public var isBusted: Bool { bestValue > 21 }
    public var isBlackjack: Bool { cards.count == 2 && bestValue == 21 }
    /// A bust alone no longer resolves a hand — only an explicit stand, or
    /// a bust the player has accepted via `acceptBust()`, does. This is
    /// what gives the player a real window to hack a card's rank back down
    /// before the loss locks in, instead of the turn ending the instant
    /// `bestValue` crosses 21.
    public var isResolved: Bool { isStood || (isBusted && bustLocked) }
    public var hasPendingSpark: Bool { cards.contains { $0.pendingMutations != nil } }
}
