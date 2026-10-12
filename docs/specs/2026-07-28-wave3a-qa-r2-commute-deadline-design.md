# Wave 3a QA Round 2 — Arrival Deadline + Traffic That Can Ruin Your Morning

**Date:** 2026-07-28
**Wave:** 3a (morning clock + triage), QA Round 2 — same branch `feat/wave3a-clock-morning`, not wave 3b
**Origin:** user playtest 2026-07-28, verbatim: *"drive sucks to play once again. randomize car speeds so there is even a chance that you just get late to work just because. drive should be distance based and include the time it takes in the morning to get to work"* and *"i want the morning to feel like a mad dash thats possible to make it on time but its hard. we can do some play testing with timing to get that time down"*

## Goal

The morning becomes a mad dash against a **stated arrival time** instead of an abstract budget, and the commute becomes the place where luck can beat you. A clean, fast morning makes it. One dawdle, one skip, or a bad traffic roll does not.

## What the user decided

Four design forks were put to the user; all four answers are binding on this spec.

1. **Time model:** keep the existing real-time charging (`delta * clock_scale`); add a distance readout to the drive. The clock does NOT switch to a simulated travel-time model.
2. **Pressure source:** a **hard arrival deadline**. Work starts at a fixed clock time; the HUD counts toward it. This replaces the budget framing.
3. **Traffic luck:** the roll is a **surprise at the drive** — no forecast beat at wake. The player budgets the morning blind.
4. **Open lane:** the guaranteed gap is dropped. **A bad roll can fully wall off all five lanes.**

## Non-goals

- No simulated travel-time model (fork 1 was answered against it).
- No traffic forecast, radio beat, or any pre-drive signal (fork 3).
- No retune of the other five morning minigames' internals. Pressure comes from the deadline and the commute, not from making the shower harder.
- No change to what lateness costs. The capped `performance` debit and the late beat stay exactly as shipped.

---

## Section 1 — The deadline replaces the budget

`DayClock`'s arithmetic is unchanged. `remaining()`, `overrun()`, and `zone()` already express exactly what a deadline needs; only the framing and the HUD change.

**Config:**
- `morning_budget_minutes` retires.
- New `work_start_minutes: int = 510` (8:30). Starting value only — this is the primary playtest lever.
- Budget is derived at construction: `work_start_minutes - morning_start_minutes` (420 → 7:00, unchanged). Shipping default is therefore a 90-minute morning, down from 120.

**HUD:** the clock label gains the deadline — `7:42 · in by 8:30`. Calm/amber/red coloring still applies to the current time only. Amber at 40% of the morning left, red at 15% — same constants, re-anchored to the derived budget.

**Late:** unchanged. `overrun()` is stamped onto the drive result in `game.gd`, `StatEffects` charges `lateness_debit_per_min` capped at `lateness_debit_cap`, and the late beat fires. `LATE_COPY` already prints the arrival time, so it now reads against a time the player was told.

**Invariants kept:** the clock never blocks a slot, never fails a minigame, never ends the day. Red still precedes any possible debit.

**Invariant amended:** "red before debit" survives as a *telegraph* guarantee but no longer implies *avoidability*. With a surprise traffic roll, the player can be shown the red and still have no move that saves the day. This is the user's explicit intent, and the repo `CLAUDE.md` invariant text must say so rather than implying agency.

---

## Section 2 — Traffic that can ruin your morning

Three independent layers of randomness, each with a distinct job.

**1. Day roll (the "just because").** One traffic speed sampled per commute from a band — starting value `0.20 … 0.60` of `top_speed`, as `drive_day_speed_min` / `drive_day_speed_max`. A gridlock roll costs minutes that no amount of weaving recovers. Rolled when the drive starts; the player has no earlier signal.

**2. Per-wave jitter.** Each wall's speed varies around the day roll, so one commute isn't uniformly bad — you get a crawler, then a wall you barely notice. `drive_wave_speed_jitter` is a **fraction of the day roll**, applied symmetrically: a wave's speed is `day_roll * (1 ± jitter)`, clamped into the day band.

**3. Per-car jitter inside a wave** (`drive_car_speed_jitter`, likewise a symmetric fraction of that wave's speed). Small, and load-bearing: it makes a wall **shear apart** as it rolls down the route. This is the mechanism that stops a fully-blocked wall from pinning the dog for the entire remaining route. The player crawls behind it, watches it stagger, and takes the lane that opens first.

**Blocked walls.** `drive_blocked_wave_chance` rolls per wave. On a hit, the wave fills all five lanes with no open lane. No crash — the dog pins to the wall's speed until the shear opens a lane. Skill on a blocked wave is reading the shear early, not threading a gap that isn't there.

`make_traffic`'s input contract is unchanged: `car_count` in, `waves = car_count / CARS_PER_WAVE` as today. A blocked wave simply emits one extra car (`LANES` instead of `CARS_PER_WAVE`), so the returned array can exceed `car_count`. `CARS_PER_WAVE` stays the divisor and stops being the per-wave car count for every wave — the tests and `drive_minigame.gd`'s rect allocation both read `_sim.cars()` rather than assuming the product, so nothing downstream needs the two to agree.

**Spawn positions.** Currently back-computed from a single shared `WAVE_SPEED`. They become **per-wave**, back-computed from that wave's own speed, so each wall still arrives near its intended meet point (`FIRST_WAVE_MEET` 0.20 → `LAST_WAVE_MEET` 0.85).

**Why the old "uniform speed is structurally load-bearing" claim dies.** It was true only because spawn was back-computed from one shared speed. Pass-through was never the real risk: `_advance_cars` already clamps both speed and position per lane, so a fast car settles behind a slow one at `car_min_gap` rather than tunneling. Varied speeds make that clamp *observable* for the first time — which also resolves the standing ruling that traffic "reads synthetic because you never see the no-pass rule work."

**Accepted consequence:** waves can merge into a jam when a fast wave catches a slow one. Under the no-crash invariant that is a crawl, never a failure, and it is the most honest version of "some mornings are just bad."

**Invariant amended:** the repo `CLAUDE.md` line "Traffic is wave-structured… no wave leaves the same lane open as the one before it, so no straight line survives the route" becomes false. Its replacement states: traffic is wave-structured with per-wave and per-car speed variance; a wave may be fully blocked; walls shear apart over time; cars never pass through each other in-lane.

---

## Section 3 — Distance readout

`drive_route_miles: float = 9.0`, **display-only**. The sim keeps working in its existing 400 units; miles are a presentation mapping.

The drive HUD gains, beside the existing progress bar:
- miles remaining, counting down
- current speed as mph, so a pin reads as a pin (`22 mph` behind a wall vs `55 mph` clean)

No sim behavior depends on either readout. They exist so the commute reads as a trip and so a bad traffic roll is legible while it is happening.

---

## Section 4 — Tuning and verification

**Tuning is a playtest loop, not a plan-time guess.** Levers in the order to reach for them:

1. `work_start_minutes` — the deadline itself
2. `clock_scale` — how fast game-minutes burn per real second
3. `drive_day_speed_min` / `drive_day_speed_max` — how bad a bad day gets
4. `drive_blocked_wave_chance` — how often luck removes skill entirely

Target feel: a clean fast morning arrives roughly five minutes early. One dawdle, one skip, or a bad roll loses it.

**Tests that carry weight:**

- **No pass-through under varied speeds** — property test over randomized per-car speeds within a lane. Previously a guarantee by uniformity; now the position+speed clamp actually has to hold.
- **A fully-blocked wave shears open within a bounded time** — the property that keeps a blocked wall from eating the whole route. This is the single most important new test; without it the blocked-wall roll is a soft lock on fun.
- **Per-wave spawn back-computation** still places each wall near its intended meet point when every wave has a different speed.
- **Day-roll bounds** — sampled speed always within the configured band.
- **Deadline math** — derived budget from `work_start_minutes - morning_start_minutes`, zone anchors, `clock_text` rendering against the deadline.
- **Existing day-flow coverage** — drive still stamps `overrun` onto its result, late beat still fires, `car_count` key still emitted (`test_day_flow.gd:346` asserts it).

**Tests retired or rewritten:**

- `test_the_fresh_morning_commute_can_be_driven_flat_out` is false by construction once a blocked wall can roll. Rewritten as: *fastest day roll, zero blocked walls → an ideal driver approaches open-road time*.
- The guaranteed-gap property test and the no-repeat-open-lane test are removed — both assert behavior this spec deletes.

**Timing-test domain rule applies:** any GUT test depending on a window NOT elapsing uses an absurd window (100s+), per the games CLAUDE.md.

**Docs:** the repo `README.md` and `CLAUDE.md` already sit uncommitted in the working tree from Task 10 Step 5. The wave-3a invariant block's drive lines and the "red before debit" line are now wrong and get rewritten **in place**, in the same branch — never a follow-up PR.

---

## Files in scope

| File | Change |
|---|---|
| `scripts/core/balance_config.gd` | retire `morning_budget_minutes`; add `work_start_minutes`, `drive_day_speed_min/max`, `drive_wave_speed_jitter`, `drive_car_speed_jitter`, `drive_blocked_wave_chance`, `drive_route_miles` |
| `scripts/core/difficulty.gd` | `drive_params` carries the new traffic tunables; keeps emitting `car_count` |
| `scripts/minigames/lane_sim.gd` | per-wave + per-car speeds, per-wave spawn back-computation, blocked-wave roll; `WAVE_SPEED` const retires |
| `scripts/minigames/drive_minigame.gd` | miles + mph readout wiring |
| `scenes/minigames/drive.tscn` | two readout labels (`MOUSE_FILTER_IGNORE`, per the standing repo rule) |
| `scripts/game.gd` | clock constructed from derived budget; HUD label shows the deadline |
| `scripts/core/day_clock.gd` | unchanged — verified sufficient as-is |
| `tests/unit/test_lane_sim.gd` | new property tests; retire the gap/flat-out assertions |
| `tests/unit/test_day_clock.gd`, `test_day_flow.gd`, `test_scene_smoke.gd` | deadline math, HUD text, new labels |
| repo `README.md`, `CLAUDE.md` | rewrite the drive + clock invariant lines already dirty in the tree |

## Open risks

- **A blocked wall plus a slow day roll is the worst case in the game.** If the shear rate is tuned too low, that combination is several minutes of near-zero input. The bounded-shear test sets a ceiling; the playtest decides whether the ceiling is fun.
- **90 minutes is a guess.** The deadline default is the starting point of the tuning loop, not a designed value.
- **`Difficulty` referencing `LaneSim.CARS_PER_WAVE`** remains a mild layering inversion carried from QA-R1. Flagged, not fixed here.
