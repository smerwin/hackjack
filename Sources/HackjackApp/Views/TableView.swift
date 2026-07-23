import SwiftUI
import HackjackCore

struct TableView: View {
    @State private var viewModel = GameViewModel()
    /// Frames reported by `reportFrame(_:)` (the shoe, the dealer row, and
    /// each hand row) in the shared "table" coordinate space below —
    /// `dealOrigin(for:)` turns these into the real shoe → hand vector
    /// each `HandRowView` flies its newly-dealt cards in from.
    @State private var frames: [String: CGRect] = [:]

    var body: some View {
        ZStack {
            background
            VStack(spacing: 10) {
                header
                statusReadout
                shoeRow
                if let boss = viewModel.currentBoss {
                    bossBanner(boss)
                }
                ScrollView {
                    VStack(spacing: 10) {
                        HandRowView(
                            hand: viewModel.dealerHand,
                            label: "DEALER",
                            isActive: false,
                            isDealer: true,
                            hideHoleCard: !viewModel.dealerRevealed,
                            isTargetable: viewModel.armedHack != nil,
                            dealOrigin: dealOrigin(for: "dealer"),
                            onTapCard: { id in viewModel.targetCard(handIndex: nil, cardID: id, isDealer: true) }
                        )
                        .reportFrame("dealer")

                        ForEach(Array(viewModel.playerHands.enumerated()), id: \.element.id) { index, hand in
                            HandRowView(
                                hand: hand,
                                label: viewModel.playerHands.count > 1 ? "HAND \(index + 1)" : "YOU",
                                isActive: index == viewModel.activeHandIndex && !viewModel.allHandsResolved,
                                isDealer: false,
                                hideHoleCard: false,
                                isTargetable: viewModel.armedHack != nil && index == viewModel.activeHandIndex,
                                dealOrigin: dealOrigin(for: "hand-\(hand.id)"),
                                onTapCard: { id in viewModel.targetCard(handIndex: index, cardID: id, isDealer: false) }
                            )
                            .reportFrame("hand-\(hand.id)")
                        }

                        if viewModel.dealerRevealed && !viewModel.lastOutcomes.isEmpty {
                            outcomeBanner
                        }

                        logFeed
                    }
                    .padding(.horizontal)
                }

                if let armed = viewModel.armedHack {
                    armedHackHint(armed)
                }

                if viewModel.dealerRevealed && !viewModel.lastOutcomes.isEmpty {
                    Button("[ NEXT HAND ]") {
                        withAnimation { viewModel.startHand() }
                    }
                    .buttonStyle(TerminalBracketButtonStyle(tint: Term.green, filled: true))
                    .padding(.horizontal)
                } else if viewModel.bustPendingHandIndex != nil {
                    bustReprieveBar
                    hackToolsMenu
                } else {
                    actionBar
                    hackToolsMenu
                }
            }
            .padding(.top, 8)
            .fontDesign(.monospaced)

            if let offer = viewModel.pendingFirmwareOffer {
                dimmedOverlay {
                    FirmwareOfferOverlayView(
                        offer: offer,
                        onKeep: { withAnimation { viewModel.keepFirmware() } },
                        onDecline: { withAnimation { viewModel.declineFirmware() } }
                    )
                }
            } else if let offers = viewModel.pendingShopOffers {
                dimmedOverlay {
                    ShopOverlayView(
                        offers: offers,
                        currency: viewModel.runState.shopCurrency,
                        onPurchase: { viewModel.purchase($0) },
                        onClose: { withAnimation { viewModel.closeShop() } }
                    )
                }
            }

            if let pulse = viewModel.hiddenHackPulse {
                HiddenHackFlashView().id(pulse)
            }
        }
        .coordinateSpace(name: "table")
        .onPreferenceChange(FramePreferenceKey.self) { frames = $0 }
        .alert("HACKJACK", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
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
            Text("> HACKJACK v0.2")
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
                bracketStat("SHIFT", "\(viewModel.runState.currentShiftIndex)")
                bracketStat("STREAK", "\(viewModel.runState.streakWithinShift)/\(viewModel.shiftConfig.targetStreak)")
            }
            HStack(spacing: 8) {
                bracketStat("CHARGES", "\(viewModel.runState.chargePool.current)/\(viewModel.runState.chargePool.max)")
                bracketStat("CREDITS", "\(viewModel.runState.shopCurrency)")
                bracketStat("FIRMWARE", "\(viewModel.runState.firmware.equipped.count)/\(viewModel.runState.firmware.capacity)")
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

    /// Real shoe → hand-row vector for the deal-in transition, from
    /// frames `reportFrame(_:)` bubbles up. Falls back to the old fixed
    /// guess until both frames have actually been reported at least once
    /// (the first render or two, before layout has run) so a card never
    /// deals with a zero/no-op offset.
    private func dealOrigin(for key: String) -> CGSize {
        guard let shoe = frames["shoe"], let row = frames[key] else {
            return CGSize(width: -60, height: -70)
        }
        return CGSize(width: shoe.midX - row.midX, height: shoe.midY - row.midY)
    }

    private func bossBanner(_ boss: BossCorruption) -> some View {
        VStack(spacing: 2) {
            Text("!! SECURITY ALERT — \(boss.name) !!")
                .font(.caption.weight(.heavy))
            Text(boss.introLine)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Term.alertRed)
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .overlay(RoundedRectangle(cornerRadius: Term.cornerRadius).stroke(Term.alertRed, lineWidth: Term.lineThick))
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var outcomeBanner: some View {
        VStack(spacing: 4) {
            ForEach(Array(viewModel.lastOutcomes.enumerated()), id: \.offset) { index, outcome in
                Text(viewModel.lastOutcomes.count > 1 ? "HAND \(index + 1): \(outcome.description)" : outcome.description)
                    .font(.subheadline.bold())
            }
        }
        .foregroundStyle(Term.green)
        .padding(10)
        .frame(maxWidth: .infinity)
        .terminalPanel()
        .transition(.opacity)
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

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("[ HIT ]") {
                withAnimation { viewModel.hit() }
            }
            .buttonStyle(TerminalBracketButtonStyle(tint: Term.green, filled: true))

            Button("[ STAND ]") {
                withAnimation { viewModel.stand() }
            }
            .buttonStyle(TerminalBracketButtonStyle(tint: Term.green))

            if viewModel.canSplit {
                Button("[ SPLIT ]") {
                    withAnimation { viewModel.split() }
                }
                .buttonStyle(TerminalBracketButtonStyle(tint: .orange))
            }
        }
        .padding(.horizontal)
    }

    /// Shown instead of the normal HIT/STAND bar the instant a hit busts
    /// the active hand — hitting further can't help (a hand's value only
    /// ever goes up), but Jack/Crash still can, since they change a
    /// card's rank immediately rather than through the spark-resolve
    /// pipeline. The hack tools menu stays available underneath this.
    private var bustReprieveBar: some View {
        VStack(spacing: 8) {
            Text("!! OVERFLOW — HACK A CARD BACK IN RANGE, OR ACCEPT THE LOSS !!")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Term.alertRed)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Button("[ ACCEPT BUST ]") {
                withAnimation { viewModel.acceptBust() }
            }
            .buttonStyle(TerminalBracketButtonStyle(tint: Term.alertRed, filled: true))
        }
        .padding(.horizontal)
    }

    /// The whole point of the dropdown: every option shows its full name
    /// and what it does, right there — no need to already know the game's
    /// vocabulary to understand a button.
    private var hackToolsMenu: some View {
        Menu {
            ForEach(PlayerHackType.allCases, id: \.self) { type in
                Button {
                    withAnimation { viewModel.arm(type) }
                } label: {
                    Label("\(type.displayName) — \(type.menuSubtitle)", systemImage: type.symbolName)
                }
            }
        } label: {
            HStack {
                Image(systemName: "chevron.down.circle")
                Text(viewModel.armedHack.map { "[ \($0.displayName) ARMED ▾ ]" } ?? "[ HACK TOOLS ▾ ]")
            }
            .font(.system(.subheadline, design: .monospaced, weight: .heavy))
            .foregroundStyle(viewModel.armedHack == nil ? Term.green : .yellow)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .overlay(RoundedRectangle(cornerRadius: Term.cornerRadius).stroke(viewModel.armedHack == nil ? Term.green : .yellow, lineWidth: Term.lineRegular))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func armedHackHint(_ type: PlayerHackType) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: type.symbolName)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 1) {
                Text(type.needsTarget ? "\(type.displayName) armed — tap a card to target it" : "\(type.displayName)")
                    .font(.caption.weight(.heavy))
                Text(type.fullDescription)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if type.needsTarget {
                Button("cancel") { withAnimation { viewModel.armedHack = nil } }
                    .font(.caption2.weight(.bold))
            }
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(Color.black)
        .overlay(RoundedRectangle(cornerRadius: Term.cornerRadius).stroke(Color.yellow.opacity(0.6), lineWidth: Term.lineRegular))
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func dimmedOverlay<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            content()
        }
        .fontDesign(.monospaced)
        .transition(.opacity)
    }
}

private extension HandOutcome {
    var description: String {
        switch self {
        case .playerBlackjack: return "21, unassisted."
        case .dealerBlackjack: return "Dealer blackjack."
        case .playerBust: return "Overflow error — you busted."
        case .dealerBust: return "The house overflowed."
        case .playerWin: return "You win the hand."
        case .dealerWin: return "The house wins."
        case .push: return "Push."
        }
    }
}
