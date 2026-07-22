import SwiftUI
import HackjackCore

struct HandRowView: View {
    let hand: Hand
    let label: String
    let isActive: Bool
    let isDealer: Bool
    let hideHoleCard: Bool
    let isTargetable: Bool
    let onTapCard: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Term.dimGreen)
                if hand.isBusted {
                    Label("BUSTED", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Term.alertRed)
                } else if hand.isBlackjack {
                    Label("21!", systemImage: "bolt.fill")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.yellow)
                }
                Spacer()
                Text(isDealer && hideHoleCard ? "?" : "\(hand.bestValue)")
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
                        insertion: .dealt.animation(.spring(response: 0.42, dampingFraction: 0.78).delay(min(Double(index) * 0.1, 0.3))),
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
