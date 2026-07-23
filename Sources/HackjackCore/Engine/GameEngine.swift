import Foundation

/// Drives one hand at a time within a run. Owns the shoe, all live player
/// hands, the dealer hand, and RunState; views/CLI should only ever call
/// these methods, never mutate Card/Hand/RunState fields directly (§3).
public final class GameEngine {
    public private(set) var runState: RunState
    public private(set) var shiftConfig: ShiftConfig
    public private(set) var shoe: [Card] = []
    public private(set) var playerHands: [Hand] = [Hand()]
    public private(set) var activeHandIndex: Int = 0
    public private(set) var dealerHand = Hand()
    public private(set) var currentBoss: BossCorruption?
    public private(set) var ruleset = HandRuleset()
    public private(set) var pendingFirmwareOffer: FirmwareMutation?
    public private(set) var pendingShopOffers: [ShopOffer]?

    private var effectiveShift: ShiftConfig
    private var log: [String] = []
    private var events: [GameEvent] = []
    private var hacksUsedThisHand = false
    private var guardDaemonUsedThisHand = false
    private var sparkedMutationsThisHand: Set<MutationType> = []
    private var rng: SeededGenerator

    public enum HackError: Error, Equatable, Sendable {
        case insufficientCharges
        case invalidTarget
        case patchDisabled
    }

    public var activeHand: Hand { playerHands[activeHandIndex] }
    public var allPlayerHandsResolved: Bool { playerHands.allSatisfy { $0.isResolved } }

    public init(runState: RunState = RunState(), seed: UInt64? = nil) {
        self.runState = runState
        self.shiftConfig = ShiftConfig.standard(index: runState.currentShiftIndex)
        self.effectiveShift = self.shiftConfig
        self.rng = SeededGenerator(seed: runState.seed ?? seed ?? UInt64.random(in: UInt64.min...UInt64.max))
    }

    /// Drains and returns narrative events accumulated since the last call —
    /// the CLI's (and later, SwiftUI's) only window into what just happened.
    public func drainLog() -> [String] {
        let entries = log
        log = []
        return entries
    }

    /// Drains and returns discrete events since the last call — the App
    /// layer's hook for haptics (§5.2, §0's documented hidden-hack-tell
    /// gap). Same drain-on-read shape as `drainLog()`, kept separate
    /// because consumers act on these, not display them.
    public func drainEvents() -> [GameEvent] {
        let entries = events
        events = []
        return entries
    }

    public func startHand() {
        // Auto-decline anything the caller left unresolved from the previous
        // hand/Shift-clear rather than hard-blocking (§0 documented tradeoff).
        pendingFirmwareOffer = nil
        pendingShopOffers = nil

        shiftConfig = ShiftConfig.standard(index: runState.currentShiftIndex)
        ruleset = HandRuleset()
        let isBossHand = runState.streakWithinShift == shiftConfig.targetStreak - 1
        if isBossHand {
            let boss = BossCorruption.forShift(index: shiftConfig.index)
            currentBoss = boss
            boss.apply(to: &ruleset)
            log.append("BOSS CORRUPTION — \(boss.name): \(boss.introLine)")
        } else {
            currentBoss = nil
        }

        effectiveShift = ruleset.fullShoeSpark
            ? ShiftConfig(index: shiftConfig.index, targetStreak: shiftConfig.targetStreak, corruptionDensity: 1.0...1.0, dealerHackChance: shiftConfig.dealerHackChance, hiddenHacksUnlocked: shiftConfig.hiddenHacksUnlocked)
            : shiftConfig

        shoe = CorruptionGenerator.buildShoe(shift: effectiveShift, removedTypes: runState.removedCorruptionTypes, using: &rng)
        if runState.firmware.has(.aceStorm) {
            applyAceStorm()
        }

        playerHands = [Hand()]
        activeHandIndex = 0
        dealerHand = Hand()
        hacksUsedThisHand = false
        guardDaemonUsedThisHand = false
        sparkedMutationsThisHand = []

        // Passive floor, not a general regen: only kicks in from a fully
        // drained pool, and only 1 charge, so running out mid-Shift never
        // permanently locks the player out of hacking, but charges still
        // stay a real resource otherwise (a Shift-clear refill already
        // covers the non-empty case via ScoringEngine).
        if runState.chargePool.current == 0 && runState.chargePool.max > 0 {
            runState.chargePool.current = 1
            log.append(FlavorText.chargeRegen(using: &rng))
        }

        if ruleset.playerBonusCharges > 0 {
            runState.chargePool.current += ruleset.playerBonusCharges
        }

        playerHands[0].cards.append(drawCard())
        dealerHand.cards.append(drawCard())
        playerHands[0].cards.append(drawCard())
        dealerHand.cards.append(drawCard())

        for card in playerHands[0].cards {
            if let pair = card.pendingMutations {
                log.append("Your \(card) is sparking — could resolve to \(pair.0) or \(pair.1).")
            }
        }
        if let upcard = dealerHand.cards.first, let pair = upcard.pendingMutations {
            log.append("Dealer's \(upcard) is sparking — could resolve to \(pair.0) or \(pair.1).")
        }
    }

    private func applyAceStorm() {
        let boostCount = min(3, shoe.count)
        for i in shoe.indices.shuffled(using: &rng).prefix(boostCount) {
            shoe[i].rank = .ace
        }
    }

    private func drawCard() -> Card {
        if shoe.isEmpty {
            shoe = CorruptionGenerator.buildShoe(shift: effectiveShift, removedTypes: runState.removedCorruptionTypes, using: &rng)
            log.append("Shoe exhausted — fresh packets compiled mid-hand.")
        }
        let card = shoe.removeFirst()
        events.append(.cardDealt)
        return card
    }

    /// Resolves every pending spark in a hand. Called at the top of any
    /// player/dealer action that "commits" to the hand (hit or stand) —
    /// never eagerly — so a sparking card's two-mutation range is always
    /// visible to the player for at least one full decision before it
    /// resolves (§5.1). Returns whether a Leech fired, so callers touching
    /// `playerHands` can apply lateral infection *after* this returns —
    /// doing it inside would alias `playerHands` while one element is still
    /// exclusively borrowed via `inout`.
    @discardableResult
    private func resolvePendingSparks(in hand: inout Hand) -> Bool {
        var leechFired = false
        for i in hand.cards.indices where hand.cards[i].pendingMutations != nil {
            let before = "\(hand.cards[i])"
            let otherRanks = hand.cards.indices.filter { $0 != i }.map { hand.cards[$0].rank }
            let pair = hand.cards[i].pendingMutations!

            if runState.firmware.has(.guardDaemon) && !guardDaemonUsedThisHand {
                hand.cards[i].sparkTell = nil
                hand.cards[i].pendingMutations = nil
                hand.cards[i].integrity = 100
                guardDaemonUsedThisHand = true
                log.append("Guard Daemon patches \(before) before it can resolve. Free of charge.")
                continue
            }

            var preferred: MutationType?
            if runState.favorableMutationCharges > 0 {
                preferred = favorablePick(from: pair)
            } else if runState.firmware.has(.twinnerLoop) {
                preferred = twinnerLoopPick(from: pair)
            }
            let floor = runState.firmware.has(.leechWard) ? 50 : 0

            let mutation = CorruptionGenerator.resolve(&hand.cards[i], otherRanksInHand: otherRanks, preferredMutation: preferred, integrityFloor: floor, using: &rng)
            if runState.favorableMutationCharges > 0 {
                runState.favorableMutationCharges -= 1
            }
            if let mutation {
                sparkedMutationsThisHand.insert(mutation)
            }

            if mutation == .leech {
                log.append(FlavorText.leechResolve(card: before, integrity: hand.cards[i].integrity, using: &rng))
                leechFired = true
            } else {
                log.append("Spark resolved: \(before) -> \(hand.cards[i]).")
            }
        }
        return leechFired
    }

    private func favorablePick(from pair: (MutationType, MutationType)) -> MutationType {
        if pair.0 == .leech && pair.1 != .leech { return pair.1 }
        if pair.1 == .leech && pair.0 != .leech { return pair.0 }
        return pair.0
    }

    private func twinnerLoopPick(from pair: (MutationType, MutationType)) -> MutationType? {
        if pair.0 == .twinner || pair.0 == .volatileValue { return pair.0 }
        if pair.1 == .twinner || pair.1 == .volatileValue { return pair.1 }
        return nil
    }

    /// Leech's "steal integrity from an adjacent hand" (§5.5) — the only
    /// place that can see other live hands, so it lives here rather than in
    /// CorruptionGenerator.
    private func applyLateralInfection(sourceIndex: Int) {
        guard playerHands.count > 1 else { return }
        let source = playerHands[sourceIndex]
        let neighborIndices = playerHands.indices.filter {
            $0 != sourceIndex && source.adjacentHandIDs.contains(playerHands[$0].id) && !playerHands[$0].cards.isEmpty
        }
        guard let targetIndex = neighborIndices.randomElement(using: &rng) else { return }
        guard Double.random(in: 0...1, using: &rng) < 0.5 else { return }
        let cardIndices = playerHands[targetIndex].cards.indices.filter { playerHands[targetIndex].cards[$0].sparkTell == nil }
        guard let cardIndex = cardIndices.randomElement(using: &rng) else { return }
        CorruptionGenerator.markSparking(&playerHands[targetIndex].cards[cardIndex], tell: .visible, removedTypes: runState.removedCorruptionTypes, using: &rng)
        log.append("The leech jumps the gap — Hand \(targetIndex + 1) just sparked too.")
    }

    private func dealerMaybeHack() {
        DealerAI.maybeHack(
            shift: shiftConfig,
            removedTypes: runState.removedCorruptionTypes,
            playerHands: &playerHands,
            shoe: &shoe,
            log: &log,
            events: &events,
            attempts: ruleset.dealerHackAttemptMultiplier,
            forceHidden: ruleset.hiddenHacksOnly,
            using: &rng
        )
    }

    public func playerHit() {
        var hand = playerHands[activeHandIndex]
        let leeched = resolvePendingSparks(in: &hand)
        playerHands[activeHandIndex] = hand
        if leeched { applyLateralInfection(sourceIndex: activeHandIndex) }

        dealerMaybeHack()

        let card = drawCard()
        playerHands[activeHandIndex].cards.append(card)
        if let pair = card.pendingMutations {
            log.append("Dealt \(card) — sparking (\(pair.0)/\(pair.1)).")
        } else {
            log.append("Dealt \(card).")
        }
        // A bust no longer locks the hand in by itself — it stays live
        // (isResolved stays false) until acceptBust() finalizes it, so the
        // player has a real window to Jack/Crash a card back under 21
        // first. See Hand.isResolved and acceptBust() below.
        if playerHands[activeHandIndex].isBusted {
            log.append(FlavorText.bustReprieve(using: &rng))
        }
        advanceActiveHandIfNeeded()
    }

    /// Locks in a bust the player has chosen not to (or can't) hack their
    /// way out of. Only meaningful on an already-busted active hand; a
    /// no-op otherwise so callers don't need to guard before calling it.
    public func acceptBust() {
        guard playerHands[activeHandIndex].isBusted else { return }
        playerHands[activeHandIndex].bustLocked = true
        advanceActiveHandIfNeeded()
    }

    public func playerStand() {
        var hand = playerHands[activeHandIndex]
        let leeched = resolvePendingSparks(in: &hand)
        playerHands[activeHandIndex] = hand
        if leeched { applyLateralInfection(sourceIndex: activeHandIndex) }
        playerHands[activeHandIndex].isStood = true
        advanceActiveHandIfNeeded()
    }

    private func advanceActiveHandIfNeeded() {
        guard playerHands[activeHandIndex].isResolved else { return }
        if let nextIndex = playerHands.indices.first(where: { $0 > activeHandIndex && !playerHands[$0].isResolved }) {
            activeHandIndex = nextIndex
        }
    }

    public func canSplitActiveHand() -> Bool {
        guard playerHands.count < 4 else { return false }
        let hand = playerHands[activeHandIndex]
        return hand.cards.count == 2 && hand.cards[0].rank == hand.cards[1].rank
    }

    public func playerSplit() throws {
        guard canSplitActiveHand() else { throw HackError.invalidTarget }
        let hand = playerHands[activeHandIndex]

        var first = Hand(isSplitChild: true)
        first.cards = [hand.cards[0], drawCard()]
        var second = Hand(isSplitChild: true)
        second.cards = [hand.cards[1], drawCard()]

        playerHands[activeHandIndex] = first
        playerHands.insert(second, at: activeHandIndex + 1)
        relinkAdjacency()
        log.append("Hand split — \(playerHands.count) live now. Charges stay shared across all of them.")
    }

    private func relinkAdjacency() {
        for i in playerHands.indices {
            var neighbors: [UUID] = []
            if i > 0 { neighbors.append(playerHands[i - 1].id) }
            if i < playerHands.count - 1 { neighbors.append(playerHands[i + 1].id) }
            playerHands[i].adjacentHandIDs = neighbors
        }
    }

    public func playerHack(_ type: PlayerHackType, targetIsDealer: Bool = false, targetHandIndex: Int? = nil, cardID: UUID? = nil) throws {
        if type == .patch && !ruleset.patchAllowed {
            throw HackError.patchDisabled
        }
        let cost = hackCost(type)
        guard runState.chargePool.current >= cost else { throw HackError.insufficientCharges }

        if type == .peek {
            runState.chargePool.spend(cost)
            let confirm = FlavorText.hackConfirm(.peek, using: &rng)
            if let hole = dealerHand.cards.dropFirst().first {
                log.append("\(confirm) Hole card: \(hole).")
            } else {
                log.append("\(confirm) No hole card to read.")
            }
            hacksUsedThisHand = true
            return
        }

        guard let cardID else { throw HackError.invalidTarget }

        if targetIsDealer {
            guard let idx = dealerHand.cards.firstIndex(where: { $0.id == cardID }) else {
                throw HackError.invalidTarget
            }
            runState.chargePool.spend(cost)
            applyPlayerHackEffect(type, to: &dealerHand.cards[idx])
            log.append("\(FlavorText.hackConfirm(type, using: &rng)) (\(dealerHand.cards[idx]))")
            events.append(.hackTriggered(visible: true))
        } else {
            let handIdx = targetHandIndex ?? activeHandIndex
            guard playerHands.indices.contains(handIdx),
                  let idx = playerHands[handIdx].cards.firstIndex(where: { $0.id == cardID }) else {
                throw HackError.invalidTarget
            }
            runState.chargePool.spend(cost)
            applyPlayerHackEffect(type, to: &playerHands[handIdx].cards[idx])
            log.append("\(FlavorText.hackConfirm(type, using: &rng)) (\(playerHands[handIdx].cards[idx]))")
            events.append(.hackTriggered(visible: true))
        }
        hacksUsedThisHand = true
    }

    private func applyPlayerHackEffect(_ type: PlayerHackType, to card: inout Card) {
        switch type {
        case .jack:
            let delta = Int.random(in: -3...3, using: &rng)
            card.rank = shiftedRank(card.rank, by: delta)
            CorruptionGenerator.markSparking(&card, tell: .visible, removedTypes: runState.removedCorruptionTypes, using: &rng)
        case .spoof:
            card.suit = Suit.allCases.filter { $0 != card.suit }.randomElement(using: &rng)!
            CorruptionGenerator.markSparking(&card, tell: .visible, removedTypes: runState.removedCorruptionTypes, using: &rng)
        case .crash:
            card = Card(rank: Rank.allCases.randomElement(using: &rng)!, suit: Suit.allCases.randomElement(using: &rng)!)
            CorruptionGenerator.markSparking(&card, tell: .visible, removedTypes: runState.removedCorruptionTypes, using: &rng)
        case .patch:
            card.sparkTell = nil
            card.pendingMutations = nil
            card.integrity = 100
        case .peek:
            break // handled above; unreachable here
        }
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

    public func settleHands() -> [HandOutcome] {
        let outcomes = playerHands.map { outcome(for: $0) }

        runState.handsPlayedThisShift += 1
        let shiftBefore = runState.currentShiftIndex
        for outcome in outcomes {
            ScoringEngine.apply(outcome: outcome, usedHacksThisHand: hacksUsedThisHand, shiftConfig: shiftConfig, runState: &runState)
        }

        checkFirmwareOffer(outcomes: outcomes)

        if runState.currentShiftIndex != shiftBefore {
            log.append("Shift \(shiftBefore) cleared. Compiling Shift \(runState.currentShiftIndex)...")
            runState.handsPlayedThisShift = 0
            generateShopOffers()
        } else {
            checkSystemPurge()
        }

        return outcomes
    }

    private func outcome(for hand: Hand) -> HandOutcome {
        if hand.isBusted { return .playerBust }
        if dealerHand.isBusted { return .dealerBust }
        if hand.isBlackjack && !dealerHand.isBlackjack { return .playerBlackjack }
        if dealerHand.isBlackjack && !hand.isBlackjack { return .dealerBlackjack }
        if hand.bestValue > dealerHand.bestValue { return .playerWin }
        if hand.bestValue < dealerHand.bestValue { return .dealerWin }
        return .push
    }

    /// Per-Shift density meter (§5.9) — density itself doesn't literally
    /// accumulate card-by-card here (every hand already rebuilds a fresh
    /// shoe; see §0), so this counts hands played without clearing the
    /// Shift instead, as the practical equivalent of "things are getting
    /// out of hand" that a Purge should relieve.
    private func checkSystemPurge() {
        let purgeThreshold = shiftConfig.targetStreak * 2
        guard runState.handsPlayedThisShift >= purgeThreshold else { return }
        runState.handsPlayedThisShift = 0
        log.append(FlavorText.systemPurge(using: &rng))
    }

    private func checkFirmwareOffer(outcomes: [HandOutcome]) {
        guard !runState.firmware.isFull else { return }
        let favorable = outcomes.contains { $0 == .playerWin || $0 == .playerBlackjack || $0 == .dealerBust }
        guard favorable, !sparkedMutationsThisHand.isEmpty else { return }
        let available = FirmwareEffect.allCases.filter { !runState.firmware.has($0) }
        guard let effect = available.randomElement(using: &rng) else { return }
        let offer = FirmwareMutation(effect: effect)
        pendingFirmwareOffer = offer
        log.append("Firmware offer — keep \(effect.displayName)? \(effect.flavorDescription)")
    }

    public func keepFirmwareOffer(replacing replacedID: UUID? = nil) {
        guard let offer = pendingFirmwareOffer else { return }
        if let replacedID {
            runState.firmware.equipped.removeAll { $0.id == replacedID }
        }
        guard !runState.firmware.isFull else {
            log.append("Firmware slots full — \(offer.effect.displayName) let go.")
            pendingFirmwareOffer = nil
            return
        }
        runState.firmware.equipped.append(offer)
        log.append("\(offer.effect.displayName) kept. It's yours for the rest of the run.")
        pendingFirmwareOffer = nil
    }

    public func declineFirmwareOffer() {
        pendingFirmwareOffer = nil
    }

    private func generateShopOffers() {
        var offers = [
            ShopOffer(id: .extraCharge, title: "Extra Charge", description: "+1 starting hack charge for future hands.", cost: 3),
            ShopOffer(id: .favorableMutationToken, title: "Favorable Range Token", description: "Your next 3 sparks avoid Leech when the pair allows it.", cost: 4),
        ]
        if runState.removedCorruptionTypes.count < 2 {
            offers.append(ShopOffer(id: .removeCorruptionType, title: "Strip a Corruption Type", description: "Permanently remove one mutation type from the pool.", cost: 5))
        }
        if runState.firmware.capacity < 7 {
            offers.append(ShopOffer(id: .extraFirmwareSlot, title: "Firmware Slot", description: "+1 Firmware slot capacity.", cost: 6))
        }
        if !runState.isDailyBreach {
            offers.append(ShopOffer(id: .reroll, title: "Reroll Offers", description: "Regenerate this shop's offers.", cost: 1))
        }
        pendingShopOffers = offers
    }

    public func purchaseShopOffer(_ kind: ShopOfferKind) {
        guard let offers = pendingShopOffers, let offer = offers.first(where: { $0.id == kind }) else { return }
        guard runState.shopCurrency >= offer.cost else {
            log.append("Not enough currency for \(offer.title).")
            return
        }
        runState.shopCurrency -= offer.cost
        switch kind {
        case .extraCharge:
            runState.chargePool.max += 1
            runState.chargePool.current += 1
        case .favorableMutationToken:
            runState.favorableMutationCharges += 3
        case .removeCorruptionType:
            let removable = MutationType.allCases.filter { !runState.removedCorruptionTypes.contains($0) }
            if let choice = removable.randomElement(using: &rng) {
                runState.removedCorruptionTypes.insert(choice)
            }
        case .extraFirmwareSlot:
            runState.firmware.capacity += 1
        case .reroll:
            break
        }
        log.append("Purchased: \(offer.title).")
        generateShopOffers()
    }

    public func closeShop() {
        pendingShopOffers = nil
    }
}
