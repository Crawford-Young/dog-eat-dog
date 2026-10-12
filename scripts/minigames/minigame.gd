class_name Minigame
extends Control

## Base contract every minigame scene implements.
## Host calls setup(params), listens for finished(result).
##
## The base owns the run flag, finish-once, the
## SkipButton handler and a countdown. A game calls _start() at the end of its
## setup(), gates input and per-frame play on _running, and ends through
## _finish()/_finish_with(), which report at most once per game.

signal finished(result: Dictionary)

## True from _start() until the game finishes; never true again after that.
## Read by name (`get("_running")`) by the dev autoplay bot.
var _running: bool = false
var _finished: bool = false
var _countdown_total: float = 0.0
var _countdown_left: float = 0.0
var _counting: bool = false


func setup(_params: Dictionary) -> void:
	pass


func is_running() -> bool:
	return _running


## Marks the game live. A no-op once it has finished.
func _start() -> void:
	if not _finished:
		_running = true


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


## Called once when the countdown runs out. Override to end the game.
func _on_timeout() -> void:
	pass


func _notification(what: int) -> void:
	if what != NOTIFICATION_INTERNAL_PROCESS or not _counting:
		return
	_countdown_left -= get_process_delta_time()
	if _countdown_left <= 0.0:
		_set_counting(false)
		_on_timeout()


func _set_counting(on: bool) -> void:
	_counting = on
	set_process_internal(on)


## Every skippable scene connects its SkipButton here.
func _on_skip_pressed() -> void:
	if _running:
		_finish(0.0, true)


func _finish(score: float, skipped: bool = false) -> void:
	_finish_with({"score": clampf(score, 0.0, 1.0), "skipped": skipped})


## Reports `extra` merged over a full, unskipped result — once per game.
func _finish_with(extra: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	_running = false
	if _counting:
		_set_counting(false)
	var result := {"score": 1.0, "skipped": false}
	result.merge(extra, true)
	finished.emit(result)
