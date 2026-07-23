import SwiftUI
import HackjackCore

/// The parade rendered as an actual receding lane — real cards, faces up,
/// laid out by their true distance to the base rather than a flat
/// horizontal list. The mob closest to the base (the one taking tower
/// damage every tick) renders largest, nearest the base marker; farther
/// mobs shrink, drift up, and fade slightly, reading as "marching in
/// from a distance" rather than just a row of icons.
struct MobParadeView: View {
    let mobs: [Mob]
    /// `stageConfig.mobStartingSteps` — every mob spawns at this many
    /// steps out, so it's the normalization denominator for how far
    /// "away" a mob currently reads.
    let maxSteps: Int

    /// Farthest-drawn-first so the nearest (largest) mob's card visually
    /// overlaps *on top of* anything behind it, like real depth — SwiftUI
    /// draws later ZStack children over earlier ones.
    private var farToNear: [Mob] {
        mobs.sorted { $0.stepsRemaining > $1.stepsRemaining }
    }

    private func depth(_ mob: Mob) -> CGFloat {
        guard maxSteps > 0 else { return 0 }
        return min(1, max(0, CGFloat(mob.stepsRemaining) / CGFloat(maxSteps)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PARADE")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Term.dimGreen)

            if mobs.isEmpty {
                Text("(clear)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Term.dimGreen)
                    .padding(.vertical, 12)
            } else {
                GeometryReader { proxy in
                    ZStack(alignment: .trailing) {
                        laneMarkings(width: proxy.size.width)
                        baseMarker

                        ForEach(farToNear) { mob in
                            let d = depth(mob)
                            MobTokenView(mob: mob)
                                .scaleEffect(1.0 - d * 0.45)
                                .opacity(1.0 - d * 0.35)
                                .offset(
                                    x: -d * proxy.size.width * 0.78 - 40,
                                    y: -d * 22
                                )
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .trailing)
                    .clipped()
                }
                .frame(height: 150)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: mobs.map { "\($0.id)-\($0.stepsRemaining)" })
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.4))
        .overlay(RoundedRectangle(cornerRadius: Term.cornerRadius).stroke(Term.alertRed.opacity(0.35), lineWidth: Term.lineRegular))
    }

    private func laneMarkings(width: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: width * 0.05, y: 40))
            path.addLine(to: CGPoint(x: width - 30, y: 95))
        }
        .stroke(Term.dimGreen.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [3, 6]))
    }

    private var baseMarker: some View {
        VStack(spacing: 2) {
            Image(systemName: "server.rack")
                .font(.system(size: 18, weight: .heavy))
            Text("ROOT")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
        }
        .foregroundStyle(Term.green)
        .padding(.trailing, 4)
    }
}

/// One mob's token — its card, HP, and distance to the base. Watches its
/// own `hp` for changes to trigger a strike beat; a mob's `hp` is the
/// only thing about it that ever mutates in place, so there's no need
/// for an externally-driven event to detect "I just got hit."
private struct MobTokenView: View {
    let mob: Mob

    @State private var isStriking = false
    @State private var shake: CGFloat = 0

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                CardView(card: mob.card)
                if isStriking {
                    LightningBoltShape()
                        .fill(Color.white)
                        .shadow(color: Term.strikePurple, radius: 8)
                        .shadow(color: .white, radius: 3)
                        .frame(width: 56, height: 80)
                        .transition(.opacity.combined(with: .scale(scale: 1.4)))
                }
            }
            .offset(x: shake * 4)
            Text("HP \(mob.hp)")
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(Term.alertRed)
            Text("\(mob.stepsRemaining)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Term.dimGreen)
        }
        .onChange(of: mob.hp) { _, _ in triggerStrike() }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.5)),
            removal: .opacity.combined(with: .scale(scale: 0.4))
        ))
    }

    private func triggerStrike() {
        isStriking = true
        withAnimation(.easeInOut(duration: 0.05).repeatCount(5, autoreverses: true)) {
            shake = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            shake = 0
            withAnimation(.easeOut(duration: 0.15)) {
                isStriking = false
            }
        }
    }
}
