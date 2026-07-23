import SwiftUI
import HackjackCore

/// One tower: its live hand, its current power, and the two actions that
/// drive it. Every tower plays independently and simultaneously — there's
/// no single "active hand" anymore, so each row owns its own HIT/REDEAL
/// controls rather than sharing one global action bar.
struct TowerRowView: View {
    let index: Int
    let hand: Hand
    /// Real shoe → this-row vector, computed by `TableView.dealOrigin(for:)`
    /// from reported frames — see `DealTransition.swift`.
    let dealOrigin: CGSize
    let onHit: () -> Void
    let onRedeal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TOWER \(index)")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Term.dimGreen)
                if hand.isBusted {
                    Label("DEAD", systemImage: "bolt.slash.fill")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Term.alertRed)
                } else if hand.isBlackjack {
                    Label("21!", systemImage: "bolt.fill")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.yellow)
                }
                Spacer()
                Text("PWR \(hand.power)")
                    .font(.subheadline.monospacedDigit().weight(.heavy))
                    .foregroundStyle(hand.power > 0 ? Term.green : Term.alertRed)
            }
            HStack(spacing: 6) {
                ForEach(Array(hand.cards.enumerated()), id: \.element.id) { i, card in
                    CardView(card: card)
                        .transition(.asymmetric(
                            insertion: .dealt(from: dealOrigin).animation(.spring(response: 0.42, dampingFraction: 0.78).delay(min(Double(i) * 0.1, 0.3))),
                            removal: .opacity.combined(with: .scale(scale: 0.7)).animation(.easeIn(duration: 0.15))
                        ))
                }
            }
            HStack(spacing: 10) {
                Button("[ HIT ]") { withAnimation { onHit() } }
                    .buttonStyle(TerminalBracketButtonStyle(tint: Term.green, filled: true))
                    .disabled(hand.isBusted)
                Button("[ REDEAL ]") { withAnimation { onRedeal() } }
                    .buttonStyle(TerminalBracketButtonStyle(tint: Term.alertRed))
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.4))
        .overlay(RoundedRectangle(cornerRadius: Term.cornerRadius).stroke(Term.dimGreen.opacity(0.35), lineWidth: Term.lineRegular))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hand.cards.count)
    }
}
