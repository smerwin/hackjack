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
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if hand.isBusted {
                    Label("Busted", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(.red)
                } else if hand.isBlackjack {
                    Label("21!", systemImage: "bolt.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(.yellow)
                }
                Spacer()
                Text(isDealer && hideHoleCard ? "?" : "\(hand.bestValue)")
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(.secondary)
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
        .background(RoundedRectangle(cornerRadius: 12).fill(isActive ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hand.cards.count)
    }
}
