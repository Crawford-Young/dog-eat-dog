extends GutTest

## Scene-level pins of the minigame contract the host relies on: a game
## reports `finished` exactly once, a skip reports {score 0, skipped} once, and
## a finished game ignores input. Written against each game's own run flag
## before the flag moved into `Minigame`, so the move cannot change any of it.

const WAKE := "res://scenes/minigames/wake.tscn"
const BRUSH := "res://scenes/minigames/brush.tscn"
const SHOWER := "res://scenes/minigames/shower.tscn"
const BREAKFAST := "res://scenes/minigames/breakfast.tscn"
const TYPING := "res://scenes/minigames/typing.tscn"

const SKIPPABLE := [
	[BREAKFAST, {"window": 0.3, "speed": 1.6, "beats": 3}],
	[BRUSH, {"strokes_required": 6, "amplitude": 40.0}],
	[SHOWER, {"spots": 2, "revolutions": 2.0, "min_radius": 12.0}],
]


func _host(path: String, params: Dictionary) -> Node:
	var node: Node = load(path).instantiate()
	add_child_autofree(node)
	node.setup(params)
	watch_signals(node)
	return node


func _space() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_SPACE
	return event


func _type_char(node: Node, c: String) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.unicode = c.unicode_at(0)
	node._unhandled_key_input(event)


func _press_skip(node: Node) -> void:
	(node.get_node("SkipButton") as Button).pressed.emit()


func test_wake_finishes_once_when_its_done_frame_repeats() -> void:
	var node := _host(WAKE, {"mash_target": 2, "decay_per_sec": 0.0})
	node._unhandled_input(_space())
	node._unhandled_input(_space())
	node._process(0.016)
	node._process(0.016)
	assert_signal_emit_count(node, "finished", 1)
	assert_eq(get_signal_parameters(node, "finished"), [{"score": 1.0, "skipped": false}])


func test_brush_finishes_once_when_its_done_frame_repeats() -> void:
	var node := _host(BRUSH, {"strokes_required": 1, "amplitude": 40.0})
	node._tracker.stroke_count = 1
	node._process(0.016)
	node._process(0.016)
	assert_signal_emit_count(node, "finished", 1)
	assert_eq(get_signal_parameters(node, "finished"), [{"score": 1.0, "skipped": false}])


func test_skip_reports_a_zero_skipped_result_exactly_once(p = use_parameters(SKIPPABLE)) -> void:
	var node := _host(p[0], p[1])
	_press_skip(node)
	_press_skip(node)
	assert_signal_emit_count(node, "finished", 1)
	assert_eq(get_signal_parameters(node, "finished"), [{"score": 0.0, "skipped": true}])


func test_skip_after_a_finished_game_reports_nothing() -> void:
	var node := _host(BRUSH, {"strokes_required": 1, "amplitude": 40.0})
	node._tracker.stroke_count = 1
	node._process(0.016)
	_press_skip(node)
	assert_signal_emit_count(node, "finished", 1)
	assert_eq(get_signal_parameters(node, "finished"), [{"score": 1.0, "skipped": false}])


func test_a_skipped_breakfast_ignores_further_presses() -> void:
	var node := _host(BREAKFAST, {"window": 0.3, "speed": 1.6, "beats": 3})
	_press_skip(node)
	node._unhandled_input(_space())
	node._unhandled_input(_space())
	node._unhandled_input(_space())
	assert_eq(node._beats_done, 0, "a press after the skip must not count a beat")
	assert_signal_emit_count(node, "finished", 1)


func test_typing_does_not_finish_before_the_shift_ends() -> void:
	var node := _host(TYPING, {"tier": 4, "wrong_cap": 5, "shift_time": 100.0, "par_units": 3})
	await wait_process_frames(10)
	assert_signal_not_emitted(node, "finished")


func test_typing_finishes_once_at_shift_end_with_its_throughput_score() -> void:
	var node := _host(TYPING, {"tier": 4, "wrong_cap": 5, "shift_time": 0.25, "par_units": 2})
	for c in node._shift.target:
		_type_char(node, c)
	assert_eq(node._shift.units_done, 1, "precondition: one phrase of a par-2 shift typed")
	assert_signal_not_emitted(node, "finished", "the shift has not run out yet")
	await wait_for_signal(node.finished, 5.0)
	await wait_process_frames(5)
	assert_signal_emit_count(node, "finished", 1)
	assert_eq(get_signal_parameters(node, "finished"), [{"score": 0.5, "skipped": false}])


func test_typing_ignores_keys_after_the_shift_ends() -> void:
	var node := _host(TYPING, {"tier": 4, "wrong_cap": 5, "shift_time": 0.1, "par_units": 3})
	await wait_for_signal(node.finished, 5.0)
	_type_char(node, node._shift.target[0])
	assert_eq(node._shift.session.typed_count, 0, "a key after the shift must not type")
	assert_signal_emit_count(node, "finished", 1)
