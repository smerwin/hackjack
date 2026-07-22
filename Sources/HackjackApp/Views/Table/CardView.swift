import SwiftUI
import HackjackCore

/// Renders one card. `Card.sparkTell`/`pendingMutations` is the single
/// source of truth for the shimmer — this view never re-derives "is this
/// card hacked" from anything else (§5.2).
struct CardView: View {
    let card: Card
    var faceDown: Bool = false
    var isTargetable: Bool = false
    var onTap: (() -> Void)? = nil

    @State private var shimmer = false

    private var isRed: Bool { card.suit == .diamonds || card.suit == .hearts }
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
        .scaleEffect(shimmer ? 1.035 : 1.0)
        .animation(.easeInOut(duration: 0.35), value: faceDown)
        .onAppear { startShimmerIfNeeded() }
        .onChange(of: isSparking) { _, _ in startShimmerIfNeeded() }
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

    private var front: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(white: 1.0))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSparking ? Term.corruptionPurple : Term.green.opacity(0.4), lineWidth: isSparking ? 2.5 : 1)
            )
            .overlay {
                VStack(spacing: 2) {
                    Text(card.rank.symbol).font(.system(size: 20, weight: .bold, design: .monospaced))
                    Text(card.suit.symbol).font(.system(size: 15))
                }
                .foregroundStyle(isRed ? Color.red : Color.black)
            }
            .overlay {
                if isTargetable {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(Color.yellow, lineWidth: 3)
                }
            }
            .shadow(color: isSparking ? Term.corruptionPurple.opacity(0.7) : .clear, radius: isSparking ? 9 : 0)
            .transition(.scale.combined(with: .opacity))
    }

    private var back: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(colors: [Color(red: 0.03, green: 0.15, blue: 0.07), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Term.green.opacity(0.4), lineWidth: 1))
            .overlay {
                Text(">_")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Term.green.opacity(0.6))
            }
            .transition(.scale.combined(with: .opacity))
    }
}
