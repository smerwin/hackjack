# HACKJACK — Implementation Guide

This file is the working spec for Hackjack as it exists today: a
card-based tower defense. It replaces an earlier design (a Balatro-style
blackjack-plus-hacking roguelike) that shipped fully — engine, tests, a
real iOS app, even App Store Connect signing — but played flat.
Diagnosis across two rounds: a pure animation/juice pass (lightning-
strike hack feedback, a hidden-hack screen flash) didn't fix it, because
the actual problem was structural — blackjack's hit/stand is a solved
probability question, and an optional hack spend on top of it doesn't
change what kind of decision that is. The fix was a genre pivot, not
another patch. The old design's code, tests, and this file's prior
content are gone from `main`; recover them from git history
(`64c528f` and earlier) if that context is ever needed again.

---

## 0. Current implementation status

The tower-defense core loop is implemented and playable end-to-end:
`HackjackCore` (engine + tests), a terminal CLI harness, and a real
SwiftUI iOS app. It is deliberately a **functional first pass, not a
polished one** — see the honest gaps at the end of this section before
assuming a specific effect or balance number is final. The point of this
pass was to validate the loop is actually more fun than the blackjack
version, not to ship a finished game.

**Run it:**

```
swift build && swift test          # HackjackCore + HackjackCLI, 13 tests
swift run HackjackCLI               # terminal playtest harness — the fastest way to feel the loop out

xcodegen generate                    # regenerates Hackjack.xcodeproj from project.yml
                                       # (the .xcodeproj itself is gitignored — never hand-edit it)
xcodebuild -project Hackjack.xcodeproj -scheme Hackjack \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl install booted <path to the built .app in DerivedData>
xcrun simctl launch booted com.smerwin.hackjack
```

**Built and working — engine (`Sources/HackjackCore`):**

- `GameEngine` drives `towerCount` (default 3) simultaneous, independent,
  **dealer-less** blackjack hands (`towers: [Hand]`) against a parade of
  `Mob`s marching on a base. There is no dealer, no hack system, and no
  corruption — see §2 for why each of those is gone, not just missing.
- A tower's `Hand.power` (its live damage/fire-rate) is exactly its
  current `bestValue`, or `0` if busted — a one-line computed property,
  not a separately tracked stat. This is the entire mechanical payoff of
  "playing blackjack" in this game now.
- Every `hit(towerIndex:)` or `redeal(towerIndex:)` call is one atomic
  player action and ends by calling `advanceParade()`, which: applies
  every tower's summed power to the frontmost mob (concentrated fire, no
  lane targeting), steps every mob one closer to the base, resolves any
  mob that just arrived (damages `RunState.baseHP`, removes it), spawns
  the next queued mob, then resolves a stage clear or a defeat
  immediately if either just happened — so the engine is always in a
  consistent, ready-to-act state by the time a call returns.
- Stage clear advances `RunState.stageIndex` and heals a couple points of
  `baseHP` (capped at max), then calls `startStage()` again with the
  next, harder `StageConfig`. Defeat (`baseHP <= 0`) restores `baseHP` to
  max and retries the **same** stage — a forgiving loss, not a run-ending
  one, matching this codebase's established pacing philosophy from the
  earlier design.
- `Tests/HackjackCoreTests/GameEngineTests.swift`: 13 tests covering
  determinism (same seed → same opening state), stage start, `hit`
  drawing a card and being a no-op once busted, `redeal` producing a
  fresh hand, mob damage/death/base-arrival and their `GameEvent`s, stage
  clear advancing the stage index, and Daily Breach seed determinism.
  Several tests deliberately construct a high `stageIndex` to inflate
  `StageConfig.mobHPMultiplier` well past what a single tower can output
  in the ticks being tested — see the doc comments on
  `testMobTakesDamageEqualToTotalPowerEachTick` and
  `testMobReachingBaseEmitsBaseHitAndIsRemoved` for the exact bound —
  rather than searching for a lucky seed, since the numbers make survival
  (or non-survival) deterministic instead.

**Built and working — app (`Sources/HackjackApp`, `project.yml`):**

- Real iOS app target (Xcode 26.3, iPhone 17 Simulator verified), signed
  for App Store Connect distribution (`com.smerwin.hackjack`, team
  `Q2GAZA687V`) — see §7 for the remaining submission steps, all of
  which are orthogonal to this rewrite and still apply.
- `GameViewModel` snapshots `GameEngine` state after every call
  (`towers`, `mobs`, `runState`, `stageConfig`, `shoeCount`, `log`) and
  turns `GameEngine.drainEvents()` into haptics: a plain tap for a card
  dealt, a sharper `UINotificationFeedbackGenerator(.warning)` for a mob
  taking damage, and a distinctly bad `.error` pattern for a mob reaching
  the base — `Sources/HackjackApp/Support/Haptics.swift`.
- `TableView` renders a status readout (stage / base HP / total power), a
  visible shoe (`ShoeView`, reused from the earlier design), the
  `MobParadeView` (a horizontal strip of marching mobs, each showing its
  card, HP, and steps-to-base), and one `TowerRowView` per tower — hand,
  live power, and its own `[ HIT ]`/`[ REDEAL ]` buttons. There's no
  single "active hand" anymore, so control is per-row, not a shared
  action bar.
- **Visual identity is unchanged**: the 90s green-on-black terminal look
  (`Theme.swift`) carries over as-is — bracket-tagged stats, monospaced
  everywhere, card backs stamped `>_`. `Term.corruptionPurple` was
  renamed to `Term.strikePurple` since corruption is gone but the color's
  actual job (mark the instant a strike lands) persists unchanged.
- **The lightning-strike visual survived the rewrite by changing what it
  points at.** The old design struck a card in the *player's own hand*
  when a hack landed on it. That mechanism doesn't apply anymore — a
  tower's own cards never mutate in place (a hit only appends, a redeal
  replaces the whole hand with fresh identities) — so `CardView` is back
  to a bare, static renderer. `LightningBoltShape` was pulled out into
  its own file and is now driven by `MobParadeView`'s `MobTokenView`,
  which watches its own `mob.hp` for changes (the one thing about a mob
  that *does* mutate in place) and strikes+shakes itself when it drops.
  Same visual grammar, retargeted from "your card got hacked" to "that
  mob just got hit."
- Verified in the iOS Simulator: `xcodebuild` succeeds, the `.app`
  installs and launches via `simctl`, and a screenshot confirms live
  gameplay state (three tower rows with real dealt hands and correct
  power numbers, a mob with real HP/distance, correct stage/base/power
  readout) — matching what the engine reports.
- **Not verified: interactive taps.** Same standing limitation as the
  earlier design — this sandbox has no way to drive the Simulator's UI
  programmatically. Confidence comes from the engine tests, the CLI
  exercising the identical `GameEngine` calls the ViewModel makes (and
  actually played through manually via the CLI — see §0's honest gaps
  below for what that playtest surfaced), and straightforward, obvious
  SwiftUI wiring (each button directly calls one `GameViewModel` method).

**Honest gaps — real, not polish-later items:**

- **Balance is unvalidated beyond one manual CLI playtest.** That
  playtest surfaced a real pattern worth flagging: with the default 3
  towers, combined power reliably one-shots most Stage 1 mobs (max HP
  11) almost immediately, and a busted tower going dark for a few turns
  barely mattered because the other two towers carried the parade
  regardless. Whether that's "appropriately easy at Stage 1" or "the
  towers scale faster than the mobs do" needs more playtesting across
  several stages, not just one, before the numbers in `StageConfig.
  standard(index:)` should be treated as tuned rather than placeholder.
- **No lanes, no manual targeting.** Every tower's power lands on the
  single frontmost mob every tick (§0 above). This was the deliberate v1
  simplification agreed on, but it means towers never have to make a
  *targeting* decision — only a *hand-management* one. Worth revisiting
  once the core loop's fun is otherwise confirmed.
- **No sound**, same gap as the earlier design carried the whole way
  through — haptics are the only non-visual feedback that exists.
- **Firmware, the Patch Shop, and Boss Corruptions were cut, not
  redesigned.** Every effect/offer in the old versions of those systems
  referenced corruption or hacking, both gone. There is currently no
  meta-progression at all beyond stage index climbing and base HP
  persisting across stages — no purchases, no persistent upgrades, no
  boss-stage twists. This is real, scoped-out work, not an oversight.
- **Deal-in animation, shoe visual, and the coordinate-space frame-
  reporting plumbing (`DealTransition.swift`, `reportFrame(_:)`,
  `FramePreferenceKey`) carried over from the earlier design untouched**
  — they were about "cards fly in from the shoe," which is still exactly
  what tower hands do, so there was nothing to change here.

---

## 1. Vocabulary

| Term | Meaning |
|---|---|
| **Stage** | One wave of the defense — a parade of mobs to kill (or survive) before advancing. Replaces the old "Shift." |
| **Tower** | One of `towerCount` (default 3) independent blackjack hands. Its live total is its damage output. |
| **Power** | `Hand.power` — a tower's current `bestValue`, or `0` if busted. The only thing "playing blackjack" produces now. |
| **Mob** | One enemy in the parade — a `Card` wrapped with `hp` and `stepsRemaining`. Literally "a parade of cards." |
| **Base** | The thing being defended. `RunState.baseHP` — a mob reaching the base deals its remaining HP as damage and is removed. |
| **Defeat / retry** | `baseHP` hitting 0. Not a run-ending loss — the same stage restarts with `baseHP` and every tower's hand reset. |

---

## 2. What changed from the old design, and why

The full old design (Firmware, Patch Shop, Boss Corruptions, splits,
player/dealer hacks, the corruption/spark tell system, System Purge,
Daily Breach as part of a scoring/streak system) is described in git
history, not here — reconstructing it isn't useful context for working
on the current game. What matters going forward is *why* each major
piece is gone, since a future feature request might unknowingly ask to
reintroduce something that was cut on purpose:

- **The dealer is gone.** A dealer's turn is a discrete, blocking
  resolution step (draw to 17, compare hands). That doesn't mesh with
  towers firing continuously off a *live*, ever-changing hand total —
  there's no natural point to pause and run a dealer's turn without
  breaking the "your total is your power, right now" premise the whole
  redesign is built on.
- **Hacks and corruption are gone.** They were the entire reason the old
  game didn't feel like an active decision — spending a charge to nudge
  a card's value is still a math-correction decision, dressed up. Cutting
  them was the actual fix; the strike-animation work that preceded this
  rewrite (see git history) was a good-faith attempt to fix the *feel*
  without fixing the *structure*, and it didn't work.
- **Splits are gone.** They were a blackjack-specific complication
  (pairs, shared charge pools, lateral corruption infection between
  adjacent hands) with no equivalent concept in a tower-defense frame.
  `towerCount` independent hands already gives "manage several hands at
  once" for free, without needing a splitting mechanic to get there.
- **Firmware/Shop/Boss Corruptions are gone, not reimagined**, per the
  explicit scope decision in §0 — every one of their effects assumed
  hacking or corruption existed to modify.

---

## 3. Architecture

Unchanged from the earlier design's structure — an SPM package
(`Package.swift`) for the UI-independent core plus CLI, and a separate
`xcodegen`-generated iOS app target that depends on it. The
UI-independence rule (`Engine/`/`Models/` never `import SwiftUI`) is
still load-bearing and still holds.

```
hackjack/
  Package.swift
  project.yml
  Sources/
    HackjackCore/
      Models/
        Card.swift          # Suit, Rank, Card — id/rank/suit only, no corruption fields
        Hand.swift            # Hand (cards, bestValue/isBusted/isBlackjack/power computed)
        Mob.swift              # Mob — wraps a Card with hp/stepsRemaining
        Shift.swift             # StageConfig + .standard(index:) — file kept, type renamed
        RunState.swift            # RunState (stageIndex/baseHP/baseMaxHP/seed) + dailyBreach(dateKey:)
        GameEvent.swift             # cardDealt/mobHit/mobKilled/baseHit
      Engine/
        SeededGenerator.swift      # unchanged — SplitMix64 deterministic RNG
        GameEngine.swift             # the whole loop: startStage/hit/redeal/advanceParade
      Resources/
        FlavorText.swift           # pooled narrative copy — mob killed/base hit/stage cleared/defeated
    HackjackCLI/
      main.swift                  # rebuilt: print towers+parade, accept hit/redeal/quit
    HackjackApp/
      App/HackjackApp.swift        # unchanged
      ViewModels/GameViewModel.swift  # rebuilt around towers/mobs/runState
      Support/Haptics.swift          # cardDealt/mobHit/baseHit
      Views/
        ContentView.swift, Theme.swift, MatrixRainView.swift   # unchanged
        TableView.swift              # rebuilt: status readout, shoe, parade, N tower rows, log
        Table/
          CardView.swift             # simplified back to a bare renderer — see §0
          TowerRowView.swift          # was HandRowView.swift — one tower's hand + power + controls
          MobParadeView.swift         # new — the marching parade, per-mob strike-on-hp-change
          LightningBoltShape.swift    # extracted from CardView.swift, now shared with MobParadeView
          ShoeView.swift, DealTransition.swift   # unchanged — see §0
  Tests/
    HackjackCoreTests/
      GameEngineTests.swift        # rebuilt, 13 tests — see §0
```

---

## 4. Data Models

```swift
// Card.swift
enum Suit: CaseIterable, Sendable { case clubs, diamonds, hearts, spades }
enum Rank: Int, CaseIterable, Comparable, Sendable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king, ace
    var blackjackValue: Int { /* ace=11, face=10, else rawValue */ }
}
struct Card: Identifiable, Equatable, Sendable {
    let id: UUID
    var rank: Rank
    var suit: Suit
}

// Hand.swift
struct Hand: Identifiable, Sendable {
    let id: UUID
    var cards: [Card]
    var bestValue: Int { get }      // computed, soft-ace aware
    var isBusted: Bool { get }       // computed: bestValue > 21
    var isBlackjack: Bool { get }     // computed: 2 cards, bestValue == 21
    var power: Int { get }             // computed: isBusted ? 0 : bestValue
}

// Mob.swift
struct Mob: Identifiable, Sendable {
    let id: UUID              // == card.id
    let card: Card
    var hp: Int
    var stepsRemaining: Int
    var isDead: Bool { get }             // hp <= 0
    var hasReachedBase: Bool { get }      // stepsRemaining <= 0
}

// Shift.swift (file name kept, type renamed)
struct StageConfig: Sendable {
    let index: Int
    let mobCount: Int
    let mobStartingSteps: Int
    let mobHPMultiplier: Double
    static func standard(index: Int) -> StageConfig
    // mobCount = min(6 + (index-1)*2, 24)
    // mobStartingSteps = max(3, 6 - (index-1))
    // mobHPMultiplier = 1.0 + (index-1)*0.5
}

// RunState.swift
struct RunState: Sendable {
    var stageIndex: Int
    var baseHP: Int
    var baseMaxHP: Int
    var seed: UInt64?
    static func dailyBreach(dateKey: String) -> RunState   // unchanged FNV-1a derivation
}

// GameEvent.swift
enum GameEvent: Sendable, Equatable {
    case cardDealt
    case mobHit(mobID: UUID)
    case mobKilled(mobID: UUID)
    case baseHit
}
```

---

## 5. Core loop (`GameEngine`)

```swift
final class GameEngine {
    private(set) var runState: RunState
    private(set) var stageConfig: StageConfig
    private(set) var towers: [Hand]        // count == towerCount, index = tower slot
    private(set) var mobs: [Mob]             // currently marching, spawn order == distance order
    let towerCount: Int

    var totalPower: Int { get }              // sum of every tower's power
    var shoeCount: Int { get }
    var isStageCleared: Bool { get }          // mobSpawnQueue.isEmpty && mobs.isEmpty
    var isDefeated: Bool { get }               // baseHP <= 0

    func startStage()                    // fresh shoe, fresh mob queue, every tower redealt
    func hit(towerIndex: Int)             // draw one card; no-op if already busted; ticks the parade
    func redeal(towerIndex: Int)           // fresh 2-card hand; ticks the parade
    func drainLog() -> [String]
    func drainEvents() -> [GameEvent]
}
```

- **Card source**: a single shared `shoe`, rebuilt fresh (and reshuffled)
  whenever it runs out, feeds both tower hands and the mob spawn queue —
  "you and the parade come from the same deck" is a deliberate thematic
  choice, not an implementation shortcut.
- **Tick order** (`advanceParade()`, called at the end of every `hit`/
  `redeal`): apply `totalPower` to the frontmost mob (removing it and
  emitting `.mobKilled` if it dies) → step every remaining mob's
  `stepsRemaining` down by one → resolve any mob that just reached the
  base (damage `baseHP` by its remaining `hp`, remove it, emit
  `.baseHit`) → spawn the next queued mob if there is one → resolve
  defeat or stage-clear if either just became true.
- **Frontmost mob** is always `mobs.first`, not a distance comparison —
  mobs are appended in spawn order and all share the same
  `stageConfig.mobStartingSteps` at spawn, so spawn order and distance
  order are the same list order for as long as nothing reorders the
  array (nothing does).
- **No manual targeting exists.** All towers always hit the same mob.
  This is the biggest deliberate simplification versus a "real" tower
  defense game — see §0's honest gaps.

---

## 6. Testing strategy

- `Engine/`/`Models/` stay UI-independent — `swift test` runs `GameEngineTests`
  with no simulator needed.
- Seed the RNG in every engine test — no live `Int.random` in test paths,
  same hard requirement as before (also what makes Daily Breach
  determinism possible).
- Where a test needs a mob to reliably survive or reliably die within a
  fixed number of ticks, prefer picking `stageIndex`/`towerCount` so the
  bound is *guaranteed* by the numbers (see
  `testMobTakesDamageEqualToTotalPowerEachTick`'s and
  `testMobReachingBaseEmitsBaseHitAndIsRemoved`'s doc comments for the
  actual arithmetic) over searching for a lucky seed — it's both more
  reliable and self-documenting about *why* the scenario is guaranteed.
  Where that's not practical (e.g. "does a stage ever clear"), the
  existing seed-search-with-`XCTUnwrap` pattern from the old test suite
  is still the right fallback — see `testStageClearAdvancesStageIndex`,
  `testMobDyingIsRemovedAndEmitsMobKilled`, and
  `testHitIsANoOpOnAnAlreadyBustedTower`.
- For UI/animation work: actually run the app and exercise the feature
  before calling it done. This sandbox can't drive Simulator taps (§0),
  so that verification is currently a real gap, not a completed step —
  don't claim otherwise.

**Current state:** 13 tests, all passing, `swift test`.

---

## 7. App Store Connect status (unchanged by this rewrite)

Signing (`com.smerwin.hackjack`, team `Q2GAZA687V`, `CODE_SIGN_STYLE:
Automatic`) and a real app icon (`Sources/HackjackApp/Resources/
Assets.xcassets`) are both already in place from before this rewrite —
none of that is affected by the engine/UI changes here. Still open,
exactly as before: register the app record in App Store Connect if not
already done, run on a physical device at least once (still only
Simulator-verified), complete the privacy/age-rating questionnaires, and
do a real `archive`/export/upload rather than just a `build`. A gambling-
adjacent rating question that applied to the blackjack framing likely
doesn't apply the same way to a tower-defense frame — worth a fresh look
rather than assuming the old answer still holds.
