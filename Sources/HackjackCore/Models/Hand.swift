import Foundation

public struct Hand: Identifiable, Sendable {
    public let id: UUID
    public var cards: [Card]
    public var isSplitChild: Bool
    /// Split-cluster neighbors, for lateral infection (§5.5). Unused until
    /// splits ship — left in place so Hand's shape doesn't change later.
    public var adjacentHandIDs: [UUID]
    public var isStood: Bool

    public init(id: UUID = UUID(), cards: [Card] = [], isSplitChild: Bool = false, adjacentHandIDs: [UUID] = []) {
        self.id = id
        self.cards = cards
        self.isSplitChild = isSplitChild
        self.adjacentHandIDs = adjacentHandIDs
        self.isStood = false
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
    public var isResolved: Bool { isStood || isBusted }
    public var hasPendingSpark: Bool { cards.contains { $0.pendingMutations != nil } }
}
