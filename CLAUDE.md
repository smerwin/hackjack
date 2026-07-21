# HACKJACK — Implementation Guide

This file is the working spec for building Hackjack. It expands
`Rules & Flavor v0.2 ("The Balatro Pass")` into concrete architecture, data
models, and a build order. Treat the "Premise" and "Flavor Text Bank"
sections as canonical copy — reuse the wording verbatim in-game rather than
paraphrasing. Everything else here is implementation-facing.

---

## 0. Current implementation status

A playable engine + CLI prototype exists, covering build-order steps 1, 2,
3, and 5 (§7). Nothing SwiftUI-facing has been started — the project is
currently a Swift Package, not an Xcode app target; see the note in §3.

**Run it:**

```
swift build          # builds HackjackCore + HackjackCLI
swift test            # 15 tests, all passing
swift run HackjackCLI   # play a run in the terminal
```

**Built and working:**

- `HackjackCore` (library target): `Models/` (`Card`, `Corruption`,
  `Hand`, `Hack`, `Shift`, `RunState`) and `Engine/` (`SeededGenerator`,
  `CorruptionGenerator`, `GameEngine`, `DealerAI`, `ScoringEngine`), plus
  `Resources/FlavorText.swift`.
- `HackjackCLI` (executable target): a terminal harness that plays full
  hands — deal, hit/stand, all five player hacks with targeting, dealer
  turn, outcome, Shift progression across a run.
- `Tests/HackjackCoreTests`: `CorruptionGeneratorTests`,
  `GameEngineTests`, `DealerAITests` — 15 tests, seeded/deterministic,
  no UI dependency.
- Single hands, player hacks (Jack/Spoof/Crash/Patch/Peek), dealer hacks
  (visible always, hidden shoe-targeting from Shift 4+), the
  mutation-pair-shown-before-commit ordering (§5.1), and streak/currency/
  Shift-advancement scoring (§5.10) all work end-to-end and are covered
  by tests or a scripted playthrough.

**Not started:** splits (§5.5), Firmware (§5.6), Patch Shop (§5.7), Boss
Corruptions (§5.8), System Purge (§5.9), Daily Breach, and all SwiftUI
rendering (§6). The `Models/` sketches for those systems in §4 are still
the plan — nothing there exists in code yet.

**Known deviations from this guide, worth reconciling before relying on
either the doc or the code blindly:**

- **No Xcode app target yet.** §3's file tree assumes an app project.
  What actually exists is an SPM package (`Package.swift`) with a library
  + CLI executable + test target — the console-harness milestone §7 step
  2 called for, done one step further (it also covers steps 3 and 5).
  When SwiftUI work starts, it needs its own target/app added to
  `Package.swift` (or a separate Xcode project depending on
  `HackjackCore`), plus `App/`, `Views/`, and `Resources/Audio/`.
- **RunState is smaller than §4's sketch.** No `firmware`, `isDailyBreach`,
  or `seed` fields — those belong to systems that don't exist yet.
  `GameEngine.init(seed:)` takes a seed directly instead; move it onto
  `RunState` when Daily Breach is actually built, per §5.10.
- **`ShiftConfig` has no `boss` field** and there's no `HandRuleset`/
  `BossCorruption` protocol yet — both are still just the §4/§8 plan.
- **`Hand.isBusted`/`isBlackjack` are computed properties**, not stored,
  and `PlayerHackType` carries no `baseCost` — hack cost logic (including
  Patch's Critical-state doubling) lives in `GameEngine.hackCost(_:)`
  instead. Functionally equivalent to §4/§5.3, just organized differently.
- **§8's "hard cap of 1 hidden-hack attempt per hand" is not implemented.**
  `DealerAI.maybeHack` rolls independently on every player action once
  Shift 4+ unlocks hidden hacks, so a long hit streak can draw more than
  one hidden hack in a single hand. Flagged here as a real gap, not
  reconciled yet — decide whether to add the cap or update §8 to match.
- **Flavor text shipped as pools, not single canonical lines.** §9 was
  written when each event had exactly one line; `FlavorText.swift` now
  picks randomly from a 2-4 line pool per event (added after playtesting
  found single fixed lines went flat on repeat). §9 below has been
  updated to match — treat the lines there as "what's in the pool," not
  "the one canonical line."

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

Actual current layout (SPM package — see §0 for why this differs from an
Xcode app target):

```
hackjack/
  Package.swift
  Sources/
    HackjackCore/                   # ✅ built — no import SwiftUI anywhere in here
      Models/
        Card.swift                    # Suit, Rank, Card
        Corruption.swift               # SparkTell, MutationType
        Hand.swift                      # Hand (bestValue/isBusted/isBlackjack computed)
        Hack.swift                       # PlayerHackType, DealerHackType, HackChargePool
        Shift.swift                       # ShiftConfig + .standard(index:) defaults
        RunState.swift                     # RunState, HandOutcome
      Engine/
        SeededGenerator.swift          # SplitMix64 deterministic RNG
        CorruptionGenerator.swift       # shoe build, mutation-pair rolls, resolve()
        GameEngine.swift                 # deal/hit/stand/hacks/dealer turn/settle
        DealerAI.swift                    # dealer hack targeting + Shift scaling
        ScoringEngine.swift                # streak/currency, Shift advancement
      Resources/
        FlavorText.swift               # pooled, randomly-picked copy (see §9)
    HackjackCLI/
      main.swift                      # ✅ built — terminal playtest harness
  Tests/
    HackjackCoreTests/                # ✅ built — 15 tests, `swift test`
      CorruptionGeneratorTests.swift
      GameEngineTests.swift
      DealerAITests.swift
```

Not yet created (still the plan, not a description of code that exists):

```
  Models/
    Firmware.swift              # FirmwareMutation, FirmwareSlots
    BossCorruption.swift         # BossCorruption protocol + concrete bosses, HandRuleset
    ShopOffer.swift                # ShopOffer, ShopState, pricing
  Engine/
    DailyBreach.swift             # seeded RunState.seed-driven mode
  App/
    HackjackApp.swift               # needs a SwiftUI app target added to Package.swift
  Views/
    Table/                     # TableView, HandView, CardView, ShoeView
    Hacks/                      # HackTrayView, HackConfirmView
    Shop/                       # PatchShopView, ShopOfferCardView
    Firmware/                    # FirmwareRailView, FirmwareSlotView
    BossIntro/                    # BossCorruptionIntroView
    Effects/                       # SparkShimmer, HiddenHackFlicker, InfectionThreadView
  Resources/
    Audio/                       # spark hum, zap, hack confirms, purge stings
```

Keep `Engine/` and `Models/` free of `import SwiftUI`. Views observe engine
state via `@Observable` (or `ObservableObject` if targeting pre-iOS 17) and
dispatch intents (`engine.playerHits(handID:)`) rather than mutating state
directly.

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
    var isSplitChild: Bool           // stored, unused until splits ship
    var adjacentHandIDs: [UUID]       // stored, unused until splits ship
    var isStood: Bool
    var bestValue: Int { get }          // computed, soft-ace aware
    var isBusted: Bool { get }           // computed: bestValue > 21
    var isBlackjack: Bool { get }         // computed: 2 cards, bestValue == 21
    var isResolved: Bool { get }           // computed: isStood || isBusted
    var hasPendingSpark: Bool { get }       // computed
}

// Hack.swift
enum PlayerHackType: String, CaseIterable, Sendable { case jack, spoof, crash, patch, peek }
enum DealerHackType: String, CaseIterable, Sendable { case jack, spoof, crash }  // no patch/peek — offense-only

struct HackChargePool: Sendable {
    var current: Int
    var max: Int
    mutating func spend(_ amount: Int) -> Bool   // shared across all live hands once splits ship
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
}

enum HandOutcome: Sendable {
    case playerBlackjack, dealerBlackjack, playerBust, dealerBust, playerWin, dealerWin, push
}
```

Deliberately absent from the current `RunState`/`ShiftConfig`, versus the
original plan: `firmware`, `isDailyBreach`, `seed` (RunState) and `boss`
(ShiftConfig) — all belong to systems below that aren't built yet. Add
them back when those systems land, not before (per the "no unused
abstractions" rule — an empty `FirmwareSlots` sitting in `RunState` today
would be dead weight).

### 4b. Planned — not yet implemented

These sketches are still the spec for Firmware, the Patch Shop, and Boss
Corruptions. Nothing below exists in code; build it when §7 reaches that
step.

```swift
struct FirmwareMutation: Identifiable {
    let id: UUID
    let type: MutationType
    var description: String       // flavor-specific, generated at the moment it's kept
}

struct FirmwareSlots {
    var capacity: Int   // starts 3, shop-expandable, cap ~6-7 per open question
    var equipped: [FirmwareMutation]
    var isFull: Bool { equipped.count >= capacity }
}

protocol BossCorruption {
    var name: String { get }
    var introLine: String { get }
    func modify(_ ruleset: inout HandRuleset)  // e.g. Firewall Down disables Patch
}

// Add to ShiftConfig once bosses exist: let boss: BossCorruption
// Add to RunState once Firmware/Daily Breach exist:
//   var firmware: FirmwareSlots
//   var isDailyBreach: Bool
//   var seed: UInt64?   // GameEngine.init(seed:) already takes this directly today —
//                       // move the source of truth here when Daily Breach is built
```

`HandRuleset` is a small mutable struct (`patchAllowed: Bool`,
`dealerChargeMultiplier: Int`, `hiddenHacksOnly: Bool`, `fullShoeSpark:
Bool`) that the engine builds fresh each hand and lets the active
`BossCorruption` mutate before dealing. This keeps boss one-offs from
branching the engine's control flow with special cases.

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
covers it directly via seeded trials. `Twinner`'s "duplicate another card"
and `Leech`'s "steal integrity from an adjacent hand" both fall back to a
same-hand behavior for now (see 5.5 — no adjacent hand exists until
splits ship).

### 5.2 The Spark tell — ✅ implemented, CLI-text form (see §6 for the real rendering plan)

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

The CLI necessarily violates the letter of this rule today — it's a
terminal, so `[SPARK]` tags and log lines *are* the only UI available.
`Card.sparkTell` is still the single source of truth the CLI reads from,
which is the part of this rule that has to hold once real rendering
exists; the "no text" part is specifically about the SwiftUI build.

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

All five draw from the single shared `HackChargePool`. ("Including across
split hands" doesn't apply yet — see 5.5.) Cost is `hackCost(_:)`: 1
charge for everything except Patch, which is 2 when the Shift's midpoint
corruption density is ≥ 0.35 ("Critical" band, per the threshold this
guide originally left vague). Jack's rank shift is
`Int.random(in: -3...3)` through the shared `shiftedRank(_:by:)` helper —
same function the dealer's Jack uses (Card.swift), so the two can't drift.

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

Steps 1-3 are implemented and tested (`DealerAITests` — locked out below
Shift 4, reachable above it, across 500 seeded trials each way). Step 4
is not — there's no `HandRuleset` yet, so Root Access/Ghost Protocol
overrides don't exist. **Also not implemented: the §8 "hard cap of 1
hidden-hack attempt per hand" default.** `maybeHack` rolls independently
on every player action with no per-hand counter, so a long hit streak in
a late Shift can, in principle, draw more than one hidden hack in a
single hand. Either add the cap or update §8 — currently the code and
the stated default disagree.

The "shoe-resident analog of a face-down card" targeting for hidden hacks
always hits `shoe[0]` (the next card due to be dealt) — reasonable for
single-hand play where the player's own cards are always face-up; revisit
once real face-down dealing (if any) or splits change what "hidden" means.

### 5.5 Splits — ⬜ planned, not implemented

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

### 5.6 Firmware (persistent mutations) — ⬜ planned, not implemented

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

### 5.7 Patch Shop — ⬜ planned, not implemented

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

### 5.8 Boss Corruptions — ⬜ planned, not implemented

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

### 5.9 Corruption meter / System Purge — ⬜ planned, not implemented

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

### 5.10 Scoring & meta-progression — ✅ implemented (`ScoringEngine.apply`), Daily Breach still planned

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

Implemented: clean win +2/+2 currency, hack-assisted win +1/+1 (`+2/+3`
and `+1/+1` respectively in the actual code — currency values were never
pinned down by §8, so `+3`/`+1` were chosen as reasonable defaults),
streak reset to 0 on a loss, and automatic Shift advancement (index +1,
streak reset, charge pool `max` +1 and refilled) once
`streakWithinShift >= targetStreak`. Not implemented: Purge-triggered
resets (5.9 doesn't exist yet) and Daily Breach (seed currently comes
from `GameEngine.init(seed:)`, not `RunState.seed` — see §0).

---

## 6. Rendering plan (SwiftUI) — ⬜ not started

Follow the tech proposal's stack choice: SwiftUI + Core Animation, no
SpriteKit for v1.

| Effect | Technique |
|---|---|
| Card flip (face-down → face-up) | `rotation3DEffect` on Y axis + `.easeInOut`, content swap at the midpoint |
| Sparking shimmer | `withAnimation(.repeatForever())` driving small random offset jitter + glow/shadow color pulse |
| Deal (shoe → hand slot) | `matchedGeometryEffect` between a shared namespace on the shoe view and the destination hand slot |
| Corruption resolve reveal | Quick `.spring()` shake (offset) + brief color-flash overlay |
| Hidden-hack tell | Low-opacity overlay view, animated independently of the card grid — build and validate this early since it carries gameplay information, not just polish |
| Lateral infection thread | Animated `Path`/`Shape` with dash-phase animation between two tracked card frame origins (requires shared `PreferenceKey`-based frame tracking between hand views) |

Build order for rendering, matching the tech proposal:

1. Static card views + table/shop layout.
2. Deal + flip.
3. Spark/twitch shimmer — highest priority, since the tell system is
   gameplay-critical, not decorative.
4. Hack resolve feedback (shake + flash + sound hook).
5. Split-hand infection thread.
6. Boss one-off visual states (Blue Screen full-shoe spark, Ghost
   Protocol's audio-only hidden hacks).

Do a rough perf pass once 4-hand splits + visible shoe render
simultaneously; not expected to need a redesign, but verify rather than
assume.

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
4. ⬜ **Static rendering** (tech proposal step 1) in parallel once the
   engine has a stable `Hand`/`Card` shape to bind to.
5. ✅ **Dealer AI** — visible-hack targeting first (early-shift behavior
   only), then hidden-hack targeting once the `.hidden` tell renders
   correctly (tech proposal step 3 must land before this is testable
   end-to-end, since hidden hacks are meaningless without their tell).
   *(Built without waiting on step 4's `.hidden` render — the CLI's
   `[SPARK]`/log-line text stood in for it. Real rendering still needs
   validating once step 4 exists, per the "muffled tell" requirement.)*
6. ⬜ **Deal/flip/shimmer animations** (tech proposal steps 2-3).
7. ⬜ **Splits** — shared charge pool, adjacency graph, lateral infection.
8. ⬜ **Firmware** — keep/discard offer flow, 4-6 concrete effects.
9. ⬜ **Patch Shop** — offer generation, currency, apply closures.
10. ⬜ **Boss Corruptions** — all four, with intro screens.
11. 🟨 **Scoring, Shift progression** done; **System Purge** not (§5.9/§5.10).
12. ⬜ **Daily Breach mode** — seeded RNG, fixed economy, leaderboard hook
    (leaderboard backend is out of scope for this guide — flag as a
    follow-up spec if pursued).
13. ⬜ Sound pass — called out in the doc as load-bearing for Ghost Protocol
    and hidden hacks generally; don't treat as final-polish-only, budget
    real time for it before those features are considered done.

Each numbered step should be playable/testable before moving to the next;
don't build splits on top of an engine that hasn't proven single-hand
hacking works correctly first. Next up per this order: step 4 (static
SwiftUI rendering) — steps 1, 2, 3, and 5 are done and step 6 can't
usefully start without it.

---

## 8. Open design questions — working defaults

The original doc leaves these open. Use these as starting defaults so
implementation isn't blocked; revisit after playtesting rather than
before building:

- **Firmware slot curve**: start 3, +1 available roughly every 2 Shifts
  via shop, cap at 6.
- **Dealer hidden-hack scaling**: hard cap of 1 hidden-hack attempt per
  hand until Shift 7+, even if the probability roll would allow more.
  Prevents feeling unfair despite the tell system. **Not yet implemented**
  in `DealerAI.maybeHack` — see §5.4/§0 for the gap.
- **Shop currency economy**: clean win banks more than a standard win
  clears in one shop visit; Shift-clear bonus should be large enough to
  guarantee at least one shop purchase per Shift, small enough that
  buying out the whole offer list isn't typical.
- **Split lateral-infection visual**: build the thread (§6) rather than
  relying on shimmer alone — the doc flags 4-hand tables as crowded
  enough that an unconnected shimmer won't read clearly.
- **Sound identity**: needs its own pass before Ghost Protocol or general
  hidden-hack behavior is considered feature-complete, per §7 step 13.

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

**System Purge** (not wired up — §5.9 doesn't exist yet):
- "INTEGRITY FAILURE. Flushing shoe. Try not to look so relieved."
- "The table remembers nothing. Neither should you."

**Boss Corruption intros** (not wired up — §5.8 doesn't exist yet):
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
- The doc's original "Firmware-assisted win" line ("21. Your deck's haunted and it's working for you now.") isn't used — there's no Firmware system yet to distinguish a Firmware-assisted win from a plain one.

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

**Current state:** 15 tests, all passing, run with `swift test` (no
simulator needed — confirms the UI-independence requirement above holds).

- `CorruptionGeneratorTests` (5): same-seed shoe determinism,
  different-seed divergence, shop-removed-type exclusion, the
  pending-pair-visible-until-`resolve()` invariant, Twinner's
  duplicate-another-card behavior.
- `GameEngineTests` (7): deal shape, hit-until-turn-ends, stand doesn't
  draw, **the mutation-pair-shown-before-a-committing-action ordering**
  (via the public API, searching seeds 0..<300 for one that deals a
  starting spark — this is the test called out above as easy to
  silently regress), insufficient-charges error, Crash replacing the
  target card, Patch clearing spark/restoring integrity.
- `DealerAITests` (3): hidden hacks locked out before Shift 4 (500 seeded
  trials), reachable after Shift 4 (500 seeded trials), visible hacks
  land on the player's hand.

**Gaps versus the original plan, not yet closed:** no `ScoringEngineTests`
file (Shift advancement is only exercised indirectly, via a scripted CLI
playthrough — see the commit history); split charge-pool sharing and
Boss Corruption `HandRuleset` overrides can't be tested yet since neither
system exists (§5.5, §5.8). Add both when those land.
