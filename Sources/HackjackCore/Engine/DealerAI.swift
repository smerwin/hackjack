/// Dealer hack targeting (§5.4). Runs through the same
/// CorruptionGenerator.markSparking pipeline as the shoe itself and as
/// player hacks, so visible and hidden dealer hacks can't drift in behavior
/// from what a player-triggered corruption looks like.
public enum DealerAI {
    /// `attempts` > 1 and `forceHidden` exist only for Boss Corruptions
    /// (§5.8: Root Access doubles attempts, Ghost Protocol forces hidden) —
    /// both default to normal single-roll, tell-respecting behavior.
    public static func maybeHack<G: RandomNumberGenerator>(
        shift: ShiftConfig,
        removedTypes: Set<MutationType>,
        playerHands: inout [Hand],
        shoe: inout [Card],
        log: inout [String],
        attempts: Int = 1,
        forceHidden: Bool = false,
        using rng: inout G
    ) {
        for _ in 0..<max(1, attempts) {
            attemptOnce(
                shift: shift,
                removedTypes: removedTypes,
                playerHands: &playerHands,
                shoe: &shoe,
                log: &log,
                forceHidden: forceHidden,
                using: &rng
            )
        }
    }

    private static func attemptOnce<G: RandomNumberGenerator>(
        shift: ShiftConfig,
        removedTypes: Set<MutationType>,
        playerHands: inout [Hand],
        shoe: inout [Card],
        log: inout [String],
        forceHidden: Bool,
        using rng: inout G
    ) {
        guard Double.random(in: 0...1, using: &rng) < shift.dealerHackChance else { return }

        let attemptHidden = !shoe.isEmpty && (forceHidden || (shift.hiddenHacksUnlocked && Bool.random(using: &rng)))
        if attemptHidden {
            hackShoe(&shoe, removedTypes: removedTypes, log: &log, using: &rng)
            return
        }

        let liveHandIndices = playerHands.indices.filter { !playerHands[$0].cards.isEmpty && !playerHands[$0].isResolved }
        guard let targetIndex = liveHandIndices.randomElement(using: &rng) else { return }
        hackVisibleCard(in: &playerHands[targetIndex], removedTypes: removedTypes, log: &log, using: &rng)
    }

    private static func hackVisibleCard<G: RandomNumberGenerator>(
        in hand: inout Hand,
        removedTypes: Set<MutationType>,
        log: inout [String],
        using rng: inout G
    ) {
        let idx = Int.random(in: 0..<hand.cards.count, using: &rng)
        applyDealerHack(to: &hand.cards[idx], removedTypes: removedTypes, tell: .visible, using: &rng)
        log.append("\(FlavorText.dealerHackVisible(using: &rng)) (\(hand.cards[idx]))")
    }

    /// Targets the next card due to be drawn — the shoe-resident analog of
    /// "a face-down card you haven't looked at yet" (§5.4). Tell is muffled
    /// and carries no card identity, matching the "no HUD callouts" rule.
    private static func hackShoe<G: RandomNumberGenerator>(
        _ shoe: inout [Card],
        removedTypes: Set<MutationType>,
        log: inout [String],
        using rng: inout G
    ) {
        applyDealerHack(to: &shoe[0], removedTypes: removedTypes, tell: .hidden, using: &rng)
        log.append(FlavorText.dealerHackHidden(using: &rng))
    }

    private static func applyDealerHack<G: RandomNumberGenerator>(
        to card: inout Card,
        removedTypes: Set<MutationType>,
        tell: SparkTell,
        using rng: inout G
    ) {
        let type = DealerHackType.allCases.randomElement(using: &rng)!
        switch type {
        case .jack:
            let delta = Int.random(in: -3...3, using: &rng)
            card.rank = shiftedRank(card.rank, by: delta)
        case .spoof:
            card.suit = Suit.allCases.filter { $0 != card.suit }.randomElement(using: &rng)!
        case .crash:
            card.rank = Rank.allCases.randomElement(using: &rng)!
            card.suit = Suit.allCases.randomElement(using: &rng)!
        }
        CorruptionGenerator.markSparking(&card, tell: tell, removedTypes: removedTypes, using: &rng)
    }
}
