extends Control

## Game flow: build the morning's schedule, host one minigame at a time, close
## the day (pay, rank ladder), show a summary, loop. Energy is shown ONLY as the
## dog's state text — never a number (spec rule). Money is fine to show: the
## poster line is the retirement counter.

const SCENES := {
	"wake": preload("res://scenes/minigames/wake.tscn"),
	"brush": preload("res://scenes/minigames/brush.tscn"),
	"coffee": preload("res://scenes/minigames/coffee.tscn"),
	"work_am": preload("res://scenes/minigames/typing.tscn"),
	"lunch": preload("res://scenes/minigames/listening.tscn"),
	"work_pm": preload("res://scenes/minigames/typing.tscn"),
	"dinner": preload("res://scenes/minigames/dinner.tscn"),
	"freetime": preload("res://scenes/minigames/freetime.tscn"),
	"sleep": preload("res://scenes/minigames/sleep.tscn"),
	"retire_offer": preload("res://scenes/minigames/retire_offer.tscn"),
	"warning": preload("res://scenes/minigames/warning.tscn"),
	"sick": preload("res://scenes/minigames/sick.tscn"),
}
const DOG_STATES := ["a husk", "running on fumes", "kinda tired", "doing okay", "bright-eyed"]
const SLOT_LABELS := {
	"wake": "morning",
	"brush": "bathroom",
	"coffee": "coffee cart",
	"work_am": "work, morning",
	"lunch": "lunch",
	"work_pm": "work, afternoon",
	"dinner": "dinner",
	"freetime": "free time",
	"sleep": "bed",
	"retire_offer": "morning",
	"warning": "the office",
	"sick": "in bed",
}
const WARNING_COPY := "the cat calls you in. \"you seem tired lately. we just want you at your best.\" the door clicks shut very softly."
const EVENT_COPY := {
	"promoted": "new desk. same dog, better title.",
	"demoted": "they moved your things down a floor. gently.",
	"warned": "the cat glanced at your screen today. twice.",
	"warning_cleared": "the cat nods at you in the hallway. crisis averted.",
	"sick_no_pay": "no pay today. the blanket understood.",
}
const SENIOR_TEASE := "word is, senior roles go to dogs the office knows. maybe eat lunch with people more."
## Telegraphed a night early so a sick morning is never a surprise.
const WOBBLE_COPY := "the dog can barely lift its head. tomorrow might not happen."

var state := GameState.new()
var schedule := DaySchedule.new()
var cfg: BalanceConfig = preload("res://resources/balance_default.tres")

@onready var _host: Control = %MinigameHost
@onready var _summary: Panel = %Summary
@onready var _summary_label: Label = %SummaryLabel
@onready var _day_label: Label = %DayLabel
@onready var _dog_label: Label = %DogLabel
@onready var _poster_label: Label = %PosterLabel
@onready var _ending: Panel = %Ending
@onready var _ending_label: Label = %EndingLabel
@onready var _summary_typer := TypewriterLabel.new()
@onready var _ending_typer := TypewriterLabel.new()


func _ready() -> void:
	add_child(_summary_typer)
	_summary_typer.bind(_summary_label)
	add_child(_ending_typer)
	_ending_typer.bind(_ending_label)
	_summary.visible = false
	_ending.visible = false
	schedule.set_slots(DaySchedule.build(state, cfg))
	_start_slot()


func _start_slot() -> void:
	var slot := schedule.current()
	_day_label.text = "day %d — %s" % [state.day, SLOT_LABELS[slot]]
	_dog_label.text = "dog is %s" % DOG_STATES[Difficulty.clarity_tier(state.energy)]
	_poster_label.text = "%s · savings %d / %d" % [
		RankLadder.RANK_NAMES[state.rank],
		state.wallet.savings,
		cfg.retirement_target,
	]
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
		"work_am":
			return Difficulty.typing_params(
				state.energy, cfg, cfg.coffee_buff_tiers if state.coffee_today else 0
			)
		"work_pm":
			return Difficulty.typing_params(state.energy, cfg)
		"lunch":
			return Difficulty.listening_params(state.energy, cfg)
		"freetime":
			return Difficulty.temptation_params(state.energy, cfg, state.played_late)
		"dinner":
			return {
				"text_speed": cfg.typewriter_chars_per_sec,
				"disabled_choices":
					[] if state.wallet.savings >= cfg.takeout_price else ["takeout"],
			}
		"sleep":
			return {
				"bedtime": state.bedtime,
				"text_speed": cfg.typewriter_chars_per_sec,
				"hold": cfg.sleep_hold_time,
			}
		"coffee":
			return {
				"text_speed": cfg.typewriter_chars_per_sec,
				"disabled_choices":
					[] if state.wallet.savings >= cfg.coffee_price else ["buy"],
			}
		"retire_offer":
			return {"text_speed": cfg.typewriter_chars_per_sec}
		"warning":
			return {
				"text": WARNING_COPY,
				"text_speed": cfg.typewriter_chars_per_sec,
				"hold": cfg.sleep_hold_time,
			}
		"sick":
			return {
				"burrow_target": cfg.sick_burrow_target,
				"burrow_time": cfg.sick_burrow_time,
				"text_speed": cfg.typewriter_chars_per_sec,
				"hold": cfg.sleep_hold_time,
			}
		_:
			return {}


func _on_finished(result: Dictionary, slot: String, node: Node) -> void:
	node.queue_free()
	if slot == "retire_offer" and result.get("choice") == "retire":
		_show_ending()
		return
	StatEffects.apply(slot, result, state, cfg)
	if schedule.advance():
		_start_slot()
	else:
		_show_summary()


## Closes the day exactly once — close_day pays the salary and runs the rank
## ladder, so it must never be called twice for one day.
func _show_summary() -> void:
	var report := StatEffects.close_day(state, cfg)
	var events: Array = report.events
	var lines: Array[String] = ["day %d done" % state.day]
	if events.has("sick_no_pay"):
		lines.append(EVENT_COPY["sick_no_pay"])
	else:
		lines.append("paid %d bone-bucks" % report.pay)
	lines.append("work felt: %s" % _performance_word())
	lines.append("dog is %s" % DOG_STATES[Difficulty.clarity_tier(state.energy)])
	for event in events:
		if event != "sick_no_pay" and EVENT_COPY.has(event):
			lines.append(EVENT_COPY[event])
	if events.has("promoted") and state.rank == RankLadder.MAX_RANK:
		lines.append(SENIOR_TEASE)
	if Difficulty.is_sick_morning(_tomorrow_energy(), cfg):
		lines.append(WOBBLE_COPY)
	_summary.visible = true
	_summary_typer.play("\n".join(lines), cfg.typewriter_chars_per_sec)


## READ-ONLY projection of tomorrow's waking energy, so the summary can warn
## about a sick morning the night before. Mirrors GameState.start_next_day's
## formula exactly — any drift between the two is a bug.
func _tomorrow_energy() -> float:
	if state.sick_today:
		return clampf(state.sick_recovery, 0.0, 100.0)
	var leftover: float = state.energy
	var energy: float = cfg.energy_carry_weight * leftover \
			+ (1.0 - cfg.energy_carry_weight) * cfg.sleep_energy[state.bedtime]
	if not state.brushed_today:
		energy -= cfg.skip_brush_penalty
	return clampf(energy, 0.0, 100.0)


func _show_ending() -> void:
	for child in _host.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
	_ending.visible = true
	_ending_typer.play(
		"the poster comes off the wall.\n%d days. %s, retired.\nthe old dog naps in the sun." % [
			state.day,
			RankLadder.RANK_NAMES[state.rank],
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
	schedule.set_slots(DaySchedule.build(state, cfg))
	_start_slot()


func _on_restart_pressed() -> void:
	# Stop the ending mid-line — otherwise it keeps typing into a hidden label.
	_ending_typer.skip()
	_ending_label.text = ""
	state = GameState.new()
	schedule.set_slots(DaySchedule.build(state, cfg))
	_ending.visible = false
	_start_slot()
