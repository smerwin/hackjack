public struct RunState: Sendable {
    public var stageIndex: Int
    public var baseHP: Int
    public var baseMaxHP: Int
    /// Set only for Daily Breach; when non-nil, GameEngine seeds its RNG
    /// from this instead of a fresh random seed.
    public var seed: UInt64?

    public init(
        stageIndex: Int = 1,
        baseHP: Int = 10,
        baseMaxHP: Int = 10,
        seed: UInt64? = nil
    ) {
        self.stageIndex = stageIndex
        self.baseHP = baseHP
        self.baseMaxHP = baseMaxHP
        self.seed = seed
    }

    /// Derives a deterministic seed from a calendar-day string (e.g.
    /// "2026-07-20") via FNV-1a, so every player on the same day gets the
    /// same run — no wall-clock or device-random input involved.
    public static func dailyBreach(dateKey: String) -> RunState {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in dateKey.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return RunState(seed: hash)
    }
}
