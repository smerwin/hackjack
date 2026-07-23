import Foundation
import Observation
import HackjackCore

/// Bridges the UI-free `GameEngine` to SwiftUI. GameEngine itself has no
/// SwiftUI dependency (§3) — this class exists purely to snapshot engine
/// state into `@Observable` properties after every call, since a plain
/// class's property mutations aren't otherwise tracked by the view system.
@Observable
final class GameViewModel {
    private let engine: GameEngine

    private(set) var runState: RunState
    private(set) var shiftConfig: ShiftConfig
    private(set) var playerHands: [Hand]
    private(set) var activeHandIndex: Int
    private(set) var dealerHand: Hand
    private(set) var shoeCount: Int
    private(set) var currentBoss: BossCorruption?
    private(set) var ruleset: HandRuleset
    private(set) var pendingFirmwareOffer: FirmwareMutation?
    private(set) var pendingShopOffers: [ShopOffer]?
    private(set) var log: [String] = []
    private(set) var lastOutcomes: [HandOutcome] = []
    private(set) var dealerRevealed = false
    /// Bumps to a new value every time a *hidden* dealer hack fires —
    /// there's no on-screen card to strike for one of these (§5.4's
    /// shoe-resident target isn't in any rendered hand yet), so
    /// `TableView` watches this token to trigger a location-less ambient
    /// flash instead. A visible hack needs no equivalent here: the struck
    /// `CardView` picks up its own strike animation directly from its
    /// `rank`/`suit` changing.
    private(set) var hiddenHackPulse: UUID?

    var armedHack: PlayerHackType?
    var errorMessage: String?

    init(runState: RunState = RunState()) {
        engine = GameEngine(runState: runState)
        self.runState = engine.runState
        self.shiftConfig = engine.shiftConfig
        self.playerHands = engine.playerHands
        self.activeHandIndex = engine.activeHandIndex
        self.dealerHand = engine.dealerHand
        self.shoeCount = engine.shoe.count
        self.currentBoss = engine.currentBoss
        self.ruleset = engine.ruleset
        self.pendingFirmwareOffer = engine.pendingFirmwareOffer
        self.pendingShopOffers = engine.pendingShopOffers
        Haptics.prepare()
        startHand()
    }

    private func sync() {
        runState = engine.runState
        shiftConfig = engine.shiftConfig
        playerHands = engine.playerHands
        activeHandIndex = engine.activeHandIndex
        dealerHand = engine.dealerHand
        shoeCount = engine.shoe.count
        currentBoss = engine.currentBoss
        ruleset = engine.ruleset
        pendingFirmwareOffer = engine.pendingFirmwareOffer
        pendingShopOffers = engine.pendingShopOffers
        log.append(contentsOf: engine.drainLog())
        if log.count > 60 {
            log.removeFirst(log.count - 60)
        }
        fireHaptics(for: engine.drainEvents())
    }

    /// Staggers back-to-back events (an opening 4-card deal, mainly) the
    /// same way `DealTransition` staggers the matching visual — otherwise
    /// several `impactOccurred()` calls issued in the same runloop tick
    /// tend to blur into one buzz on-device instead of reading as distinct
    /// taps.
    private func fireHaptics(for events: [GameEvent]) {
        for (index, event) in events.enumerated() {
            let delay = min(Double(index) * 0.12, 0.4)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                switch event {
                case .cardDealt:
                    Haptics.cardDealt()
                case .hackTriggered(let visible):
                    Haptics.hackTriggered()
                    if !visible {
                        self.hiddenHackPulse = UUID()
                    }
                }
            }
        }
    }

    var allHandsResolved: Bool { engine.allPlayerHandsResolved }
    var canSplit: Bool { engine.canSplitActiveHand() }
    /// Non-nil exactly when the active hand busted from a hit and hasn't
    /// been locked in yet — the window `acceptBust()`/a rescuing hack
    /// resolves. See `Hand.isResolved` for why a bust alone doesn't
    /// already end the turn.
    var bustPendingHandIndex: Int? {
        guard !allHandsResolved, playerHands.indices.contains(activeHandIndex) else { return nil }
        return playerHands[activeHandIndex].isBusted ? activeHandIndex : nil
    }

    func startHand() {
        dealerRevealed = false
        armedHack = nil
        lastOutcomes = []
        engine.startHand()
        sync()
    }

    func hit() {
        engine.playerHit()
        sync()
        finishTurnIfNeeded()
    }

    func stand() {
        engine.playerStand()
        sync()
        finishTurnIfNeeded()
    }

    func split() {
        do {
            try engine.playerSplit()
        } catch {
            errorMessage = "Can't split that hand."
        }
        sync()
    }

    /// Locks in a bust the player didn't (or couldn't) hack their way out
    /// of. A no-op if the active hand isn't actually busted.
    func acceptBust() {
        engine.acceptBust()
        sync()
        finishTurnIfNeeded()
    }

    func arm(_ type: PlayerHackType) {
        armedHack = (armedHack == type) ? nil : type
        if type == .peek {
            peek()
        }
    }

    func targetCard(handIndex: Int?, cardID: UUID, isDealer: Bool) {
        guard let type = armedHack, type != .peek else { return }
        do {
            try engine.playerHack(type, targetIsDealer: isDealer, targetHandIndex: handIndex, cardID: cardID)
        } catch {
            errorMessage = describeHackError(error)
        }
        armedHack = nil
        sync()
    }

    private func peek() {
        do {
            try engine.playerHack(.peek)
        } catch {
            errorMessage = describeHackError(error)
        }
        armedHack = nil
        sync()
    }

    private func describeHackError(_ error: Error) -> String {
        switch error as? GameEngine.HackError {
        case .insufficientCharges: return "Not enough charges."
        case .patchDisabled: return "Firewall Down — no patches this hand."
        case .invalidTarget: return "Invalid target."
        case nil: return "Hack failed."
        }
    }

    private func finishTurnIfNeeded() {
        guard engine.allPlayerHandsResolved else { return }
        if playerHands.contains(where: { !$0.isBusted }) {
            engine.playDealerTurn()
        }
        sync()
        dealerRevealed = true
        lastOutcomes = engine.settleHands()
        sync()
    }

    func keepFirmware() {
        engine.keepFirmwareOffer()
        sync()
    }

    func declineFirmware() {
        engine.declineFirmwareOffer()
        sync()
    }

    func purchase(_ kind: ShopOfferKind) {
        engine.purchaseShopOffer(kind)
        sync()
    }

    func closeShop() {
        engine.closeShop()
        sync()
    }
}
