import Foundation

public enum Suit: CaseIterable, Sendable {
    case clubs, diamonds, hearts, spades

    public var symbol: String {
        switch self {
        case .clubs: return "♣"
        case .diamonds: return "♦"
        case .hearts: return "♥"
        case .spades: return "♠"
        }
    }
}

public enum Rank: Int, CaseIterable, Comparable, Sendable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king, ace

    public var blackjackValue: Int {
        switch self {
        case .ace: return 11
        case .jack, .queen, .king: return 10
        default: return rawValue
        }
    }

    public var symbol: String {
        switch self {
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        default: return "\(rawValue)"
        }
    }

    public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Shifts a rank by a signed delta, clamped to the Two...Ace range. Shared by
/// the player's Jack hack and the dealer's mirrored Jack hack (§5.3/§5.4) so
/// both sides run through identical logic.
public func shiftedRank(_ rank: Rank, by delta: Int) -> Rank {
    let clampedRaw = min(max(rank.rawValue + delta, Rank.two.rawValue), Rank.ace.rawValue)
    return Rank(rawValue: clampedRaw) ?? rank
}

public struct Card: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var rank: Rank
    public var suit: Suit
    /// Hidden stat; below a shift-scaled threshold the card is sparking. 0...100.
    public var integrity: Int
    /// nil when not corrupted. Set at generation or by a hack; cleared on resolve/Patch.
    public var sparkTell: SparkTell?
    /// The two mutations this card could resolve into. Shown to the player
    /// before they commit to an action that plays into the card (§5.1) —
    /// never resolved silently.
    public var pendingMutations: (MutationType, MutationType)?

    public init(rank: Rank, suit: Suit, integrity: Int = 100, id: UUID = UUID()) {
        self.id = id
        self.rank = rank
        self.suit = suit
        self.integrity = integrity
    }

    public static func == (lhs: Card, rhs: Card) -> Bool { lhs.id == rhs.id }
}

extension Card: CustomStringConvertible {
    public var description: String {
        "\(rank.symbol)\(suit.symbol)"
    }
}
