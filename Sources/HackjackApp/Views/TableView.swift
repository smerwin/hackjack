import SwiftUI
import HackjackCore

struct TableView: View {
    @State private var viewModel = GameViewModel()
    /// Frames reported by `reportFrame(_:)` (the shoe and each tower row)
    /// in the shared "table" coordinate space below — `dealOrigin(for:)`
    /// turns these into the real shoe → tower vector each `TowerRowView`
    /// flies its newly-dealt cards in from.
    @State private var frames: [String: CGRect] = [:]

    var body: some View {
        ZStack {
            background
            VStack(spacing: 10) {
                header
                statusReadout
                shoeRow

                ScrollView {
                    VStack(spacing: 10) {
                        MobParadeView(mobs: viewModel.mobs, maxSteps: viewModel.stageConfig.mobStartingSteps)

                        ForEach(Array(viewModel.towers.enumerated()), id: \.element.id) { index, hand in
                            TowerRowView(
                                index: index,
                                hand: hand,
                                dealOrigin: dealOrigin(for: "tower-\(hand.id)"),
                                onHit: { viewModel.hit(towerIndex: index) },
                                onRedeal: { viewModel.redeal(towerIndex: index) }
                            )
                            .reportFrame("tower-\(hand.id)")
                        }

                        logFeed
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 8)
            .fontDesign(.monospaced)
        }
        .coordinateSpace(name: "table")
        .onPreferenceChange(FramePreferenceKey.self) { frames = $0 }
    }

    private var background: some View {
        ZStack {
            Term.background
            MatrixRainView()
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack {
            Text("> HACKJACK :: DEFENSE")
                .font(.system(.footnote, design: .monospaced, weight: .bold))
                .foregroundStyle(Term.green)
            Text("_")
                .font(.system(.footnote, design: .monospaced, weight: .bold))
                .foregroundStyle(Term.green)
                .opacity(0.8)
            Spacer()
        }
        .padding(.horizontal)
    }

    private var statusReadout: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                bracketStat("STAGE", "\(viewModel.runState.stageIndex)")
                bracketStat("BASE", "\(viewModel.runState.baseHP)/\(viewModel.runState.baseMaxHP)")
                bracketStat("POWER", "\(viewModel.towers.reduce(0) { $0 + $1.power })")
            }
        }
        .padding(.horizontal)
    }

    private func bracketStat(_ label: String, _ value: String) -> some View {
        Text("[\(label) \(value)]")
            .font(.system(.caption2, design: .monospaced, weight: .bold))
            .foregroundStyle(Term.green)
    }

    private var shoeRow: some View {
        HStack {
            Spacer()
            ShoeView(remaining: viewModel.shoeCount)
                .reportFrame("shoe")
        }
        .padding(.horizontal)
    }

    /// Real shoe → tower-row vector for the deal-in transition, from
    /// frames `reportFrame(_:)` bubbles up. Falls back to a fixed guess
    /// until both frames have actually been reported at least once (the
    /// first render or two, before layout has run).
    private func dealOrigin(for key: String) -> CGSize {
        guard let shoe = frames["shoe"], let row = frames[key] else {
            return CGSize(width: -60, height: -70)
        }
        return CGSize(width: shoe.midX - row.midX, height: shoe.midY - row.midY)
    }

    private var logFeed: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(viewModel.log.suffix(6).enumerated()), id: \.offset) { _, line in
                Text("$ \(line)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Term.dimGreen)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
