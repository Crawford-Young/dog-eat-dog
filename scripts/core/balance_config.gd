class_name BalanceConfig
extends Resource

## All wave-1 tunables. Feel iteration edits this (or balance_default.tres), not code.

## The bedtime bands, in order. This is also the key set `sleep_energy` is
## indexed by and the name list `DayClock.set_bands` receives — one vocabulary,
## so a rename cannot desync the refill table from the clock.
const BANDS: PackedStringArray = ["early", "mid", "late"]

@export var wake_mash_base: int = 12
@export var wake_mash_max: int = 40
@export var wake_decay_max: float = 6.0

@export var brush_strokes_base: int = 6
@export var brush_strokes_max: int = 16
@export var brush_amplitude: float = 40.0

@export var typing_wrong_cap: int = 5

@export var listening_window_base: float = 1.2
@export var listening_window_min: float = 0.45
# Speech, not narration: a coworker's line has to land well before its gesture
# window shuts. Fatigue makes the words rush at you — speed lerps base (fresh)
# -> max (empty energy) on deficit, alongside the shrinking window.
@export var listening_text_speed_base: float = 70.0
@export var listening_text_speed_max: float = 120.0

@export var temptation_pull_base: float = 60.0
@export var temptation_pull_max: float = 420.0
@export var temptation_habit_bonus: float = 120.0
@export var temptation_dwell_time: float = 0.25
@export var temptation_pull_growth: float = 90.0
## The game-shaped hole in the evening — what one more round actually costs
## in clock minutes. game.gd spends this per game_played signal.
@export var freetime_game_minutes: float = 45.0
# Hard ceiling on the drift, in px/sec. Logoff is the loop's only exit, so an
# uncapped pull eventually outruns any mouse and softlocks the night. 600 sits
# just above the worst uncapped start (pull_max 420 + habit_bonus 120) and well
# under a deliberate flick, which clears a few thousand px/sec.
@export var temptation_pull_ceiling: float = 600.0

## Losing a minigame (issue #17): the gag beat before the result reports (keep
## it 1-2 s), and what the loss costs in the slots that pay it — StatEffects
## owns the slot list.
@export var fail_gag_seconds: float = 1.5
@export var fail_performance_cost: float = 0.01
@export var fail_energy_cost: float = 3.0

@export var typewriter_chars_per_sec: float = 30.0
@export var sleep_hold_time: float = 1.4

@export var work_drain: float = 12.0
@export var selfcare_restore: float = 6.0
@export var lunch_restore: float = 3.0
@export var dinner_takeout_energy: float = 3.0
@export var skip_brush_penalty: float = 10.0
@export var sleep_energy: Dictionary = {"early": 90.0, "mid": 65.0, "late": 35.0}
# Wave-2 QA ruling (issue #5): a night's rest is a blend of leftover energy and
# the bedtime target, not a full reset — 0.5 means yesterday's exhaustion
# carries half its weight into tomorrow morning.
@export var energy_carry_weight: float = 0.5

# --- wave 2: ranks + economy ---
@export var salaries: Array[int] = [60, 90, 130]
# QA ruling (issue #8): retirement pacing is a living-costs drain, not a raw
# salary tally — rent + kibble, taken every close_day. The margin over this is
# the only real saving. Margins at defaults: 15 / 45 / 85 per rank.
@export var daily_living_cost: int = 45
@export var promote_threshold: float = 0.7
@export var promote_sustain_days: int = 3
@export var demote_threshold: float = 0.25
@export var coffee_price: int = 5
@export var coffee_buff_tiers: int = 2
@export var coffee_crash_drain: float = 18.0
@export var takeout_price: int = 12
@export var retirement_target: int = 4000
@export var sick_energy_threshold: float = 12.0
@export var sick_reset_min: float = 45.0
@export var sick_reset_max: float = 80.0
@export var sick_burrow_target: int = 20
@export var sick_burrow_time: float = 6.0

# --- wave 3a: day clock + morning minigames ---
@export var morning_start_minutes: int = 420
## Work starts at 8:00. The morning is whatever is left between waking up and
## being at the desk, so the deadline is the ONE tunable — there is no separate
## budget to keep in sync with it. Primary playtest lever for this round.
##
## 510 -> 525 -> 480, and the last move is the only one grounded in a real ride.
## A clean user playtest clocked in at 7:44 — a 44-minute morning against what
## was then a 105-minute budget, arriving an hour early. That ride also settled
## the split the earlier numbers only guessed at: the commute is ~33 of those 44
## minutes, so THE OTHER FIVE MORNING SLOTS COST ABOUT 11 MINUTES BETWEEN THEM.
## The 525 value had been set to preserve a 72-minute margin for those five
## slots; that margin never existed. At 480 a clean morning arrives ~16 minutes
## early and a bad traffic roll (10-15 minutes) lands on the wire, which is the
## "possible but hard" the round was asked for. Retuning the drive's length or
## band moves this number with it — the commute IS the morning.
@export var work_start_minutes: int = 480
@export var clock_scale: float = 1.5
@export var skip_time_cost: float = 8.0
@export var clock_amber_fraction: float = 0.4
@export var clock_red_fraction: float = 0.15
@export var lateness_debit_per_min: float = 0.004
@export var lateness_debit_cap: float = 0.12
@export var shower_spots_base: int = 2
@export var shower_spots_max: int = 5
@export var shower_revolutions: float = 2.0
@export var shower_min_radius: float = 12.0
@export var skip_shower_penalty: float = 10.0
@export var dress_fumble_base: float = 0.0
@export var dress_fumble_max: float = 0.9
@export var breakfast_window_base: float = 0.30
@export var breakfast_window_min: float = 0.12
@export var breakfast_beat_speed: float = 1.6
@export var breakfast_beats: int = 3
@export var breakfast_energy_min: float = 2.0
@export var breakfast_energy_max: float = 8.0
@export var skip_breakfast_penalty: float = 4.0
## The route is LONG on purpose, and its length is what buys the traffic its
## speed. The weave cost (pin_gap + block_margin = 55 units) is fixed, while the
## room between walls is length * 0.65 * (1 - the day roll) / (waves - 1) — so a
## longer route is the only way to run fast traffic and still leave the dog room
## to get around it. Measured 2026-07-29: at 400 units an ideal driver spent 44%
## of the route pinned; at 900 with the same traffic it is 22%. The bill is paid
## on the morning clock — the commute went from 18.2 to 32.9 game-minutes, and
## `work_start_minutes` was moved to cover exactly that.
@export var drive_length: float = 900.0
@export var drive_top_speed: float = 50.0
@export var drive_accel: float = 40.0
@export var drive_pin_gap: float = 30.0
@export var drive_block_margin: float = 25.0
@export var drive_switch_lag_base: float = 0.0
@export var drive_switch_lag_max: float = 0.45
## Traffic comes in waves — one car in every lane but one. These are wave
## counts, not car counts: the commute scales by how many walls you weave
## through.
##
## Base rose 3 -> 4 with the longer route, and it is not padding. On a 900-unit
## route three walls leave so much open road that the dog is at top speed for
## most of it, and the few pins it does take are behind the slowest cars in the
## draw — measured, that reads as a SLOWER commute (pinned speed 20.5 mph at 3
## waves vs 31.1 at 4) even though it is spent pinned less often. Four walls is
## where the road feels busy and the pins read as traffic rather than as bad luck.
@export var drive_waves_base: int = 4
@export var drive_waves_max: int = 5
## How far behind the car ahead of it a car settles, in its own lane. 20 units
## is 80px — wider than a 72px car, so traffic never overlaps on screen.
@export var drive_car_min_gap: float = 20.0
## Traffic speed as a fraction of the dog's top speed, rolled ONCE per commute.
## This is the "you were just late today" knob: a gridlock roll costs minutes no
## amount of weaving recovers, and the player gets no signal before the drive.
## Note the layout coupling — wall spacing scales with (1 - the roll), so a FAST
## roll packs the walls tighter, not looser. That coupling is also the CEILING on
## this band, and it is geometry rather than taste: the dog closes on traffic at
## (top_speed - v), so fast traffic must spawn nearly on the start line to be met
## at all. Measured on the 400-unit route, a 0.65 max already puts the first wall
## at ~22 units on its worst roll, against the 25-unit readability floor. Raising
## it further needs a LONGER ROUTE, not a bigger number here — and a longer route
## costs real seconds off the morning clock.
@export var drive_day_speed_min: float = 0.55
@export var drive_day_speed_max: float = 0.75
## Symmetric spread around the day roll, per wave, clamped back into the band —
## so one commute is a crawler then a wall you barely notice, not a flat grind.
@export var drive_wave_speed_jitter: float = 0.25
## Symmetric spread around the wave's speed, per car. Load-bearing, and NOT
## small: this is what makes a fully blocked wall SHEAR APART as it rolls down
## the route instead of pinning the dog to the horizon. Do not set it to zero.
##
## Measured 2026-07-29 against the ideal driver: this is the ONLY lever that
## moves how much of the route is spent pinned, and traffic speed moves it not
## at all (raising the band packs the walls tighter by exactly as much as the
## faster cars help). At 0.12 the ideal driver spent 60% of the route pinned; at
## 0.35 it is 44%. The counter-pressure is that the dog pins to the SLOWEST car
## in a wall, which is v * (1 - this), so pushing it much past 0.35 starts
## dragging the pinned speed back down — which is the thing it was raised to fix.
@export var drive_car_speed_jitter: float = 0.35
## Odds that a wave fills all five lanes with no gap at all. No crash — the dog
## pins to the wall until the shear opens a lane. Skill becomes reading the
## stagger early rather than threading a gap that is not there.
@export var drive_blocked_wave_chance: float = 0.25
## Display only. The sim works in its own 400 units; these map that to a trip
## the player can read while a bad roll is happening to them.
@export var drive_route_miles: float = 9.0
@export var drive_display_top_mph: float = 60.0
@export var typing_shift_time: float = 25.0
@export var typing_par_units: Array[int] = [3, 4, 5]

## The evening block's absolute start — the minute the dog leaves the office.
## This is the wave's PRIMARY playtest lever: moving it moves every band's
## effective margin without touching a single band threshold.
@export var evening_start_minutes: int = 1290
## Absolute wall-clock lines the bedtime bands are cut at. Stored absolute for
## the same reason work_start_minutes is — the deadline is the design intent,
## the span is derived.
@export var bed_early_line_minutes: int = 1320
@export var bed_mid_line_minutes: int = 1410
## What a night is supposed to be. Sleep shorter and the difference accrues.
@export var sleep_need_minutes: float = 480.0
## A good week buys one late night, not immunity — this is how far below zero
## the ledger may bank.
@export var sleep_bank_cap_minutes: float = 240.0
## And how far above zero it may rot. Uncapped debt is a death spiral: the
## ceiling bottoms out and no reachable number of good nights climbs back.
##
## T11 round 2 retune, 960 -> 420. This number is not a limit, it is the SLOPE:
## max_energy lerps 100 -> sleep_ceiling_min across it, so the cap alone decides
## how many late nights stand between the dog and the cliff. At 960 a late night
## moved the ceiling ~7 points and the lab's in_debt preset sat 4-11 nights away
## from sick — the spiral was real on paper and unreachable in a ride. At 420 the
## same night moves it ~16, which puts in_debt two late nights from the cliff
## with the wobble night visible in between, and still leaves one bad night from
## square at a ceiling of ~74 — a shrug, not a spiral.
##
## Kept deliberately close to sick_sleep_minutes - sleep_need_minutes (240), the
## credit one sick day banks: a sick day must dent the cap without erasing it,
## or the escape hatch becomes a free reset.
@export var sleep_debt_cap_minutes: float = 420.0
## The energy ceiling at a fully maxed debt. BELOW sick_energy_threshold on
## purpose — chronic lateness has to be able to make the dog sick.
@export var sleep_ceiling_min: float = 8.0
## How long a sick day sleeps. This is the sick loop's ESCAPE HATCH, not
## flavour. A sick day's schedule collapses to the sick beat, so no freetime slot
## records a night and the debt would freeze — and a debt frozen at the cap pins
## energy under sick_energy_threshold, which builds another sick day tomorrow,
## forever. That breaks both "no firing, no death" and "sick day = exactly 1
## day". It must therefore stay comfortably ABOVE sleep_need_minutes, so one
## sick day always pays debt down rather than accruing more.
@export var sick_sleep_minutes: float = 720.0
## Cooking's energy payoff, scaled by how few steps got spoiled: the meal is a
## minigame, so its value is earned.
@export var cook_energy_min: float = 2.0
@export var cook_energy_max: float = 14.0
## Per-verb gesture tolerance, 0..1 — widens with the energy deficit so a
## wrecked dog gets more slack per step, not fewer steps.
@export var cook_tolerance_base: float = 0.2
@export var cook_tolerance_max: float = 0.55
## The timing axis: the rhythm window narrows when tired, while tolerance
## (above) widens to forgive what the narrower window costs.
@export var cook_window_base: float = 0.3
@export var cook_window_min: float = 0.15
@export var cook_beat_speed: float = 1.2
## The drive home. Shorter than the morning commute BY DESIGN (wave-3b
## invariant) — evening time belongs in cooking and freetime, where the choices
## are. Everything else about the road is shared with the morning.
@export var drive_home_length: float = 450.0
@export var drive_home_route_miles: float = 4.5
@export var drive_home_waves_base: float = 2.0
@export var drive_home_waves_max: float = 3.0


## The morning's game-minute budget, derived. game.gd builds every DayClock
## from this; nothing stores it.
func morning_budget() -> float:
	return maxf(work_start_minutes - morning_start_minutes, 0.0)


## The evening's game-minute budget, derived — same rule as morning_budget().
## The last band line is the stored value; nothing stores this.
func evening_budget() -> float:
	return maxf(bed_mid_line_minutes - evening_start_minutes, 0.0)


## The band lines as offsets from the evening's start, which is the form
## DayClock.set_bands takes.
func bed_band_lines() -> PackedFloat32Array:
	return PackedFloat32Array([
		maxf(bed_early_line_minutes - evening_start_minutes, 0.0),
		maxf(bed_mid_line_minutes - evening_start_minutes, 0.0),
	])
