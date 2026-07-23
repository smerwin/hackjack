import UIKit

/// Sharp, physical taps for two things: a card being dealt, and a hack
/// resolving. The hack tap is the one that matters most — it's the only
/// tell a hidden dealer hack gets at all right now (§5.2, §0's documented
/// gap: hidden hacks have no visual tell in this app, only a log line).
/// A vibration is neither visual nor text, so it can carry that cue
/// without breaking the "spark is the only tell" rule.
enum Haptics {
    private static let dealGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let hackGenerator = UINotificationFeedbackGenerator()

    static func prepare() {
        dealGenerator.prepare()
        hackGenerator.prepare()
    }

    static func cardDealt() {
        dealGenerator.impactOccurred(intensity: 0.85)
    }

    /// Distinct pattern from `cardDealt()` on purpose — a hack, especially
    /// a hidden one, needs to read as "something different just happened,"
    /// not just another card landing.
    static func hackTriggered() {
        hackGenerator.notificationOccurred(.warning)
    }
}
