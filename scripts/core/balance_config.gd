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
## How long a game's HIT/MISS/SKIP stamp holds before the next slot mounts, in
## real seconds. The DayClock holds still through it, as it does for the gag.
@export var stamp_hold_seconds: float = 0.8
@export var fail_performance_cost: float = 0.01
@export var fail_energy_cost: float = 3.0
## Per-game time limits in real seconds, and the score floors that make a game
## a MISS (issue #17). Difficulty hands each one to its game as a param.
##
## Each limit lerps _base (full energy) -> _max (empty) on the same deficit the
## game's difficulty uses (user revision, #17), aiming at ~10% sharp misses at
## any energy. Base = sharp p90 from the #11 baseline. Max = sharp p90 at full
## deficit: autoplay sharp, seeds 1-5 x 30 days (n=137), on 6c6d8bd with
## Difficulty._deficit pinned to 1.0 in a throwaway copy, rounded to 0.1 s.
@export var wake_time_limit_base: float = 3.7  # sharp p90, #11 baseline
@export var wake_time_limit_max: float = 17.0  # sharp p90 at d=1 (16.98), #17
@export var brush_time_limit_base: float = 2.3  # sharp p90, #11 baseline
@export var brush_time_limit_max: float = 3.3  # sharp p90 at d=1 (3.32), #17
@export var shower_time_limit_base: float = 3.5  # sharp p90, #11 baseline
@export var shower_time_limit_max: float = 7.0  # sharp p90 at d=1 (7.00), #17
@export var clothes_time_limit_base: float = 4.2  # sharp p90, #11 baseline
@export var clothes_time_limit_max: float = 6.1  # sharp p90 at d=1 (6.10), #17
@export var breakfast_time_limit_base: float = 2.3  # sharp p90, #11 baseline
## The beat speed does not move with energy, so the duration does not scale
## (d=1 p90 2.23). The day ramp speeds it up but never moves this limit.
@export var breakfast_time_limit_max: float = 2.3  # = base, measured, #17
@export var cook_time_limit_base: float = 6.4  # sharp p90, #11 baseline
## The verbs run at a fixed speed too (d=1 p90 6.43).
@export var cook_time_limit_max: float = 6.4  # = base, measured, #17
@export var work_fail_score: float = 0.5  # MISS below it; ruling, #17
## MISS below it, and lunch scores in thirds (hits / 3 cues), so 0.01 misses
## exactly the no-hit lunch with the same "score < floor" rule as work.
@export var lunch_fail_score: float = 0.01  # MISS on no hits; ruling, #17
@export var breakfast_fail_hits: int = 1  # MISS below 1 hit of 3; ruling, #17
@export var cook_spoil_limit: int = 3  # the 3rd spoiled step (of 4) is a MISS; ruling, #17

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
## The coffee cart's cup grab (#18): the cup crosses the track at
## coffee_cup_speed track widths a second (the day ramp multiplies it), entering
## coffee_cup_lead seconds in. The paw grabs it in a zone coffee_zone_width wide
## around coffee_zone_center (both track fractions): 0.14 / 0.77 s is +-0.09 s
## at the day's fastest, past a sharp press (sd 0.02 s) and short of a sloppy
## one (sd 0.07 s).
@export var coffee_cup_speed: float = 0.7
@export var coffee_cup_lead: float = 1.0
@export var coffee_zone_center: float = 0.7
@export var coffee_zone_width: float = 0.14
@export var takeout_price: int = 12
## Dinner as a walk (#18): the dog starts dinner_walk_start of the way along a
## floor with the pan at 0 and the phone at 1, and walks dinner_walk_speed
## floor widths a second. Neither moves with energy or the day; only the time
## limit scales, base to max on the energy deficit.
@export var dinner_walk_speed: float = 0.5
@export var dinner_walk_start: float = 0.5
## Set from the bot, seeds 1-5 x 10 days: sharp walks in 2.09-2.17 s median,
## p90 at most 2.23 s, at energy 55-79; sloppy in 2.93-3.00 s median, slowest
## 3.27 s, at energy 0-52. The base clears sharp's p90 by ~0.8 s; the max
## clears sloppy's slowest by ~1.2 s, and its best evening (52) still gets 3.7 s.
@export var dinner_time_limit_base: float = 3.0
@export var dinner_time_limit_max: float = 4.5
@export var retirement_target: int = 4000
@export var sick_energy_threshold: float = 12.0
@export var sick_reset_min: float = 45.0
@export var sick_reset_max: float = 80.0
@export var sick_burrow_target: int = 20
@export var sick_burrow_time: float = 6.0

# --- wave 3a: day clock + morning minigames ---
## The wake, and the morning's tuning lever: the drive and the five chores
## before it decide when the dog arrives, and this is set so a clean sharp
## morning arrives just before 8:00. Sharp bot, seeds 1-5 x 10 days
## (just autoplay prints it): median 4.8 minutes early, late on 3 of 50
## mornings, each one of the three slowest drives (14.0-16.0 s). The ledger
## counts sleep from here, so moving it moves sleep_need_minutes and
## sick_sleep_minutes by the same amount (420 -> 435 moved them 15, #18).
@export var morning_start_minutes: int = 435
## Work starts at 8:00. This is the deadline and stays put; the morning's budget
## is derived from it (morning_budget()), never stored beside it. Tune the
## morning through morning_start_minutes.
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
## Day ramp (#18): play-speed multiplier at the day's last game, lerped from
## 1.0 on day progress; speed only, never a time limit. Breakfast cliff: sharp
## misses jump between 1.10 and 1.15 (each beat restarts at phase 0, p90 limit).
@export var day_ramp_speed_max: float = 1.1
@export var breakfast_energy_min: float = 2.0
@export var breakfast_energy_max: float = 8.0
@export var skip_breakfast_penalty: float = 4.0
## The weave cost (pin_gap + block_margin = 55 units) is fixed, while the room
## between walls is length * 0.65 * (1 - the day roll) / (waves - 1), so the
## route has to stay long enough to leave room around every wall it ships
## (test_weaving_to_the_open_lane_beats_holding_a_lane runs every wave count).
## The time comes from top speed instead: 850 units at 100 is a ~10 s drive
## (sharp bot median 10.1 s, p90 12.3 s). Drive home shares the top speed.
@export var drive_length: float = 850.0
@export var drive_top_speed: float = 100.0
@export var drive_accel: float = 40.0
@export var drive_pin_gap: float = 30.0
@export var drive_block_margin: float = 25.0
@export var drive_switch_lag_base: float = 0.0
@export var drive_switch_lag_max: float = 0.45
## Traffic comes in waves — one car in every lane but one. These are wave
## counts, not car counts: the commute scales by how many walls you weave
## through, from base (a fresh dog) to max (a wrecked one).
##
## 3/4 on the 850-unit route: both counts pass the skill tests in
## test_lane_sim, and the morning keeps one wall more than drive home's 2/3 at
## every energy (test_difficulty), since both round a lerp on the same deficit.
@export var drive_waves_base: int = 3
@export var drive_waves_max: int = 4
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
## Display only. These map the sim's route units to a trip the player can read
## while a bad roll is happening to them (0.01 mile per unit, as on drive home).
@export var drive_route_miles: float = 8.5
@export var drive_display_top_mph: float = 60.0
## Work AM's word burst (#18): words stream for the whole shift, the timer
## ends it (no time_limit), and the score is words typed / words shown. Every
## word gets burst_word_windows[rank] seconds, divided by the day ramp's speed;
## the clarity tier picks the word's length (longer as the dog fades), so the
## rank sets the bar and the dog's state decides how many words clear it.
@export var burst_shift_time: float = 25.0
@export var burst_word_windows: Array[float] = [3.0, 2.0, 1.15]
## Work PM's inbox triage (#18): emails land every triage_arrival_gap seconds
## (each gap rolled within triage_arrival_jitter of it either side), over the
## day ramp's speed; the shift timer ends it (no time_limit), and the score is
## correct sorts / emails shown. The email on top gets
## triage_email_windows[rank] seconds (also over the speed) from reaching the
## top; the inbox holds triage_inbox_capacity emails and buries what lands on
## a full one, so the arrival gap is the pace to keep. The clarity tier is the
## read delay: the email on top is out of focus for triage_read_delays[tier]
## seconds (indexed by tier, 0 to 4) each time a new one reaches it — the dog's
## eyes, so the ramp does not shorten it, and it never shrinks as the tier falls.
@export var triage_shift_time: float = 25.0
@export var triage_email_windows: Array[float] = [2.0, 1.5, 1.1]
@export var triage_arrival_gap: float = 0.75
@export var triage_arrival_jitter: float = 0.5
@export var triage_inbox_capacity: int = 6
@export var triage_read_delays: Array[float] = [0.45, 0.3, 0.2, 0.1, 0.0]

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
## Counted to the wake (morning_start_minutes), so the two move together: 495
## is the 23:00-to-7:15 night, which keeps 23:00 the square bedtime (#18).
@export var sleep_need_minutes: float = 495.0
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
## sick day always pays debt down rather than accruing more. What it banks is
## this minus sleep_need_minutes (240), so it moves with the need (720 -> 735
## when the wake moved to 7:15, #18).
@export var sick_sleep_minutes: float = 735.0
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
## The drive home: the morning's road and car (top speed, accel, traffic
## rolls), shorter and with one wall fewer at every energy (test_difficulty).
## 2/3 is the most walls that stays one under the morning's 3/4 at every
## energy, so length is the only lever left, and it has to stay under
## drive_length: 840 units (0.01 mile each) is a sharp bot median of 9.65 s,
## p90 10.5, over seeds 1-5 x 10 days (450 was 5.9 s). Both lane-sim skill
## tests run it at every wall count it ships.
@export var drive_home_length: float = 840.0
@export var drive_home_route_miles: float = 8.4
@export var drive_home_waves_base: float = 2.0
@export var drive_home_waves_max: float = 3.0
## Home by this, or the drive home is a MISS: the evening's 8:00. Absolute,
## like work_start_minutes; the span from leaving the office is derived
## (home_budget()). Its miss pays no loss cost, only the evening minutes the
## slow drive already spent, which reach the bed minute and the sleep ledger.
## 21:46 is set so a clean sharp drive barely makes it: sharp bot, seeds 1-5 x
## 10 days, median 1.5 minutes to spare, late on 3 of 50, each one of the
## three slowest drives (10.8-12.5 s, the bad traffic rolls). At 21:45 any
## drive over 10.0 s is late (12 of 50).
@export var home_by_minutes: int = 1306


## The morning's game-minute budget, derived. game.gd builds every DayClock
## from this; nothing stores it.
func morning_budget() -> float:
	return maxf(work_start_minutes - morning_start_minutes, 0.0)


## The drive home's game-minute budget, derived from home_by_minutes the way
## morning_budget() is from work_start_minutes.
func home_budget() -> float:
	return maxf(home_by_minutes - evening_start_minutes, 0.0)


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
