import SwiftUI
import HackjackCore

struct ShopOverlayView: View {
    let offers: [ShopOffer]
    let currency: Int
    let onPurchase: (ShopOfferKind) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("PATCH SHOP")
                .font(.headline.bold())
            Text("Currency: \(currency)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(spacing: 10) {
                ForEach(offers) { offer in
                    Button {
                        onPurchase(offer.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(offer.title).font(.subheadline.bold())
                                Text(offer.description).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(offer.cost)")
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(currency >= offer.cost ? Color.green : Color.red)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .disabled(currency < offer.cost)
                }
            }
            Button("Done", action: onClose)
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 20)
        .transition(.scale.combined(with: .opacity))
    }
}
