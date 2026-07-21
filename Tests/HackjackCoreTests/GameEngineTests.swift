import XCTest
@testable import HackjackCore

final class GameEngineTests: XCTestCase {
    func testStartHandDealsTwoAndTwo() {
        let engine = GameEngine(seed: 1)
        engine.startHand()
        XCTAssertEqual(engine.playerHand.cards.count, 2)
        XCTAssertEqual(engine.dealerHand.cards.count, 2)
    }

    func testHittingRepeatedlyEventuallyEndsTurn() {
        let engine = GameEngine(seed: 5)
        engine.startHand()
        var guardCount = 0
        while !engine.playerHand.isStood && guardCount < 20 {
            engine.playerHit()
            guardCount += 1
        }
        XCTAssertTrue(engine.playerHand.isStood, "hitting until bust must set isStood so the turn ends")
    }

    func testStandDoesNotDrawCards() {
        let engine = GameEngine(seed: 9)
        engine.startHand()
        let countBefore = engine.playerHand.cards.count
        engine.playerStand()
        XCTAssertEqual(engine.playerHand.cards.count, countBefore)
        XCTAssertTrue(engine.playerHand.isStood)
    }

    /// A sparking card's mutation pair must survive at least one full
    /// player decision before it resolves — this is the ordering the
    /// legible-risk tell system depends on (CLAUDE.md §5.1).
    func testPendingSparkSurvivesUntilACommittingAction() throws {
        var found: (seed: UInt64, engine: GameEngine)?
        for seed: UInt64 in 0..<300 {
            let engine = GameEngine(runState: RunState(currentShiftIndex: 8), seed: seed)
            engine.startHand()
            if engine.playerHand.cards.contains(where: { $0.pendingMutations != nil }) {
                found = (seed, engine)
                break
            }
        }
        let (_, engine) = try XCTUnwrap(found, "expected at least one seed to deal a sparking starting card")
        XCTAssertTrue(engine.playerHand.cards.contains { $0.pendingMutations != nil })

        engine.playerStand()
        XCTAssertFalse(
            engine.playerHand.cards.contains { $0.pendingMutations != nil },
            "standing is a committing action and must resolve any pending spark"
        )
    }

    func testInsufficientChargesThrows() {
        let runState = RunState(chargePool: HackChargePool(current: 0, max: 3))
        let engine = GameEngine(runState: runState, seed: 2)
        engine.startHand()
        let targetID = engine.playerHand.cards[0].id
        XCTAssertThrowsError(try engine.playerHack(.jack, cardID: targetID)) { error in
            XCTAssertEqual(error as? GameEngine.HackError, .insufficientCharges)
        }
    }

    func testCrashHackReplacesTargetCard() throws {
        let engine = GameEngine(seed: 11)
        engine.startHand()
        let before = engine.playerHand.cards[0]
        try engine.playerHack(.crash, cardID: before.id)
        XCTAssertEqual(engine.playerHand.cards.count, 2)
        XCTAssertFalse(engine.playerHand.cards.contains { $0.id == before.id })
    }

    func testPatchClearsSparkAndRestoresIntegrity() throws {
        let engine = GameEngine(seed: 4)
        engine.startHand()
        let targetID = engine.playerHand.cards[0].id
        try engine.playerHack(.patch, cardID: targetID)
        let patched = try XCTUnwrap(engine.playerHand.cards.first { $0.id == targetID })
        XCTAssertNil(patched.sparkTell)
        XCTAssertNil(patched.pendingMutations)
        XCTAssertEqual(patched.integrity, 100)
    }
}
