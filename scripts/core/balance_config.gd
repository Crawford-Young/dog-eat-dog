class_name BalanceConfig
extends Resource

## All wave-1 tunables. Feel iteration edits this (or balance_default.tres), not code.

@export var wake_mash_base: int = 12
@export var wake_mash_max: int = 40
@export var wake_decay_max: float = 6.0
@export var wake_par_time: float = 4.0

@export var brush_strokes_base: int = 6
@export var brush_strokes_max: int = 16
@export var brush_amplitude: float = 40.0
@export var brush_par_time: float = 5.0

@export var typing_error_tolerance_base: float = 0.30
@export var typing_error_tolerance_min: float = 0.05

@export var listening_window_base: float = 1.2
@export var listening_window_min: float = 0.45

@export var temptation_pull_base: float = 60.0
@export var temptation_pull_max: float = 420.0
@export var temptation_habit_bonus: float = 120.0

@export var work_drain: float = 12.0
@export var selfcare_restore: float = 6.0
@export var lunch_restore: float = 3.0
@export var dinner_cook_energy: float = 10.0
@export var dinner_takeout_energy: float = 3.0
@export var late_game_drain: float = 15.0
@export var skip_brush_penalty: float = 10.0
@export var sleep_energy: Dictionary = {"early": 90.0, "mid": 65.0, "late": 35.0}
