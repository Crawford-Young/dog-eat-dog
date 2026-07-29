class_name BalanceConfig
extends Resource

## All wave-1 tunables. Feel iteration edits this (or balance_default.tres), not code.

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
# Hard ceiling on the drift, in px/sec. Logoff is the loop's only exit, so an
# uncapped pull eventually outruns any mouse and softlocks the night. 600 sits
# just above the worst uncapped start (pull_max 420 + habit_bonus 120) and well
# under a deliberate flick, which clears a few thousand px/sec.
@export var temptation_pull_ceiling: float = 600.0

@export var typewriter_chars_per_sec: float = 30.0
@export var sleep_hold_time: float = 1.4

@export var work_drain: float = 12.0
@export var selfcare_restore: float = 6.0
@export var lunch_restore: float = 3.0
@export var dinner_cook_energy: float = 10.0
@export var dinner_takeout_energy: float = 3.0
@export var late_game_drain: float = 15.0
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
## Work starts at 8:30. The morning is whatever is left between waking up and
## being at the desk, so the deadline is the ONE tunable — there is no separate
## budget to keep in sync with it. Primary playtest lever for this round.
@export var work_start_minutes: int = 510
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
@export var drive_length: float = 400.0
@export var drive_top_speed: float = 50.0
@export var drive_accel: float = 40.0
@export var drive_pin_gap: float = 30.0
@export var drive_block_margin: float = 25.0
@export var drive_switch_lag_base: float = 0.0
@export var drive_switch_lag_max: float = 0.45
## Traffic comes in waves — one car in every lane but one. These are wave
## counts, not car counts: the commute scales by how many walls you weave
## through. Past 3 waves the walls sit closer together than block_margin +
## pin_gap, so a tired dog eats a pin at each one no matter how well it drives.
@export var drive_waves_base: int = 3
@export var drive_waves_max: int = 5
## How far behind the car ahead of it a car settles, in its own lane. 20 units
## is 80px — wider than a 72px car, so traffic never overlaps on screen.
@export var drive_car_min_gap: float = 20.0
## Traffic speed as a fraction of the dog's top speed, rolled ONCE per commute.
## This is the "you were just late today" knob: a gridlock roll costs minutes no
## amount of weaving recovers, and the player gets no signal before the drive.
## Note the layout coupling — wall spacing scales with (1 - the roll), so a FAST
## roll packs the walls tighter, not looser.
@export var drive_day_speed_min: float = 0.20
@export var drive_day_speed_max: float = 0.60
## Symmetric spread around the day roll, per wave, clamped back into the band —
## so one commute is a crawler then a wall you barely notice, not a flat grind.
@export var drive_wave_speed_jitter: float = 0.25
## Symmetric spread around the wave's speed, per car. Small and load-bearing:
## this is what makes a fully blocked wall SHEAR APART as it rolls down the
## route instead of pinning the dog to the horizon. Do not set it to zero.
@export var drive_car_speed_jitter: float = 0.12
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


## The morning's game-minute budget, derived. game.gd builds every DayClock
## from this; nothing stores it.
func morning_budget() -> float:
	return maxf(work_start_minutes - morning_start_minutes, 0.0)
