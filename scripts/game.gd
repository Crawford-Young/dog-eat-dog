extends Control

## Game flow: build the morning's schedule, host one minigame at a time, close
## the day (pay, rank ladder), show a summary, loop. Energy is shown ONLY as the
## dog's state text — never a number (spec rule). Money is fine to show: the
## poster line, top-right, is the retirement counter and the run's score.
## Each game ends on a HIT/MISS/SKIP stamp that holds the next slot back, and
## the day's verdicts line up as a strip under the day label (issue #17).
##
## Wave 3a: this script is the ONLY spender of the morning DayClock — it turns
## real seconds into game-minutes in _process and charges the fixed skip costs
## in _on_finished. No minigame ever touches the clock.

const SCENES := {
	"wake": preload("res://scenes/minigames/wake.tscn"),
	"brush": preload("res://scenes/minigames/brush.tscn"),
	"shower": preload("res://scenes/minigames/shower.tscn"),
	"clothes": preload("res://scenes/minigames/clothes.tscn"),
	"breakfast": preload("res://scenes/minigames/breakfast.tscn"),
	"drive": preload("res://scenes/minigames/drive.tscn"),
	"coffee": preload("res://scenes/minigames/coffee.tscn"),
	"work_am": preload("res://scenes/minigames/burst.tscn"),
	"lunch": preload("res://scenes/minigames/listening.tscn"),
	"work_pm": preload("res://scenes/minigames/triage.tscn"),
	"drive_home": preload("res://scenes/minigames/drive.tscn"),
	"dinner": preload("res://scenes/minigames/dinner.tscn"),
	"cooking": preload("res://scenes/minigames/cooking.tscn"),
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
	"shower": "bathroom",
	"clothes": "bedroom",
	"breakfast": "kitchen",
	"drive": "the commute",
	"coffee": "coffee cart",
	"work_am": "work, morning",
	"lunch": "lunch",
	"work_pm": "work, afternoon",
	"drive_home": "the drive home",
	"dinner": "dinner",
	"cooking": "the kitchen",
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
const LATE_COPY := "you slink in at %s. the cat checks the clock. says nothing. writes nothing down. probably."
const STINK_COPY := "the stink kept its own desk chair today"
## The slots the morning clock runs during — everything from waking up to
## parking the car. Once the dog is at the office, time stops mattering.
const MORNING_TIMED := ["wake", "brush", "shower", "clothes", "breakfast", "drive"]
## The slots the evening clock runs during. Sleep is NOT one of them: the bed
## minute is settled the moment freetime ends, so the beat is a readout.
const EVENING_TIMED := ["drive_home", "dinner", "cooking", "freetime"]
## Chores that can be ducked out of. Skipping buys no time back — it costs a
## flat penalty, so ducking out is a stat trade, never a clock trade.
const SKIP_SLOTS := ["brush", "shower", "breakfast"]
const ZONE_COLORS := {
	"calm": Color(1.0, 1.0, 1.0),
	"amber": Color(1.0, 0.8, 0.3),
	"red": Color(1.0, 0.35, 0.3),
}
## A skip is neither a win nor a loss, so it stamps muted (issue #17 ruling).
const STAMP_COLORS := {
	Verdict.HIT: Color(0.45, 0.9, 0.45),
	Verdict.MISS: Color(1.0, 0.35, 0.3),
	Verdict.SKIP: Color(0.8, 0.8, 0.8, 0.55),
}

var state := GameState.new()
var schedule := DaySchedule.new()
var cfg: BalanceConfig = preload("res://resources/balance_default.tres")
var clock: DayClock
var _clock_running := false
var _evening := false
## Dev/lab-only fast-forward — the day is still built by DaySchedule.build in
## full (the schedule invariant holds); this only skips INTO it, never
## reshapes it. "" starts from the morning as normal.
var start_from_slot: String = ""
## The run's randomness. Unseeded by default; assign RngSource.seeded(n) before
## _ready (like start_from_slot) to reproduce a whole run.
var rng := RngSource.new()
## The evening's till, mirrored off the freetime stamp so the sleep beat can
## still read it after the slot boundary. Seeded to bed_mid_line_minutes (also
## setup()'s own bed_clock default) in _ready and at each day reset — not 0.0 — because a
## schedule that reaches "sleep" without passing through freetime (the lab,
## T9) would otherwise print "0:00" and hand the ledger a 31-hour night.
var _bed_minute := 0.0
## The minigame (or beat) currently up — the timer bar reads its countdown.
var _hosted: Minigame
## The SCENES key _hosted was mounted under, so the timer bar can tell the
## morning commute from the drive home (both are drive.tscn).
var _hosted_key := ""
## Today's verdicts in play order, for the strip.
var _verdicts: Array[String] = []
## What runs once the stamp's hold is over; invalid while nothing is held.
var _after_stamp := Callable()
var _stamp_left := 0.0

@onready var _host: Control = %MinigameHost
@onready var _summary: Panel = %Summary
@onready var _summary_label: Label = %SummaryLabel
@onready var _day_label: Label = %DayLabel
@onready var _dog_label: Label = %DogLabel
@onready var _rank_label: Label = %RankLabel
@onready var _poster_label: Label = %PosterLabel
@onready var _strip_label: Label = %StripLabel
@onready var _stamp_label: Label = %StampLabel
@onready var _ending: Panel = %Ending
@onready var _ending_label: Label = %EndingLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _timer_bar: Range = %TimerBar
@onready var _summary_typer := TypewriterLabel.new()
@onready var _ending_typer := TypewriterLabel.new()


func _ready() -> void:
	add_child(_summary_typer)
	_summary_typer.bind(_summary_label)
	add_child(_ending_typer)
	_ending_typer.bind(_ending_label)
	_summary.visible = false
	_ending.visible = false
	for label in [_poster_label, _strip_label]:
		PropArt.with_emoji_fallback(label)
	clock = DayClock.new(cfg.morning_budget())
	_bed_minute = float(cfg.bed_mid_line_minutes)
	schedule.set_slots(DaySchedule.build(state, cfg))
	if start_from_slot != "":
		while schedule.current() != start_from_slot and schedule.advance():
			pass
	_start_slot()


## The HUD persists across slots; only the clock label hides, when no timed
## (morning or evening) slot is up. The clock is the only thing that converts
## real seconds into game-minutes.
func _process(delta: float) -> void:
	_update_timer_bar()
	_clock_label.visible = _clock_running
	# The stamp is presentation, like the gag: no clock is spent while it
	# holds, nor on the frame it lets the next slot in.
	if _after_stamp.is_valid():
		_tick_stamp(delta)
		return
	if not _clock_running:
		return
	# A lost game's gag is presentation; the loss cost is the penalty, so the
	# clock holds still while it plays (user revision, issue #17).
	if not _hosted_is_gagging():
		clock.spend(delta * cfg.clock_scale)
	_clock_label.text = _evening_hud() if _evening else "%s · in by %s" % [
		clock.clock_text(cfg.morning_start_minutes),
		DayClock.format_minutes(cfg.work_start_minutes),
	]
	_clock_label.add_theme_color_override(
		"font_color",
		ZONE_COLORS[clock.zone(cfg.clock_amber_fraction, cfg.clock_red_fraction)],
	)


## True while the hosted game is playing its loss gag.
func _hosted_is_gagging() -> bool:
	return is_instance_valid(_hosted) and not _hosted.is_queued_for_deletion() \
			and _hosted.is_gagging()


## The bottom-edge bar shows whatever _timer_bar_fraction picks, or hides.
func _update_timer_bar() -> void:
	var fraction := _timer_bar_fraction()
	_timer_bar.visible = fraction >= 0.0
	if _timer_bar.visible:
		_timer_bar.value = fraction


## The one place that decides what the timer bar reads: the hosted game's own
## countdown, as a 1 -> 0 fraction, or -1 for no bar (nothing hosted, or no
## countdown). The drives and free time have no countdown — the clock never
## fails a minigame — so their bar is the DayClock's time left: to 8:00 for the
## commute (so it starts part-drained), to home_by for the drive home, and to
## the 23:30 mid line for free time, since the evening budget is derived as
## exactly that span.
func _timer_bar_fraction() -> float:
	if not is_instance_valid(_hosted) or _hosted.is_queued_for_deletion():
		return -1.0
	if _hosted_key == "drive" or _hosted_key == "freetime":
		return _left_fraction(clock.budget)
	if _hosted_key == "drive_home":
		return _left_fraction(cfg.home_budget())
	if not _hosted.has_countdown():
		return -1.0
	return _hosted.time_fraction()


## The clock's minutes left to `span` (an offset from its start) as a 1 -> 0
## fraction, 0 for an empty span.
func _left_fraction(span: float) -> float:
	return clampf((span - clock.elapsed) / span, 0.0, 1.0) if span > 0.0 else 0.0


## The evening always states the best night still available and when it runs
## out — "21:47 · early until 22:00". In the last band there is nothing left to
## be late for, so the deadline half drops away.
func _evening_hud() -> String:
	var now := clock.clock_text(cfg.evening_start_minutes)
	var line := clock.next_line()
	if line < 0.0:
		return "%s · %s" % [now, clock.band_name()]
	return "%s · %s until %s" % [
		now,
		clock.band_name(),
		DayClock.format_minutes(cfg.evening_start_minutes + int(line)),
	]


func _start_slot() -> void:
	var slot := schedule.current()
	if slot in EVENING_TIMED and not _evening:
		# One fresh clock per block, built from the derived span — game.gd is
		# still the only place a DayClock is constructed or spent. Keyed on
		# ENTERING the block rather than on drive_home specifically: a lab
		# launch or any reshaped schedule that starts mid-evening would
		# otherwise run the evening against a morning-shaped, band-less clock,
		# and band_name() would return "" into the HUD.
		clock = DayClock.new(cfg.evening_budget())
		clock.set_bands(BalanceConfig.BANDS, cfg.bed_band_lines())
		_evening = true
	_clock_running = slot in MORNING_TIMED or slot in EVENING_TIMED
	_day_label.text = "day %d — %s" % [state.day, SLOT_LABELS[slot]]
	_dog_label.text = "dog is %s" % DOG_STATES[Difficulty.clarity_tier(state.energy)]
	_rank_label.text = RankLadder.RANK_NAMES[state.rank]
	_update_score()
	var node := _mount(slot)
	node.finished.connect(_on_finished.bind(slot, node), CONNECT_ONE_SHOT)
	if slot == "freetime":
		# String form: node is typed Minigame here, and game_played lives only
		# on the freetime subclass, so a typed `node.game_played.connect(...)`
		# would not resolve against the base class.
		node.connect("game_played", _on_game_played)
	node.setup(_hosted_params(slot))


func _update_score() -> void:
	_poster_label.text = "🦴 %d / %d to retire" % [state.wallet.savings, cfg.retirement_target]


## Instantiates `scene_key`'s scene into the host and makes it the hosted game.
func _mount(scene_key: String) -> Minigame:
	var node: Minigame = SCENES[scene_key].instantiate()
	_host.add_child(node)
	_hosted = node
	_hosted_key = scene_key
	return node


## A playable slot's params plus what game.gd hands every one of them.
func _hosted_params(slot: String) -> Dictionary:
	var params := _params_for(slot)
	# Every slot draws one, used or not, so stream position never depends on
	# which games happen to consume randomness.
	params["rng"] = rng.next_rng()
	params["fail_gag_seconds"] = cfg.fail_gag_seconds
	return params


func _params_for(slot: String) -> Dictionary:
	match slot:
		"wake":
			return Difficulty.wake_params(state.energy, cfg)
		"brush":
			return Difficulty.brush_params(state.energy, cfg)
		"shower":
			return Difficulty.shower_params(state.energy, cfg)
		"clothes":
			return Difficulty.dress_params(state.energy, cfg)
		"breakfast":
			return Difficulty.breakfast_params(state.energy, cfg, _day_progress())
		"drive":
			return Difficulty.drive_params(state.energy, cfg)
		"work_am":
			return Difficulty.burst_params(
				state.energy,
				cfg,
				cfg.coffee_buff_tiers if state.coffee_today else 0,
				state.rank,
				_day_progress(),
			)
		"work_pm":
			# No boost: coffee is a morning buff (it lifts work AM only).
			return Difficulty.triage_params(state.energy, cfg, 0, state.rank, _day_progress())
		"drive_home":
			return Difficulty.drive_home_params(state.energy, cfg)
		"cooking":
			return Difficulty.cooking_params(state.energy, cfg)
		"lunch":
			return Difficulty.listening_params(state.energy, cfg)
		"freetime":
			return Difficulty.temptation_params(state.energy, cfg, state.ledger.debt_minutes)
		"dinner":
			var walk := Difficulty.dinner_params(state.energy, cfg)
			walk["can_afford"] = state.wallet.savings >= cfg.takeout_price
			return walk
		"sleep":
			# The night was recorded when freetime ended, so both of these
			# read a ledger that already moved. Debt is stated ONCE, here,
			# in clock-minutes — never as a persistent gauge.
			var slept := float(cfg.morning_start_minutes) + 1440.0 - _bed_minute
			return {
				"bedtime": state.bedtime,
				"bed_clock": DayClock.format_minutes(int(_bed_minute)),
				"ledger": state.ledger.ledger_text(slept, cfg),
				"text_speed": cfg.typewriter_chars_per_sec,
				"hold": cfg.sleep_hold_time,
			}
		"coffee":
			var cup := Difficulty.cup_params(state.energy, cfg, _day_progress())
			cup["can_afford"] = state.wallet.savings >= cfg.coffee_price
			return cup
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


## The minigame only reports that a game finished — game.gd is the single
## spender of any DayClock (wave-3a invariant), same shape as skip_time_cost
## charging the fixed penalty for a ducked chore. Each game costs the clock
## freetime_game_minutes, so more games move the bed minute (issue #12).
func _on_game_played() -> void:
	clock.spend(cfg.freetime_game_minutes)


func _on_finished(result: Dictionary, slot: String, node: Node) -> void:
	node.queue_free()
	if slot == "retire_offer" and result.get("choice") == "retire":
		_show_ending()
		return
	if slot in SKIP_SLOTS and result.get("skipped", false):
		clock.spend(cfg.skip_time_cost)
	if slot == "drive":
		# The commute is the morning's till: whatever the clock overran by is
		# stamped on the result here, and StatEffects charges it below.
		result["overrun"] = clock.overrun()
		# Late is the drive's MISS (issue #17). Stamped, never charged again:
		# StatEffects leaves drive out of the loss cost, the debit is the bill.
		if clock.overrun() > 0.0:
			result["failed"] = true
	# Home past home_by is the drive home's MISS (#18), stamped the same way.
	# Its bill is the evening minutes already spent, which reach the bed
	# minute; StatEffects leaves drive_home out of the loss cost.
	if slot == "drive_home" and clock.elapsed > cfg.home_budget():
		result["failed"] = true
	if slot == "freetime":
		# Freetime is the evening's till, exactly as the commute is the
		# morning's: the clock stops here and what it reads becomes the night.
		result["band"] = clock.band_name()
		# The late band is free time's MISS (issue #17); the sleep ledger,
		# not the loss cost, is what it pays.
		if result["band"] == "late":
			result["failed"] = true
		_bed_minute = float(cfg.evening_start_minutes) + clock.elapsed
		result["bed_minute"] = _bed_minute
		_clock_running = false
	StatEffects.apply(slot, result, state, cfg)
	var verdict := Verdict.of(slot, result)
	if verdict == "":
		_continue_day(slot, result)
		return
	_verdicts.append(verdict)
	_strip_label.text = Verdict.strip(_verdicts)
	_stamp_label.text = verdict
	_stamp_label.add_theme_color_override("font_color", STAMP_COLORS[verdict])
	_stamp_label.visible = true
	_hold_stamp(_continue_day.bind(slot, result))


## The one place the stamp holds the day: `next` (whatever the finished game
## leads to, in or out of band) runs once stamp_hold_seconds of frames pass.
func _hold_stamp(next: Callable) -> void:
	_after_stamp = next
	_stamp_left = cfg.stamp_hold_seconds
	if _stamp_left <= 0.0:
		_release_stamp()


func _tick_stamp(delta: float) -> void:
	_stamp_left -= delta
	if _stamp_left <= 0.0:
		_release_stamp()


func _release_stamp() -> void:
	var next := _after_stamp
	_after_stamp = Callable()
	_stamp_label.visible = false
	next.call()


## Where a finished slot leads: the late beat, the pan, rank news, the next
## slot or the summary. Effects are already applied; this only routes.
func _continue_day(slot: String, result: Dictionary) -> void:
	if slot == "drive" and clock.overrun() > 0.0:
		_show_late_beat()
		return
	if slot == "dinner" and result.get("choice") == "cook":
		_show_cooking()
		return
	if slot == "work_pm":
		# QA ruling (issue #10 / finding 1): rank news lands right after
		# afternoon work, same day, at the office — not as morning-in-bed news
		# in the close-of-day summary.
		var rank_events := RankLadder.evaluate(state, cfg)
		if not rank_events.is_empty():
			_show_rank_news(rank_events)
			return
	if schedule.advance():
		_start_slot()
	else:
		_show_summary()


## Hosted OUTSIDE the normal slot schedule — schedule.advance() is never
## called for it, so schedule.current() stays "work_pm" while it's up. Its own
## finished signal resumes the normal advance()/_show_summary flow. One beat
## even with multiple events: every matching EVENT_COPY line is joined.
func _show_rank_news(rank_events: Array[String]) -> void:
	_day_label.text = "day %d — the office" % state.day
	var lines: Array[String] = []
	for event in rank_events:
		if EVENT_COPY.has(event):
			lines.append(EVENT_COPY[event])
	if rank_events.has("promoted") and state.rank == RankLadder.MAX_RANK:
		lines.append(SENIOR_TEASE)
	var node := _mount("warning")
	node.finished.connect(_on_out_of_band_beat_finished.bind(node), CONNECT_ONE_SHOT)
	node.setup({
		"text": "\n".join(lines),
		"text_speed": cfg.typewriter_chars_per_sec,
		"hold": cfg.sleep_hold_time,
	})


## Shared tail for every out-of-band beat (rank news, late arrival): the beat
## sat outside the schedule, so finishing it just resumes the day where the
## slot walk left off.
func _on_out_of_band_beat_finished(_result: Dictionary, node: Node) -> void:
	node.queue_free()
	if schedule.advance():
		_start_slot()
	else:
		_show_summary()


## Same out-of-band shape as _show_rank_news: advance() never runs for it, so
## schedule.current() stays "dinner" while the pan is up. Unlike a beat it
## finishes through the slot tail, _on_finished, because a dinner has effects
## to bank and a verdict to stamp. The clock keeps running, which IS the
## point — cooking is what takeout buys you out of.
func _show_cooking() -> void:
	_clock_running = true
	_day_label.text = "day %d — %s" % [state.day, SLOT_LABELS["cooking"]]
	var node := _mount("cooking")
	node.finished.connect(_on_finished.bind("cooking", node), CONNECT_ONE_SHOT)
	node.setup(_hosted_params("cooking"))


## Same out-of-band shape as _show_rank_news: advance() never runs for it, so
## schedule.current() stays "drive" while it's up. The clock stops first — the
## overrun is already banked into the drive result, so letting the HUD keep
## ticking behind this copy would be a lie.
func _show_late_beat() -> void:
	_clock_running = false
	_day_label.text = "day %d — the office" % state.day
	var node := _mount("warning")
	node.finished.connect(_on_out_of_band_beat_finished.bind(node), CONNECT_ONE_SHOT)
	node.setup({
		"text": LATE_COPY % clock.clock_text(cfg.morning_start_minutes),
		"text_speed": cfg.typewriter_chars_per_sec,
		"hold": cfg.sleep_hold_time,
	})


## Closes the day exactly once — close_day pays the salary and drains living
## costs, so it must never be called twice for one day. Rank news (promotion/
## demotion/warning) is not handled here — it's a same-day office beat fired
## right after work_pm (_show_rank_news), before this gets called.
func _show_summary() -> void:
	_clock_running = false
	var report := StatEffects.close_day(state, cfg)
	_update_score()
	var events: Array = report.events
	var lines: Array[String] = ["day %d done" % state.day]
	if events.has("sick_no_pay"):
		lines.append(EVENT_COPY["sick_no_pay"])
	else:
		lines.append("paid %d bone-bucks" % report.pay)
	lines.append("rent and kibble took %d" % report.cost)
	lines.append("work felt: %s" % _performance_word())
	lines.append("dog is %s" % DOG_STATES[Difficulty.clarity_tier(state.energy)])
	if not state.showered_today and not state.sick_today:
		lines.append(STINK_COPY)
	if Difficulty.is_sick_morning(_tomorrow_energy(), cfg):
		lines.append(WOBBLE_COPY)
	_summary.visible = true
	_summary_typer.play("\n".join(lines), cfg.typewriter_chars_per_sec)


## READ-ONLY projection of tomorrow's waking energy, so the summary can warn
## about a sick morning the night before. Mirrors GameState.start_next_day's
## formula exactly — any drift between the two is a bug.
func _tomorrow_energy() -> float:
	if state.sick_today:
		# The ceiling catches a sick recovery too — start_next_day clamps at its
		# tail, past both branches, so an absolute reset is still capped by the
		# week's debt (wave-3b). Mirroring only the OTHER clamp would leave the
		# telegraph silent on exactly the morning a sick dog cannot get up.
		return clampf(state.sick_recovery, 0.0, state.energy_ceiling)
	var leftover: float = state.energy
	var energy: float = cfg.energy_carry_weight * leftover \
			+ (1.0 - cfg.energy_carry_weight) * cfg.sleep_energy[state.bedtime]
	if not state.brushed_today:
		energy -= cfg.skip_brush_penalty
	if not state.showered_today:
		energy -= cfg.skip_shower_penalty
	return clampf(energy, 0.0, state.energy_ceiling)


func _show_ending() -> void:
	_clock_running = false
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
	_begin_day()


func _on_restart_pressed() -> void:
	# Stop the ending mid-line — otherwise it keeps typing into a hidden label.
	_ending_typer.skip()
	_ending_label.text = ""
	state = GameState.new()
	_ending.visible = false
	_begin_day()


## How far through today the current slot is, 0-1 (the speed ramp, #18).
func _day_progress() -> float:
	return Difficulty.day_progress(schedule.slots(), schedule.index())


## A fresh morning for whatever `state` is now: new clock, empty strip.
func _begin_day() -> void:
	clock = DayClock.new(cfg.morning_budget())
	_evening = false
	_bed_minute = float(cfg.bed_mid_line_minutes)
	_verdicts.clear()
	_strip_label.text = ""
	schedule.set_slots(DaySchedule.build(state, cfg))
	_start_slot()
