/// Per-hand rule overrides a Boss Corruption applies (§5.8). Built fresh
/// each hand by GameEngine and left at its defaults unless a boss is live —
/// keeps boss one-offs out of the engine's normal control flow.
public struct HandRuleset: Sendable {
    public var patchAllowed: Bool = true
    public var dealerHackAttemptMultiplier: Int = 1
    public var playerBonusCharges: Int = 0
    public var hiddenHacksOnly: Bool = false
    public var fullShoeSpark: Bool = false
}

/// The four launch bosses (§5.8). Implemented as an enum rather than the
/// `protocol BossCorruption` sketch in §4 — with exactly four fixed,
/// non-extensible-at-runtime cases, a protocol added indirection without
/// buying anything; switch-exhaustiveness catches a missed case the same
/// way a missing conformance would.
public enum BossCorruption: CaseIterable, Equatable, Sendable {
    case firewallDown
    case rootAccess
    case blueScreen
    case ghostProtocol

    public var name: String {
        switch self {
        case .firewallDown: return "Firewall Down"
        case .rootAccess: return "Root Access"
        case .blueScreen: return "Blue Screen"
        case .ghostProtocol: return "Ghost Protocol"
        }
    }

    public var introLine: String {
        switch self {
        case .firewallDown: return "No patches today. Whatever sparks, you're wearing it."
        case .rootAccess: return "Everybody's got admin now. Try not to break the table."
        case .blueScreen: return "Every card's compromised. This was always going to happen eventually."
        case .ghostProtocol: return "You won't see this one coming. Listen instead."
        }
    }

    public func apply(to ruleset: inout HandRuleset) {
        switch self {
        case .firewallDown:
            ruleset.patchAllowed = false
        case .rootAccess:
            ruleset.dealerHackAttemptMultiplier = 2
            ruleset.playerBonusCharges = 2
        case .blueScreen:
            ruleset.fullShoeSpark = true
        case .ghostProtocol:
            ruleset.hiddenHacksOnly = true
        }
    }

    /// Deterministic per-Shift assignment so the same Shift always presents
    /// the same boss across retries after a loss, rather than re-rolling —
    /// telegraphing requires the boss to be knowable, not just visible once
    /// the hand has already started.
    public static func forShift(index: Int) -> BossCorruption {
        allCases[(index - 1) % allCases.count]
    }
}
