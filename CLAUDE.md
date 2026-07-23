# HACKJACK — Implementation Guide

This file is the working spec for building Hackjack. It expands
`Rules & Flavor v0.2 ("The Balatro Pass")` into concrete architecture, data
models, and a build order. Treat the "Premise" and "Flavor Text Bank"
sections as canonical copy — reuse the wording verbatim in-game rather than
paraphrasing. Everything else here is implementation-facing.

---

## 0. Current implementation status

Every system in this guide is implemented and playable: the full v0.2
engine (single hands, splits, Firmware, Patch Shop, all four Boss
Corruptions, System Purge, Daily Breach) plus a real SwiftUI iOS app that
builds, installs, and launches in the iOS Simulator. The CLI from the
previous milestone still exists alongside it as a lighter playtest
harness. What's *not* fully built is some of §6's animation fidelity —
see the honest accounting near the end of this section before assuming a
specific effect exists.

**Run it:**

```
swift build && swift test          # HackjackCore + HackjackCLI, 34 tests
swift run HackjackCLI               # terminal playtest harness

xcodegen generate                    # regenerates Hackjack.xcodeproj from project.yml
                                       # (the .xcodeproj itself is gitignored — never hand-edit it)
xcodebuild -project Hackjack.xcodeproj -scheme Hackjack \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl install booted <path to the built .app in DerivedData>
xcrun simctl launch booted com.hackjack.app
```

**Built and working — engine (`Sources/HackjackCore`):**

- All models from §4, including the previously-"planned" ones:
  `Firmware.swift` (`FirmwareEffect`, `FirmwareMutation`, `FirmwareSlots`),
  `ShopOffer.swift`, `BossCorruption.swift` (`HandRuleset` +
  `BossCorruption`). `RunState` now carries `firmware`,
  `handsPlayedThisShift`, `favorableMutationCharges`, `isDailyBreach`, and
  `seed`.
- `GameEngine` now tracks `playerHands: [Hand]` + `activeHandIndex`
  instead of a single hand, supporting splits up to 4 hands with one
  shared `HackChargePool` and lateral infection between adjacent hands
  when a Leech resolves (§5.5).
- Firmware offers (4 concrete effects), the Patch Shop (5 offer types,
  generated on every Shift clear), all four Boss Corruptions (triggered
  deterministically on each Shift's clearing hand), System Purge (a
  hands-played meter, since every hand already rebuilds its own shoe —
  see the §5.9 note on why this isn't literal density accumulation), and
  `RunState.dailyBreach(dateKey:)` for deterministic seeded runs.
- A latent bug fix: Jack/Spoof/Crash used to mark a card `sparkTell =
  .visible` without ever giving it a `pendingMutations` pair, so a
  player-hacked card could show as sparking but never resolve. All three
  now route through `CorruptionGenerator.markSparking` like every other
  corruption source.
- `Tests/HackjackCoreTests`: 34 tests across `CorruptionGeneratorTests`,
  `GameEngineTests`, `DealerAITests`, and `AdvancedSystemsTests`
  (splits, Firmware, shop, bosses, Purge, Daily Breach). `GameEngineTests`
  now also covers the bust-reprieve mechanic (§5.3a): a bust no longer
  auto-resolves the hand, and Jack/Crash can pull a busted hand back
  under 21 before it locks in.
- Two new features since the last pass: **bust reprieve** (§5.3a — a bust
  no longer ends the hand; the player can hack a card's rank back under
  21 before accepting the loss) and **haptics** (§5.3b — sharp taps on
  every card deal and every hack, visible or hidden, via a new typed
  `GameEvent`/`drainEvents()` feed alongside the existing narrative log).

**Built and working — app (`Sources/HackjackApp`, `project.yml`):**

- A real iOS app target, generated via `xcodegen` rather than a
  hand-authored `.xcodeproj`. Depends on `HackjackCore` as a local SPM
  package product (`Package.swift` now declares that product and adds
  `.iOS(.v17)`).
- `GameViewModel` (`@Observable`) wraps `GameEngine` and snapshots its
  public state after every call — `GameEngine` itself has zero SwiftUI
  dependency, per §3.
- `TableView` + `CardView`/`HandRowView` render the live table: dealer
  and all player hands, active-hand highlighting during splits,
  bust/blackjack badges, a hack tray that arms a hack type and commits it
  on the next card tap, a boss banner, and Firmware/Shop overlays driven
  directly by `pendingFirmwareOffer`/`pendingShopOffers`.
- **Visual identity: a 90s script-kiddie terminal** (`Theme.swift`) —
  green-on-black, monospaced everywhere via `.fontDesign(.monospaced)`,
  bracket-tagged status readouts (`[SHIFT 1] [STREAK 0/4]`), card backs
  and the shoe stamped with a `>_` glyph. Not specified anywhere in the
  original v0.2 doc, which never picked a concrete visual style — this
  is the house style now; keep new UI consistent with it (`Term.*`
  colors, `TerminalBracketButtonStyle`) rather than reintroducing
  default SwiftUI chrome. Corruption stays purple
  (`Term.corruptionPurple`) deliberately, so a spark still reads as an
  anomaly breaking through the green system rather than blending into
  the theme.
- **Hack tools are a dropdown (`Menu`), not five individual buttons.**
  Early playtesting of the button-tray version surfaced a real problem:
  `J`/`S`/`C`/`P`/`◎` explained nothing, even to someone who knew the
  design doc. `HackInfo.swift` (App layer, not `HackjackCore` — this is
  presentation metadata, not engine state) gives every `PlayerHackType`
  a full display name, SF Symbol, one-line menu subtitle, and a longer
  description shown in a hint banner once armed ("JACK armed — tap a
  card to target it"). Worth keeping this principle for any future
  control: a button's label must be enough to guess what it does without
  already knowing the ruleset.
- Verified in the iOS Simulator (booted "iPhone 17", Xcode 26.3):
  `xcodebuild` succeeds, the `.app` installs and launches via `simctl`,
  and a screenshot confirms it renders real dealt cards and correct
  status-bar state pulled from the engine (Shift/streak/charges/
  currency/Firmware counts all matched what the engine reported). The
  process ran without crashing or logging a fatal error over several
  minutes (checked via `simctl spawn booted log show`).
- **Not verified: interactive taps.** This sandbox has no working path to
  drive the Simulator's UI programmatically — `xcrun simctl` has no
  tap/touch primitive, and `osascript`/System Events can't reach the
  Simulator app's windows here (`Can't get window 1 of process
  "Simulator"`, even though the process itself is visible to System
  Events). So button-tap → engine-call → re-render was never exercised
  end-to-end *through the UI*. Confidence instead comes from: the 31
  engine tests, the CLI exercising the identical `GameEngine` calls the
  ViewModel makes, and a straightforward, unsurprising SwiftUI wiring
  (each button's action directly calls one `GameViewModel` method). If
  you have a way to drive the Simulator in this environment, that's the
  gap to close next.

**Known simplifications versus §6's rendering plan — real gaps, not
polish to get to eventually:**

- **Card flip is a scale+opacity crossfade, not a Y-axis 3D flip.**
  `CardView` swaps `front`/`back` content behind a plain
  `.transition(.scale.combined(with: .opacity))`. §6 calls the true
  `rotation3DEffect` flip "a common, solved pattern" — it probably is,
  but getting the axis/mirroring right without a live preview loop in
  this environment was a real risk, and the crossfade reads fine as "a
  card just resolved." Worth revisiting with actual device/preview
  iteration.
- **A visible shoe and per-card deal animation now exist** (`ShoeView`,
  top-trailing of the table, showing remaining count), **but the deal
  isn't a `matchedGeometryEffect` tracking the shoe's real on-screen
  frame** — it's a stylized `.transition` (`DealTransition.swift`) that
  offsets/scales/fades/rotates a card in from a fixed direction matching
  the shoe's corner, staggered per card index (`delay: index * 0.1s,
  capped at 0.3s`) so the opening 2-card deal reads as sequential rather
  than simultaneous. Chosen over literal frame-tracking for the same
  reason as the flip: no live preview loop here to debug a subtly wrong
  anchor, and this is far lower-risk to get right blind while still
  reading clearly as "dealt from the shoe." Revisit with real
  `matchedGeometryEffect` if/when there's a way to iterate visually.
- **No dedicated hack-resolve shake+flash.** A resolved spark is only
  visible via the card's content changing (rank swaps) and the shimmer
  stopping — there's no explicit `.spring()` shake or color-flash
  overlay marking the moment of resolution.
- **No distinct hidden-hack *visual* tell — now partially mitigated by
  haptics.** §5.2 specifies a muffled, edge-of-screen flicker for dealer
  hidden hacks, separate from the sharp on-card shimmer used for visible
  hacks. That flicker still doesn't exist — there's no dedicated
  low-opacity overlay view. What does now exist (§5.3b): a distinct
  `UINotificationFeedbackGenerator` haptic fires for every hack, visible
  or hidden, via `GameEngine.drainEvents()`. A vibration isn't a visual
  or text tell, so it doesn't reopen the "no text" violation the old gap
  described, but it also isn't the flicker §5.2 specifies — treat the
  visual gap as still open, with haptics as a real but separate,
  additional tell layered on top of it.
- **No lateral-infection thread.** The engine mechanic (§5.5) works and
  is tested; the `Path`/dash-phase visual connecting adjacent hands
  described in §6 doesn't exist. Infection is only visible as a log line
  plus the newly-sparked card's own shimmer.
- **Boss one-off visual states don't exist.** Blue Screen and Ghost
  Protocol get the same generic boss banner as Firewall Down/Root
  Access — no full-shoe-spark visual treatment, no audio-only handling.
- **No sound at all.** §7 step 13 flagged sound as load-bearing for
  Ghost Protocol and hidden hacks specifically; none exists yet, so
  Ghost Protocol currently has no way to telegraph a hack except the log
  line, which undercuts its whole "audio only, no visual tell" premise.

**Other known deviations, carried forward from the previous milestone:**

- **`Hand.isBusted`/`isBlackjack` are computed properties**, not stored,
  and hack cost logic (including Patch's Critical-state doubling) lives
  in `GameEngine.hackCost(_:)` rather than on `PlayerHackType` itself.
  Functionally equivalent to §4/§5.3, just organized differently.
- **§8's "hard cap of 1 hidden-hack attempt per hand" is still not
  implemented.** `DealerAI.maybeHack` rolls independently on every
  player action once Shift 4+ unlocks hidden hacks; `attempts: 2` (Root
  Access) makes this more pronounced, not less. Decide whether to add
  the cap or update §8 to match.
- **`BossCorruption` is an enum, not the §4 protocol sketch.** Four
  fixed, non-extensible-at-runtime cases didn't need the indirection;
  switch exhaustiveness catches a missed case the same way a missing
  conformance would.
- **Flavor text is pooled, not single canonical lines** — §9 documents
  the actual pools, including new Leech and System Purge lines the
  original v0.2 doc didn't have.

---

## 1. Premise (verbatim, use as loading/about copy)

> The house doesn't shuffle cards anymore. It compiles them.
>
> Every hand is a live data stream — 52 packets rendered as cards, pushed
> through a dealer node running on hardware nobody's patched since the
> crash of '31. You're not playing the house. You're playing its firmware.
> And firmware breaks both ways — yours and theirs.

Design goal: Balatro's "one more run" pacing — persistent build-around
mutations, a shop between rounds, escalating legible chaos — applied to
blackjack instead of poker hands.

---

## 2. Vocabulary

| Term | Meaning |
|---|---|
| **Shift** | One "Ante" — a stretch of hands with a target streak to clear, ending in a Boss Corruption. |
| **Integrity** | Hidden per-card stat. Below threshold → card is **sparking**. |
| **Spark** | The universal visual/audio tell for any corrupted or hacked card. Sharp = visible-hand hack. Muffled = hidden-hand hack. This is the *only* tell system — no HUD text. |
| **Mutation** | What a sparking card resolves into when played. Player is shown the two possible mutations before committing (legible risk, not ambush). |
| **Hack** | An active ability, player or dealer, that alters a card (Jack, Spoof, Crash, Patch, Peek). Costs charges. |
| **Firmware** | A kept mutation that becomes a permanent run-long effect, occupying one of a limited number of slots (Balatro's Joker slots). |
| **Patch Shop** | Between-Shift upgrade screen. |
| **Boss Corruption** | End-of-Shift one-hand rule-twist encounter. |
| **System Purge** | Full reshuffle triggered by maxing the Shift's corruption density. Pacing valve, not a loss. |

---

## 3. Architecture

SwiftUI + Core Animation only, per the tech proposal — no SpriteKit unless
a future particle-heavy pass demands it. Structure as MVVM with an explicit
state-machine engine driving a `RunState`, kept separate from views so game
logic is unit-testable without SwiftUI.

Actual current layout — an SPM package (`Package.swift`) for the
UI-independent core plus CLI, and a separate `xcodegen`-generated iOS app
target that depends on it:

```
hackjack/
  Package.swift                       # declares HackjackCore as a library product, adds .iOS(.v17)
  project.yml                          # xcodegen spec for the iOS app target — see below
  Sources/
    HackjackCore/                   # ✅ built — no import SwiftUI anywhere in here
      Models/
        Card.swift                    # Suit, Rank, Card
        Corruption.swift               # SparkTell, MutationType
        Hand.swift                      # Hand (bestValue/isBusted/isBlackjack computed, bustLocked — §5.3a)
        Hack.swift                       # PlayerHackType, DealerHackType, HackChargePool
        GameEvent.swift                   # GameEvent — typed drain-on-read feed for haptics (§5.3b)
        Shift.swift                       # ShiftConfig + .standard(index:) defaults
        RunState.swift                     # RunState, HandOutcome
        Firmware.swift                       # FirmwareEffect, FirmwareMutation, FirmwareSlots
        ShopOffer.swift                       # ShopOffer, ShopOfferKind
        BossCorruption.swift                   # HandRuleset, BossCorruption (enum, not protocol — see §0)
      Engine/
        SeededGenerator.swift          # SplitMix64 deterministic RNG
        CorruptionGenerator.swift       # shoe build, mutation-pair rolls, resolve()
        GameEngine.swift                 # deal/hit/stand/split/hacks/dealer turn/settle, boss+shop+firmware+purge hooks
        DealerAI.swift                    # dealer hack targeting + Shift scaling, splits-aware
        ScoringEngine.swift                # streak/currency, Shift advancement
      Resources/
        FlavorText.swift               # pooled, randomly-picked copy (see §9)
    HackjackCLI/
      main.swift                      # ✅ built — terminal playtest harness (multi-hand, shop, firmware aware)
    HackjackApp/                      # ✅ built — the real iOS app
      App/
        HackjackApp.swift               # @main App entry point
      ViewModels/
        GameViewModel.swift              # @Observable wrapper snapshotting GameEngine state
      Support/
        Haptics.swift                     # UIKit haptics — deal taps + a distinct hack tap (§5.3b)
      Views/
        ContentView.swift                 # hosts TableView
        TableView.swift                    # main game screen: status bar, hands, hack tray, overlays
        Table/
          CardView.swift                     # single-card render + shimmer
          HandRowView.swift                    # one hand's row, active-hand highlight
          ShoeView.swift                        # visible remaining-card stack
          DealTransition.swift                   # stylized shoe-corner deal-in transition
        Sheets/
          FirmwareOfferOverlayView.swift        # keep/decline overlay
          ShopOverlayView.swift                  # Patch Shop overlay
  Tests/
    HackjackCoreTests/                # ✅ built — 34 tests, `swift test`
      CorruptionGeneratorTests.swift
      GameEngineTests.swift
      DealerAITests.swift
      AdvancedSystemsTests.swift       # splits, Firmware, shop, bosses, Purge, Daily Breach
```

`Hackjack.xcodeproj` is generated from `project.yml` by `xcodegen
generate` and is gitignored — regenerate it after adding new files under
`Sources/HackjackApp` (or rely on Xcode 16+'s folder-synchronized groups
picking them up automatically; regenerating is the safe default either
way). `Sources/HackjackApp` is deliberately *not* declared as a target in
`Package.swift`, so `swift build`/`swift test` at the repo root never try
to compile it — only `xcodebuild` (via the generated project) does.

Not yet created: `Resources/Audio/` and any dedicated effects views
(`Effects/SparkShimmer.swift` etc. from the original sketch were folded
directly into `CardView` instead of split out — see §0 for the real gaps
in rendering fidelity versus §6).

`GameEngine`/`Models` remain free of `import SwiftUI`, as planned.
`GameViewModel` is the `@Observable` bridge — it owns a `GameEngine`
instance and re-snapshots its public state into its own properties after
every call, since a plain class's property mutations aren't otherwise
tracked by SwiftUI's observation system. Views only ever call
`GameViewModel` methods, never touch `GameEngine` directly.

---

## 4. Data Models

### 4a. Implemented (Sources/HackjackCore/Models/) — shapes below match the
actual code, not a sketch. Treat these as documentation of what exists,
not a spec to re-derive.

```swift
// Card.swift
enum Suit: CaseIterable, Sendable { case clubs, diamonds, hearts, spades }

enum Rank: Int, CaseIterable, Comparable, Sendable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king, ace
    var blackjackValue: Int { /* ace=11, face=10, else rawValue */ }
}

func shiftedRank(_ rank: Rank, by delta: Int) -> Rank  // clamped Two...Ace; shared by player Jack + dealer Jack

struct Card: Identifiable, Equatable, Sendable {
    let id: UUID
    var rank: Rank
    var suit: Suit
    var integrity: Int                                   // 0...100, hidden from rendering
    var sparkTell: SparkTell?                              // nil, .visible, .hidden
    var pendingMutations: (MutationType, MutationType)?     // shown before commit
}

// Corruption.swift
enum SparkTell: Sendable { case visible, hidden }
enum MutationType: CaseIterable, Sendable { case volatileValue, overload, leech, twinner }

// Hand.swift
struct Hand: Identifiable, Sendable {
    let id: UUID
    var cards: [Card]
    var isSplitChild: Bool           // ✅ set on split children (GameEngine.playerSplit)
    var adjacentHandIDs: [UUID]       // ✅ linked by GameEngine.relinkAdjacency after every split
    var isStood: Bool
    var bustLocked: Bool             // ✅ set only by GameEngine.acceptBust() — see §5.3a
    var bestValue: Int { get }          // computed, soft-ace aware
    var isBusted: Bool { get }           // computed: bestValue > 21
    var isBlackjack: Bool { get }         // computed: 2 cards, bestValue == 21
    var isResolved: Bool { get }           // computed: isStood || (isBusted && bustLocked)
    var hasPendingSpark: Bool { get }       // computed
}

// GameEvent.swift
enum GameEvent: Sendable, Equatable { case cardDealt, hackTriggered }  // ✅ see §5.3a — drained like the log, but typed

// Hack.swift
enum PlayerHackType: String, CaseIterable, Sendable { case jack, spoof, crash, patch, peek }
enum DealerHackType: String, CaseIterable, Sendable { case jack, spoof, crash }  // no patch/peek — offense-only

struct HackChargePool: Sendable {
    var current: Int
    var max: Int
    mutating func spend(_ amount: Int) -> Bool   // ✅ shared across all live hands — one pool on RunState, not per-Hand
}

// Shift.swift
struct ShiftConfig: Sendable {
    let index: Int
    let targetStreak: Int
    let corruptionDensity: ClosedRange<Double>
    let dealerHackChance: Double
    let hiddenHacksUnlocked: Bool
    static func standard(index: Int) -> ShiftConfig   // §8 working-default curves
}

// RunState.swift
struct RunState: Sendable {
    var currentShiftIndex: Int
    var streakWithinShift: Int
    var chargePool: HackChargePool
    var shopCurrency: Int
    var removedCorruptionTypes: Set<MutationType>
    var firmware: FirmwareSlots
    var handsPlayedThisShift: Int          // drives System Purge (§5.9)
    var favorableMutationCharges: Int       // shop's "guarantee a favorable range" token (§5.7)
    var isDailyBreach: Bool
    var seed: UInt64?                        // GameEngine seeds from this when set (§5.10)

    static func dailyBreach(dateKey: String) -> RunState   // FNV-1a hash of e.g. "2026-07-20" -> seed
}

enum HandOutcome: Sendable {
    case playerBlackjack, dealerBlackjack, playerBust, dealerBust, playerWin, dealerWin, push
}

// Firmware.swift
enum FirmwareEffect: String, CaseIterable, Equatable, Sendable {
    case guardDaemon    // first spark each hand resolves as a free Patch
    case aceStorm        // shoe generation biased toward extra Aces after the normal build
    case twinnerLoop       // Twinner/Volatile Value biased over Overload/Leech on resolve
    case leechWard           // Leech can't drain a card's integrity below 50
}

struct FirmwareMutation: Identifiable, Sendable {
    let id: UUID
    let effect: FirmwareEffect
}

struct FirmwareSlots: Sendable {
    var capacity: Int   // starts 3, shop-expandable
    var equipped: [FirmwareMutation]
    var isFull: Bool { equipped.count >= capacity }
    func has(_ effect: FirmwareEffect) -> Bool
}

// ShopOffer.swift
enum ShopOfferKind: Sendable, Hashable {
    case extraCharge, favorableMutationToken, removeCorruptionType, extraFirmwareSlot, reroll
}

struct ShopOffer: Identifiable, Sendable {
    let id: ShopOfferKind
    let title: String
    let description: String
    let cost: Int
}

// BossCorruption.swift
struct HandRuleset: Sendable {
    var patchAllowed = true
    var dealerHackAttemptMultiplier = 1
    var playerBonusCharges = 0
    var hiddenHacksOnly = false
    var fullShoeSpark = false
}

enum BossCorruption: CaseIterable, Equatable, Sendable {
    case firewallDown, rootAccess, blueScreen, ghostProtocol
    var name: String { get }
    var introLine: String { get }
    func apply(to ruleset: inout HandRuleset)
    static func forShift(index: Int) -> BossCorruption   // deterministic: allCases[(index-1) % 4]
}
```

`BossCorruption` is an enum, not the protocol this section originally
sketched — see §0 for why. `HandRuleset` is built fresh by
`GameEngine.startHand()` every hand and left at its defaults unless
`streakWithinShift == targetStreak - 1` (i.e. this hand would clear the
Shift), in which case `BossCorruption.forShift(index:)` picks a boss
deterministically and mutates the ruleset — same Shift always gets the
same boss across retries, since boss assignment depends on Shift index,
not RNG seed.

---

## 5. Core Systems

### 5.1 Deck & Corruption generation — ✅ implemented (`CorruptionGenerator.swift`)

- Each card gets an `integrity` roll at shoe-build time. Threshold for
  "sparking" scales with `ShiftConfig.corruptionDensity`.
- When a sparking card is *about to be played into* (hit/stand/split
  target), roll and freeze its `pendingMutations` pair immediately —
  this pair must be computed and shown to the player *before* the
  hit/stand/split action is confirmable, not after. That ordering is the
  entire "legible risk, not ambush" contract from the design doc; get this
  wrong and the spark-tell system loses its meaning.
- Actual resolved mutation is picked (weighted or 50/50 — start 50/50,
  tune later) only once the player commits.

Implemented as `buildShoe`, `markSparking`, `pickMutationPair`, and
`resolve` (which now returns the `MutationType` it applied, so callers —
currently `GameEngine`, for the Leech-specific log line in §9 — can react
to which mutation fired). `GameEngine.resolvePendingSparks(in:)` is what
actually calls `resolve` at the right moment (top of `playerHit`/
`playerStand`/dealer's hit loop) — that's where the "shown before commit"
ordering above is enforced; `GameEngineTests.testPendingSparkSurvivesUntilACommittingAction`
covers it directly via seeded trials. `Twinner`'s "duplicate another
card" only ever looks within the same hand (`otherRanksInHand`) — it has
no cross-hand behavior even now that splits exist, which is a reasonable
reading of "another card," not a gap. `Leech` does two things on resolve:
directly drains its own card's integrity (`CorruptionGenerator.apply`,
unconditional), and — only when splits are live — a 50% chance to spread
to an unsparked card in an adjacent hand, handled by
`GameEngine.applyLateralInfection` since `CorruptionGenerator` has no
visibility into sibling hands (§5.5).

### 5.2 The Spark tell — ✅ implemented, partially — visible tell only; hidden tell is CLI-text only

Single source of truth: `Card.sparkTell`. Rendering must not derive "is
this card hacked" from any other state — the engine sets this field and
the view reacts. Two render styles only:

- `.visible`: sharp shimmer + zap sound. Used for (a) naturally sparking
  cards revealed face-up, and (b) any hack — player or dealer — targeting
  a card already on the table.
- `.hidden`: muffled flicker + low hum, positioned at the edge of the
  screen or on the card back, not on the card face. Used for dealer hacks
  targeting cards still in the shoe or face-down.

No other UI element (no HUD banner, no toast) may announce a hack. If a
feature request asks for "tell the player what got hacked," the answer is
"strengthen the spark rendering," not "add text."

`CardView` in the SwiftUI app implements `.visible` correctly: it reads
`card.pendingMutations`/`card.sparkTell` directly (no re-derived state)
and drives a shimmer (subtle rotation + scale jitter) purely off that.
`.hidden` is not implemented as a distinct visual anywhere — the app has
no edge-of-screen flicker overlay at all, so a dealer hidden hack is
currently only visible via the log feed's text line. That's a real gap
against this section, not just missing polish (see §0). The CLI
necessarily violates the letter of this rule too — it's a terminal, so
`[SPARK]` tags and log lines are the only UI available there — but
`Card.sparkTell` is still the single source of truth both surfaces read
from, which is the part of this rule that actually matters structurally;
the "no text, spark only" part is specifically a rendering-layer
obligation that's only half met.

### 5.3 Hacking — player — ✅ implemented (`GameEngine.playerHack(_:targetIsDealer:cardID:)`)

Player hack menu is available during their turn on any hand still live.
Each hack:

- **Jack**: shift target card rank by 1-3, direction chosen by player.
- **Spoof**: change target card's suit only (no rank change — suits carry
  no blackjack value, so Spoof exists for Firmware-effect targeting, e.g.
  a mutation that keys off suit, not for direct hand-value manipulation).
- **Crash**: full reroll of target card (new rank + suit).
- **Patch**: immunize one of the player's own cards from corruption for
  the rest of the hand. Costs 2 charges if `RunState` is in a Critical
  corruption state (define Critical as shoe density above some threshold,
  e.g. top band of the Shift's density range).
- **Peek**: reveal the dealer's hole card for 1 second, UI-only (no state
  change), then re-hide.

All five draw from the single shared `HackChargePool`, including across
split hands (§5.5) — there's exactly one pool on `RunState`, never a
per-`Hand` one. Cost is `hackCost(_:)`: 1
charge for everything except Patch, which is 2 when the Shift's midpoint
corruption density is ≥ 0.35 ("Critical" band, per the threshold this
guide originally left vague). Jack's rank shift is
`Int.random(in: -3...3)` through the shared `shiftedRank(_:by:)` helper —
same function the dealer's Jack uses (Card.swift), so the two can't drift.

### 5.3a Bust reprieve — ✅ implemented (`Hand.bustLocked`, `GameEngine.acceptBust()`)

A bust no longer ends the hand by itself. `Hand.isResolved` is now `isStood
|| (isBusted && bustLocked)` rather than the original `isStood ||
isBusted` — going over 21 stops advancing the active hand and stops
`GameEngine.allPlayerHandsResolved` from going true, but doesn't finalize
anything on its own. This matters because Jack and Crash change a card's
rank *immediately*, synchronously, inside `applyPlayerHackEffect` — the
`markSparking` call alongside them only queues a *later* mutation, it
doesn't gate the rank change already applied. So `playerHack(.jack, ...)`
or `.crash` on a card in the busted hand can pull `bestValue` back under
21 right there, with no engine change needed beyond keeping the hand open
long enough for the player to try it.

`GameEngine.acceptBust()` is the explicit "give up on this hand" action —
it sets `bustLocked = true` on the active hand and calls
`advanceActiveHandIfNeeded()`, exactly mirroring what `playerStand()`
already does via `isStood`. If the player instead successfully hacks the
hand back under 21, `isBusted` goes false on its own and the hand is
simply live again — no separate "un-bust" method exists or is needed.
This composes with splits for free: since `advanceActiveHandIfNeeded()`
already keys off `isResolved`, a busted-and-unlocked hand in a split
correctly blocks auto-advance to the next hand until the player resolves
it one way or the other, same as it already did for a hand awaiting a
stand.

The CLI needed no changes — `playerStand()` still sets `isStood = true`
unconditionally, so hitting "stand" on an already-busted hand already
finalizes it there, same effective outcome as `acceptBust()`. The SwiftUI
app does need dedicated UI (`GameViewModel.bustPendingHandIndex`,
`TableView`'s `bustReprieveBar` swapped in for the normal HIT/STAND bar)
since it's the one surface where the turn used to auto-advance to the
dealer/settlement the instant `allPlayerHandsResolved` went true.

### 5.3b Event feed for haptics — ✅ implemented (`GameEvent`, `GameEngine.drainEvents()`)

A second drain-on-read queue alongside `log`/`drainLog()`, typed instead
of narrative text, added specifically so the App layer can trigger
haptics off discrete facts (`.cardDealt`, `.hackTriggered`) rather than
pattern-matching `FlavorText` strings. `drawCard()` appends `.cardDealt`
at its single choke point (covers the opening deal, hits, dealer draws,
and split draws in one place). `.hackTriggered` is appended both by
`GameEngine.playerHack(_:)` and by `DealerAI` (now threaded with an
`events: inout [GameEvent]` parameter alongside its existing `log: inout
[String]` one) for **both** visible and hidden dealer hacks.

This is what closes — partially — the §5.2/§0/§6 gap that a hidden
dealer hack has no tell at all in the SwiftUI app beyond a log line: the
App layer's `Haptics.hackTriggered()` (a `UINotificationFeedbackGenerator`
`.warning`, deliberately a different pattern from `Haptics.cardDealt()`'s
plain `UIImpactFeedbackGenerator`) fires for a hidden hack same as a
visible one, and a vibration is neither visual nor text, so it doesn't
violate the "spark is the only tell" rule (§5.2) the way a HUD toast
would. It is *not* the sound §7/§8 call out as the single biggest
remaining gap — Ghost Protocol's "audio only" premise still has no actual
audio — but it's a real, working tactile tell where previously there was
none, and `GameViewModel.fireHaptics(for:)` staggers back-to-back events
(`delay: index * 0.12s, capped at 0.4s`) the same way `DealTransition`
already staggers the visual deal, so a 4-card opening hand reads as
distinct taps rather than one blurred buzz.

### 5.3c Charge pool floor regen — ✅ implemented (`GameEngine.startHand()`)

A fully drained `HackChargePool` (`current == 0`) regenerates exactly 1
charge at the start of the next hand, logged via
`FlavorText.chargeRegen(using:)`. This is a floor against permanent
lockout within a Shift, not a general regen — it only fires from zero; a
pool sitting at 1 or 2 charges is left untouched, and a Shift-clear
refill (`ScoringEngine.apply`, already existing) still covers the
non-empty case. Placed before the boss `playerBonusCharges` bump in
`startHand()` so the two stack normally (a Root Access hand after a fully
drained pool gets the +1 floor, then +2 more from the boss).

### 5.4 Hacking — dealer — ✅ implemented (`DealerAI.maybeHack`)

`DealerAI.swift` decides, once per player action, whether the dealer
spends a hack:

1. Roll hack attempt probability from `ShiftConfig.index` (monotonic
   increase; see open question on capping this).
2. If triggered, pick a target: a live face-up player card (→
   `.visible` tell) or a card still in the shoe / face-down (→ `.hidden`
   tell). Early shifts (roughly 1-3) restrict to `.visible` only; hidden
   hacks unlock starting mid-run.
3. Pick a `DealerHackType` (jack/spoof/crash — no patch/peek, dealer has
   no defensive or information kit) and apply it through the same
   mutation pipeline as player hacks, so both sides share one code path
   (`applyHack(type:target:) `) and can't drift in behavior.
4. Boss `HandRuleset.dealerChargeMultiplier` and `.hiddenHacksOnly`
   override the normal roll for that one hand (Root Access, Ghost
   Protocol).

Keep dealer targeting logic isolated in `DealerAI` so it can be unit
tested against fixed RNG seeds independent of rendering.

All four steps are implemented and tested (`DealerAITests` — locked out
below Shift 4, reachable above it, `forceHidden` always wins, `attempts:
2` can land two hacks — each across seeded trials). Root Access sets
`dealerHackAttemptMultiplier = 2`, which `GameEngine.dealerMaybeHack()`
turns into `DealerAI.maybeHack(attempts: 2, ...)`; Ghost Protocol sets
`hiddenHacksOnly = true`, passed through as `forceHidden: true`. **Still
not implemented: the §8 "hard cap of 1 hidden-hack attempt per hand"
default.** `maybeHack` rolls independently on every player action with
no per-hand counter, and Root Access's `attempts: 2` makes this more
pronounced now, not less. Either add the cap or update §8 — the code and
the stated default still disagree.

The "shoe-resident analog of a face-down card" targeting for hidden hacks
always hits `shoe[0]` (the next card due to be dealt) — reasonable for
single-hand play where the player's own cards are always face-up; revisit
once real face-down dealing (if any) or splits change what "hidden" means.

### 5.5 Splits — ✅ implemented (`GameEngine.playerSplit`, `playerHands: [Hand]`)

- Trigger: pair, standard rule. Cap at 4 live hands.
- All hands drawn from the split share `chargePool` — do not give hands
  independent pools.
- `Hand.adjacentHandIDs` defines the lateral-infection graph (adjacent =
  next to each other in table layout, not "all other hands"). A corrupted
  card resolving badly can roll to infect one adjacent hand's card,
  converting it to sparking if not already.
- When a dealer hidden-hack targets a card within a live split cluster,
  the `.hidden` tell should render near the cluster's shared edge rather
  than pinned to one specific hand — ambiguity about *which* hand is
  deliberate per the design doc, don't leak the target through render
  position.

`canSplitActiveHand()` gates on a same-rank pair and `playerHands.count <
4`. Splitting draws one new card per resulting hand and re-links
`adjacentHandIDs` for every hand via `relinkAdjacency()`, called after
every split so a 3- or 4-hand table's adjacency stays correct, not just
the two hands that just split. Lateral infection is a flat 50% roll onto
a random adjacent hand's *unsparked* card, only triggered when a Leech
resolves (`GameEngine.applyLateralInfection`) — implemented this way
because `CorruptionGenerator` has no visibility into sibling hands by
design (§5.1). The last bullet — rendering the `.hidden` tell ambiguously
near a split cluster's shared edge — is not implemented; there's no
dedicated hidden-hack visual at all yet (§0, §5.2).

One Swift-specific note worth keeping: resolving a spark on
`playerHands[activeHandIndex]` and then triggering lateral infection on a
*different* index of `playerHands` in the same breath isn't legal —
mutating one array element via `inout` exclusively borrows the whole
array for the call's duration. `GameEngine` works around this by copying
the active hand out, resolving on the copy, writing it back, and only
then touching sibling elements once the borrow has ended.

### 5.6 Firmware (persistent mutations) — ✅ implemented, 4 effects (doc called for 4-6)

- Trigger to *offer* a Firmware keep: a hand resolves in the player's
  favor and a corrupted card was involved in that resolution.
- Offering a keep when `FirmwareSlots.isFull` requires either declining or
  swapping out an equipped slot — surface this as an explicit choice, not
  an automatic overwrite.
- Each `FirmwareMutation` needs a concrete, always-on effect function
  hooked into `CorruptionGenerator` and `ScoringEngine` (e.g. Twinner:
  before integrity rolls, duplicate a chosen card's rank every hand).
  Build 4-6 concrete Firmware effects for the first playable slice; the
  synergy pairs called out in the doc (Overload + Ace Storm) should be
  among them since they're the doc's example of "where run identity comes
  from."

Shipped as `FirmwareEffect` (a fixed enum, not an open closure system —
four cases don't need one): **Guard Daemon** (first spark each hand
resolves as a free Patch), **Ace Storm** (post-processes a freshly-built
shoe to bias a few cards toward Ace), **Twinner Loop** (biases spark
resolution toward Twinner/Volatile Value over Overload/Leech when the
pair allows it), **Leech Ward** (floors Leech's integrity drain at 50
instead of 0). The doc's suggested Overload+Ace Storm synergy pair isn't
literally implemented as a named combo — Ace Storm just makes Aces more
common, which happens to synergize with anything wanting big cards, but
there's no explicit "these two amplify each other" hook. Offer trigger
(`GameEngine.checkFirmwareOffer`) matches the spec: player-favorable
outcome (win/blackjack/dealer-bust) plus at least one resolved mutation
that hand. `keepFirmwareOffer(replacing:)` supports swapping out a full
slot; an unresolved offer is silently dropped at the next `startHand()`
rather than blocking (§0's documented UI-doesn't-have-to-respond
tradeoff).

### 5.7 Patch Shop — ✅ implemented (`GameEngine.generateShopOffers`/`purchaseShopOffer`)

Between-Shift screen, purchasable with `shopCurrency`:

- +1 starting hack charge (future hands)
- Guarantee-favorable-mutation-range token (consumed on next N sparks)
- Permanently remove one `MutationType` from generation
  (`removedCorruptionTypes`)
- +1 Firmware slot capacity
- Reroll offered items (small currency cost)

Model each offer as a `ShopOffer` with a `cost: Int` and an `apply:
(inout RunState) -> Void` closure so new offer types don't require engine
changes elsewhere — the shop should be the only place that reads/writes
`RunState` outside the engine itself.

Implemented with a `switch` inside `purchaseShopOffer(_:)` rather than a
per-offer closure — five fixed offer types didn't justify the closure
indirection, same call as Boss Corruptions (§5.8). All five from the list
above exist; "guarantee a favorable range" became `favorableMutationCharges`,
consumed one-per-spark and biasing away from Leech when the pair allows
it (not a literal "next 3 sparks always land the single best outcome" —
see `favorablePick(from:)`). Offers regenerate after every purchase so
availability gating stays correct (e.g. corruption-type removal stops
being offered once only 2 types remain — `CorruptionGenerator` requires
at least 2 survive). Reroll's "effect" is exactly that regeneration, so
it doesn't do anything visibly different from any other purchase besides
costing 1 and not otherwise changing state — a thinner reroll than a full
implementation would probably want, worth revisiting.

### 5.8 Boss Corruptions — ✅ implemented (`BossCorruption` enum, `HandRuleset`)

Implement the four launch bosses as concrete `BossCorruption` conformers:

- **Firewall Down**: `ruleset.patchAllowed = false`
- **Root Access**: `ruleset.dealerChargeMultiplier = 2`,
  `chargePool.current += chargePool.max` for the player too (both sides
  double for this hand only — apply as a temporary bonus, not a permanent
  pool change)
- **Blue Screen**: force every card in that hand's shoe draw to be
  sparking; mutation pairs still shown (known but unavoidable is the
  point — don't skip the tell)
- **Ghost Protocol**: `ruleset.hiddenHacksOnly = true`, and per the doc
  this is the one sanctioned exception where a hack has *no* visual tell
  at all — audio only. Don't generalize this exception elsewhere; it's a
  one-boss special case reserved for late-run stakes.

Each boss needs an intro screen (`BossCorruptionIntroView`) that shows
name + intro line before the hand starts, per the "telegraphed" design
requirement — bosses must never surprise the player with an unstated rule
change mid-hand.

All four are implemented, matching the mapping above (the field is named
`dealerHackAttemptMultiplier`, not `dealerChargeMultiplier` — the dealer
never had a charge pool, only an attempt-probability roll, so "multiplier"
means extra `DealerAI.maybeHack` attempts, not extra currency).
**Which hand is the boss hand** wasn't fully specified by the original
doc beyond "end of each Shift," so it's defined here as: whichever hand
would clear the Shift if won (`streakWithinShift == targetStreak - 1`),
computed at the top of every `startHand()`. Boss identity itself is
`BossCorruption.forShift(index:)` — deterministic per Shift index
(`allCases[(index-1) % 4]`), not per RNG seed, so the same Shift always
presents the same boss even after a loss forces a retry — that's the
"telegraphed, knowable" requirement satisfied structurally rather than by
re-showing an intro each attempt. The intro *is* shown every time that
hand comes up (logged at the top of `startHand()`, rendered as a banner
in `TableView`), including on retries. No dedicated
`BossCorruptionIntroView`/per-boss visual state exists — Blue Screen and
Ghost Protocol currently render with the same generic banner as the other
two (§0).

### 5.9 Corruption meter / System Purge — ✅ implemented, as a hands-played meter (see deviation below)

Per-Shift, not global: density resets at Shift start and climbs toward a
max tied to the target streak. On hitting max, trigger a Purge: reshuffle
the shoe, void any in-progress hand, leave Firmware/shop state untouched.
Purge should read as a reset valve (see flavor lines) — not a fail state,
so don't attach any streak penalty beyond what a normal loss would apply
in that Shift.

Note: `GameEngine.drawCard()` already reshuffles a fresh shoe if the shoe
empties mid-hand (logged as "Shoe exhausted — fresh packets compiled
mid-hand"). That's a capacity fallback, not the density-triggered System
Purge described here — don't confuse the two when this section gets built.

Real deviation, not just an implementation detail: because every hand
already rebuilds a fresh shoe from `ShiftConfig.corruptionDensity` (a
simplification made back in §7 step 1, before this section existed),
there's no persistent shoe for corruption density to literally
accumulate *in* across hands. `RunState.handsPlayedThisShift` tracks
hands played without clearing the Shift instead, as the practical
stand-in for "things are getting out of hand," and Purge fires
(`GameEngine.checkSystemPurge`, called from `settleHands()` whenever the
Shift *didn't* clear) once that count reaches `targetStreak * 2`,
resetting the meter and logging a Purge flavor line. Streak is untouched
by a Purge, matching "not a fail state." If this guide's per-hand-fresh-
shoe simplification ever gets revisited in favor of one continuous shoe
per Shift, this section should be rebuilt around literal density
accumulation instead.

### 5.10 Scoring & meta-progression — ✅ implemented (`ScoringEngine.apply`), Daily Breach included

- Clean win (no hacks used by player that hand): +2 streak, bonus shop
  currency.
- Standard win: +1 streak.
- Loss or mid-hand Purge: streak resets to 1x *within the current Shift
  only* — Firmware and shop state persist across the reset.
- Daily Breach: seed the RNG (`RunState.seed`) so shoe order and
  corruption rolls are deterministic for the day; fix starting charges;
  disable shop rerolls. Build this as a pure function of the seed so a
  given day's seed is fully reproducible for leaderboard integrity —
  no wall-clock or device-random inputs may leak into a Daily Breach run.

Implemented: clean win +2 streak/+3 currency, hack-assisted win +1
streak/+1 currency (currency values were never pinned down by §8, so
these were chosen as reasonable defaults), streak reset to 0 on a loss,
and automatic Shift advancement (index +1, streak reset, charge pool
`max` +1 and refilled) once `streakWithinShift >= targetStreak`. Purge
now exists (§5.9) and correctly leaves streak untouched. Daily Breach is
implemented as `RunState.dailyBreach(dateKey:)`, deriving a seed via
FNV-1a over a date string like `"2026-07-20"` — `GameEngine.init` now
prefers `runState.seed` over its own `seed:` parameter when both are
present, so constructing the engine from a Daily Breach `RunState` is
sufficient; no separate API needed. Not implemented: any leaderboard or
network layer to actually compare Daily Breach runs across players — the
determinism is there, nothing consumes it yet.

---

## 6. Rendering plan (SwiftUI) — 🟨 app exists and is playable; most individual effects below are simplified or missing

Follow the tech proposal's stack choice: SwiftUI + Core Animation, no
SpriteKit for v1.

| Effect | Technique | Status |
|---|---|---|
| Card flip (face-down → face-up) | `rotation3DEffect` on Y axis + `.easeInOut`, content swap at the midpoint | 🟨 simplified — `CardView` crossfades front/back via `.transition(.scale.combined(with: .opacity))` instead of a true Y-axis flip. Safer to get right without a live preview loop; revisit with real device iteration. |
| Sparking shimmer | `withAnimation(.repeatForever())` driving small random offset jitter + glow/shadow color pulse | ✅ implemented — tiny z-axis `rotation3DEffect` + `scaleEffect` jitter, `repeatForever(autoreverses: true)`, driven directly off `card.pendingMutations != nil`. |
| Deal (shoe → hand slot) | `matchedGeometryEffect` between a shared namespace on the shoe view and the destination hand slot | 🟨 simplified — a visible `ShoeView` exists (top-trailing, shows remaining count), and cards use a stylized `.dealt` transition (offset+scale+fade+rotate from the shoe's corner, per-card stagger) rather than `matchedGeometryEffect` tracking the shoe's real frame. See §0 for why. |
| Corruption resolve reveal | Quick `.spring()` shake (offset) + brief color-flash overlay | ⬜ not implemented — a resolved spark is only visible via the card's rank changing and the shimmer stopping; no explicit shake/flash. |
| Hidden-hack tell | Low-opacity overlay view, animated independently of the card grid — build and validate this early since it carries gameplay information, not just polish | ⬜ not implemented — the one item this table calls out as highest-risk-if-skipped is, in fact, the one that got skipped. A hidden hack is only visible via the log feed's text line right now (§5.2, §0). |
| Lateral infection thread | Animated `Path`/`Shape` with dash-phase animation between two tracked card frame origins (requires shared `PreferenceKey`-based frame tracking between hand views) | ⬜ not implemented — the underlying engine mechanic (§5.5) works and is tested; only the visual is missing. |

Build order for rendering, matching the tech proposal:

1. ✅ Static card views + table/shop layout.
2. 🟨 Deal + flip — a visible shoe and a stylized per-card deal-in
   animation both exist (stagger delay per card index), just not via
   `matchedGeometryEffect` against the shoe's real frame; flip exists as
   a crossfade, not a true 3D rotation. See the table above.
3. ✅ Spark/twitch shimmer — highest priority, since the tell system is
   gameplay-critical, not decorative. This is the one row of the table
   that landed as originally specified.
4. ⬜ Hack resolve feedback (shake + flash + sound hook).
5. ⬜ Split-hand infection thread.
6. ⬜ Boss one-off visual states (Blue Screen full-shoe spark, Ghost
   Protocol's audio-only hidden hacks).

Do a rough perf pass once 4-hand splits + visible shoe render
simultaneously; not expected to need a redesign, but verify rather than
assume. (Not yet done — splits were only exercised through the CLI and
via unit tests, never visually confirmed in the app with 3-4 live hands
on screen at once.)

---

## 7. Suggested build order (engine-first, cutting across the rendering plan above)

1. ✅ **Models + `CorruptionGenerator`** — shoe generation, integrity rolls,
   mutation-pair selection. Unit test in isolation, no UI.
2. ✅ **`GameEngine` core loop** — deal, player hit/stand, bust/21 detection,
   single hand, no hacks, no splits. Get one full hand playable
   end-to-end (even via console/test harness) before touching SwiftUI.
   *(Went further than "no hacks" — the CLI harness that landed for this
   step already includes hacks and dealer AI, i.e. steps 3 and 5 too.)*
3. ✅ **Player hacks** — wire the five hack types through
   `applyHack(type:target:)`, charge pool deduction, Patch immunity flag.
4. ✅ **Static rendering** (tech proposal step 1) in parallel once the
   engine has a stable `Hand`/`Card` shape to bind to.
5. ✅ **Dealer AI** — visible-hack targeting first (early-shift behavior
   only), then hidden-hack targeting once the `.hidden` tell renders
   correctly (tech proposal step 3 must land before this is testable
   end-to-end, since hidden hacks are meaningless without their tell).
   *(Built without waiting on step 4's `.hidden` render — the CLI's
   `[SPARK]`/log-line text stood in for it, and the app still has no
   dedicated `.hidden` visual either — see §0/§5.2/§6. The "meaningless
   without their tell" risk this step called out is real and current.)*
6. 🟨 **Deal/flip/shimmer animations** (tech proposal steps 2-3) — shimmer
   landed as specified; deal and flip are both simplified substitutes
   (§6).
7. ✅ **Splits** — shared charge pool, adjacency graph, lateral infection.
   Engine + tests only; never visually confirmed with multiple hands on
   screen at once (see the perf-pass note in §6).
8. ✅ **Firmware** — keep/discard offer flow, 4 concrete effects (doc
   suggested 4-6).
9. ✅ **Patch Shop** — offer generation, currency, apply logic (a
   `switch`, not per-offer closures — see §5.7).
10. ✅ **Boss Corruptions** — all four. Banner intro exists; no per-boss
    visual states or a dedicated intro screen component (§5.8).
11. ✅ **Scoring, Shift progression, System Purge** — all three now exist
    (§5.9/§5.10; Purge as a hands-played meter, not literal density).
12. ✅ **Daily Breach mode** — seeded RNG (`RunState.dailyBreach(dateKey:)`),
    fixed economy (no reroll offer when `isDailyBreach`). No leaderboard
    backend — still explicitly out of scope for this guide.
13. ⬜ Sound pass — called out in the doc as load-bearing for Ghost Protocol
    and hidden hacks generally; don't treat as final-polish-only, budget
    real time for it before those features are considered done. **Still
    the single biggest gap**: Ghost Protocol's entire premise (no visual
    tell, audio only) currently has no tell at all in the app beyond a
    log line, because neither the hidden-hack visual (step 6/§6) nor any
    sound exists.

Every step above is at least functionally done except sound (13). What's
left is exclusively about §6's rendering fidelity — see §0's "known
simplifications" list for the specific, real gaps (hidden-hack tell and
sound are the two that actually change what the game communicates, not
just how it looks).

---

## 8. Open design questions — working defaults

The original doc leaves these open. Use these as starting defaults so
implementation isn't blocked; revisit after playtesting rather than
before building:

- **Firmware slot curve**: start 3, +1 available roughly every 2 Shifts
  via shop, cap at 6. ✅ **Implemented**, cap is 7 not 6 (top of the
  documented "~6-7" range) — `generateShopOffers()` stops offering
  `extraFirmwareSlot` once `runState.firmware.capacity >= 7`.
- **Dealer hidden-hack scaling**: hard cap of 1 hidden-hack attempt per
  hand until Shift 7+, even if the probability roll would allow more.
  Prevents feeling unfair despite the tell system. **Still not
  implemented** in `DealerAI.maybeHack` — see §5.4/§0 for the gap. Root
  Access's `attempts: 2` makes this more likely to matter, not less.
- **Shop currency economy**: clean win banks more than a standard win
  clears in one shop visit; Shift-clear bonus should be large enough to
  guarantee at least one shop purchase per Shift, small enough that
  buying out the whole offer list isn't typical. ✅ **Implemented** as
  +2 streak/+3 currency (clean) vs. +1/+1 (hack-assisted) — not
  separately playtested for balance, just a reasonable starting split.
- **Split lateral-infection visual**: build the thread (§6) rather than
  relying on shimmer alone — the doc flags 4-hand tables as crowded
  enough that an unconnected shimmer won't read clearly. **Still not
  implemented** — the engine mechanic exists and is tested (§5.5); only
  the dedicated visual is missing, and infection currently reads only as
  a log line plus the newly-sparked card's ordinary shimmer, which is
  exactly the "won't read clearly on a crowded table" failure mode this
  bullet warned about.
- **Sound identity**: needs its own pass before Ghost Protocol or general
  hidden-hack behavior is considered feature-complete, per §7 step 13.
  **Still not implemented** — no audio exists anywhere in the app yet.
  This is the most consequential remaining gap: Ghost Protocol's entire
  design premise depends on it.

---

## 9. Flavor text — ✅ implemented (`Sources/HackjackCore/Resources/FlavorText.swift`), pooled

Implemented as a static enum, one function or array per event, each
holding 2-4 lines instead of a single canonical string — every call site
picks a random one (`.randomElement(using:)`) rather than always
returning the same line. This changed after playtesting: a single fixed
line per event read flat by the third or fourth repetition in a run.
Treat everything below as "what's in the pool today," freely extendable —
adding a line is just appending to the relevant array, no gameplay code
touched.

**Loading screen** (`FlavorText.loadingScreen`, CLI picks 2 at random each launch):
- "Compiling shoe... 52 packets found. Integrity: unverified."
- "The house doesn't cheat. The house just has root access."
- "Every card was a zero once. Some remember."
- "You're not beating the dealer. You're beating dial-up."

**Hack confirmation** (`FlavorText.hackConfirm(_:using:)`, keyed by `PlayerHackType`):
- Jack: "Value spoofed. Nobody downstream will notice. Probably." / "Rewrote the value in transit. The card won't remember this." / "One digit, shifted quietly. Nobody audits this layer."
- Spoof: "Suit reassigned at the socket. Nothing upstream complained." / "Wrong flag, right card. Close enough for the house's parser." / "Header rewritten mid-flight. The suit never knew." *(Spoof had no line in the original v0.2 doc — added here.)*
- Crash: "Segfault induced. Card core dumped and reborn." / "Forced a crash. What comes back never remembers what it was." / "Fatal exception, caught and rethrown as something new."
- Patch: "Firewall up. For now." / "Patched. It'll hold — until something bigger tries the door." / "Integrity restored. Don't get used to it."
- Peek: "One frame. That's all root gets you." / "A glimpse through the hole card. Gone before it registers." / "Borrowed a frame of the house's buffer. Frame's over."

**Dealer hack** (`FlavorText.dealerHackVisible`/`dealerHackHidden`):
- Visible: "Found a way in. Rude of you to leave it open." / "Somebody left a port open. Not anymore." / "The house just walked right through your firewall." / "That was yours a second ago."
- Hidden: "A faint hum crawls at the edge of the screen. Something in the shoe just changed." / "A flicker, barely there. You'll find out what it cost you later." / "Static, low and brief. Whatever that was, it's already done." *(Text-visible in the CLI, unlike the SwiftUI target — see the §5.2 note on why.)*
- "Hidden resolves badly for player" line ("You didn't even know, did you?") from the original doc is not yet wired up — nothing currently detects "this hidden hack made the outcome worse for the player" to trigger it.

**Leech resolve** (`FlavorText.leechResolve(card:integrity:using:)`, new — not in the original doc):
- Leech was the one mutation with no visible effect (integrity isn't rendered), so a resolved Leech spark looked identical to nothing happening. Added a dedicated line reporting the drain: "Leech bites into {card} — integrity down to {n}. Something on the table just got hungrier." / "Leech drains {card} — integrity at {n} and falling." / "Leech siphons {card} dry — integrity {n}. It'll spread if you let it sit."

**System Purge** (`FlavorText.systemPurge(using:)` — wired up, fires from `GameEngine.checkSystemPurge` per §5.9):
- "INTEGRITY FAILURE. Flushing shoe. Try not to look so relieved."
- "The table remembers nothing. Neither should you."

**Bust reprieve** (`FlavorText.bustReprieve(using:)`, new — see §5.3a; fires from `GameEngine.playerHit()` the instant a hit pushes the active hand over 21):
- "Overflow detected. Not committed yet — patch it before it writes."
- "Stack's over the limit. There's still a window to rewrite it."
- "Overflow, uncommitted. Hack a card back in range, or let it write."

**Charge pool regen** (`FlavorText.chargeRegen(using:)`, new — see §5.3c; fires from `GameEngine.startHand()` only when the pool was fully drained):
- "Charge pool was bone dry. One trickles back in from somewhere upstream."
- "Buffer hit zero. A stray charge drifts back before the next hand compiles."
- "Empty pool, refilled by one. Don't get used to it."

**Boss Corruption intros** (wired up, but *not* through `FlavorText` — they live as `BossCorruption.introLine` in `BossCorruption.swift` instead, since each boss already needed a computed `name`/`introLine` pair and duplicating that through a second lookup didn't add anything. Worth noting as the one exception to this section's "all copy in one place" principle):
- Firewall Down: "No patches today. Whatever sparks, you're wearing it."
- Root Access: "Everybody's got admin now. Try not to break the table."
- Blue Screen: "Every card's compromised. This was always going to happen eventually."
- Ghost Protocol: "You won't see this one coming. Listen instead."

**Outcome** (`FlavorText.outcome(_:using:)`, keyed by `HandOutcome` — covers all 7 cases, not just the doc's original 3):
- Player blackjack: "21, unassisted. The old-fashioned kind of cheating: skill." / "Natural 21. Nothing sparked. Nothing needed to."
- Dealer blackjack: "House hits 21 first. Root always wins ties it deals itself." / "Dealer's holding a natural. Some things don't need corrupting."
- Player bust: "Overflow error. You know what that means here." / "Stack overflow. The house doesn't even have to try." / "Too many packets, not enough room. You know how this ends."
- Dealer bust: "The house overflowed. Doesn't happen twice, usually." / "Root just crashed its own process. Take the win." / "The dealer's node choked on its own hand. Rare. Take it."
- Player win: "You win the hand." / "Clean enough. The house logs it and moves on." / "Hand's yours. The dealer doesn't blink."
- Dealer win: "The house wins the hand." / "Table holds. It usually does." / "Dealer takes it. No fanfare — the house doesn't need any."
- Push: "Push — nobody's integrity changes." / "Dead heat. Neither side's firmware budges." / "Push. The table stays exactly as compromised as before."
- The doc's original "Firmware-assisted win" line ("21. Your deck's haunted and it's working for you now.") still isn't used, even though Firmware now exists — `HandOutcome` has no "was a kept Firmware effect involved in this win" case to key off of, so there's currently no trigger point that would call it correctly.

---

## 10. Testing strategy

- `Engine/` and `Models/` must stay UI-independent so `GameEngineTests`,
  `CorruptionGeneratorTests`, and `DealerAITests` can run as plain XCTest
  targets without a simulator.
- Seed the RNG in every engine test (no live `Int.random` in test paths)
  — this is also a prerequisite for Daily Breach determinism, so treat
  "engine is fully seedable" as a hard requirement, not a nice-to-have.
- Cover explicitly: split charge-pool sharing under triage (patch one
  hand vs. save for another), each Boss Corruption's `HandRuleset`
  override, and the mutation-pair-shown-before-commit ordering from §5.1
  (this one is easy to silently regress and hard to notice visually).
- For UI/animation work, follow the standing instruction to actually run
  the app and exercise the feature before calling it done — type-checking
  a shimmer animation doesn't confirm it reads as "sparking" at a glance.

**Current state:** 34 tests, all passing, run with `swift test` (no
simulator needed — confirms the UI-independence requirement above holds;
`Sources/HackjackApp` isn't declared as a Package.swift target, so it
plays no part in this test run at all).

- `CorruptionGeneratorTests` (5): same-seed shoe determinism,
  different-seed divergence, shop-removed-type exclusion, the
  pending-pair-visible-until-`resolve()` invariant, Twinner's
  duplicate-another-card behavior.
- `GameEngineTests` (11): deal shape, **hitting into a bust no longer
  auto-resolves the hand until `acceptBust()`** (replaces the old
  hit-until-turn-ends test now that a bust doesn't auto-stand — §5.3a),
  **hacking a busted hand's card back under 21 reopens it** (the actual
  "hack yourself out of busting" feature, verified by searching seeds for
  one where Crash pulls `bestValue` back under 21), **a fully drained
  charge pool regenerates exactly 1 charge at the next hand, and a
  non-empty pool doesn't** (§5.3c), stand doesn't
  draw, **the mutation-pair-shown-before-a-committing-action ordering**
  (via the public API, searching seeds 0..<300 for one that deals a
  starting spark — this is the test called out above as easy to
  silently regress), insufficient-charges error, Crash replacing the
  target card (plus a dedicated regression test that Crash actually
  leaves a fresh `pendingMutations` pair, catching the latent bug fixed
  in §0), Patch clearing spark/restoring integrity.
- `DealerAITests` (5): hidden hacks locked out before Shift 4 (500 seeded
  trials), reachable after Shift 4 (500 seeded trials), `forceHidden`
  always wins even when otherwise locked out (Ghost Protocol), `attempts:
  2` can land two hacks (Root Access), visible hacks land on the
  player's hand.
- `AdvancedSystemsTests` (13): split creates two hands sharing one charge
  pool, split respects the 4-hand cap, active hand advances after a split
  hand resolves, a favorable sparked win offers Firmware, keeping an
  offer adds it to `RunState`, clearing a Shift generates shop offers,
  purchasing extends the charge pool and spends currency, each of the
  four bosses' `HandRuleset` effects (Firewall Down blocks Patch, Root
  Access grants +2 charges), boss-per-Shift determinism across all four
  cases plus the wraparound at Shift 5, System Purge resets its meter
  past the threshold, and Daily Breach same-date/different-date
  determinism.

**Gaps versus the original plan, not yet closed:** no `ScoringEngineTests`
file specifically — Shift/streak/currency math is exercised indirectly
through `AdvancedSystemsTests`' shop and boss tests rather than in
isolation. No tests at all for the SwiftUI layer (`GameViewModel`,
`CardView`, etc.) — see §0 for why interactive verification wasn't
possible in this environment; if a way to drive the Simulator becomes
available, `GameViewModel` is unit-testable on its own (it's a thin,
synchronous wrapper) without needing UI automation at all.
