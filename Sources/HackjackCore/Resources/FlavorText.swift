/// Centralized narrative copy. Every call site picks a random line from
/// the relevant pool rather than a single fixed string, so the same beat
/// doesn't read identically hand after hand.
public enum FlavorText {
    public static let loadingScreen: [String] = [
        "Compiling defenses... towers online.",
        "The parade doesn't stop. Neither do you.",
        "Every packet in that line wants your root.",
        "Hold the line. Or don't — the base has done this before.",
    ]

    public static func mobKilled<G: RandomNumberGenerator>(card: String, using rng: inout G) -> String {
        let pool = [
            "\(card) crashed.",
            "\(card) — deleted.",
            "\(card) core-dumped before it got close.",
        ]
        return pool.randomElement(using: &rng)!
    }

    public static func baseHit<G: RandomNumberGenerator>(card: String, using rng: inout G) -> String {
        let pool = [
            "\(card) reached root. Integrity down.",
            "\(card) breached the base. That's going to cost you.",
            "\(card) got through. The towers were too slow.",
        ]
        return pool.randomElement(using: &rng)!
    }

    public static func stageCleared<G: RandomNumberGenerator>(using rng: inout G) -> String {
        let pool = [
            "Parade cleared. Compiling the next one — bigger.",
            "Stage held. Don't get comfortable.",
            "Line's clear. For now.",
        ]
        return pool.randomElement(using: &rng)!
    }

    public static func defeated<G: RandomNumberGenerator>(using rng: inout G) -> String {
        let pool = [
            "Base integrity hit zero. Rebooting the stage.",
            "Overrun. Restoring from the last checkpoint.",
            "The line broke. Try that stage again.",
        ]
        return pool.randomElement(using: &rng)!
    }
}
