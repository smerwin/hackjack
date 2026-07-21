public struct RunState: Sendable {
    public var currentShiftIndex: Int
    public var streakWithinShift: Int
    public var chargePool: HackChargePool
    public var shopCurrency: Int
    /// Permanent shop purchases that strip a mutation type out of generation.
    public var removedCorruptionTypes: Set<MutationType>
    public var firmware: FirmwareSlots
    /// Hands played in the current Shift without clearing it — drives the
    /// System Purge meter (§5.9).
    public var handsPlayedThisShift: Int
    /// Consumed one-at-a-time by the shop's "guarantee a favorable range"
    /// token (§5.7).
    public var favorableMutationCharges: Int
    public var isDailyBreach: Bool
    /// Set only for Daily Breach; when non-nil, GameEngine seeds its RNG
    /// from this instead of a fresh random seed (§5.10).
    public var seed: UInt64?

    public init(
        currentShiftIndex: Int = 1,
        streakWithinShift: Int = 0,
        chargePool: HackChargePool = HackChargePool(current: 3, max: 3),
        shopCurrency: Int = 0,
        removedCorruptionTypes: Set<MutationType> = [],
        firmware: FirmwareSlots = FirmwareSlots(),
        handsPlayedThisShift: Int = 0,
        favorableMutationCharges: Int = 0,
        isDailyBreach: Bool = false,
        seed: UInt64? = nil
    ) {
        self.currentShiftIndex = currentShiftIndex
        self.streakWithinShift = streakWithinShift
        self.chargePool = chargePool
        self.shopCurrency = shopCurrency
        self.removedCorruptionTypes = removedCorruptionTypes
        self.firmware = firmware
        self.handsPlayedThisShift = handsPlayedThisShift
        self.favorableMutationCharges = favorableMutationCharges
        self.isDailyBreach = isDailyBreach
        self.seed = seed
    }

    /// Derives a deterministic seed from a calendar-day string (e.g.
    /// "2026-07-20") via FNV-1a, so every player on the same day gets the
    /// same run — no wall-clock or device-random input involved (§5.10).
    public static func dailyBreach(dateKey: String) -> RunState {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in dateKey.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return RunState(
            chargePool: HackChargePool(current: 3, max: 3),
            isDailyBreach: true,
            seed: hash
        )
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
