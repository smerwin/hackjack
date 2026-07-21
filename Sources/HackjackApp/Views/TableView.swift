import SwiftUI
import HackjackCore

struct TableView: View {
    @State private var viewModel = GameViewModel()

    var body: some View {
        ZStack {
            background
            VStack(spacing: 10) {
                statusBar
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
                            onTapCard: { id in viewModel.targetCard(handIndex: nil, cardID: id, isDealer: true) }
                        )

                        ForEach(Array(viewModel.playerHands.enumerated()), id: \.element.id) { index, hand in
                            HandRowView(
                                hand: hand,
                                label: viewModel.playerHands.count > 1 ? "HAND \(index + 1)" : "YOU",
                                isActive: index == viewModel.activeHandIndex && !viewModel.allHandsResolved,
                                isDealer: false,
                                hideHoleCard: false,
                                isTargetable: viewModel.armedHack != nil && index == viewModel.activeHandIndex,
                                onTapCard: { id in viewModel.targetCard(handIndex: index, cardID: id, isDealer: false) }
                            )
                        }

                        if viewModel.dealerRevealed && !viewModel.lastOutcomes.isEmpty {
                            outcomeBanner
                        }

                        logFeed
                    }
                    .padding(.horizontal)
                }

                if viewModel.dealerRevealed && !viewModel.lastOutcomes.isEmpty {
                    Button {
                        withAnimation { viewModel.startHand() }
                    } label: {
                        Text("Next Hand")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                } else {
                    actionBar
                    hackTray
                }
            }
            .padding(.top, 8)

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
        }
        .alert("Hackjack", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var background: some View {
        LinearGradient(colors: [Color.black, Color(red: 0.08, green: 0.05, blue: 0.15)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            statChip("Shift", "\(viewModel.runState.currentShiftIndex)")
            statChip("Streak", "\(viewModel.runState.streakWithinShift)/\(viewModel.shiftConfig.targetStreak)")
            statChip("Charges", "\(viewModel.runState.chargePool.current)/\(viewModel.runState.chargePool.max)")
            statChip("¤", "\(viewModel.runState.shopCurrency)")
            statChip("FW", "\(viewModel.runState.firmware.equipped.count)/\(viewModel.runState.firmware.capacity)")
        }
        .padding(.horizontal)
    }

    private func statChip(_ label: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.subheadline.bold().monospacedDigit()).foregroundStyle(.white)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private func bossBanner(_ boss: BossCorruption) -> some View {
        VStack(spacing: 2) {
            Text("BOSS CORRUPTION — \(boss.name)")
                .font(.caption.bold())
            Text(boss.introLine)
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.35)))
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var outcomeBanner: some View {
        VStack(spacing: 4) {
            ForEach(Array(viewModel.lastOutcomes.enumerated()), id: \.offset) { index, outcome in
                Text(viewModel.lastOutcomes.count > 1 ? "Hand \(index + 1): \(outcome.description)" : outcome.description)
                    .font(.subheadline.bold())
            }
        }
        .foregroundStyle(.white)
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
        .transition(.opacity)
    }

    private var logFeed: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(viewModel.log.suffix(6).enumerated()), id: \.offset) { _, line in
                Text("· \(line)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation { viewModel.hit() }
            } label: {
                Text("Hit").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                withAnimation { viewModel.stand() }
            } label: {
                Text("Stand").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if viewModel.canSplit {
                Button {
                    withAnimation { viewModel.split() }
                } label: {
                    Text("Split").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .padding(.horizontal)
    }

    private var hackTray: some View {
        HStack(spacing: 8) {
            hackButton(.jack, "J")
            hackButton(.spoof, "S")
            hackButton(.crash, "C")
            hackButton(.patch, "P")
            hackButton(.peek, "◎")
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func hackButton(_ type: PlayerHackType, _ symbol: String) -> some View {
        Button {
            withAnimation { viewModel.arm(type) }
        } label: {
            Text(symbol)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .tint(viewModel.armedHack == type ? .yellow : .purple)
    }

    private func dimmedOverlay<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            content()
        }
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
