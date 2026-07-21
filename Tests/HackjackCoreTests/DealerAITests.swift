import XCTest
@testable import HackjackCore

final class DealerAITests: XCTestCase {
    private func plainShoe() -> [Card] {
        Suit.allCases.flatMap { suit in Rank.allCases.map { Card(rank: $0, suit: suit) } }
    }

    func testEarlyShiftNeverTargetsTheShoe() {
        let shift = ShiftConfig.standard(index: 1)
        XCTAssertFalse(shift.hiddenHacksUnlocked)

        for seed: UInt64 in 0..<500 {
            var rng = SeededGenerator(seed: seed)
            var hand = Hand(cards: [Card(rank: .nine, suit: .hearts), Card(rank: .six, suit: .clubs)])
            var shoe = plainShoe()
            var log: [String] = []
            DealerAI.maybeHack(shift: shift, removedTypes: [], playerHand: &hand, shoe: &shoe, log: &log, using: &rng)
            XCTAssertNil(shoe[0].sparkTell, "hidden hacks must stay locked out before Shift 4")
        }
    }

    func testLateShiftCanTargetTheShoe() {
        let shift = ShiftConfig.standard(index: 8)
        XCTAssertTrue(shift.hiddenHacksUnlocked)

        var foundHiddenHack = false
        for seed: UInt64 in 0..<500 {
            var rng = SeededGenerator(seed: seed)
            var hand = Hand(cards: [Card(rank: .nine, suit: .hearts), Card(rank: .six, suit: .clubs)])
            var shoe = plainShoe()
            var log: [String] = []
            DealerAI.maybeHack(shift: shift, removedTypes: [], playerHand: &hand, shoe: &shoe, log: &log, using: &rng)
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
        var hand = Hand(cards: [Card(rank: .nine, suit: .hearts), Card(rank: .six, suit: .clubs)])
        var shoe = plainShoe()
        var log: [String] = []
        DealerAI.maybeHack(shift: shift, removedTypes: [], playerHand: &hand, shoe: &shoe, log: &log, using: &rng)
        XCTAssertTrue(hand.cards.contains { $0.sparkTell == .visible })
        XCTAssertFalse(log.isEmpty)
    }
}
