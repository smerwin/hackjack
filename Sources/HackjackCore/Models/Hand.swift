import Foundation

/// One tower's blackjack hand. There's no dealer and no "resolving" a
/// hand anymore — a tower just keeps whatever total its hand currently
/// has (busted or not) until the player redeals it. `power` is the one
/// piece of new logic this game actually runs on: a tower's live
/// damage/fire-rate *is* its hand's current total.
public struct Hand: Identifiable, Sendable {
    public let id: UUID
    public var cards: [Card]

    public init(id: UUID = UUID(), cards: [Card] = []) {
        self.id = id
        self.cards = cards
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

    /// The tower's live damage/fire-rate. A bust drops a tower to zero
    /// power until it's redealt — no rescue, no ceremony, just the
    /// direct consequence of pushing a hand too far.
    public var power: Int { isBusted ? 0 : bestValue }
}
