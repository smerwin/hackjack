import HackjackCore
import Foundation

func renderHand(_ hand: Hand, label: String, hideHoleCard: Bool) -> String {
    let cardText = hand.cards.enumerated().map { index, card -> String in
        if hideHoleCard && index == 1 {
            return "??"
        }
        var text = "\(card)"
        if card.pendingMutations != nil {
            text += "[SPARK]"
        }
        return text
    }.joined(separator: "  ")
    let valueText = hideHoleCard ? "?" : "\(hand.bestValue)"
    return "\(label): \(cardText)   (value: \(valueText))"
}

func printLog(_ engine: GameEngine) {
    for line in engine.drainLog() {
        print("  · \(line)")
    }
}

func promptLine(_ text: String) -> String {
    print(text, terminator: "")
    return readLine()?.trimmingCharacters(in: .whitespaces).lowercased() ?? "s"
}

func promptTarget(engine: GameEngine) -> (targetIsDealer: Bool, cardID: UUID)? {
    let input = promptLine("    target — index 0-\(engine.playerHand.cards.count - 1) in your hand, or 'd' for dealer's up-card: ")
    if input == "d" {
        guard let card = engine.dealerHand.cards.first else { return nil }
        return (true, card.id)
    }
    guard let index = Int(input), engine.playerHand.cards.indices.contains(index) else { return nil }
    return (false, engine.playerHand.cards[index].id)
}

var uiRNG = SystemRandomNumberGenerator()

for line in FlavorText.loadingScreen.shuffled(using: &uiRNG).prefix(2) {
    print(line)
}
print("")

let engine = GameEngine(runState: RunState())

runLoop: while true {
    engine.startHand()
    print("\n== Shift \(engine.runState.currentShiftIndex) · streak \(engine.runState.streakWithinShift)/\(engine.shiftConfig.targetStreak) · charges \(engine.runState.chargePool.current)/\(engine.runState.chargePool.max) · currency \(engine.runState.shopCurrency) ==")
    print(renderHand(engine.dealerHand, label: "Dealer", hideHoleCard: true))
    print(renderHand(engine.playerHand, label: "You   ", hideHoleCard: false))
    printLog(engine)

    while !engine.playerHand.isStood {
        let action = promptLine("\n[h]it  [s]tand  [1]Jack  [2]Spoof  [3]Crash  [4]Patch  [5]Peek  [q]uit\n> ")
        switch action {
        case "h":
            engine.playerHit()
        case "s":
            engine.playerStand()
        case "1", "2", "3", "4":
            let type: PlayerHackType = ["1": .jack, "2": .spoof, "3": .crash, "4": .patch][action]!
            if let target = promptTarget(engine: engine) {
                do {
                    try engine.playerHack(type, targetIsDealer: target.targetIsDealer, cardID: target.cardID)
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
        print(renderHand(engine.dealerHand, label: "Dealer", hideHoleCard: true))
        print(renderHand(engine.playerHand, label: "You   ", hideHoleCard: false))
        printLog(engine)
    }

    if !engine.playerHand.isBusted {
        engine.playDealerTurn()
    }
    print(renderHand(engine.dealerHand, label: "Dealer", hideHoleCard: false))
    print(renderHand(engine.playerHand, label: "You   ", hideHoleCard: false))
    printLog(engine)

    let outcome = engine.settleHand()
    print("\n\(FlavorText.outcome(outcome, using: &uiRNG))")
    print("Streak: \(engine.runState.streakWithinShift)/\(engine.shiftConfig.targetStreak)   Currency: \(engine.runState.shopCurrency)   Charges: \(engine.runState.chargePool.current)/\(engine.runState.chargePool.max)")
}

print("\nSession terminated. The table remembers nothing. Neither should you.")
