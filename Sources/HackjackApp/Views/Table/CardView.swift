import SwiftUI
import HackjackCore

/// Renders one card. `Card.sparkTell`/`pendingMutations` is the single
/// source of truth for the shimmer — this view never re-derives "is this
/// card hacked" from anything else (§5.2).
///
/// What's actually *shown* (`displayedCard`) is deliberately decoupled
/// from the live `card` prop: when `rank`/`suit` change in place — a
/// hack landing, or a spark resolving — the engine has already committed
/// the new value by the time this view re-renders, so without this
/// buffer the swap would be instant and silent. Instead the view holds
/// the old value on screen, plays a lightning-strike beat, and only then
/// reveals the new one. `Card`'s own `Equatable` only compares `id`, so
/// detecting this needs `.onChange` on `rank`/`suit` directly, not on
/// `card` as a whole.
struct CardView: View {
    let card: Card
    var faceDown: Bool = false
    var isTargetable: Bool = false
    var onTap: (() -> Void)? = nil

    @State private var displayedCard: Card
    @State private var shimmer = false
    @State private var isStriking = false
    @State private var strikeShake: CGFloat = 0

    init(card: Card, faceDown: Bool = false, isTargetable: Bool = false, onTap: (() -> Void)? = nil) {
        self.card = card
        self.faceDown = faceDown
        self.isTargetable = isTargetable
        self.onTap = onTap
        _displayedCard = State(initialValue: card)
    }

    private var isRed: Bool { displayedCard.suit == .diamonds || displayedCard.suit == .hearts }
    private var isSparking: Bool { card.pendingMutations != nil }

    var body: some View {
        ZStack {
            if faceDown {
                back
            } else {
                front
            }
        }
        .frame(width: 56, height: 80)
        .rotation3DEffect(.degrees(shimmer ? 2.5 : 0), axis: (x: 0, y: 0, z: 1))
        .scaleEffect(shimmer ? 1.035 : (isStriking ? 1.08 : 1.0))
        .offset(x: strikeShake * 5)
        .animation(.easeInOut(duration: 0.35), value: faceDown)
        .onAppear { startShimmerIfNeeded() }
        .onChange(of: isSparking) { _, _ in startShimmerIfNeeded() }
        .onChange(of: card.rank) { _, _ in triggerStrikeIfNeeded() }
        .onChange(of: card.suit) { _, _ in triggerStrikeIfNeeded() }
        .onTapGesture { onTap?() }
    }

    private func startShimmerIfNeeded() {
        guard isSparking else {
            shimmer = false
            return
        }
        withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
            shimmer = true
        }
    }

    /// Holds `displayedCard` at its old value for one beat while a bolt
    /// strikes the card, then reveals whatever `card` has already become.
    /// Guarded against re-entry so a rank-and-suit change in the same
    /// update (e.g. a natural mutation resolve landing alongside a fresh
    /// hack) only plays one strike, not two overlapping ones.
    private func triggerStrikeIfNeeded() {
        guard !isStriking else { return }
        isStriking = true
        withAnimation(.easeInOut(duration: 0.05).repeatCount(7, autoreverses: true)) {
            strikeShake = 1
        }
        let revealedCard = card
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            strikeShake = 0
            withAnimation(.spring(response: 0.3, dampingFraction: 0.62)) {
                displayedCard = revealedCard
            }
            withAnimation(.easeOut(duration: 0.15)) {
                isStriking = false
            }
        }
    }

    private var front: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(white: 1.0))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSparking ? Term.corruptionPurple : Term.green.opacity(0.5), lineWidth: isSparking ? Term.lineEmphasis : Term.lineRegular)
            )
            .overlay {
                VStack(spacing: 2) {
                    Text(displayedCard.rank.symbol).font(.system(size: 21, weight: .heavy, design: .monospaced))
                    Text(displayedCard.suit.symbol).font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(isRed ? Color.red : Color.black)
                .opacity(isStriking ? 0.15 : 1)
            }
            .overlay {
                if isTargetable {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(Color.yellow, lineWidth: Term.lineEmphasis)
                }
            }
            .overlay {
                if isStriking {
                    LightningBoltShape()
                        .fill(Color.white)
                        .shadow(color: Term.corruptionPurple, radius: 8)
                        .shadow(color: .white, radius: 3)
                        .transition(.opacity.combined(with: .scale(scale: 1.4)))
                }
            }
            .overlay {
                if isStriking {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Term.corruptionPurple.opacity(0.3))
                        .blendMode(.plusLighter)
                        .transition(.opacity)
                }
            }
            .shadow(color: isSparking ? Term.corruptionPurple.opacity(0.7) : .clear, radius: isSparking ? 9 : 0)
            .transition(.scale.combined(with: .opacity))
    }

    private var back: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(colors: [Color(red: 0.03, green: 0.15, blue: 0.07), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Term.green.opacity(0.5), lineWidth: Term.lineRegular))
            .overlay {
                Text(">_")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Term.green.opacity(0.7))
            }
            .overlay {
                if isStriking {
                    LightningBoltShape()
                        .fill(Color.white)
                        .shadow(color: Term.corruptionPurple, radius: 8)
                        .shadow(color: .white, radius: 3)
                        .transition(.opacity.combined(with: .scale(scale: 1.4)))
                }
            }
            .transition(.scale.combined(with: .opacity))
    }
}

/// A simple jagged bolt silhouette — used both here (a hack physically
/// striking a card) and could be reused wherever else "something got hit"
/// needs to read at a glance.
private struct LightningBoltShape: Shape {
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
