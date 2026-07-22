import SwiftUI

/// Ambient digital-rain background — purely decorative, sits behind all
/// game content at low opacity. Each column's character string, fall
/// duration, and start delay are randomized once (via `State(initialValue:)`
/// in `init`, which SwiftUI only honors the first time a view identity
/// appears) and then just loop forever — they must NOT re-randomize every
/// time `TableView` re-renders from a game-state change, or the rain would
/// visibly glitch on every tap. `.allowsHitTesting(false)` keeps it from
/// stealing taps meant for cards/buttons.
struct MatrixRainView: View {
    private let columnCount: Int
    private let charset = Array("01ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%&*+=<>[]/\\|?")

    init(columnCount: Int = 16) {
        self.columnCount = columnCount
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<columnCount, id: \.self) { _ in
                    MatrixColumn(charset: charset, height: geo.size.height)
                        .frame(width: geo.size.width / CGFloat(columnCount))
                }
            }
        }
        .mask(
            LinearGradient(
                colors: [.black.opacity(0), .black, .black, .black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .opacity(0.16)
        .allowsHitTesting(false)
    }
}

private struct MatrixColumn: View {
    let height: CGFloat

    @State private var offset: CGFloat
    @State private var text: String
    @State private var duration: Double
    @State private var delay: Double

    init(charset: [Character], height: CGFloat) {
        self.height = height
        let lineCount = 44
        _text = State(initialValue: (0..<lineCount).map { _ in String(charset.randomElement()!) }.joined(separator: "\n"))
        _offset = State(initialValue: -height)
        _duration = State(initialValue: Double.random(in: 4.5...9.0))
        _delay = State(initialValue: Double.random(in: 0...4))
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(Term.green)
            .lineSpacing(6)
            .fixedSize()
            .offset(y: offset)
            .onAppear {
                withAnimation(.linear(duration: duration).delay(delay).repeatForever(autoreverses: false)) {
                    offset = height
                }
            }
    }
}
