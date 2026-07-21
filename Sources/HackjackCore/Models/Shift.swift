public struct ShiftConfig: Sendable {
    public let index: Int
    public let targetStreak: Int
    /// Fraction of the shoe that spawns sparking, sampled once per shoe build.
    public let corruptionDensity: ClosedRange<Double>
    /// Probability the dealer attempts a hack after a given player action.
    public let dealerHackChance: Double
    public let hiddenHacksUnlocked: Bool

    public init(index: Int, targetStreak: Int, corruptionDensity: ClosedRange<Double>, dealerHackChance: Double, hiddenHacksUnlocked: Bool) {
        self.index = index
        self.targetStreak = targetStreak
        self.corruptionDensity = corruptionDensity
        self.dealerHackChance = dealerHackChance
        self.hiddenHacksUnlocked = hiddenHacksUnlocked
    }

    /// Working defaults from CLAUDE.md §8: hidden hacks unlock mid-run
    /// (Shift 4+), corruption density and dealer hack pressure climb each
    /// Shift, both capped so late-run hands stay legible rather than chaotic.
    public static func standard(index: Int) -> ShiftConfig {
        let density = min(0.10 + Double(index - 1) * 0.05, 0.45)
        let hackChance = min(0.15 + Double(index - 1) * 0.08, 0.6)
        return ShiftConfig(
            index: index,
            targetStreak: 3 + index,
            corruptionDensity: density...min(density + 0.15, 0.6),
            dealerHackChance: hackChance,
            hiddenHacksUnlocked: index >= 4
        )
    }
}
