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
                    .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .frame(width: 46, height: 64)
            } else {
                ForEach(0..<stackCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [Color.indigo, Color.black], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 46, height: 64)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
                        .offset(x: CGFloat(i) * 2, y: -CGFloat(i) * 2)
                }
                Image(systemName: "bolt.horizontal.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .offset(x: CGFloat(stackCount - 1) * 2, y: -CGFloat(stackCount - 1) * 2)
            }
        }
        .frame(width: 54, height: 72)
        .overlay(alignment: .bottom) {
            Text("\(remaining) left")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize()
                .offset(y: 14)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: stackCount)
    }
}
