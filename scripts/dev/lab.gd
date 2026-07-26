extends Control

## Dev-only playtest lab: launches any single minigame in isolation with a
## chosen energy preset (+ habit toggle for freetime, + bedtime override for
## sleep), then shows the raw finished(result) dict verbatim. This is a dev
## diagnostic surface, not player-facing UI — the "energy is never shown as a
## number" rule does NOT bind here; presets and result values are shown raw
## on purpose so feel can be judged per activity.
##
## Minigame launches never touch GameState, StatEffects, or DaySchedule. The
## day presets below are a different class: they construct a fresh GameState
## to seed a full res://scenes/main.tscn run, so the whole day plays out from
## an engineered morning. Still never mutates shared/global state — there are
## no autoloads, and every preset gets its own throwaway GameState instance.

const SCENES := {
	"wake": preload("res://scenes/minigames/wake.tscn"),
	"brush": preload("res://scenes/minigames/brush.tscn"),
	"typing": preload("res://scenes/minigames/typing.tscn"),
	"listening": preload("res://scenes/minigames/listening.tscn"),
	"dinner": preload("res://scenes/minigames/dinner.tscn"),
	"freetime": preload("res://scenes/minigames/freetime.tscn"),
	"sleep": preload("res://scenes/minigames/sleep.tscn"),
}
# "okay" sits at 65, not the midpoint: 60-79 is tier 3 — the lowest band that
# still renders coworker text (and where speech runs fastest) — so the mid
# preset must land inside it or the listening speed scaling is untestable here.
const ENERGY_PRESETS := {"fresh": 90.0, "okay": 65.0, "wrecked": 20.0}
const BEDTIMES := ["early", "mid", "late"]

## Full-day presets: each seeds a fresh GameState and rides res://scenes/main.tscn
## from an engineered morning instead of hosting a single minigame.
const DAY_SCENE := preload("res://scenes/main.tscn")

var cfg: BalanceConfig = preload("res://resources/balance_default.tres")
var _current_activity: String = ""

@onready var _menu: VBoxContainer = %Menu
@onready var _activities: VBoxContainer = %Activities
@onready var _day_presets: VBoxContainer = %DayPresets
@onready var _energy_row: HBoxContainer = %EnergyRow
@onready var _habit_check: CheckBox = %HabitCheck
@onready var _bedtime_option: OptionButton = %BedtimeOption
@onready var _host: Control = %Host
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
	for bedtime in BEDTIMES:
		_bedtime_option.add_item(bedtime.capitalize())
	_bedtime_option.selected = BEDTIMES.find("mid")
	_result_panel.visible = false


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
	_host.add_child(node)


## Pure preset -> GameState mapping, kept separate from _launch_day so it can
## be unit-tested on its own without touching the scene tree.
func _preset_state(preset: String) -> GameState:
	var state := GameState.new()
	match preset:
		"flush":
			# One paid day crosses the retirement target -> retire_offer
			# appears at the next morning's build.
			state.wallet.savings = cfg.retirement_target - cfg.salaries[state.rank]
		"on_warning":
			state.warning = true
			state.performance = 0.2
		"wreck_morning":
			# Below sick_energy_threshold -> DaySchedule.build returns ["sick"].
			state.energy = 8.0
		"coffee_morning":
			state.wallet.savings = 20
			state.energy = 45.0
	return state


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
	match activity:
		"wake":
			return Difficulty.wake_params(energy, cfg)
		"brush":
			return Difficulty.brush_params(energy, cfg)
		"typing":
			return Difficulty.typing_params(energy, cfg)
		"listening":
			return Difficulty.listening_params(energy, cfg)
		"freetime":
			return Difficulty.temptation_params(energy, cfg, _habit_check.button_pressed)
		"dinner":
			return {"text_speed": cfg.typewriter_chars_per_sec}
		"sleep":
			return {
				"bedtime": BEDTIMES[_bedtime_option.selected],
				"text_speed": cfg.typewriter_chars_per_sec,
				"hold": cfg.sleep_hold_time,
			}
		_:
			return {}


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
