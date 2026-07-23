import Foundation

/// Drives the tower-defense loop: `towerCount` towers each playing a
/// dealer-less blackjack hand, a parade of mobs marching on the base,
/// every tower auto-firing its hand's live total at the frontmost mob on
/// every player action. No hacks, no corruption, no dealer — see
/// CLAUDE.md for how this replaced the original hacking-blackjack design.
public final class GameEngine {
    public private(set) var runState: RunState
    public private(set) var stageConfig: StageConfig
    public private(set) var towers: [Hand]
    public private(set) var mobs: [Mob] = []
    public let towerCount: Int

    private var shoe: [Card] = []
    private var mobSpawnQueue: [Card] = []
    private var log: [String] = []
    private var events: [GameEvent] = []
    private var rng: SeededGenerator

    /// Sum of every live tower's current power — what the frontmost mob
    /// takes each tick.
    public var totalPower: Int { towers.reduce(0) { $0 + $1.power } }
    public var shoeCount: Int { shoe.count }
    public var isStageCleared: Bool { mobSpawnQueue.isEmpty && mobs.isEmpty }
    public var isDefeated: Bool { runState.baseHP <= 0 }

    public init(runState: RunState = RunState(), towerCount: Int = 3, seed: UInt64? = nil) {
        self.runState = runState
        self.towerCount = towerCount
        self.stageConfig = StageConfig.standard(index: runState.stageIndex)
        self.towers = Array(repeating: Hand(), count: towerCount)
        self.rng = SeededGenerator(seed: runState.seed ?? seed ?? UInt64.random(in: UInt64.min...UInt64.max))
    }

    /// Drains and returns narrative events accumulated since the last
    /// call — the CLI's and SwiftUI's only window into what just happened.
    public func drainLog() -> [String] {
        let entries = log
        log = []
        return entries
    }

    /// Drains and returns discrete events since the last call — the App
    /// layer's hook for haptics.
    public func drainEvents() -> [GameEvent] {
        let entries = events
        events = []
        return entries
    }

    /// (Re)starts the stage at `runState.stageIndex`: fresh shoe, fresh
    /// mob queue, every tower redealt. Also what a defeat or a clear
    /// calls internally to move on — callers only need to invoke this
    /// once, at launch.
    public func startStage() {
        stageConfig = StageConfig.standard(index: runState.stageIndex)
        shoe = freshShoe()
        mobs = []
        mobSpawnQueue = buildMobSpawnQueue(for: stageConfig)
        towers = (0..<towerCount).map { _ in dealFreshHand() }
        log.append("Stage \(stageConfig.index) — \(stageConfig.mobCount) inbound.")
        spawnMobIfPossible()
    }

    /// Draws one card into that tower's hand and ticks the parade.
    /// No-op on an already-busted tower — hitting further can't help,
    /// only `redeal` recovers it.
    public func hit(towerIndex: Int) {
        guard towers.indices.contains(towerIndex), !towers[towerIndex].isBusted else { return }
        towers[towerIndex].cards.append(drawCardForTower())
        if towers[towerIndex].isBusted {
            log.append("Tower \(towerIndex) overloaded at \(towers[towerIndex].bestValue) — dead power until redealt.")
        }
        advanceParade()
    }

    /// Resets one tower to a fresh 2-card hand and ticks the parade —
    /// the only way to recover a busted tower, or to gamble a decent
    /// total for a shot at a better one.
    public func redeal(towerIndex: Int) {
        guard towers.indices.contains(towerIndex) else { return }
        towers[towerIndex] = dealFreshHand()
        advanceParade()
    }

    private func freshShoe() -> [Card] {
        var deck: [Card] = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                deck.append(Card(rank: rank, suit: suit))
            }
        }
        deck.shuffle(using: &rng)
        return deck
    }

    private func buildMobSpawnQueue(for stage: StageConfig) -> [Card] {
        (0..<stage.mobCount).map { _ in drawFromShoe() }
    }

    private func drawFromShoe() -> Card {
        if shoe.isEmpty {
            shoe = freshShoe()
        }
        return shoe.removeFirst()
    }

    private func dealFreshHand() -> Hand {
        Hand(cards: [drawCardForTower(), drawCardForTower()])
    }

    private func drawCardForTower() -> Card {
        let card = drawFromShoe()
        events.append(.cardDealt)
        return card
    }

    /// One atomic tick: towers concentrate fire on the frontmost mob,
    /// every mob steps one closer to the base, anything that arrived
    /// hits the base and is removed, a fresh mob spawns from the queue —
    /// then a defeat or a stage clear is resolved immediately, so the
    /// engine is always in a consistent, ready-to-act state by the time
    /// this returns.
    private func advanceParade() {
        applyTowerDamage()
        stepMobsForward()

        if isDefeated {
            log.append(FlavorText.defeated(using: &rng))
            runState.baseHP = runState.baseMaxHP
            startStage()
            return
        }

        spawnMobIfPossible()

        if isStageCleared {
            log.append(FlavorText.stageCleared(using: &rng))
            runState.stageIndex += 1
            runState.baseHP = min(runState.baseMaxHP, runState.baseHP + 2)
            startStage()
        }
    }

    /// Every live tower's power lands on the same, frontmost (closest to
    /// the base) mob — concentrated fire, no lane targeting. `mobs` stays
    /// in spawn order and every mob starts with the same
    /// `stageConfig.mobStartingSteps`, so the first element is always the
    /// one nearest the base.
    private func applyTowerDamage() {
        guard let frontIndex = mobs.indices.first else { return }
        let power = totalPower
        guard power > 0 else { return }
        mobs[frontIndex].hp -= power
        events.append(.mobHit(mobID: mobs[frontIndex].id))
        if mobs[frontIndex].isDead {
            log.append(FlavorText.mobKilled(card: "\(mobs[frontIndex].card)", using: &rng))
            events.append(.mobKilled(mobID: mobs[frontIndex].id))
            mobs.remove(at: frontIndex)
        }
    }

    private func stepMobsForward() {
        for i in mobs.indices {
            mobs[i].stepsRemaining -= 1
        }
        var i = 0
        while i < mobs.count {
            if mobs[i].hasReachedBase {
                let mob = mobs.remove(at: i)
                runState.baseHP = max(0, runState.baseHP - mob.hp)
                log.append(FlavorText.baseHit(card: "\(mob.card)", using: &rng))
                events.append(.baseHit)
            } else {
                i += 1
            }
        }
    }

    private func spawnMobIfPossible() {
        guard !mobSpawnQueue.isEmpty else { return }
        let card = mobSpawnQueue.removeFirst()
        let hp = max(1, Int(Double(card.rank.blackjackValue) * stageConfig.mobHPMultiplier))
        mobs.append(Mob(card: card, hp: hp, stepsRemaining: stageConfig.mobStartingSteps))
    }
}
