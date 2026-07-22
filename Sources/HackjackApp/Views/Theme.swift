import SwiftUI

/// Shared terminal/script-kiddie visual language. Centralized so the whole
/// app reads as one system instead of scattered color literals — a
/// direct response to "the buttons don't explain themselves": monospace
/// everywhere, green-on-black terminal chrome, corruption stays purple so
/// it still reads as "an anomaly breaking through the normal system."
enum Term {
    static let green = Color(red: 0.31, green: 1.0, blue: 0.44)
    static let dimGreen = Color(red: 0.31, green: 1.0, blue: 0.44).opacity(0.55)
    static let background = Color.black
    static let alertRed = Color(red: 1.0, green: 0.28, blue: 0.35)
    static let corruptionPurple = Color(red: 0.72, green: 0.4, blue: 1.0)

    static let cornerRadius: CGFloat = 3
}

struct TerminalBracketButtonStyle: ButtonStyle {
    var tint: Color = Term.green
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .monospaced, weight: .bold))
            .foregroundStyle(filled ? Color.black : tint)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Term.cornerRadius)
                    .fill(filled ? tint : Color.black)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Term.cornerRadius)
                    .stroke(tint, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension View {
    func terminalPanel(tint: Color = Term.dimGreen) -> some View {
        self
            .background(Color.black.opacity(0.4))
            .overlay(RoundedRectangle(cornerRadius: Term.cornerRadius).stroke(tint, lineWidth: 1))
    }
}
