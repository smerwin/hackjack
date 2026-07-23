/// One stage of the defense — a parade of mobs the player has to kill or
/// survive before the base takes too much damage. Replaces the old
/// `ShiftConfig` (Shift → Stage, target streak → mob parade).
public struct StageConfig: Sendable {
    public let index: Int
    public let mobCount: Int
    /// Steps (player actions) a freshly-spawned mob takes to reach the
    /// base, before towers whittle it down.
    public let mobStartingSteps: Int
    /// Scales `Rank.blackjackValue` into a mob's starting HP — 1.0 at
    /// Stage 1 (a King mob has 10 HP, a Two has 2), climbing each stage.
    public let mobHPMultiplier: Double

    public init(index: Int, mobCount: Int, mobStartingSteps: Int, mobHPMultiplier: Double) {
        self.index = index
        self.mobCount = mobCount
        self.mobStartingSteps = mobStartingSteps
        self.mobHPMultiplier = mobHPMultiplier
    }

    /// Working defaults: more mobs and tankier mobs each stage, capped so
    /// late stages stay finite rather than runaway; steps-to-base shrinks
    /// slightly (faster mobs) down to a floor so the parade never becomes
    /// instant.
    public static func standard(index: Int) -> StageConfig {
        StageConfig(
            index: index,
            mobCount: min(6 + (index - 1) * 2, 24),
            mobStartingSteps: max(3, 6 - (index - 1)),
            mobHPMultiplier: 1.0 + Double(index - 1) * 0.5
        )
    }
}
