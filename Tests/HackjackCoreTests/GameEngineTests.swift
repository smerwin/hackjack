import XCTest
@testable import HackjackCore

final class GameEngineTests: XCTestCase {
    func testStartHandDealsTwoAndTwo() {
        let engine = GameEngine(seed: 1)
        engine.startHand()
        XCTAssertEqual(engine.activeHand.cards.count, 2)
        XCTAssertEqual(engine.dealerHand.cards.count, 2)
    }

    /// A fully drained charge pool regenerates exactly 1 charge at the
    /// start of the next hand — a floor against permanent lockout, not a
    /// general regen (a non-empty pool is left untouched).
    func testChargePoolRegeneratesOneWhenFullyDrained() {
        let runState = RunState(chargePool: HackChargePool(current: 0, max: 3))
        let engine = GameEngine(runState: runState, seed: 6)
        engine.startHand()
        XCTAssertEqual(engine.runState.chargePool.current, 1)
    }

    func testChargePoolDoesNotRegenerateWhenNotFullyDrained() {
        let runState = RunState(chargePool: HackChargePool(current: 2, max: 3))
        let engine = GameEngine(runState: runState, seed: 6)
        engine.startHand()
        XCTAssertEqual(engine.runState.chargePool.current, 2, "regen must only kick in from a fully empty pool")
    }

    /// A bust no longer finalizes the hand by itself — the player gets a
    /// window to hack a card back under 21 before it locks in (see
    /// `testHackingOutOfABustReopensTheHand` and `Hand.isResolved`).
    /// Repeatedly hitting still reaches a bust; only `acceptBust()`
    /// actually ends the turn from there.
    func testHittingIntoABustDoesNotAutoResolveUntilAccepted() {
        let engine = GameEngine(seed: 5)
        engine.startHand()
        var guardCount = 0
        while !engine.activeHand.isBusted && guardCount < 20 {
            engine.playerHit()
            guardCount += 1
        }
        XCTAssertTrue(engine.activeHand.isBusted, "expected repeated hits to eventually bust")
        XCTAssertFalse(engine.activeHand.isStood, "a bust must not auto-stand the hand")
        XCTAssertFalse(engine.activeHand.isResolved, "a bust must stay reprievable, not resolved, until accepted")

        engine.acceptBust()
        XCTAssertTrue(engine.activeHand.bustLocked, "accepting the bust must lock it in")
        XCTAssertTrue(engine.activeHand.isResolved, "a locked-in bust must count as resolved")
    }

    /// The actual "hack yourself out of busting" feature: once a hit
    /// busts the active hand, Jack/Crash can still change the target
    /// card's rank immediately, which can pull `bestValue` back under 21
    /// and reopen the hand for normal play.
    func testHackingOutOfABustReopensTheHand() throws {
        var found: (seed: UInt64, engine: GameEngine)?
        for seed: UInt64 in 0..<500 {
            let runState = RunState(chargePool: HackChargePool(current: 10, max: 10))
            let engine = GameEngine(runState: runState, seed: seed)
            engine.startHand()
            var guardCount = 0
            while !engine.activeHand.isBusted && guardCount < 20 {
                engine.playerHit()
                guardCount += 1
            }
            guard engine.activeHand.isBusted else { continue }

            // Try every card in the busted hand with Crash (a full reroll
            // is the most reliable way to possibly land under 21) until
            // one seed produces a recovery.
            for card in engine.activeHand.cards {
                try? engine.playerHack(.crash, cardID: card.id)
                if !engine.activeHand.isBusted {
                    found = (seed, engine)
                    break
                }
            }
            if found != nil { break }
        }

        let (_, engine) = try XCTUnwrap(found, "expected at least one seed where Crash pulls a busted hand back under 21")
        XCTAssertFalse(engine.activeHand.isBusted)
        XCTAssertFalse(engine.activeHand.isResolved, "a recovered hand should be live again, not locked in")
        XCTAssertFalse(engine.activeHand.isStood)
    }

    func testStandDoesNotDrawCards() {
        let engine = GameEngine(seed: 9)
        engine.startHand()
        let countBefore = engine.activeHand.cards.count
        engine.playerStand()
        XCTAssertEqual(engine.activeHand.cards.count, countBefore)
        XCTAssertTrue(engine.activeHand.isStood)
    }

    /// A sparking card's mutation pair must survive at least one full
    /// player decision before it resolves — this is the ordering the
    /// legible-risk tell system depends on (CLAUDE.md §5.1).
    func testPendingSparkSurvivesUntilACommittingAction() throws {
        var found: (seed: UInt64, engine: GameEngine)?
        for seed: UInt64 in 0..<300 {
            let engine = GameEngine(runState: RunState(currentShiftIndex: 8), seed: seed)
            engine.startHand()
            if engine.activeHand.cards.contains(where: { $0.pendingMutations != nil }) {
                found = (seed, engine)
                break
            }
        }
        let (_, engine) = try XCTUnwrap(found, "expected at least one seed to deal a sparking starting card")
        XCTAssertTrue(engine.activeHand.cards.contains { $0.pendingMutations != nil })

        engine.playerStand()
        XCTAssertFalse(
            engine.activeHand.cards.contains { $0.pendingMutations != nil },
            "standing is a committing action and must resolve any pending spark"
        )
    }

    /// A drained pool regenerates 1 charge at the start of the next hand
    /// (testChargePoolRegeneratesOneWhenFullyDrained), so an empty-pool
    /// hack attempt only actually fails once that single regenerated
    /// charge is spent too — this spends it first, then confirms a
    /// second hack in the same hand throws.
    func testInsufficientChargesThrows() {
        let runState = RunState(chargePool: HackChargePool(current: 0, max: 3))
        let engine = GameEngine(runState: runState, seed: 2)
        engine.startHand()
        XCTAssertEqual(engine.runState.chargePool.current, 1, "expected the regenerated charge from a fully drained pool")
        let targetID = engine.activeHand.cards[0].id
        try? engine.playerHack(.jack, cardID: targetID)
        XCTAssertEqual(engine.runState.chargePool.current, 0)

        XCTAssertThrowsError(try engine.playerHack(.jack, cardID: targetID)) { error in
            XCTAssertEqual(error as? GameEngine.HackError, .insufficientCharges)
        }
    }

    func testCrashHackReplacesTargetCard() throws {
        let engine = GameEngine(seed: 11)
        engine.startHand()
        let before = engine.activeHand.cards[0]
        try engine.playerHack(.crash, cardID: before.id)
        XCTAssertEqual(engine.activeHand.cards.count, 2)
        XCTAssertFalse(engine.activeHand.cards.contains { $0.id == before.id })
    }

    func testCrashHackAlwaysLeavesAFreshSpark() throws {
        // A latent bug fixed as part of the v0.2 systems pass: Jack/Spoof/
        // Crash used to set sparkTell without ever giving the card a
        // pendingMutations pair, so it could never resolve. All three now
        // go through markSparking like every other corruption source.
        let engine = GameEngine(seed: 11)
        engine.startHand()
        let before = engine.activeHand.cards[0]
        try engine.playerHack(.crash, cardID: before.id)
        let hacked = try XCTUnwrap(engine.activeHand.cards.first { $0.id != before.id })
        XCTAssertNotNil(hacked.pendingMutations)
        XCTAssertEqual(hacked.sparkTell, .visible)
    }

    func testPatchClearsSparkAndRestoresIntegrity() throws {
        let engine = GameEngine(seed: 4)
        engine.startHand()
        let targetID = engine.activeHand.cards[0].id
        try engine.playerHack(.patch, cardID: targetID)
        let patched = try XCTUnwrap(engine.activeHand.cards.first { $0.id == targetID })
        XCTAssertNil(patched.sparkTell)
        XCTAssertNil(patched.pendingMutations)
        XCTAssertEqual(patched.integrity, 100)
    }
}
