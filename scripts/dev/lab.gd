extends Control

## Dev-only playtest lab: launches any single minigame in isolation with a
## chosen energy preset (+ sleep-debt preset for freetime and sleep, +
## bedtime override for sleep), then shows the raw finished(result) dict
## verbatim. This is a dev diagnostic surface, not player-facing UI — the
## "energy is never shown as a number" rule does NOT bind here; presets and
## result values are shown raw on purpose so feel can be judged per activity.
##
## Minigame launches never touch GameState, StatEffects, or DaySchedule. The
## day presets below are a different class: they construct a fresh GameState
## to seed a full res://scenes/main.tscn run, so the whole day plays out from
## an engineered morning. Still never mutates shared/global state — there are
## no autoloads, and every preset gets its own throwaway GameState instance.

const SCENES := {
	"wake": preload("res://scenes/minigames/wake.tscn"),
	"brush": preload("res://scenes/minigames/brush.tscn"),
	"shower": preload("res://scenes/minigames/shower.tscn"),
	"clothes": preload("res://scenes/minigames/clothes.tscn"),
	"breakfast": preload("res://scenes/minigames/breakfast.tscn"),
	"drive": preload("res://scenes/minigames/drive.tscn"),
	"drive_home": preload("res://scenes/minigames/drive.tscn"),
	"cooking": preload("res://scenes/minigames/cooking.tscn"),
	"coffee": preload("res://scenes/minigames/coffee.tscn"),
	"work_am": preload("res://scenes/minigames/burst.tscn"),
	"work_pm": preload("res://scenes/minigames/triage.tscn"),
	"listening": preload("res://scenes/minigames/listening.tscn"),
	"dinner": preload("res://scenes/minigames/dinner.tscn"),
	"freetime": preload("res://scenes/minigames/freetime.tscn"),
	"sleep": preload("res://scenes/minigames/sleep.tscn"),
}
# "okay" sits at 65, not the midpoint: 60-79 is tier 3 — the lowest band that
# still renders coworker text (and where speech runs fastest) — so the mid
# preset must land inside it or the listening speed scaling is untestable here.
const ENERGY_PRESETS := {"fresh": 90.0, "okay": 65.0, "wrecked": 20.0}
# Fractions of sleep_debt_cap_minutes, so the presets follow any retune of the cap.
const DEBT_PRESETS := {"square": 0.0, "short": 0.5, "fumes": 1.0}

## Full-day presets: each seeds a fresh GameState and rides res://scenes/main.tscn
## from an engineered morning instead of hosting a single minigame.
const DAY_SCENE := preload("res://scenes/main.tscn")

var cfg: BalanceConfig = preload("res://resources/balance_default.tres")
var _current_activity: String = ""
## How far through the day the ramped games (breakfast, the cup, work AM and
## PM) play, 0-1; built in _ready beside the rank row. Zero is the start of the
## day, where every ramp multiplies by 1.
var _progress_slider: HSlider

@onready var _menu: ScrollContainer = %Menu
@onready var _activities: VBoxContainer = %Activities
@onready var _day_presets: VBoxContainer = %DayPresets
@onready var _energy_row: HBoxContainer = %EnergyRow
@onready var _debt_option: OptionButton = %DebtOption
@onready var _bedtime_option: OptionButton = %BedtimeOption
@onready var _rank_option: OptionButton = %RankOption
@onready var _host: Control = %Host
@onready var _day_readout: Label = %DayReadout
@onready var _result_panel: Panel = %ResultPanel
@onready var _result_label: Label = %ResultLabel
@onready var _replay_button: Button = %ReplayButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	for child in _activities.get_children():
		if child is Button:
			child.pressed.connect(_on_activity_pressed.bind(String(child.name).to_lower()))
	for child in _day_presets.get_children():
		if child is Button:
			child.pressed.connect(_on_day_preset_pressed.bind(String(child.name).to_lower()))
	_replay_button.pressed.connect(_on_replay_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	for bedtime in BalanceConfig.BANDS:
		_bedtime_option.add_item(bedtime.capitalize())
	_bedtime_option.selected = BalanceConfig.BANDS.find("mid")
	for preset in DEBT_PRESETS:
		_debt_option.add_item(preset.capitalize())
	_debt_option.selected = 0
	for rank_name in RankLadder.RANK_NAMES:
		_rank_option.add_item(rank_name.capitalize())
	_rank_option.selected = 0
	_add_progress_row()
	_result_panel.visible = false


## A "day progress" row straight after the rank row: a 0-1 slider and its raw
## value, so every ramped game can be felt anywhere on the day's escalation.
func _add_progress_row() -> void:
	var rank_row := _rank_option.get_parent()
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "day progress (breakfast, coffee, work)"
	_progress_slider = HSlider.new()
	_progress_slider.min_value = 0.0
	_progress_slider.max_value = 1.0
	_progress_slider.step = 0.05
	_progress_slider.custom_minimum_size.x = 200.0
	var readout := Label.new()
	readout.text = "0.00"
	_progress_slider.value_changed.connect(func(v: float) -> void: readout.text = "%.2f" % v)
	row.add_child(label)
	row.add_child(_progress_slider)
	row.add_child(readout)
	rank_row.get_parent().add_child(row)
	rank_row.get_parent().move_child(row, rank_row.get_index() + 1)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or _menu.visible:
		return
	if not _host.get_children().is_empty():
		_cancel_run()
	else:
		_on_back_pressed()


func _on_activity_pressed(activity: String) -> void:
	_launch(activity)


func _on_day_preset_pressed(preset: String) -> void:
	_launch_day(preset)


## No finished signal to wire up — the day scene loops morning after morning
## and never emits one. Exit is the existing ESC handler (_cancel_run), which
## already queue_frees whatever is hosted and reshows the menu.
func _launch_day(preset: String) -> void:
	_menu.visible = false
	_result_panel.visible = false
	var node := DAY_SCENE.instantiate()
	node.state = _preset_state(preset)
	node.cfg = _preset_cfg(preset)
	node.start_from_slot = _preset_start_slot(preset)
	_host.add_child(node)


## T11 round-1 instrument: a live readout of the evening clock while a day
## preset rides, so the measurement evenings can be read off the screen
## instead of divined. Raw numbers are fine here — the lab's own header rule
## says the energy-never-a-number rule does not bind on this dev surface.
## READS the hosted scene only — never spends, never mutates.
func _update_day_readout() -> void:
	if _host.get_child_count() == 0:
		_day_readout.visible = false
		return
	# Untyped on purpose: a single-minigame launch hosts a Minigame, which has
	# no `clock` — the "clock" in child guard needs child treated as Variant,
	# not statically typed Node, or the dynamic member reads below would not
	# compile against a scene that legitimately doesn't have them.
	var child = _host.get_child(_host.get_child_count() - 1)
	if not ("clock" in child):
		_day_readout.visible = false
		return
	_day_readout.visible = true
	var clock: DayClock = child.clock
	var text: String
	if not child._evening:
		text = "morning · %.0f elapsed" % clock.elapsed
	else:
		text = "evening · %.0f elapsed · %s · bed-if-now %s" % [
			clock.elapsed,
			clock.band_name(),
			DayClock.format_minutes(cfg.evening_start_minutes + int(clock.elapsed)),
		]
	if child._bed_minute > 0.0:
		# Freetime already ended and stamped the real bed minute — freeze the
		# measurement on screen through the sleep beat rather than let
		# "bed-if-now" keep drifting on a clock nothing spends anymore.
		text += " · FINAL bed %s (elapsed %.0f)" % [
			DayClock.format_minutes(int(child._bed_minute)), clock.elapsed,
		]
	_day_readout.text = text


func _process(_delta: float) -> void:
	_update_day_readout()


## Pure preset -> GameState mapping, kept separate from _launch_day so it can
## be unit-tested on its own without touching the scene tree.
func _preset_state(preset: String) -> GameState:
	var state := GameState.new()
	match preset:
		"flush":
			# QA ruling (issue #8): close_day nets the margin over living
			# costs, not the raw salary — seed one margin under target so a
			# single paid day still crosses it -> retire_offer appears at the
			# next morning's build.
			state.wallet.savings = cfg.retirement_target \
					- (cfg.salaries[state.rank] - cfg.daily_living_cost)
		"on_warning":
			state.warning = true
			state.performance = 0.2
		"wreck_morning":
			# Below sick_energy_threshold -> DaySchedule.build returns ["sick"].
			state.energy = 8.0
		"coffee_morning":
			state.wallet.savings = 20
			state.energy = 45.0
		"in_debt":
			# 60% of the debt cap: the ceiling is down but not yet under
			# the sick threshold — one more late night brings the wobble,
			# a second tips it sick. This is the only way to playtest the
			# chronic case without playing a real week.
			state.ledger.debt_minutes = cfg.sleep_debt_cap_minutes * 0.6
			state.refresh_ceiling(cfg)
		"post_work":
			# An ordinary after-work energy — the point of this preset is
			# measuring an ORDINARY evening, not an engineered one.
			state.energy = 55.0
	return state


## Pure preset -> BalanceConfig mapping, kept separate from _launch_day so it
## can be unit-tested without touching the scene tree (same reasoning as
## _preset_state above). cfg is a preloaded SHARED .tres resource — mutating
## it in place would poison every other launch this session, and worse, the
## resource cache itself. duplicate() is load-bearing.
func _preset_cfg(preset: String) -> BalanceConfig:
	if preset == "late_morning":
		var late_cfg: BalanceConfig = cfg.duplicate()
		late_cfg.work_start_minutes = cfg.morning_start_minutes + 20
		return late_cfg
	return cfg


## Pure preset -> fast-forward slot mapping. "" means start from the morning.
func _preset_start_slot(preset: String) -> String:
	return "drive_home" if preset == "post_work" else ""


func _launch(activity: String) -> void:
	_current_activity = activity
	_menu.visible = false
	_result_panel.visible = false
	var node: Minigame = SCENES[activity].instantiate()
	_host.add_child(node)
	node.finished.connect(_on_finished.bind(node), CONNECT_ONE_SHOT)
	node.setup(_params_for(activity))


func _params_for(activity: String) -> Dictionary:
	var energy := _selected_energy()
	var progress := _progress_slider.value
	match activity:
		"wake":
			return Difficulty.wake_params(energy, cfg)
		"brush":
			return Difficulty.brush_params(energy, cfg)
		"shower":
			return Difficulty.shower_params(energy, cfg)
		"clothes":
			return Difficulty.dress_params(energy, cfg)
		"breakfast":
			return Difficulty.breakfast_params(energy, cfg, progress)
		"drive":
			return Difficulty.drive_params(energy, cfg)
		"drive_home":
			return Difficulty.drive_home_params(energy, cfg)
		"cooking":
			return Difficulty.cooking_params(energy, cfg)
		"coffee":
			var cup := Difficulty.cup_params(energy, cfg, progress)
			cup["can_afford"] = true
			return cup
		"work_am":
			return Difficulty.burst_params(energy, cfg, 0, _rank_option.selected, progress)
		"work_pm":
			return Difficulty.triage_params(energy, cfg, 0, _rank_option.selected, progress)
		"listening":
			return Difficulty.listening_params(energy, cfg)
		"freetime", "sleep":
			return _params_for_debt(activity, _selected_debt())
		"dinner":
			var walk := Difficulty.dinner_params(energy, cfg)
			walk["can_afford"] = true
			return walk
		_:
			return {}


## Pure debt -> params mapping for the two activities a sleep debt changes,
## kept out of _params_for so it can be unit-tested without a scene tree.
func _params_for_debt(activity: String, debt_minutes: float) -> Dictionary:
	if activity == "freetime":
		return Difficulty.temptation_params(_selected_energy(), cfg, debt_minutes)
	var ledger := SleepLedger.new()
	ledger.debt_minutes = debt_minutes
	var band: String = BalanceConfig.BANDS[_bedtime_option.selected]
	var bed_minute: int = (
		cfg.bed_early_line_minutes if band == "early"
		else cfg.bed_mid_line_minutes if band == "mid"
		else cfg.bed_mid_line_minutes + 30
	)
	var slept := float(cfg.morning_start_minutes) + 1440.0 - float(bed_minute)
	return {
		"bedtime": band,
		"bed_clock": DayClock.format_minutes(bed_minute),
		"ledger": ledger.ledger_text(slept, cfg),
		"text_speed": cfg.typewriter_chars_per_sec,
		"hold": cfg.sleep_hold_time,
	}


func _selected_debt() -> float:
	return DEBT_PRESETS.values()[maxi(_debt_option.selected, 0)] * cfg.sleep_debt_cap_minutes


func _selected_energy() -> float:
	for button in _energy_row.get_children():
		if button is Button and button.button_pressed:
			return ENERGY_PRESETS.get(String(button.name).to_lower(), 55.0)
	return 55.0


func _on_finished(result: Dictionary, node: Node) -> void:
	node.queue_free()
	_show_result(result)


func _show_result(result: Dictionary) -> void:
	var lines := ["activity: %s" % _current_activity]
	for key in result.keys():
		lines.append("%s: %s" % [key, result[key]])
	_result_label.text = "\n".join(lines)
	_result_panel.visible = true


func _cancel_run() -> void:
	for child in _host.get_children():
		child.queue_free()
	_result_panel.visible = false
	_menu.visible = true


func _on_replay_pressed() -> void:
	_result_panel.visible = false
	_launch(_current_activity)


func _on_back_pressed() -> void:
	_result_panel.visible = false
	_menu.visible = true
