# Dog Eat Dog — Wave 3b Design: Evening Clock + Sleep Economy

**Date:** 2026-07-29
**Status:** Approved pending user review
**Parent spec:** `2026-07-24-dog-eat-dog-design.md`
**Prior wave:** `2026-07-27-wave3a-clock-morning-design.md` + `2026-07-28-wave3a-qa-r2-commute-deadline-design.md` (DONE 2026-07-29, PR #8)
**Repo:** `~/code/games/dog-eat-dog`

## Original pitch (user's words)

Wave 3b was named in the 3a spec as "the evening half of the timing punishment" — evening clock, drive home, cooking (chop → transfer → stir → pour), workout (freetime alternative), pajamas.

Mid-brainstorm addition (user's words):

> "can we add sleep deficit and sleep bank into the game as a mechanism to really encourage going to bed"

That addition is the wave's centre of gravity, not a side feature. It fixes a real weakness: the evening's memory is currently **one night deep** — `energy_carry_weight` blends yesterday's leftover with tonight's refill and then forgets. A week of late nights costs exactly what one costs.

## User decisions (locked at brainstorm)

| Decision | Pick |
|---|---|
| What dawdling costs | Bedtime derives from the evening clock; punishment flows through the existing energy-carryover path |
| Clock shape on screen | Sliding bands — the HUD always states the next line you can still make |
| Sleep debt teeth | Energy ceiling **and** the sick cliff (found at spec time to be one chain, not two — see Correction) |
| Debt display | Ledger line at the sleep beat (clock-minutes, legal) + art only during the day |
| Wave-2 tunables the clock subsumes | `late_game_drain` retires; `played_late` re-sourced from debt rather than retired (see Correction) |
| Scope | Evening clock + sleep economy + drive home + cooking. Workout and pajamas → 3c |

## Correction found at spec time

Two code facts contradicted the options as originally framed, and both make the design **smaller**:

1. **`played_late` is not the sick trigger.** It is a *habit* flag feeding `Difficulty.temptation_params(energy, cfg, played_late)` — played late yesterday, the temptation pull is stronger tonight. The real sick trigger is `Difficulty.is_sick_morning(energy, cfg)` → `energy < cfg.sick_energy_threshold`.
2. **Therefore the sick cliff needs no new code.** Debt lowers the energy ceiling; a low enough ceiling crosses the threshold that already exists. Ceiling and cliff are one chain. `game.gd:299` already runs `is_sick_morning(_tomorrow_energy(), cfg)` for the wobble telegraph, so the one-day-ahead warning required by the wave-2 telegraph invariant comes **free**.

**This also closes a live gap.** `sleep_energy["late"] = 35.0` and the carry blend trends toward it, so `sick_energy_threshold = 12.0` is unreachable by chronic lateness — today you can be permanently late forever and never get sick; only a single bad day does it. The energy ceiling is what makes chronic debt actually bite, which is the point of the mechanic.

**`played_late` is re-sourced, not retired.** Retiring it would delete the habit spiral (a late night makes the next one harder to resist), which is good design. Scaling the temptation pull with `debt_minutes` instead of a yesterday-only bool keeps the spiral under the single new authority and gives it depth instead of one bit.

## The chain

One authority, one direction. Every consequence is an existing system reading a lower energy number.

```
freetime games / slow cooking / slow drive home
  → evening clock elapses
  → bed minute → band (early|mid|late) → sleep_energy[band]     ← wave-2 code untouched
  → slept minutes = (morning_start_minutes + 1440) − bed minute
       bed minute is absolute-from-midnight and the evening crosses it, so the
       wrap is mandatory: bed 23:41 (1421) → 420 + 1440 − 1421 = 439 min slept.
       A naive wake − bed goes negative for every late night, which is exactly
       the band the mechanic exists to punish.
  → debt += sleep_need − slept        (clamped both directions; banked surplus capped)
  → max_energy = f(debt)
  → clamps GameState.apply_energy AND start_next_day's blend
  → Difficulty.*_params(energy, cfg) → every minigame harder
  → energy < sick_energy_threshold → sick day (existing path, existing telegraph)
  → temptation pull scales with debt (replaces played_late's bool)
```

The ceiling clamping **both** `apply_energy` and the `start_next_day` blend is load-bearing: without the `apply_energy` clamp, coffee or breakfast would refill a sleep-deprived dog back to full and the mechanic would have no daytime presence.

## Architecture

**Bands clock — extend `DayClock`, do not add a second clock.** `DayClock` gains an optional list of band lines plus `band_name()`; `zone()` runs against whichever line is currently live. The morning passes one line (`work_start_minutes`), the evening passes three. The morning becomes the one-line case of the general thing, so 3a's behaviour is unchanged and its tests keep passing.

Rejected: a separate `EveningClock` class. Risks nothing in 3a, but installs a second time authority — directly against the wave-3a invariant that `DayClock` is the only time authority and `game.gd` its only spender.

**Sleep ledger — new pure class.** `SleepLedger` (RefCounted, `scripts/core/`) owns `debt_minutes` and exposes `record_night(bed_minute, wake_minute, need)`, `max_energy()`, and `ledger_text()`. `GameState` holds one, exactly as it holds `Wallet`. 100% unit-testable with zero scene dependencies, matching how `DayClock`, `Wallet`, and `RankLadder` are already built.

Rejected: fields on `GameState`. Fewer files, but `GameState` is already the god-object and the accrual math would not be testable in isolation.

## Slot changes

New evening order:

```
work_pm → [rank news] → drive_home → dinner → freetime → sleep
```

The evening clock runs for `EVENING_TIMED` only, mirroring `MORNING_TIMED` (`game.gd:64`); the HUD is hidden outside those slots. Rank news keeps its position — it lands at the office right after afternoon work (wave-2 invariant), so the evening clock starts after it.

**The evening needs its own absolute start minute.** The morning's clock is seeded from `morning_start_minutes` (420 = 7:00) and the band lines here are absolute wall-clock times, so a new `evening_start_minutes` tunable seeds the evening block at office departure. It is the evening's counterpart to `work_start_minutes` and, like it, is a primary playtest lever: moving it moves every band's effective margin without touching the band thresholds themselves.

| Slot | Build | Notes |
|---|---|---|
| `drive_home` | `drive.tscn`, new params | **Deliberately shorter than the morning commute.** The 3a reflect's carried-forward note flags that 900 units at 4 waves already spends a third of the morning on one slot; making the evening do it again would make the game feel like two commutes. Evening time belongs in cooking and freetime, where the choices are. |
| `dinner` | existing choice card, new teeth | `cook` launches the cooking minigame and costs clock. `takeout` costs `takeout_price` and costs **no** clock. First time the wallet buys time. |
| `cooking` | NEW scene | Four verbs in sequence: chop → transfer → stir → pour. Energy knob is per-verb tolerance. Skill is speed, so it feeds the clock directly rather than scoring separately. |
| `freetime` | existing, re-sourced | Unchanged loop. `late_game_drain` retires; games now cost time, and the pull scales with debt instead of `played_late`. |
| `sleep` | existing narration beat | Gains the ledger line. Still no input, still derived. |

**The money↔time exchange is the evening's signature decision**, and it is inverted from the morning on purpose: the morning has no way to buy time back (skipping *costs* time, wave-3a invariant), the evening does, for money.

**Freetime is already the evening's engine.** The "one more game" temptation loop exists and pulls harder every game. A visible clock plus banded bedtime only makes its cost legible — every game visibly eats toward the next line. No new mechanic is needed to make bedtime tense.

## HUD + copy

The clock reads `21:47 · early until 22:00`, calm → amber → red against whichever line is live; crossing a line re-targets the readout to the next one.

```
21:47  ·  early until 22:00      [calm]
22:14  ·  mid until 23:30        [amber]
23:41  ·  late                   [red]
```

Debt is stated **once**, at the sleep beat, in clock terms — `"6h10 tonight. Three nights behind."` / `"8h40. Banking it."` Those are minutes, and the game already prints minutes, so this does not touch the energy-display rule.

Debt's *effect* is art only: eye bags deepen, the idle animation slows, the sprite state text carries it. Never a number, never a gauge, never a persistent HUD element.

## New invariants (add to repo `CLAUDE.md` at wave close)

- **Bedtime derives from the evening clock.** `StatEffects.derive_bedtime(games_played)` is retired. A tunable that reintroduces game-count authority splits it — same class as `morning_budget_minutes` in 3a.
- **Debt's only consequence path is the energy ceiling.** Nothing reads `debt_minutes` to apply a penalty directly. The sick cliff, the harder minigames, and the temptation spiral are all downstream of a lower energy number.
- **Debt is never a number outside the sleep beat's once-a-night line.** The energy rule bans energy as a number; debt is minutes and so is legal there, but a persistent gauge violates the rule's intent.
- **The evening clock is a punishment, never a gate.** It never blocks a slot, never fails a minigame, never ends the day early. Same rule as the morning clock.
- **Banked surplus is capped.** A good week buys one late night, not immunity.
- **`drive_home` is shorter than the morning commute by design.** Two full commutes a day is the failure mode this constraint exists to prevent.

## Testing

Full TDD, 100% on pure logic:

- `SleepLedger` — accrual, repayment, bank cap, ceiling curve, `ledger_text()` phrasing, clamping in both directions
- `DayClock` band lines — crossing, re-target, `band_name()`, and the morning's one-line case proven unchanged
- Cooking's four-verb sequence logic (order enforcement, per-verb tolerance)
- Drive-home params distinct from the morning's
- Ceiling applied at both clamp sites — a test that coffee cannot refill past the ceiling

Scene smoke test for cooking. **No coverage gate on visual scenes** (domain rule). GUT timing tests that depend on windows NOT elapsing use absurd windows (domain rule, physical-clock class).

Day-flow integration: a chronic-debt run reaching the sick cliff, and a bank run absorbing a late night without one.

**Draw-order assertion required.** The 3a reflect's closing lesson: *a correct node drawn behind an opaque one passes every test the suite can express.* The evening clock HUD is exactly that case — a HUD element over minigames that paint a background. It needs a draw-order assertion, not just a visibility one.

## Out of scope (3b)

Workout and pajamas (3c). Ranks 4–6 + senior tier. Energy drink + snack. Unconsumed lunch score → rep sink. Emoji art pass. The 4 open dependabot PRs (`actions/checkout-7`, `actions/cache-6`, `actions/setup-node-7`, `pnpm/action-setup-6`) — separate housekeeping pass.

## Open items for plan time

All seed numbers are plan-authored and tuned at playtest via `BalanceConfig`, per the 3a precedent: `evening_start_minutes`, the band thresholds, `sleep_need`, the ceiling curve, the bank cap, drive-home length and speed band, cooking's per-verb tolerances, takeout's clock saving.

Two are genuinely uncertain and no amount of reasoning beats one ride:

- **Does the mid band break even or slowly accrue?** Working assumption: early banks, mid ≈ break-even, late accrues — so the neutral path is sustainable and only deliberate lateness rots.
- **How far must the ceiling fall to reach `sick_energy_threshold = 12.0`?** This curve is the entire difficulty of the mechanic. Reference points: `sleep_energy` is `{early: 90, mid: 65, late: 35}` and `energy_carry_weight` is `0.5`, so a permanently-late dog currently floors around 35 — the ceiling has to be able to pull below that and eventually below 12, but slowly enough that one bad night is never a death spiral.

Cooking's four-verb copy and the ledger's phrasing are plan-authored, user-gated at playtest (copy = value judgment, domain rule).
