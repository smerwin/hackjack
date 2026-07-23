import Foundation
import Observation
import HackjackCore

/// Bridges the UI-free `GameEngine` to SwiftUI. `GameEngine` itself has
/// no SwiftUI dependency — this class exists purely to snapshot engine
/// state into `@Observable` properties after every call, since a plain
/// class's property mutations aren't otherwise tracked by the view system.
@Observable
final class GameViewModel {
    private let engine: GameEngine

    private(set) var runState: RunState
    private(set) var stageConfig: StageConfig
    private(set) var towers: [Hand]
    private(set) var mobs: [Mob]
    private(set) var shoeCount: Int
    private(set) var log: [String] = []

    init(runState: RunState = RunState()) {
        engine = GameEngine(runState: runState)
        self.runState = engine.runState
        self.stageConfig = engine.stageConfig
        self.towers = engine.towers
        self.mobs = engine.mobs
        self.shoeCount = engine.shoeCount
        Haptics.prepare()
        engine.startStage()
        sync()
    }

    private func sync() {
        runState = engine.runState
        stageConfig = engine.stageConfig
        towers = engine.towers
        mobs = engine.mobs
        shoeCount = engine.shoeCount
        log.append(contentsOf: engine.drainLog())
        if log.count > 60 {
            log.removeFirst(log.count - 60)
        }
        fireHaptics(for: engine.drainEvents())
    }

    /// Staggers back-to-back events the same way `DealTransition` staggers
    /// the matching visual — otherwise several feedback calls issued in
    /// the same runloop tick tend to blur into one buzz on-device instead
    /// of reading as distinct taps.
    private func fireHaptics(for events: [GameEvent]) {
        for (index, event) in events.enumerated() {
            let delay = min(Double(index) * 0.08, 0.4)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                switch event {
                case .cardDealt:
                    Haptics.cardDealt()
                case .mobHit:
                    Haptics.mobHit()
                case .mobKilled:
                    break // the kill is the hit that landed — avoid double-buzzing the same tick
                case .baseHit:
                    Haptics.baseHit()
                }
            }
        }
    }

    func hit(towerIndex: Int) {
        engine.hit(towerIndex: towerIndex)
        sync()
    }

    func redeal(towerIndex: Int) {
        engine.redeal(towerIndex: towerIndex)
        sync()
    }
}
