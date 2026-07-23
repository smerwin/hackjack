import SwiftUI

/// A simple jagged bolt silhouette — the visual for "something just got
/// hit." Used by `MobParadeView` when tower damage lands on a mob.
struct LightningBoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.58, y: 0))
        path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.48))
        path.addLine(to: CGPoint(x: w * 0.32, y: h))
        path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.42))
        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.42))
        path.closeSubpath()
        return path
    }
}
