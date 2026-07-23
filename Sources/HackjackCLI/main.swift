import HackjackCore

func printStatus(_ engine: GameEngine) {
    let rs = engine.runState
    print("\n== Stage \(engine.stageConfig.index) · base \(rs.baseHP)/\(rs.baseMaxHP) · power \(engine.totalPower) ==")

    for (i, tower) in engine.towers.enumerated() {
        let cards = tower.cards.map(\.description).joined(separator: " ")
        let status = tower.isBusted ? "BUSTED" : (tower.isBlackjack ? "BLACKJACK" : "")
        print("  Tower \(i): \(cards)  [\(tower.bestValue)]  power=\(tower.power) \(status)")
    }

    if engine.mobs.isEmpty {
        print("  (parade clear)")
    } else {
        for mob in engine.mobs {
            print("  Mob \(mob.card)  hp=\(mob.hp)  steps=\(mob.stepsRemaining)")
        }
    }
}

func printLog(_ engine: GameEngine) {
    for line in engine.drainLog() {
        print("  $ \(line)")
    }
}

var uiRNG = SystemRandomNumberGenerator()

for line in FlavorText.loadingScreen.shuffled(using: &uiRNG).prefix(2) {
    print(line)
}
print("")

let engine = GameEngine()
engine.startStage()
printLog(engine)

runLoop: while true {
    printStatus(engine)
    let towerRange = "0-\(engine.towerCount - 1)"
    let input = readLine(strippingNewline: true)?.trimmingCharacters(in: .whitespaces) ?? "q"
    let parts = input.split(separator: " ")

    switch parts.first.map(String.init) {
    case "h", "hit":
        guard parts.count > 1, let index = Int(parts[1]) else {
            print("    usage: hit <tower \(towerRange)>")
            continue
        }
        engine.hit(towerIndex: index)
    case "r", "redeal":
        guard parts.count > 1, let index = Int(parts[1]) else {
            print("    usage: redeal <tower \(towerRange)>")
            continue
        }
        engine.redeal(towerIndex: index)
    case "q", "quit":
        break runLoop
    default:
        print("    [h]it <tower> / [r]edeal <tower> / [q]uit — towers are \(towerRange)")
        continue
    }

    printLog(engine)
}

print("\nDisconnected.")
