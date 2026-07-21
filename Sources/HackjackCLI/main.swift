import HackjackCore
import Foundation

func renderCard(_ card: Card, hidden: Bool) -> String {
    if hidden { return "??" }
    var text = "\(card)"
    if card.pendingMutations != nil {
        text += "[SPARK]"
    }
    return text
}

func renderHand(_ hand: Hand, label: String, hideHoleCard: Bool) -> String {
    let cardText = hand.cards.enumerated()
        .map { index, card in renderCard(card, hidden: hideHoleCard && index == 1) }
        .joined(separator: "  ")
    let valueText = hideHoleCard ? "?" : "\(hand.bestValue)"
    return "\(label): \(cardText)   (value: \(valueText))"
}

func printTable(_ engine: GameEngine, dealerRevealed: Bool) {
    print(renderHand(engine.dealerHand, label: "Dealer", hideHoleCard: !dealerRevealed))
    for (i, hand) in engine.playerHands.enumerated() {
        let marker = engine.playerHands.count > 1 ? (i == engine.activeHandIndex && !engine.allPlayerHandsResolved ? "▶" : " ") : " "
        print("\(marker)Hand \(i + 1): \(renderHand(hand, label: "You   ", hideHoleCard: false))")
    }
}

func printLog(_ engine: GameEngine) {
    for line in engine.drainLog() {
        print("  · \(line)")
    }
}

func promptLine(_ text: String) -> String {
    print(text, terminator: "")
    guard let line = readLine() else {
        print("\nEOF on stdin — ending session.")
        exit(0)
    }
    return line.trimmingCharacters(in: .whitespaces).lowercased()
}

func promptTarget(engine: GameEngine) -> (targetIsDealer: Bool, handIndex: Int?, cardID: UUID)? {
    let hand = engine.activeHand
    let input = promptLine("    target — index 0-\(hand.cards.count - 1) in your active hand, or 'd' for dealer's up-card: ")
    if input == "d" {
        guard let card = engine.dealerHand.cards.first else { return nil }
        return (true, nil, card.id)
    }
    guard let index = Int(input), hand.cards.indices.contains(index) else { return nil }
    return (false, engine.activeHandIndex, hand.cards[index].id)
}

func runShop(_ engine: GameEngine, uiRNG: inout SystemRandomNumberGenerator) {
    print("\n== PATCH SHOP == currency: \(engine.runState.shopCurrency)")
    while let offers = engine.pendingShopOffers {
        for offer in offers {
            print("  [\(offer.id)] \(offer.title) — \(offer.description) (cost: \(offer.cost))")
        }
        let choice = promptLine("Buy which (name), or 'done': ")
        if choice == "done" { engine.closeShop(); break }
        if let kind = offers.first(where: { "\($0.id)" == choice })?.id {
            engine.purchaseShopOffer(kind)
            printLog(engine)
        } else {
            print("  Not a valid offer.")
        }
    }
}

func runFirmwareOffer(_ engine: GameEngine) {
    guard let offer = engine.pendingFirmwareOffer else { return }
    print("\n== FIRMWARE OFFER == \(offer.effect.displayName): \(offer.effect.flavorDescription)")
    let choice = promptLine("[k]eep or [d]ecline? ")
    if choice == "k" {
        engine.keepFirmwareOffer()
    } else {
        engine.declineFirmwareOffer()
    }
    printLog(engine)
}

var uiRNG = SystemRandomNumberGenerator()

for line in FlavorText.loadingScreen.shuffled(using: &uiRNG).prefix(2) {
    print(line)
}
print("")

let engine = GameEngine(runState: RunState())

runLoop: while true {
    engine.startHand()
    print("\n== Shift \(engine.runState.currentShiftIndex) · streak \(engine.runState.streakWithinShift)/\(engine.shiftConfig.targetStreak) · charges \(engine.runState.chargePool.current)/\(engine.runState.chargePool.max) · currency \(engine.runState.shopCurrency) · firmware \(engine.runState.firmware.equipped.count)/\(engine.runState.firmware.capacity) ==")
    printTable(engine, dealerRevealed: false)
    printLog(engine)

    while !engine.allPlayerHandsResolved {
        let hint = engine.canSplitActiveHand() ? "  [p]split" : ""
        let action = promptLine("\n[h]it  [s]tand  [1]Jack  [2]Spoof  [3]Crash  [4]Patch  [5]Peek\(hint)  [q]uit\n> ")
        switch action {
        case "h":
            engine.playerHit()
        case "s":
            engine.playerStand()
        case "p":
            do { try engine.playerSplit() } catch { print("    Split failed: \(error)") }
        case "1", "2", "3", "4":
            let type: PlayerHackType = ["1": .jack, "2": .spoof, "3": .crash, "4": .patch][action]!
            if let target = promptTarget(engine: engine) {
                do {
                    try engine.playerHack(type, targetIsDealer: target.targetIsDealer, targetHandIndex: target.handIndex, cardID: target.cardID)
                } catch {
                    print("    Hack failed: \(error)")
                }
            } else {
                print("    Invalid target.")
            }
        case "5":
            do { try engine.playerHack(.peek) } catch { print("    Hack failed: \(error)") }
        case "q":
            break runLoop
        default:
            print("    Firmware didn't recognize that input.")
        }
        printTable(engine, dealerRevealed: false)
        printLog(engine)
    }

    if engine.playerHands.contains(where: { !$0.isBusted }) {
        engine.playDealerTurn()
    }
    printTable(engine, dealerRevealed: true)
    printLog(engine)

    let outcomes = engine.settleHands()
    for (i, outcome) in outcomes.enumerated() {
        let prefix = outcomes.count > 1 ? "Hand \(i + 1): " : ""
        print("\(prefix)\(FlavorText.outcome(outcome, using: &uiRNG))")
    }
    print("Streak: \(engine.runState.streakWithinShift)/\(engine.shiftConfig.targetStreak)   Currency: \(engine.runState.shopCurrency)   Charges: \(engine.runState.chargePool.current)/\(engine.runState.chargePool.max)")

    runFirmwareOffer(engine)
    if engine.pendingShopOffers != nil {
        runShop(engine, uiRNG: &uiRNG)
    }
}

print("\nSession terminated. The table remembers nothing. Neither should you.")
