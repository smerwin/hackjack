/// Shoe generation and mutation-pair selection (§5.1). Deliberately has no
/// knowledge of RunState/HackChargePool/scoring — resolving a mutation at
/// play time, where those matter, is GameEngine's job, not this one's.
public enum CorruptionGenerator {
    public static func buildShoe<G: RandomNumberGenerator>(
        shift: ShiftConfig,
        removedTypes: Set<MutationType>,
        using rng: inout G
    ) -> [Card] {
        var shoe: [Card] = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                shoe.append(Card(rank: rank, suit: suit))
            }
        }
        shoe.shuffle(using: &rng)

        let sparkProbability = Double.random(in: shift.corruptionDensity, using: &rng)
        for i in shoe.indices where Double.random(in: 0...1, using: &rng) < sparkProbability {
            markSparking(&shoe[i], tell: .visible, removedTypes: removedTypes, using: &rng)
        }
        return shoe
    }

    /// Marks a card as corrupted and rolls its pending mutation pair. Used
    /// both at shoe-build time and by hacks (player Jack/Spoof/Crash, dealer
    /// hacks) that newly corrupt a card mid-hand.
    public static func markSparking<G: RandomNumberGenerator>(
        _ card: inout Card,
        tell: SparkTell,
        removedTypes: Set<MutationType>,
        using rng: inout G
    ) {
        card.integrity = Int.random(in: 0...39, using: &rng)
        card.sparkTell = tell
        card.pendingMutations = pickMutationPair(excluding: removedTypes, using: &rng)
    }

    public static func pickMutationPair<G: RandomNumberGenerator>(
        excluding removed: Set<MutationType>,
        using rng: inout G
    ) -> (MutationType, MutationType) {
        let pool = MutationType.allCases.filter { !removed.contains($0) }
        precondition(pool.count >= 2, "at least two mutation types must remain purchasable-away from")
        let shuffled = pool.shuffled(using: &rng)
        return (shuffled[0], shuffled[1])
    }

    /// Resolves a card's pending mutation into a concrete rank change. Only
    /// ever called by GameEngine at the moment a hand "commits" to the card
    /// (§5.1) — never eagerly at generation time, or the tell system's
    /// legible-risk premise (see two mutations shown, one applied) breaks.
    @discardableResult
    public static func resolve<G: RandomNumberGenerator>(_ card: inout Card, otherRanksInHand: [Rank], using rng: inout G) -> MutationType? {
        guard let pair = card.pendingMutations else { return nil }
        let chosen = Bool.random(using: &rng) ? pair.0 : pair.1
        apply(chosen, to: &card, otherRanksInHand: otherRanksInHand, using: &rng)
        card.pendingMutations = nil
        card.sparkTell = nil
        return chosen
    }

    private static func apply<G: RandomNumberGenerator>(
        _ mutation: MutationType,
        to card: inout Card,
        otherRanksInHand: [Rank],
        using rng: inout G
    ) {
        switch mutation {
        case .volatileValue:
            card.rank = Rank.allCases.randomElement(using: &rng)!
        case .overload:
            card.rank = [.jack, .queen, .king, .ace].randomElement(using: &rng)!
        case .leech:
            // No adjacent-hand target exists until splits ship (§5.5); until
            // then it drains the card's own integrity further as a stand-in.
            card.integrity = max(0, card.integrity - 20)
        case .twinner:
            if let target = otherRanksInHand.randomElement(using: &rng) {
                card.rank = target
            } else {
                card.rank = Rank.allCases.randomElement(using: &rng)!
            }
        }
    }
}
