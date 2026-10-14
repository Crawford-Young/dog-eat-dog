class_name Minigame
extends Control

## Base contract every minigame scene implements.
## Host calls setup(params), listens for finished(result).
##
## The base owns the run flag, finish-once, the
## SkipButton handler, a countdown and the loss gag. A game calls _start() (or
## _start(params), to honour a "time_limit") at the end of its setup(), gates
## input and per-frame play on _running, and ends through _finish()/
## _finish_with() or loses through _fail(gag) — each reports at most once per
## game, and every result carries score, skipped and failed.

signal finished(result: Dictionary)

## Mirrors BalanceConfig.fail_gag_seconds, for a host that passes no params.
const DEFAULT_FAIL_GAG_SECONDS := 1.5
const GAG_FONT := PropArt.EMOJI_FONT
const GAG_FONT_SIZE := 160
## The gag pops from this fraction of full size over this many seconds.
const GAG_START_SCALE := 0.4
const GAG_POP_SECONDS := 0.25

## True from _start() until the game finishes; never true again after that.
## The dev autoplay bot reads it through the public `is_running()`.
var _running: bool = false
var _finished: bool = false
var _countdown_total: float = 0.0
var _countdown_left: float = 0.0
var _counting: bool = false
var _fail_gag_seconds: float = DEFAULT_FAIL_GAG_SECONDS
## Seconds left on a loss gag; > 0 only between _fail() and its report.
var _gag_left: float = 0.0
var _gag_result: Dictionary = {}
## Where art slots are read from; tests point it at a fixture root.
var props_root: String = PropArt.ROOT


func setup(_params: Dictionary) -> void:
	pass


func is_running() -> bool:
	return _running


## Marks the game live. A no-op once it has finished. A "time_limit" > 0 in
## params starts the countdown; "fail_gag_seconds" sets the loss gag length.
func _start(params := {}) -> void:
	if _finished:
		return
	_running = true
	_fail_gag_seconds = params.get("fail_gag_seconds", DEFAULT_FAIL_GAG_SECONDS)
	var limit: float = params.get("time_limit", 0.0)
	if limit > 0.0:
		_start_countdown(limit)


## Starts (or restarts) a countdown of `seconds`; _on_timeout() fires once when
## it runs out. Ticks on internal process, so a subclass's own _process — which
## in Godot 4 replaces, not extends, the base's — cannot stop it.
func _start_countdown(seconds: float) -> void:
	_countdown_total = seconds
	_countdown_left = seconds
	_set_counting(true)


## Seconds left on the countdown, never below zero; 0 with no countdown.
func time_left() -> float:
	return maxf(_countdown_left, 0.0)


## Countdown left as a 1 -> 0 fraction; 0 with no countdown.
func time_fraction() -> float:
	if _countdown_total <= 0.0:
		return 0.0
	return clampf(_countdown_left / _countdown_total, 0.0, 1.0)


## True while a countdown runs or still has time on it — what a host timer bar
## shows. False with no countdown, or once it has run out.
func has_countdown() -> bool:
	return _counting or time_fraction() > 0.0


## True only while a lost game plays its gag, before the result reports. The
## host pauses the DayClock on it: the gag is presentation, not time spent.
func is_gagging() -> bool:
	return _gag_left > 0.0


## Called once when the countdown runs out. Override to end the game.
func _on_timeout() -> void:
	pass


## Both the countdown and the gag tick here, on internal process.
func _notification(what: int) -> void:
	if what != NOTIFICATION_INTERNAL_PROCESS:
		return
	var delta := get_process_delta_time()
	if _gag_left > 0.0:
		_gag_left -= delta
		if _gag_left <= 0.0:
			_gag_left = 0.0
			_sync_internal_process()
			_emit_result(_gag_result)
		return
	if not _counting:
		return
	_countdown_left -= delta
	if _countdown_left <= 0.0:
		_set_counting(false)
		_on_timeout()


func _set_counting(on: bool) -> void:
	_counting = on
	_sync_internal_process()


func _sync_internal_process() -> void:
	set_process_internal(_counting or _gag_left > 0.0)


## Every skippable scene connects its SkipButton here.
func _on_skip_pressed() -> void:
	if _running:
		_finish(0.0, true)


func _finish(score: float, skipped: bool = false) -> void:
	_finish_with({"score": clampf(score, 0.0, 1.0), "skipped": skipped})


## Reports `extra` merged over a full, unskipped, unfailed result — once per
## game, and never while a loss gag is playing.
func _finish_with(extra: Dictionary) -> void:
	if _finished:
		return
	_close()
	_emit_result(extra)


## Loses the game: input, skip and the countdown go dead now, `gag` (emoji)
## pops up centred, and after fail_gag_seconds the game reports a failed zero
## with `extra` merged over it. Once per game, like a finish.
func _fail(gag: String, extra := {}) -> void:
	if _finished:
		return
	_close()
	_gag_result = {"score": 0.0, "failed": true}
	_gag_result.merge(extra, true)
	_show_gag(gag)
	_gag_left = maxf(_fail_gag_seconds, 0.001)
	_sync_internal_process()


func _close() -> void:
	_finished = true
	_running = false
	if _counting:
		_set_counting(false)


func _emit_result(extra: Dictionary) -> void:
	var result := {"score": 1.0, "skipped": false, "failed": false}
	result.merge(extra, true)
	finished.emit(result)


## The game's own play detail for its probe line (#18 step 12), read by the
## host once the game finishes. Override to report what the game already
## tracks; read-only, never a gameplay input. Empty by default.
func probe_detail() -> Dictionary:
	return {}


## The game's art folder under assets/props (`props/<folder>/gag.png` draws
## the loss gag). Each losable game overrides it; "" draws only the emoji.
func _art_folder() -> String:
	return ""


## One of the game's art slots, sized to fill the parent it is added to:
## props/<folder>/<slot>.png when present, else `placeholder` centred at
## `font_size` (in `font` when given, else the label's own font over
## Twemoji). PropArt makes it mouse-transparent either way.
func _prop(slot: String, placeholder: String, font_size: int, font: Font = null) -> Control:
	var art := PropArt.make(_art_folder(), slot, placeholder, props_root, font)
	if art is Label:
		var label := art as Label
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", font_size)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return art


## Pops the game's gag.png when present, else the `gag` emoji, full size over
## Twemoji — centred, mouse-transparent.
func _show_gag(gag: String) -> void:
	var art := _prop("gag", gag, GAG_FONT_SIZE, GAG_FONT)
	add_child(art)
	art.pivot_offset = size / 2.0
	art.scale = Vector2.ONE * GAG_START_SCALE
	var pop := art.create_tween()
	pop.tween_property(art, "scale", Vector2.ONE, GAG_POP_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
