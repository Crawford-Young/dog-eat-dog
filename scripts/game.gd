extends Control

## Wave-1 game flow: run the day schedule, host one minigame at a time,
## show a day summary, loop to the next day. Energy is shown ONLY as the
## dog's state text — never a number (spec rule).

const SCENES := {
	"wake": preload("res://scenes/minigames/wake.tscn"),
	"brush": preload("res://scenes/minigames/brush.tscn"),
	"work_am": preload("res://scenes/minigames/typing.tscn"),
	"lunch": preload("res://scenes/minigames/listening.tscn"),
	"work_pm": preload("res://scenes/minigames/typing.tscn"),
	"dinner": preload("res://scenes/minigames/dinner.tscn"),
	"freetime": preload("res://scenes/minigames/freetime.tscn"),
	"sleep": preload("res://scenes/minigames/sleep.tscn"),
}
const DOG_STATES := ["a husk", "running on fumes", "kinda tired", "doing okay", "bright-eyed"]
const SLOT_LABELS := {
	"wake": "morning",
	"brush": "bathroom",
	"work_am": "work, morning",
	"lunch": "lunch",
	"work_pm": "work, afternoon",
	"dinner": "dinner",
	"freetime": "free time",
	"sleep": "bed",
}

var state := GameState.new()
var schedule := DaySchedule.new()
var cfg: BalanceConfig = preload("res://resources/balance_default.tres")

@onready var _host: Control = %MinigameHost
@onready var _summary: Panel = %Summary
@onready var _summary_label: Label = %SummaryLabel
@onready var _day_label: Label = %DayLabel
@onready var _dog_label: Label = %DogLabel
@onready var _summary_typer := TypewriterLabel.new()


func _ready() -> void:
	add_child(_summary_typer)
	_summary_typer.bind(_summary_label)
	_summary.visible = false
	_start_slot()


func _start_slot() -> void:
	var slot := schedule.current()
	_day_label.text = "day %d — %s" % [state.day, SLOT_LABELS[slot]]
	_dog_label.text = "dog is %s" % DOG_STATES[Difficulty.clarity_tier(state.energy)]
	var node: Minigame = SCENES[slot].instantiate()
	_host.add_child(node)
	node.finished.connect(_on_finished.bind(slot, node), CONNECT_ONE_SHOT)
	node.setup(_params_for(slot))


func _params_for(slot: String) -> Dictionary:
	match slot:
		"wake":
			return Difficulty.wake_params(state.energy, cfg)
		"brush":
			return Difficulty.brush_params(state.energy, cfg)
		"work_am", "work_pm":
			return Difficulty.typing_params(state.energy, cfg)
		"lunch":
			return Difficulty.listening_params(state.energy, cfg)
		"freetime":
			return Difficulty.temptation_params(state.energy, cfg, state.played_late)
		"dinner":
			return {"text_speed": cfg.typewriter_chars_per_sec}
		"sleep":
			return {
				"bedtime": state.bedtime,
				"text_speed": cfg.typewriter_chars_per_sec,
				"hold": cfg.sleep_hold_time,
			}
		_:
			return {}


func _on_finished(result: Dictionary, slot: String, node: Node) -> void:
	node.queue_free()
	StatEffects.apply(slot, result, state, cfg)
	if schedule.advance():
		_start_slot()
	else:
		_show_summary()


func _show_summary() -> void:
	_summary.visible = true
	_summary_typer.play(
		"day %d done\nwork felt: %s\ndog is %s" % [
			state.day,
			_performance_word(),
			DOG_STATES[Difficulty.clarity_tier(state.energy)],
		],
		cfg.typewriter_chars_per_sec,
	)


func _performance_word() -> String:
	if state.performance >= 0.75:
		return "genuinely great"
	if state.performance >= 0.5:
		return "solid"
	if state.performance >= 0.3:
		return "shaky"
	return "like a fog"


func _on_next_day_pressed() -> void:
	_summary.visible = false
	state.start_next_day(cfg)
	schedule.reset()
	_start_slot()
