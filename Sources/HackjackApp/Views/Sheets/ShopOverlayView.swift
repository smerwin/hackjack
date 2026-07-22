import SwiftUI
import HackjackCore

struct ShopOverlayView: View {
    let offers: [ShopOffer]
    let currency: Int
    let onPurchase: (ShopOfferKind) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("[ PATCH SHOP ]")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Term.green)
            Text("[CREDITS \(currency)]")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Term.dimGreen)
            VStack(spacing: 10) {
                ForEach(offers) { offer in
                    Button {
                        onPurchase(offer.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(offer.title).font(.subheadline.weight(.heavy))
                                Text(offer.description).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(offer.cost)")
                                .font(.subheadline.weight(.heavy).monospacedDigit())
                                .foregroundStyle(currency >= offer.cost ? Term.green : Term.alertRed)
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.4))
                        .overlay(RoundedRectangle(cornerRadius: Term.cornerRadius).stroke(Term.dimGreen.opacity(0.5), lineWidth: Term.lineRegular))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .disabled(currency < offer.cost)
                    .opacity(currency < offer.cost ? 0.5 : 1)
                }
            }
            Button("[ DONE ]", action: onClose)
                .buttonStyle(TerminalBracketButtonStyle(tint: Term.green, filled: true))
        }
        .padding(20)
        .frame(maxWidth: 360)
        .background(Color.black)
        .overlay(RoundedRectangle(cornerRadius: Term.cornerRadius).stroke(Term.green, lineWidth: Term.lineThick))
        .shadow(color: Term.green.opacity(0.3), radius: 20)
        .transition(.scale.combined(with: .opacity))
    }
}
