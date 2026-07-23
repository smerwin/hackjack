import SwiftUI
import HackjackCore

struct HandRowView: View {
    let hand: Hand
    let label: String
    let isActive: Bool
    let isDealer: Bool
    let hideHoleCard: Bool
    let isTargetable: Bool
    /// Real shoe → this-row vector, computed by `TableView.dealOrigin(for:)`
    /// from reported frames — see `DealTransition.swift`.
    let dealOrigin: CGSize
    let onTapCard: (UUID) -> Void

    /// False while the dealer's hole card is still face down — gates
    /// every badge/value that would otherwise leak the dealer's hand
    /// early (§5.2's spark tell already respects this same idea: nothing
    /// about a hidden card should be readable from other UI state).
    private var isRevealed: Bool { !(isDealer && hideHoleCard) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Term.dimGreen)
                if isRevealed && hand.isBusted {
                    Label("BUSTED", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Term.alertRed)
                } else if isRevealed && hand.isBlackjack {
                    Label("21!", systemImage: "bolt.fill")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.yellow)
                }
                Spacer()
                Text(isRevealed ? "\(hand.bestValue)" : "?")
                    .font(.subheadline.monospacedDigit().weight(.heavy))
                    .foregroundStyle(Term.green)
            }
            HStack(spacing: 6) {
                ForEach(Array(hand.cards.enumerated()), id: \.element.id) { index, card in
                    CardView(
                        card: card,
                        faceDown: isDealer && hideHoleCard && index == 1,
                        isTargetable: isTargetable,
                        onTap: { onTapCard(card.id) }
                    )
                    .transition(.asymmetric(
                        insertion: .dealt(from: dealOrigin).animation(.spring(response: 0.42, dampingFraction: 0.78).delay(min(Double(index) * 0.1, 0.3))),
                        removal: .opacity.combined(with: .scale(scale: 0.7)).animation(.easeIn(duration: 0.15))
                    ))
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.4))
        .overlay(RoundedRectangle(cornerRadius: Term.cornerRadius).stroke(isActive ? Term.green : Term.dimGreen.opacity(0.35), lineWidth: isActive ? Term.lineThick : Term.lineRegular))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hand.cards.count)
    }
}
