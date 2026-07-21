import Foundation

/// Drives one hand at a time within a run. Owns the shoe, both hands, and
/// RunState; views/CLI should only ever call these methods, never mutate
/// Card/Hand/RunState fields directly (§3).
public final class GameEngine {
    public private(set) var runState: RunState
    public private(set) var shiftConfig: ShiftConfig
    public private(set) var shoe: [Card] = []
    public private(set) var playerHand = Hand()
    public private(set) var dealerHand = Hand()

    private var log: [String] = []
    private var hacksUsedThisHand = false
    private var rng: SeededGenerator

    public enum HackError: Error, Sendable {
        case insufficientCharges
        case invalidTarget
    }

    public init(runState: RunState = RunState(), seed: UInt64? = nil) {
        self.runState = runState
        self.shiftConfig = ShiftConfig.standard(index: runState.currentShiftIndex)
        self.rng = SeededGenerator(seed: seed ?? UInt64.random(in: UInt64.min...UInt64.max))
    }

    /// Drains and returns narrative events accumulated since the last call —
    /// the CLI's (and later, SwiftUI's) only window into what just happened.
    public func drainLog() -> [String] {
        let entries = log
        log = []
        return entries
    }

    public func startHand() {
        shiftConfig = ShiftConfig.standard(index: runState.currentShiftIndex)
        shoe = CorruptionGenerator.buildShoe(shift: shiftConfig, removedTypes: runState.removedCorruptionTypes, using: &rng)
        playerHand = Hand()
        dealerHand = Hand()
        hacksUsedThisHand = false

        playerHand.cards.append(drawCard())
        dealerHand.cards.append(drawCard())
        playerHand.cards.append(drawCard())
        dealerHand.cards.append(drawCard())

        for card in playerHand.cards {
            if let pair = card.pendingMutations {
                log.append("Your \(card) is sparking — could resolve to \(pair.0) or \(pair.1).")
            }
        }
        if let upcard = dealerHand.cards.first, let pair = upcard.pendingMutations {
            log.append("Dealer's \(upcard) is sparking — could resolve to \(pair.0) or \(pair.1).")
        }
    }

    private func drawCard() -> Card {
        if shoe.isEmpty {
            shoe = CorruptionGenerator.buildShoe(shift: shiftConfig, removedTypes: runState.removedCorruptionTypes, using: &rng)
            log.append("Shoe exhausted — fresh packets compiled mid-hand.")
        }
        return shoe.removeFirst()
    }

    /// Resolves every pending spark in a hand. Called at the top of any
    /// player/dealer action that "commits" to the hand (hit or stand) —
    /// never eagerly — so a sparking card's two-mutation range is always
    /// visible to the player for at least one full decision before it
    /// resolves (§5.1).
    private func resolvePendingSparks(in hand: inout Hand) {
        for i in hand.cards.indices where hand.cards[i].pendingMutations != nil {
            let before = "\(hand.cards[i])"
            let otherRanks = hand.cards.indices.filter { $0 != i }.map { hand.cards[$0].rank }
            CorruptionGenerator.resolve(&hand.cards[i], otherRanksInHand: otherRanks, using: &rng)
            log.append("Spark resolved: \(before) -> \(hand.cards[i]).")
        }
    }

    public func playerHit() {
        resolvePendingSparks(in: &playerHand)
        DealerAI.maybeHack(
            shift: shiftConfig,
            removedTypes: runState.removedCorruptionTypes,
            playerHand: &playerHand,
            shoe: &shoe,
            log: &log,
            using: &rng
        )
        let card = drawCard()
        playerHand.cards.append(card)
        if let pair = card.pendingMutations {
            log.append("Dealt \(card) — sparking (\(pair.0)/\(pair.1)).")
        } else {
            log.append("Dealt \(card).")
        }
        if playerHand.isBusted {
            playerHand.isStood = true
        }
    }

    public func playerStand() {
        resolvePendingSparks(in: &playerHand)
        playerHand.isStood = true
    }

    public func playerHack(_ type: PlayerHackType, targetIsDealer: Bool = false, cardID: UUID? = nil) throws {
        let cost = hackCost(type)
        guard runState.chargePool.current >= cost else { throw HackError.insufficientCharges }

        if type == .peek {
            runState.chargePool.spend(cost)
            if let hole = dealerHand.cards.dropFirst().first {
                log.append("Peek: dealer hole card is \(hole).")
            } else {
                log.append("Peek: no hole card to read.")
            }
            hacksUsedThisHand = true
            return
        }

        guard let cardID else { throw HackError.invalidTarget }
        var hand = targetIsDealer ? dealerHand : playerHand
        guard let idx = hand.cards.firstIndex(where: { $0.id == cardID }) else {
            throw HackError.invalidTarget
        }
        runState.chargePool.spend(cost)

        switch type {
        case .jack:
            let delta = Int.random(in: -3...3, using: &rng)
            hand.cards[idx].rank = shiftedRank(hand.cards[idx].rank, by: delta)
            hand.cards[idx].sparkTell = .visible
        case .spoof:
            hand.cards[idx].suit = Suit.allCases.filter { $0 != hand.cards[idx].suit }.randomElement(using: &rng)!
            hand.cards[idx].sparkTell = .visible
        case .crash:
            var fresh = Card(rank: Rank.allCases.randomElement(using: &rng)!, suit: Suit.allCases.randomElement(using: &rng)!)
            fresh.sparkTell = .visible
            hand.cards[idx] = fresh
        case .patch:
            hand.cards[idx].sparkTell = nil
            hand.cards[idx].pendingMutations = nil
            hand.cards[idx].integrity = 100
        case .peek:
            break // handled above; unreachable here
        }

        log.append("You \(type.rawValue)ed \(hand.cards[idx]).")
        if targetIsDealer { dealerHand = hand } else { playerHand = hand }
        hacksUsedThisHand = true
    }

    /// Patch costs double in a Shift's high-density ("Critical") band (§5.3).
    private func hackCost(_ type: PlayerHackType) -> Int {
        guard type == .patch else { return 1 }
        let mid = (shiftConfig.corruptionDensity.lowerBound + shiftConfig.corruptionDensity.upperBound) / 2
        return mid >= 0.35 ? 2 : 1
    }

    public func playDealerTurn() {
        resolvePendingSparks(in: &dealerHand)
        while dealerHand.bestValue < 17 && !dealerHand.isBusted {
            dealerHand.cards.append(drawCard())
            resolvePendingSparks(in: &dealerHand)
        }
        dealerHand.isStood = true
    }

    public func settleHand() -> HandOutcome {
        let outcome: HandOutcome
        if playerHand.isBusted {
            outcome = .playerBust
        } else if dealerHand.isBusted {
            outcome = .dealerBust
        } else if playerHand.isBlackjack && !dealerHand.isBlackjack {
            outcome = .playerBlackjack
        } else if dealerHand.isBlackjack && !playerHand.isBlackjack {
            outcome = .dealerBlackjack
        } else if playerHand.bestValue > dealerHand.bestValue {
            outcome = .playerWin
        } else if playerHand.bestValue < dealerHand.bestValue {
            outcome = .dealerWin
        } else {
            outcome = .push
        }

        let shiftBefore = runState.currentShiftIndex
        ScoringEngine.apply(outcome: outcome, usedHacksThisHand: hacksUsedThisHand, shiftConfig: shiftConfig, runState: &runState)
        if runState.currentShiftIndex != shiftBefore {
            log.append("Shift \(shiftBefore) cleared. Compiling Shift \(runState.currentShiftIndex)...")
        }
        return outcome
    }
}
