public struct RunState: Sendable {
    public var currentShiftIndex: Int
    public var streakWithinShift: Int
    public var chargePool: HackChargePool
    public var shopCurrency: Int
    /// Permanent shop purchases that strip a mutation type out of generation.
    public var removedCorruptionTypes: Set<MutationType>

    public init(
        currentShiftIndex: Int = 1,
        streakWithinShift: Int = 0,
        chargePool: HackChargePool = HackChargePool(current: 3, max: 3),
        shopCurrency: Int = 0,
        removedCorruptionTypes: Set<MutationType> = []
    ) {
        self.currentShiftIndex = currentShiftIndex
        self.streakWithinShift = streakWithinShift
        self.chargePool = chargePool
        self.shopCurrency = shopCurrency
        self.removedCorruptionTypes = removedCorruptionTypes
    }
}

public enum HandOutcome: Sendable {
    case playerBlackjack
    case dealerBlackjack
    case playerBust
    case dealerBust
    case playerWin
    case dealerWin
    case push
}
