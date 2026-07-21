import SwiftUI
import HackjackCore

struct FirmwareOfferOverlayView: View {
    let offer: FirmwareMutation
    let onKeep: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("FIRMWARE OFFER")
                .font(.caption.bold())
                .foregroundStyle(.purple)
            Text(offer.effect.displayName)
                .font(.title2.bold())
            Text(offer.effect.flavorDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Decline", role: .cancel, action: onDecline)
                    .buttonStyle(.bordered)
                Button("Keep", action: onKeep)
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
            }
        }
        .padding(24)
        .frame(maxWidth: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 20)
        .transition(.scale.combined(with: .opacity))
    }
}
