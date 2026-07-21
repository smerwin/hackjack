import XCTest
@testable import HackjackCore

final class CorruptionGeneratorTests: XCTestCase {
    private func signature(_ card: Card) -> String {
        "\(card.rank.rawValue)-\(card.suit)-\(card.integrity)-\(card.sparkTell != nil)"
    }

    func testSameSeedProducesSameShoe() {
        let shift = ShiftConfig.standard(index: 3)
        var rngA = SeededGenerator(seed: 42)
        var rngB = SeededGenerator(seed: 42)
        let shoeA = CorruptionGenerator.buildShoe(shift: shift, removedTypes: [], using: &rngA)
        let shoeB = CorruptionGenerator.buildShoe(shift: shift, removedTypes: [], using: &rngB)
        XCTAssertEqual(shoeA.map(signature), shoeB.map(signature))
    }

    func testDifferentSeedsDiverge() {
        let shift = ShiftConfig.standard(index: 3)
        var rngA = SeededGenerator(seed: 1)
        var rngB = SeededGenerator(seed: 2)
        let shoeA = CorruptionGenerator.buildShoe(shift: shift, removedTypes: [], using: &rngA)
        let shoeB = CorruptionGenerator.buildShoe(shift: shift, removedTypes: [], using: &rngB)
        XCTAssertNotEqual(shoeA.map(signature), shoeB.map(signature))
    }

    func testRemovedTypesNeverSelected() {
        var rng = SeededGenerator(seed: 7)
        for _ in 0..<500 {
            let pair = CorruptionGenerator.pickMutationPair(excluding: [.leech, .twinner], using: &rng)
            XCTAssertFalse([pair.0, pair.1].contains(.leech))
            XCTAssertFalse([pair.0, pair.1].contains(.twinner))
        }
    }

    /// The tell system's entire premise: a sparking card carries a known,
    /// visible pair of possible outcomes right up until resolve() runs —
    /// it is never ambiguous-then-secretly-decided.
    func testMutationPairIsVisibleUntilResolved() {
        var rng = SeededGenerator(seed: 99)
        var card = Card(rank: .five, suit: .hearts)
        CorruptionGenerator.markSparking(&card, tell: .visible, removedTypes: [], using: &rng)
        XCTAssertNotNil(card.pendingMutations)
        XCTAssertNotNil(card.sparkTell)

        CorruptionGenerator.resolve(&card, otherRanksInHand: [], using: &rng)
        XCTAssertNil(card.pendingMutations)
        XCTAssertNil(card.sparkTell)
    }

    func testTwinnerDuplicatesAnotherCardInHandWhenAvailable() {
        var rng = SeededGenerator(seed: 3)
        var card = Card(rank: .two, suit: .clubs)
        card.pendingMutations = (.twinner, .twinner)
        CorruptionGenerator.resolve(&card, otherRanksInHand: [.king], using: &rng)
        XCTAssertEqual(card.rank, .king)
    }
}
