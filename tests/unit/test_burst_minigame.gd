extends GutTest

## Node-level coverage for work AM's word burst (issue #18): the key filter in
## front of BurstSession, the session ticking with the frame, the shift timer
## ending it and the public accessor the autoplay bot reads. The session's own
## rules are test_burst_session.gd; the finish/loss contract sits with the
## other games in test_minigame_contract.gd and test_minigame_losses.gd.

const BurstScene := preload("res://scenes/minigames/burst.tscn")
const LONG := {"tier": 4, "shift_time": 100.0, "window": 100.0, "speed": 1.0, "fail_score": 0.5}
## Holds no art, so every slot draws its emoji placeholder.
const NO_ART_ROOT := "res://tests/fixtures/props/none"


func _minigame(params := LONG) -> Minigame:
	var node: Minigame = BurstScene.instantiate()
	node.props_root = NO_ART_ROOT
	add_child_autofree(node)
	node.setup(params)
	return node


func _key_event(keycode: Key, unicode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.unicode = unicode
	return event


func _type(node: Minigame, c: String) -> void:
	node._unhandled_key_input(_key_event(KEY_NONE, c.unicode_at(0)))


func test_the_scene_instantiates_and_runs() -> void:
	var node := _minigame()
	assert_true(node.is_running())
	assert_gt(node.session().word.length(), 0, "a word is on screen from the start")


func test_a_modifier_keydown_is_not_a_wrong_key() -> void:
	var node := _minigame()
	node._unhandled_key_input(_key_event(KEY_SHIFT, 0))
	assert_eq(node.session().errors, 0, "a bare modifier must not register as a wrong key")
	assert_eq(node.session().typed_count, 0)


func test_an_echo_does_not_type() -> void:
	var node := _minigame()
	var event := _key_event(KEY_NONE, node.session().word.unicode_at(0))
	event.echo = true
	node._unhandled_key_input(event)
	assert_eq(node.session().typed_count, 0)


func test_a_printable_key_types_into_the_word() -> void:
	var node := _minigame()
	_type(node, node.session().word[0])
	assert_eq(node.session().typed_count, 1)


func test_typing_a_whole_word_scores_it() -> void:
	var node := _minigame()
	for c in node.session().remaining():
		_type(node, c)
	assert_eq(node.session().words_typed, 1)


func test_a_wrong_key_is_counted_and_typing_carries_on() -> void:
	var node := _minigame()
	var word: String = node.session().word
	_type(node, "z" if word[0] != "z" else "q")
	assert_eq(node.session().errors, 1)
	_type(node, word[0])
	assert_eq(node.session().typed_count, 1)


func test_the_word_window_runs_down_with_the_frames() -> void:
	var node := _minigame()
	var full: float = node.session().time_left()
	await wait_process_frames(5)
	assert_lt(node.session().time_left(), full, "the frame ticks the session")


func test_the_shift_timer_is_the_countdown() -> void:
	var node := _minigame()
	assert_true(node.has_countdown(), "the host's timer bar reads the shift")
	assert_almost_eq(node.time_left(), 100.0, 0.1)


func test_words_expire_while_the_dog_sits_idle() -> void:
	var params := LONG.duplicate()
	params.window = 0.05
	var node := _minigame(params)
	await wait_seconds(0.3)
	assert_gt(node.session().words_missed, 0)


func test_the_monitor_draws_through_its_art_slot() -> void:
	var node := _minigame()
	var slot: Control = node.get_node("%MonitorSlot")
	assert_eq(slot.get_child_count(), 1, "one monitor in the slot")
	var art := slot.get_child(0) as Label
	assert_not_null(art, "no work_am/monitor.png: the placeholder draws")
	assert_eq(art.text, node.MONITOR_PLACEHOLDER)
	assert_eq(art.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_lt(slot.get_index(), node.get_node("%WordText").get_index(),
			"the word draws over the monitor")


func test_the_controls_never_eat_a_click() -> void:
	var node := _minigame()
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		stack.append_array(current.get_children())
		if current is Control and not current is Button:
			assert_eq((current as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
					"%s is mouse-transparent" % current.name)
