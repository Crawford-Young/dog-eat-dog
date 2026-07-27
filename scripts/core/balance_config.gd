class_name BalanceConfig
extends Resource

## All wave-1 tunables. Feel iteration edits this (or balance_default.tres), not code.

@export var wake_mash_base: int = 12
@export var wake_mash_max: int = 40
@export var wake_decay_max: float = 6.0
# D1 (deferred to wave 3): par times pace a score nothing consumes yet — see
# the note at the top of stat_effects.gd. Intentionally inert through wave 2.
@export var wake_par_time: float = 4.0

@export var brush_strokes_base: int = 6
@export var brush_strokes_max: int = 16
@export var brush_amplitude: float = 40.0
# D1 (deferred to wave 3): inert for the same reason as wake_par_time.
@export var brush_par_time: float = 5.0

@export var typing_error_tolerance_base: float = 0.30
@export var typing_error_tolerance_min: float = 0.05
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
