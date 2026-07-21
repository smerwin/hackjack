# HACKJACK — Implementation Guide

This file is the working spec for building Hackjack. It expands
`Rules & Flavor v0.2 ("The Balatro Pass")` into concrete architecture, data
models, and a build order. Treat the "Premise" and "Flavor Text Bank"
sections as canonical copy — reuse the wording verbatim in-game rather than
paraphrasing. Everything else here is implementation-facing.

Project state: repo currently contains no source, only `.gitignore`
(Xcode/Swift) and `README.md`. This guide assumes a fresh SwiftUI app
target (iOS + macOS via one shared SwiftUI codebase, per the tech proposal).

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

```
Hackjack/
  App/
    HackjackApp.swift
  Models/
    Card.swift              # Suit, Rank, Card, Integrity
    Corruption.swift         # MutationType, SparkTell, corruption density
    Hand.swift                # Hand, HandState, split-hand tree
    Hack.swift                 # PlayerHackType, DealerHackType, HackCharge pool
    Firmware.swift              # FirmwareMutation, FirmwareSlots
    Shift.swift                   # ShiftConfig, target streak, density curve
    BossCorruption.swift           # BossCorruption protocol + concrete bosses
    ShopOffer.swift                  # ShopOffer, ShopState, pricing
    RunState.swift                    # top-level persistent run state
  Engine/
    GameEngine.swift          # state machine: deal → player turn → hack phase → dealer turn → resolve
    DealerAI.swift             # dealer hack targeting + frequency scaling
    CorruptionGenerator.swift   # shoe generation, integrity rolls, mutation-pair selection
    ScoringEngine.swift          # streak, clean-win bonus, shop currency
    DailyBreach.swift             # seeded RNG mode
  Views/
    Table/                     # TableView, HandView, CardView, ShoeView
    Hacks/                      # HackTrayView, HackConfirmView
    Shop/                       # PatchShopView, ShopOfferCardView
    Firmware/                    # FirmwareRailView, FirmwareSlotView
    BossIntro/                    # BossCorruptionIntroView
    Effects/                       # SparkShimmer, HiddenHackFlicker, InfectionThreadView
  Resources/
    FlavorText.swift            # all copy from §11 below, as an enum/lookup
    Audio/                       # spark hum, zap, hack confirms, purge stings
  Tests/
    CorruptionGeneratorTests.swift
    GameEngineTests.swift
    DealerAITests.swift
    ScoringEngineTests.swift
```

Keep `Engine/` and `Models/` free of `import SwiftUI`. Views observe engine
state via `@Observable` (or `ObservableObject` if targeting pre-iOS 17) and
dispatch intents (`engine.playerHits(handID:)`) rather than mutating state
directly.

---

## 4. Data Models

Sketches below are meant to be dropped in near-verbatim; adjust naming to
taste but keep the shapes, since later sections (engine, dealer AI, shop)
depend on them.

```swift
enum Suit: CaseIterable { case clubs, diamonds, hearts, spades }

enum Rank: Int, CaseIterable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king, ace
}

struct Card: Identifiable {
    let id: UUID
    var rank: Rank
    var suit: Suit
    var integrity: Int          // hidden from UI; drives isSparking
    var sparkTell: SparkTell?    // nil, .visible, .hidden — drives rendering only
    var pendingMutations: (MutationType, MutationType)?  // shown before commit
}

enum SparkTell { case visible, hidden }

enum MutationType {
    case volatileValue   // rank randomizes on resolve, within shown range
    case overload         // rank forced high
    case leech             // steals integrity from an adjacent hand's card
    case twinner             // duplicates another card's value
    // extend per playtesting — keep this enum as the single source of
    // truth for both Firmware effects and shop "remove a corruption type" offers
}

struct Hand: Identifiable {
    let id: UUID
    var cards: [Card]
    var isSplitChild: Bool
    var adjacentHandIDs: [UUID]   // for lateral infection chaining
    var isStood: Bool
    var isBusted: Bool
}

enum PlayerHackType: String, CaseIterable {
    case jack, spoof, crash, patch, peek
    var baseCost: Int { self == .patch ? 1 : 1 }  // patch costs 2 in Critical state — apply as a modifier, not here
}

enum DealerHackType { case jack, spoof, crash }  // dealer never patches/peeks — mirrors only the offensive kit

struct HackChargePool {
    var current: Int
    var max: Int
    // shared across all live hands in a split — do not model per-hand charges
}

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

struct ShiftConfig {
    let index: Int              // 1-based, drives density + dealer-hack scaling
    let targetStreak: Int
    let corruptionDensity: ClosedRange<Double>  // fraction of shoe sparking, steps up per shift
    let boss: BossCorruption
}

protocol BossCorruption {
    var name: String { get }
    var introLine: String { get }
    func modify(_ ruleset: inout HandRuleset)  // e.g. Firewall Down disables Patch
}

struct RunState {
    var currentShiftIndex: Int
    var streakWithinShift: Int
    var firmware: FirmwareSlots
    var chargePool: HackChargePool
    var shopCurrency: Int
    var removedCorruptionTypes: Set<MutationType>   // permanent shop purchase effect
    var isDailyBreach: Bool
    var seed: UInt64?   // set only for Daily Breach
}
```

`HandRuleset` is a small mutable struct (`patchAllowed: Bool`,
`dealerChargeMultiplier: Int`, `hiddenHacksOnly: Bool`, `fullShoeSpark:
Bool`) that the engine builds fresh each hand and lets the active
`BossCorruption` mutate before dealing. This keeps boss one-offs from
branching the engine's control flow with special cases.

---

## 5. Core Systems

### 5.1 Deck & Corruption generation

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

### 5.2 The Spark tell

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

### 5.3 Hacking — player

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
split hands.

### 5.4 Hacking — dealer

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

### 5.5 Splits

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

### 5.6 Firmware (persistent mutations)

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

### 5.7 Patch Shop

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

### 5.8 Boss Corruptions

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

### 5.9 Corruption meter / System Purge

Per-Shift, not global: density resets at Shift start and climbs toward a
max tied to the target streak. On hitting max, trigger a Purge: reshuffle
the shoe, void any in-progress hand, leave Firmware/shop state untouched.
Purge should read as a reset valve (see flavor lines) — not a fail state,
so don't attach any streak penalty beyond what a normal loss would apply
in that Shift.

### 5.10 Scoring & meta-progression

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

---

## 6. Rendering plan (SwiftUI)

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

1. **Models + `CorruptionGenerator`** — shoe generation, integrity rolls,
   mutation-pair selection. Unit test in isolation, no UI.
2. **`GameEngine` core loop** — deal, player hit/stand, bust/21 detection,
   single hand, no hacks, no splits. Get one full hand playable
   end-to-end (even via console/test harness) before touching SwiftUI.
3. **Player hacks** — wire the five hack types through
   `applyHack(type:target:)`, charge pool deduction, Patch immunity flag.
4. **Static rendering** (tech proposal step 1) in parallel once the
   engine has a stable `Hand`/`Card` shape to bind to.
5. **Dealer AI** — visible-hack targeting first (early-shift behavior
   only), then hidden-hack targeting once the `.hidden` tell renders
   correctly (tech proposal step 3 must land before this is testable
   end-to-end, since hidden hacks are meaningless without their tell).
6. **Deal/flip/shimmer animations** (tech proposal steps 2-3).
7. **Splits** — shared charge pool, adjacency graph, lateral infection.
8. **Firmware** — keep/discard offer flow, 4-6 concrete effects.
9. **Patch Shop** — offer generation, currency, apply closures.
10. **Boss Corruptions** — all four, with intro screens.
11. **Scoring, Shift progression, System Purge.**
12. **Daily Breach mode** — seeded RNG, fixed economy, leaderboard hook
    (leaderboard backend is out of scope for this guide — flag as a
    follow-up spec if pursued).
13. Sound pass — called out in the doc as load-bearing for Ghost Protocol
    and hidden hacks generally; don't treat as final-polish-only, budget
    real time for it before those features are considered done.

Each numbered step should be playable/testable before moving to the next;
don't build splits on top of an engine that hasn't proven single-hand
hacking works correctly first.

---

## 8. Open design questions — working defaults

The original doc leaves these open. Use these as starting defaults so
implementation isn't blocked; revisit after playtesting rather than
before building:

- **Firmware slot curve**: start 3, +1 available roughly every 2 Shifts
  via shop, cap at 6.
- **Dealer hidden-hack scaling**: hard cap of 1 hidden-hack attempt per
  hand until Shift 7+, even if the probability roll would allow more.
  Prevents feeling unfair despite the tell system.
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

## 9. Flavor text (canonical copy)

Store verbatim in `Resources/FlavorText.swift` as a keyed lookup (enum or
static struct), not scattered as string literals across views — hacks,
bosses, and win/loss states all need to pull from one place so new copy
additions don't require touching gameplay code.

**Loading screen:**
- "Compiling shoe... 52 packets found. Integrity: unverified."
- "The house doesn't cheat. The house just has root access."
- "Every card was a zero once. Some remember."
- "You're not beating the dealer. You're beating dial-up."

**Hack confirmation:**
- Jack: "Value spoofed. Nobody downstream will notice. Probably."
- Crash: "Segfault induced. Card core dumped and reborn."
- Patch: "Firewall up. For now."
- Peek: "One frame. That's all root gets you."

**Dealer hack:**
- Visible: "Found a way in. Rude of you to leave it open."
- Hidden: *(no text — muffled spark + hum only)*
- Hidden resolves badly for player: "You didn't even know, did you?"

**System Purge:**
- "INTEGRITY FAILURE. Flushing shoe. Try not to look so relieved."
- "The table remembers nothing. Neither should you."

**Boss Corruption intros:**
- Firewall Down: "No patches today. Whatever sparks, you're wearing it."
- Root Access: "Everybody's got admin now. Try not to break the table."
- Blue Screen: "Every card's compromised. This was always going to happen eventually."
- Ghost Protocol: "You won't see this one coming. Listen instead."

**Win / loss:**
- Clean win: "21, unassisted. The old-fashioned kind of cheating: skill."
- Firmware-assisted win: "21. Your deck's haunted and it's working for you now."
- Bust: "Overflow error. You know what that means here."

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
