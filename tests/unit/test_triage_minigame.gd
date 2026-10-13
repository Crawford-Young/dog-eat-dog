extends GutTest

## Node-level coverage for work PM's inbox triage (issue #18): the A/D key
## filter in front of TriageSession, the session ticking with the frame, the
## shift timer ending it, the art slots and the public accessor the autoplay
## bot reads. The session's own rules are test_triage_session.gd; the
## finish/loss contract sits with the other games in test_minigame_contract.gd
## and test_minigame_losses.gd.

const TriageScene := preload("res://scenes/minigames/triage.tscn")
const LONG := {
	"tier": 4, "read_delay": 0.0, "shift_time": 100.0, "window": 100.0,
	"gap": 100.0, "jitter": 0.0, "speed": 1.0, "fail_score": 0.5,
}
## Holds no art, so every slot draws its emoji placeholder.
const NO_ART_ROOT := "res://tests/fixtures/props/none"


func _minigame(overrides := {}) -> Minigame:
	var params := LONG.duplicate()
	params.merge(overrides, true)
	var node: Minigame = TriageScene.instantiate()
	node.props_root = NO_ART_ROOT
	add_child_autofree(node)
	node.setup(params)
	return node


func _key(node: Minigame, keycode: Key, pressed := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	node._unhandled_key_input(event)


## The key that files the top email correctly (A reply, D trash).
func _right_key(node: Minigame) -> Key:
	return KEY_A if TriageSession.is_work(node.session().front_icon()) else KEY_D


func _wrong_key(node: Minigame) -> Key:
	return KEY_D if _right_key(node) == KEY_A else KEY_A


func _label_text(slot: Control) -> String:
	assert_eq(slot.get_child_count(), 1, "%s holds one piece of art" % slot.name)
	var art := slot.get_child(0) as Label
	assert_not_null(art, "%s: no PNG, so the placeholder draws" % slot.name)
	return art.text if art else ""


func test_the_scene_instantiates_and_runs() -> void:
	var node := _minigame()
	assert_true(node.is_running())
	assert_eq(node.session().inbox_size(), 1, "an email is waiting from the start")


func test_the_right_key_files_the_email_correctly() -> void:
	var node := _minigame()
	_key(node, _right_key(node))
	assert_eq(node.session().correct, 1)
	assert_eq(node.session().inbox_size(), 0)


func test_the_wrong_key_files_the_email_wrongly() -> void:
	var node := _minigame()
	_key(node, _wrong_key(node))
	assert_eq(node.session().wrong, 1)


func test_a_sorts_reply_and_d_sorts_trash() -> void:
	var kinds := {}
	for seed_value in 30:
		var node := _minigame({"rng": RngSource.seeded(seed_value).next_rng()})
		var work := TriageSession.is_work(node.session().front_icon())
		kinds[work] = true
		_key(node, KEY_A if work else KEY_D)
		assert_eq(node.session().correct, 1, "seed %d: %s" % [seed_value, "reply" if work else "trash"])
		node.queue_free()
	assert_eq(kinds.size(), 2, "both kinds turned up")


func test_the_arrow_keys_sort_too() -> void:
	var node := _minigame()
	var work := TriageSession.is_work(node.session().front_icon())
	_key(node, KEY_LEFT if work else KEY_RIGHT)
	assert_eq(node.session().correct, 1)


func test_echoes_releases_and_other_keys_do_not_sort() -> void:
	var node := _minigame()
	_key(node, _right_key(node), true, true)
	_key(node, _right_key(node), false)
	_key(node, KEY_SPACE)
	_key(node, KEY_SHIFT)
	assert_eq(node.session().emails_shown(), 0)


func test_a_mouse_event_does_not_sort() -> void:
	var node := _minigame()
	var click := InputEventMouseButton.new()
	click.pressed = true
	node._unhandled_key_input(click)
	assert_eq(node.session().emails_shown(), 0)


func test_the_inbox_runs_with_the_frames() -> void:
	var node := _minigame()
	var full: float = node.session().front_time_left()
	await wait_process_frames(5)
	assert_lt(node.session().front_time_left(), full, "the frame ticks the session")


func test_the_shift_timer_is_the_countdown() -> void:
	var node := _minigame()
	assert_true(node.has_countdown(), "the host's timer bar reads the shift")
	assert_almost_eq(node.time_left(), 100.0, 0.1)


func test_mail_piles_up_while_the_dog_sits_idle() -> void:
	var node := _minigame({"gap": 0.05, "capacity": 100})
	await wait_seconds(0.3)
	assert_gt(node.session().inbox_size(), 2)
	assert_eq(node.get_node("%PileRow").get_child_count(), node.session().inbox_size() - 1,
			"the pile shows the waiting emails behind the top one")


func test_a_full_inbox_fills_the_pile() -> void:
	var node := _minigame({"gap": TriageSession.MIN_GAP, "capacity": 5})
	await wait_seconds(0.5)
	assert_gt(node.session().buried, 0, "precondition: the inbox overflowed")
	assert_eq(node.get_node("%PileRow").get_child_count(), 4)


func test_the_desk_props_draw_through_their_art_slots() -> void:
	var node := _minigame()
	assert_eq(_label_text(node.get_node("%MonitorSlot")), node.MONITOR_PLACEHOLDER)
	assert_eq(_label_text(node.get_node("%ReplySlot")), node.REPLY_PLACEHOLDER)
	assert_eq(_label_text(node.get_node("%TrashSlot")), node.TRASH_PLACEHOLDER)
	assert_lt(node.get_node("%MonitorSlot").get_index(), node.get_node("%EmailSlot").get_index(),
			"the email draws over the monitor")


func test_the_top_email_draws_its_icon_through_its_slot() -> void:
	var node := _minigame()
	var icon: int = node.session().front_icon()
	assert_eq(_label_text(node.get_node("%EmailSlot")), node.ICONS[icon][1])


func test_six_distinct_icons_three_work_three_junk() -> void:
	var node := _minigame()
	assert_eq(node.ICONS.size(), TriageSession.ICON_COUNT)
	var names := {}
	var glyphs := {}
	for entry in node.ICONS:
		names[entry[0]] = true
		glyphs[entry[1]] = true
	assert_eq(names.size(), 6, "six art slots")
	assert_eq(glyphs.size(), 6, "six placeholders a player can tell apart")


func test_the_email_slot_follows_the_top_email() -> void:
	var node := _minigame({"gap": 0.05})
	await wait_seconds(0.2)
	_key(node, _right_key(node))
	await wait_process_frames(1)
	var icon: int = node.session().front_icon()
	assert_eq(_label_text(node.get_node("%EmailSlot")), node.ICONS[icon][1])


func test_an_empty_inbox_shows_no_email() -> void:
	var node := _minigame()
	_key(node, _right_key(node))
	await wait_process_frames(1)
	assert_eq(node.get_node("%EmailSlot").get_child_count(), 0)


func test_the_top_email_is_faint_until_it_reads() -> void:
	var node := _minigame({"read_delay": 100.0})
	var slot: Control = node.get_node("%EmailSlot")
	assert_lt(slot.modulate.a, 0.5, "a blurred subject is faint")
	_key(node, _right_key(node))
	assert_eq(node.session().emails_shown(), 0, "and cannot be sorted yet")
	var sharp := _minigame()
	assert_almost_eq((sharp.get_node("%EmailSlot") as Control).modulate.a, 1.0, 0.0001)


func test_the_controls_never_eat_a_click() -> void:
	var node := _minigame({"gap": 0.05})
	await wait_seconds(0.2)
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		stack.append_array(current.get_children())
		if current is Control and not current is Button:
			assert_eq((current as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
					"%s is mouse-transparent" % current.name)
