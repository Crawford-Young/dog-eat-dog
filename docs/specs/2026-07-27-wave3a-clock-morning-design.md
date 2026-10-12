# Dog Eat Dog — Wave 3a Design: Day Clock + Morning Minigames

**Date:** 2026-07-27
**Status:** Approved pending user review
**Parent spec:** `2026-07-24-dog-eat-dog-design.md`
**Prior wave:** `2026-07-26-wave2-ranks-economy-design.md` (DONE 2026-07-27)
**Repo:** `~/code/games/dog-eat-dog`

## Original pitch (user's words)

> "2 things i want to work on for dog eat dog. wave 3 including timing on minigames so taking longer is more punishing / new minigames: making food (chopping, moving from cutting board to pot, stirring the pot, pouring it), driving to work and back, putting on clothes (go to work, go to sleep), working out, shower. i want this to feel like a dumb ways to die game where you have a bunch of different minigames but for this its real life activities"

Drive refinement (user's words): "basic subway surfers feel with no death scene. you are on the road with other drivers that you cant crash into but they will stop you from changing lanes or going faster."

## Wave split (user pick: two waves)

- **3a (this spec):** day clock system, shift-timer typing rework, morning minigames — shower, clothes, breakfast, drive-to-work.
- **3b (own spec later):** evening clock, drive home, cooking (chop → transfer → stir → pour), workout (freetime alternative), pajamas.

Rationale: clock is the wave's bet — validate pacing feel at half cost before evening builds on it. Note: parent spec's indicative wave 3 (rep/social/variety) is deferred, not dropped — user redirect.

## User decisions (locked at brainstorm)

| Decision | Pick |
|---|---|
| Timing punishment shape | Day clock (visible ticking budget), not per-game score sink |
| Clock scope | Morning + evening blocks; evening deferred to 3b |
| Work typing | Shift timer — fixed duration, phrases stream, score = throughput |
| Morning structure | Triage — all tasks every morning, clock too tight for all; skips cost |
| Breakfast | Included in 3a morning |
| Drive feel | Subway-surfers lane weave, no crash/death; traffic pins speed and blocks lane changes |

## Day clock core

- New pure script `DayClock` (RefCounted, `scripts/core/`): a time budget in game-minutes, spent by real seconds during minigames (scale tunable, seed 1 real sec = 1 game-min) plus fixed costs (skip = small fixed cost; scene transitions free).
- Morning clock: starts at wake, ends on work arrival. Budget seed 7:00 → 9:00. Displayed as cute HUD/wall clock with time readout ("7:42") — visible during every morning task. Color shifts as budget drains: calm → amber → red.
- **Late arrival:** overrun minutes → performance debit (scaled, capped, curve in BalanceConfig) + cute boss-glance NarrationBeat at the office. Never fired. Telegraph rule: the clock itself telegraphs — red state always precedes any debit.
- All tunables (budget, time scale, skip costs, lateness debit curve, color thresholds) in `BalanceConfig`.
- **D1 partial close:** `wake_par_time` / `brush_par_time` retire — the clock consumes elapsed time directly. Wake/brush/lunch *scores* still await their rep-wave sink.

## Morning triage + slot changes

New morning slot order:

```
wake → brush → shower → clothes → breakfast → drive → [arrive] → coffee → work_am → lunch → work_pm → dinner → freetime → sleep
```

- **Mandatory:** wake, clothes, drive — speed is the only lever.
- **Skippable:** brush, shower, breakfast — skip via existing choice pattern; costs small fixed clock + energy penalty + cute-dread art line (stink lines). Triage emerges: running late → skip shower → eat the consequence.
- Retire offer / warning / sick beats keep current positions (retire precedes sick; sick day collapses the schedule as today).

## New minigames (placeholder art; one verb each; params only via `Difficulty.*_params`)

| Minigame | Verb | Energy knob | Notes |
|---|---|---|---|
| Shower | Circular scrub on dirt/stink spots | Spot count + required revolutions | `GestureTracker` gains circle detection (angle accumulation around spot center) |
| Clothes (work) | Drag 4 items (shirt, pants, shoes, collar/tie) onto dog zones | Drop chance mid-drag (low energy = item slips, fumble) | Order rule: shoes after pants; wrong order bounces off + wobble art. Mandatory — fumbles cost clock only |
| Breakfast | Timed clicks (toast pops / pancake flip), 3 beats | Timing window width | Gives small energy bump; missed beat = burnt art + smaller refill |
| Drive to work | Discrete lane switch (A/D or ←/→), 3 lanes, snap hop tween | Traffic density + lane-change sluggishness (input lag, heavy car) | No crash: pulling up behind a car pins you to its speed (honk, ears droop); occupied lane = bounce-back. Fixed distance; elapsed time = clock cost. Same scene reused in 3b for drive home with different params |

## Typing shift timer (rework)

- Work block = fixed real-seconds shift (BalanceConfig). Phrases stream: complete one, `TextForge` serves next.
- Score = work-units completed vs par count; **par per rank** (higher rank = higher par — replaces current length scaling). Clamp 0..1, feeds performance EMA unchanged.
- Wrong-buffer mechanic untouched. Energy still gates phrase legibility — keysmash text slows throughput (natural energy → performance link).
- Coffee buff unchanged (clarity tiers).
- Shift timer is separate from the day clock — work time is fixed; you cannot leave early.

## Invariants (new; add to repo CLAUDE.md at wave close)

- Clock consequence never blocks the day — late = performance debit + boss beat; the day always continues. No firing, no death (drive included: no crash state).
- All clock time costs flow through `DayClock`; no minigame owns raw timers for clock purposes.
- Clock red-state is the telegraph; lateness debit only ever lands after visible red.
- Mandatory tasks (wake, clothes, drive) are unskippable; skips exist only where a skip cost is defined.
- Difficulty still flows only through `Difficulty.*_params(energy, cfg)` — new minigames included.

## Testing

- Full TDD, 100% on pure logic: `DayClock` (budget spend, overrun math, skip costs, lateness debit curve), shift-timer scoring (throughput vs per-rank par), lane-sim logic (lane occupancy, block/pin rules — pure script, synthetic tick streams), circle-gesture detection (synthetic mouse paths), dress order rules, breakfast timing windows.
- Scene smoke tests for new scenes. **No coverage gate on visual scenes** (domain rule, stated explicitly).
- Day-flow integration extended: full morning triage paths — skip-all-and-late vs do-all-slow vs clean run.
- Playtest gates: clock pacing feel, drive feel, per-minigame feel. Playtest drives the feature's live semantics (does lateness read fairly? does triage feel like a choice, not a chore?) per domain rule.
- GUT timing tests that depend on windows NOT elapsing use absurd windows (domain rule, physical-clock class).

## Out of scope (3a)

Evening clock + drive-home params + cooking + workout + pajamas (3b). Rep/social/variety deck. Ranks 4–6. Energy drink + snack. Art passes, audio. Wake/brush/lunch score sinks (rep wave). Emoji art revisit. CI housekeeping PR.

## Open items for plan time

- All seed numbers (clock budget, time scale, skip costs, debit curve, shift length, per-rank par, traffic densities) — plan-authored, tuned at playtest via BalanceConfig.
- Boss-glance lateness copy + skip cute-dread lines — plan-authored, user-gated at playtest (copy = value judgment).
- Clock HUD placement/look — placeholder; real art at art wave.
