import XCTest
@testable import HackjackCore

final class DealerAITests: XCTestCase {
    private func plainShoe() -> [Card] {
        Suit.allCases.flatMap { suit in Rank.allCases.map { Card(rank: $0, suit: suit) } }
    }

    private func plainHands() -> [Hand] {
        [Hand(cards: [Card(rank: .nine, suit: .hearts), Card(rank: .six, suit: .clubs)])]
    }

    func testEarlyShiftNeverTargetsTheShoe() {
        let shift = ShiftConfig.standard(index: 1)
        XCTAssertFalse(shift.hiddenHacksUnlocked)

        for seed: UInt64 in 0..<500 {
            var rng = SeededGenerator(seed: seed)
            var hands = plainHands()
            var shoe = plainShoe()
            var log: [String] = []
            DealerAI.maybeHack(shift: shift, removedTypes: [], playerHands: &hands, shoe: &shoe, log: &log, using: &rng)
            XCTAssertNil(shoe[0].sparkTell, "hidden hacks must stay locked out before Shift 4")
        }
    }

    func testLateShiftCanTargetTheShoe() {
        let shift = ShiftConfig.standard(index: 8)
        XCTAssertTrue(shift.hiddenHacksUnlocked)

        var foundHiddenHack = false
        for seed: UInt64 in 0..<500 {
            var rng = SeededGenerator(seed: seed)
            var hands = plainHands()
            var shoe = plainShoe()
            var log: [String] = []
            DealerAI.maybeHack(shift: shift, removedTypes: [], playerHands: &hands, shoe: &shoe, log: &log, using: &rng)
            if shoe[0].sparkTell == .hidden {
                foundHiddenHack = true
                break
            }
        }
        XCTAssertTrue(foundHiddenHack, "expected at least one hidden shoe hack across 500 seeded trials in a late Shift")
    }

    func testVisibleHackTargetsPlayerHand() {
        let shift = ShiftConfig(index: 1, targetStreak: 5, corruptionDensity: 0.1...0.2, dealerHackChance: 1.0, hiddenHacksUnlocked: false)
        var rng = SeededGenerator(seed: 123)
        var hands = plainHands()
        var shoe = plainShoe()
        var log: [String] = []
        DealerAI.maybeHack(shift: shift, removedTypes: [], playerHands: &hands, shoe: &shoe, log: &log, using: &rng)
        XCTAssertTrue(hands[0].cards.contains { $0.sparkTell == .visible })
        XCTAssertFalse(log.isEmpty)
    }

    func testForceHiddenAlwaysTargetsTheShoe() {
        let shift = ShiftConfig(index: 1, targetStreak: 5, corruptionDensity: 0.1...0.2, dealerHackChance: 1.0, hiddenHacksUnlocked: false)
        var rng = SeededGenerator(seed: 55)
        var hands = plainHands()
        var shoe = plainShoe()
        var log: [String] = []
        DealerAI.maybeHack(shift: shift, removedTypes: [], playerHands: &hands, shoe: &shoe, log: &log, forceHidden: true, using: &rng)
        XCTAssertEqual(shoe[0].sparkTell, .hidden, "Ghost Protocol's forceHidden must win even when hiddenHacksUnlocked is false")
        XCTAssertFalse(hands[0].cards.contains { $0.sparkTell != nil })
    }

    func testMultipleAttemptsCanHackTwice() {
        let shift = ShiftConfig(index: 8, targetStreak: 5, corruptionDensity: 0.1...0.2, dealerHackChance: 1.0, hiddenHacksUnlocked: true)
        var foundTwoHits = false
        for seed: UInt64 in 0..<200 {
            var rng = SeededGenerator(seed: seed)
            var hands = [Hand(cards: [
                Card(rank: .two, suit: .hearts), Card(rank: .three, suit: .clubs),
                Card(rank: .four, suit: .spades), Card(rank: .three, suit: .diamonds),
            ])]
            var shoe = plainShoe()
            var log: [String] = []
            DealerAI.maybeHack(shift: shift, removedTypes: [], playerHands: &hands, shoe: &shoe, log: &log, attempts: 2, using: &rng)
            let sparkedCount = hands[0].cards.filter { $0.sparkTell != nil }.count + (shoe[0].sparkTell != nil ? 1 : 0)
            if sparkedCount >= 2 {
                foundTwoHits = true
                break
            }
        }
        XCTAssertTrue(foundTwoHits, "Root Access's attempts:2 should be able to land two hacks across seeded trials")
    }
}
