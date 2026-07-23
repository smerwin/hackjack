import XCTest
@testable import HackjackCore

final class GameEngineTests: XCTestCase {
    // MARK: - Hand.power

    func testHandPowerIsCurrentTotalUnlessBusted() {
        var hand = Hand(cards: [Card(rank: .king, suit: .spades), Card(rank: .nine, suit: .hearts)])
        XCTAssertEqual(hand.power, 19)
        hand.cards.append(Card(rank: .five, suit: .clubs))
        XCTAssertTrue(hand.isBusted)
        XCTAssertEqual(hand.power, 0, "a busted hand contributes zero power until redealt")
    }

    // MARK: - Determinism

    func testSameSeedProducesSameOpeningState() {
        let engineA = GameEngine(seed: 42)
        let engineB = GameEngine(seed: 42)
        engineA.startStage()
        engineB.startStage()
        XCTAssertEqual(engineA.towers.map { $0.cards.map(\.description) }, engineB.towers.map { $0.cards.map(\.description) })
        XCTAssertEqual(engineA.mobs.map { $0.card.description }, engineB.mobs.map { $0.card.description })
    }

    func testDifferentSeedsDiverge() {
        let engineA = GameEngine(seed: 1)
        let engineB = GameEngine(seed: 2)
        engineA.startStage()
        engineB.startStage()
        XCTAssertNotEqual(engineA.towers.map { $0.cards.map(\.description) }, engineB.towers.map { $0.cards.map(\.description) })
    }

    // MARK: - Stage start

    func testStartStageDealsFreshHandsAndSpawnsFirstMob() {
        let engine = GameEngine(seed: 1)
        engine.startStage()
        XCTAssertEqual(engine.towers.count, 3)
        XCTAssertTrue(engine.towers.allSatisfy { $0.cards.count == 2 })
        XCTAssertEqual(engine.mobs.count, 1, "the first mob should spawn immediately on stage start")
        XCTAssertEqual(engine.mobs[0].stepsRemaining, engine.stageConfig.mobStartingSteps)
    }

    // MARK: - hit

    func testHitDrawsACardIntoTheTargetedTower() {
        let engine = GameEngine(seed: 3)
        engine.startStage()
        let before = engine.towers[0].cards.count
        engine.hit(towerIndex: 0)
        XCTAssertEqual(engine.towers[0].cards.count, before + 1)
    }

    /// Repeatedly hits a single tower until it busts, detecting (and
    /// skipping, via seed search) any seed where a stage transition
    /// redeals every tower before that happens naturally — a transition
    /// isn't a bug, it's just not what this test is trying to isolate.
    func testHitIsANoOpOnAnAlreadyBustedTower() throws {
        func findSeedWhereTowerBustsCleanly(limit: UInt64) -> (UInt64, GameEngine)? {
            for seed: UInt64 in 0..<limit {
                let engine = GameEngine(towerCount: 1, seed: seed)
                engine.startStage()
                var guardCount = 0
                var transitionHappened = false
                while !engine.towers[0].isBusted && guardCount < 15 {
                    let before = engine.towers[0].cards.count
                    engine.hit(towerIndex: 0)
                    if engine.towers[0].cards.count != before + 1 {
                        transitionHappened = true
                        break
                    }
                    guardCount += 1
                }
                if engine.towers[0].isBusted && !transitionHappened {
                    return (seed, engine)
                }
            }
            return nil
        }

        let (_, engine) = try XCTUnwrap(findSeedWhereTowerBustsCleanly(limit: 300), "expected a seed where tower 0 busts without a stage transition first")
        XCTAssertEqual(engine.towers[0].power, 0)
        let cardsAtBust = engine.towers[0].cards.count
        engine.hit(towerIndex: 0)
        XCTAssertEqual(engine.towers[0].cards.count, cardsAtBust, "hit must be a no-op once busted")
    }

    // MARK: - redeal

    func testRedealGivesAFreshTwoCardHand() {
        let engine = GameEngine(seed: 4)
        engine.startStage()
        engine.redeal(towerIndex: 0)
        XCTAssertEqual(engine.towers[0].cards.count, 2)
    }

    // MARK: - Mob damage

    /// Stage 25's HP multiplier (13.0) puts even the weakest mob (a Two,
    /// 26 HP) above the maximum possible single-tower single-hit power
    /// (21, a natural blackjack) — so the frontmost mob is guaranteed to
    /// survive one tick, making the exact damage dealt directly assertable
    /// with no seed search needed.
    func testMobTakesDamageEqualToTotalPowerEachTick() {
        let engine = GameEngine(runState: RunState(stageIndex: 25), towerCount: 1, seed: 5)
        engine.startStage()
        let mobID = engine.mobs[0].id
        let hpBefore = engine.mobs[0].hp
        engine.hit(towerIndex: 0)
        let powerAfter = engine.totalPower
        let mobAfter = engine.mobs.first { $0.id == mobID }
        XCTAssertNotNil(mobAfter, "a mob with HP > 21 must survive a single 2-card hand's worth of damage")
        XCTAssertEqual(mobAfter?.hp, hpBefore - powerAfter)
    }

    func testMobDyingIsRemovedAndEmitsMobKilled() throws {
        var found = false
        for seed: UInt64 in 0..<200 {
            let engine = GameEngine(towerCount: 1, seed: seed)
            engine.startStage()
            guard let mobID = engine.mobs.first?.id else { continue }
            engine.redeal(towerIndex: 0)
            if engine.drainEvents().contains(.mobKilled(mobID: mobID)) {
                XCTAssertFalse(engine.mobs.contains { $0.id == mobID })
                found = true
                break
            }
        }
        XCTAssertTrue(found, "expected at least one seed where the opening tower's power kills the opening mob")
    }

    /// Stage 70's HP multiplier (35.5) puts even the weakest mob (a Two,
    /// 71 HP) above the maximum possible cumulative damage across its
    /// starting 3 steps from a single tower (21 * 3 = 63) — guaranteed to
    /// survive to reach the base rather than die first, no seed search
    /// needed.
    func testMobReachingBaseEmitsBaseHitAndIsRemoved() {
        let engine = GameEngine(runState: RunState(stageIndex: 70), towerCount: 1, seed: 6)
        engine.startStage()
        let mobID = engine.mobs[0].id
        var sawBaseHit = false
        for _ in 0..<engine.stageConfig.mobStartingSteps {
            engine.redeal(towerIndex: 0)
            if engine.drainEvents().contains(.baseHit) {
                sawBaseHit = true
            }
        }
        XCTAssertTrue(sawBaseHit, "expected the original mob to reach the base within its starting steps")
        XCTAssertFalse(engine.mobs.contains { $0.id == mobID }, "a mob that reached base must be removed")
    }

    // MARK: - Stage clear / defeat

    func testStageClearAdvancesStageIndex() throws {
        var found = false
        outer: for seed: UInt64 in 0..<100 {
            let engine = GameEngine(seed: seed)
            engine.startStage()
            let startingIndex = engine.runState.stageIndex
            for _ in 0..<40 {
                engine.redeal(towerIndex: 0)
                if engine.runState.stageIndex > startingIndex {
                    found = true
                    break outer
                }
            }
        }
        XCTAssertTrue(found, "expected at least one seed to clear Stage 1 within 40 actions")
    }

    // MARK: - Daily Breach

    func testDailyBreachSameDateProducesSameOpeningState() {
        let stateA = RunState.dailyBreach(dateKey: "2026-07-20")
        let stateB = RunState.dailyBreach(dateKey: "2026-07-20")
        XCTAssertEqual(stateA.seed, stateB.seed)

        let engineA = GameEngine(runState: stateA)
        let engineB = GameEngine(runState: stateB)
        engineA.startStage()
        engineB.startStage()

        XCTAssertEqual(engineA.towers.map { $0.cards.map(\.description) }, engineB.towers.map { $0.cards.map(\.description) })
        XCTAssertEqual(engineA.mobs.map { $0.card.description }, engineB.mobs.map { $0.card.description })
    }

    func testDailyBreachDifferentDatesDiverge() {
        let stateA = RunState.dailyBreach(dateKey: "2026-07-20")
        let stateB = RunState.dailyBreach(dateKey: "2026-07-21")
        XCTAssertNotEqual(stateA.seed, stateB.seed)
    }
}
