import SwiftUI

/// A visible stack for the remaining shoe (§6 — previously missing
/// entirely). Purely a count-driven visual; it doesn't track individual
/// `Card`s, since the engine rebuilds the shoe fresh each hand and nothing
/// in the app needs to know which specific card is on top.
struct ShoeView: View {
    let remaining: Int

    private var stackCount: Int {
        guard remaining > 0 else { return 0 }
        return min(4, 1 + remaining / 13)
    }

    var body: some View {
        ZStack {
            if stackCount == 0 {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Term.dimGreen, style: StrokeStyle(lineWidth: Term.lineRegular, dash: [4]))
                    .frame(width: 46, height: 64)
            } else {
                ForEach(0..<stackCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [Color(red: 0.03, green: 0.15, blue: 0.07), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 46, height: 64)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Term.green.opacity(0.45), lineWidth: Term.lineRegular))
                        .offset(x: CGFloat(i) * 2, y: -CGFloat(i) * 2)
                }
                Text(">_")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Term.green.opacity(0.5))
                    .offset(x: CGFloat(stackCount - 1) * 2, y: -CGFloat(stackCount - 1) * 2)
            }
        }
        .frame(width: 54, height: 72)
        .overlay(alignment: .bottom) {
            Text("[\(remaining) LEFT]")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(Term.dimGreen)
                .fixedSize()
                .offset(y: 14)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: stackCount)
    }
}
