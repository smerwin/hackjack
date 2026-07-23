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

/// A card is now purely an identity — rank, suit, id. No integrity,
/// spark tell, or pending mutations: corruption/hacking are gone from
/// this game entirely (see CLAUDE.md's tower-defense reimagining). The
/// same `Card` type serves double duty as a tower's hand card and as a
/// mob's identity (`Mob.card`) — "mobs are a parade of cards," literally.
public struct Card: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var rank: Rank
    public var suit: Suit

    public init(rank: Rank, suit: Suit, id: UUID = UUID()) {
        self.id = id
        self.rank = rank
        self.suit = suit
    }

    public static func == (lhs: Card, rhs: Card) -> Bool { lhs.id == rhs.id }
}

extension Card: CustomStringConvertible {
    public var description: String {
        "\(rank.symbol)\(suit.symbol)"
    }
}
