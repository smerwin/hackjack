import SwiftUI
import HackjackCore

struct FirmwareOfferOverlayView: View {
    let offer: FirmwareMutation
    let onKeep: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("[ FIRMWARE OFFER ]")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Term.corruptionPurple)
            Text(offer.effect.displayName)
                .font(.title2.weight(.heavy))
                .foregroundStyle(Term.green)
            Text(offer.effect.flavorDescription)
                .font(.body.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 12) {
                Button("[ DECLINE ]", action: onDecline)
                    .buttonStyle(TerminalBracketButtonStyle(tint: Term.dimGreen))
                Button("[ KEEP ]", action: onKeep)
                    .buttonStyle(TerminalBracketButtonStyle(tint: Term.corruptionPurple, filled: true))
            }
        }
        .padding(24)
        .frame(maxWidth: 340)
        .background(Color.black)
        .overlay(RoundedRectangle(cornerRadius: Term.cornerRadius).stroke(Term.corruptionPurple, lineWidth: Term.lineThick))
        .shadow(color: Term.corruptionPurple.opacity(0.4), radius: 20)
        .transition(.scale.combined(with: .opacity))
    }
}
