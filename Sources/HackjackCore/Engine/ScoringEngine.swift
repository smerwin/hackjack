/// Streak/currency scoring and Shift advancement (§5.10). Pure over
/// RunState so it stays testable without a GameEngine instance.
public enum ScoringEngine {
    public static func apply(
        outcome: HandOutcome,
        usedHacksThisHand: Bool,
        shiftConfig: ShiftConfig,
        runState: inout RunState
    ) {
        switch outcome {
        case .playerWin, .playerBlackjack, .dealerBust:
            runState.streakWithinShift += usedHacksThisHand ? 1 : 2
            runState.shopCurrency += usedHacksThisHand ? 1 : 3
        case .push:
            break
        case .dealerWin, .dealerBlackjack, .playerBust:
            // Streak resets within the Shift only; Firmware/shop state
            // (once those systems exist) is untouched by design (§5.10).
            runState.streakWithinShift = 0
        }

        if runState.streakWithinShift >= shiftConfig.targetStreak {
            runState.currentShiftIndex += 1
            runState.streakWithinShift = 0
            runState.chargePool.max += 1
            runState.chargePool.current = runState.chargePool.max
        }
    }
}
