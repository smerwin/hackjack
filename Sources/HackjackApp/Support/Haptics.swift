import UIKit

/// Sharp, physical taps for the three things worth feeling: a card being
/// dealt, tower damage landing on a mob, and a mob reaching the base.
/// The last one is deliberately a different pattern — that's the "you're
/// losing" moment and needs to feel distinctly worse than a routine hit.
enum Haptics {
    private static let dealGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let mobHitGenerator = UINotificationFeedbackGenerator()
    private static let baseHitGenerator = UINotificationFeedbackGenerator()

    static func prepare() {
        dealGenerator.prepare()
        mobHitGenerator.prepare()
        baseHitGenerator.prepare()
    }

    static func cardDealt() {
        dealGenerator.impactOccurred(intensity: 0.85)
    }

    static func mobHit() {
        mobHitGenerator.notificationOccurred(.warning)
    }

    static func baseHit() {
        baseHitGenerator.notificationOccurred(.error)
    }
}
