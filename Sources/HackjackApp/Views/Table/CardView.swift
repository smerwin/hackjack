import SwiftUI
import HackjackCore

/// Renders one card, face-up or face-down. Purely presentational — a
/// tower's own hand cards never mutate in place anymore (a hit only
/// appends a new card; a redeal replaces the whole hand with fresh card
/// identities), so there's nothing here that needs to watch for an
/// in-place change. The strike feedback for "this got hit" lives in
/// `MobParadeView` instead, since mobs are the thing that actually take
/// damage.
struct CardView: View {
    let card: Card
    var faceDown: Bool = false

    private var isRed: Bool { card.suit == .diamonds || card.suit == .hearts }

    var body: some View {
        ZStack {
            if faceDown {
                back
            } else {
                front
            }
        }
        .frame(width: 56, height: 80)
    }

    private var front: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(white: 1.0))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Term.green.opacity(0.5), lineWidth: Term.lineRegular)
            )
            .overlay {
                VStack(spacing: 2) {
                    Text(card.rank.symbol).font(.system(size: 21, weight: .heavy, design: .monospaced))
                    Text(card.suit.symbol).font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(isRed ? Color.red : Color.black)
            }
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
            .transition(.scale.combined(with: .opacity))
    }
}
