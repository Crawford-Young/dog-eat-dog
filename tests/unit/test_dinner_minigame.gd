extends GutTest

## Node-level coverage for dinner as a walk (issue #18): the A/D (and arrow)
## filter in front of DinnerSession, the dog riding the frame, the result each
## end reports, the timeout's sad kibble, the broke dog's greyed phone, the art
## slots and the public accessor the autoplay bot reads. The session's own
## rules are test_dinner_session.gd.

const DinnerScene := preload("res://scenes/minigames/dinner.tscn")
## A slow dog in the middle of the floor with all the time in the world, so the
## test decides where it goes.
const PARKED := {"speed": 0.5, "start": 0.5, "time_limit": 100.0, "fail_gag_seconds": 0.05}
## A dog that crosses the floor in a frame or two.
const FAST := {"speed": 100.0}
## Holds no art, so every slot draws its emoji placeholder.
const NO_ART_ROOT := "res://tests/fixtures/props/none"
const WAIT := 0.3


func _minigame(overrides := {}) -> Minigame:
	var params := PARKED.duplicate()
	params.merge(overrides, true)
	var node: Minigame = DinnerScene.instantiate()
	node.props_root = NO_ART_ROOT
	add_child_autofree(node)
	watch_signals(node)
	node.setup(params)
	return node


func _key(node: Minigame, keycode: Key, pressed := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	node._unhandled_input(event)


func _result(node: Minigame) -> Dictionary:
	return get_signal_parameters(node, "finished")[0]


func _label_text(slot: Control) -> String:
	assert_eq(slot.get_child_count(), 1, "%s holds one piece of art" % slot.name)
	var art := slot.get_child(0) as Label
	assert_not_null(art, "%s: no PNG, so the placeholder draws" % slot.name)
	return art.text if art else ""


func test_the_scene_instantiates_runs_and_is_timed() -> void:
	var node := _minigame()
	assert_true(node.is_running())
	assert_true(node.session() is DinnerSession)
	assert_true(node.has_countdown(), "the walk is against the clock")
	assert_almost_eq(node.session().position(), PARKED.start, 0.0001)


func test_holding_d_walks_toward_the_phone_and_letting_go_stops() -> void:
	var node := _minigame()
	_key(node, KEY_D)
	await wait_process_frames(3)
	var walked: float = node.session().position()
	assert_gt(walked, PARKED.start, "D walks right")
	_key(node, KEY_D, false)
	await wait_process_frames(3)
	assert_almost_eq(node.session().position(), walked, 0.0001, "letting go stands still")


func test_holding_a_walks_toward_the_pan() -> void:
	var node := _minigame()
	_key(node, KEY_A)
	await wait_process_frames(3)
	assert_lt(node.session().position(), PARKED.start)


func test_the_arrow_keys_walk_too() -> void:
	var node := _minigame()
	_key(node, KEY_LEFT)
	assert_eq(node.session().heading(), -1)
	_key(node, KEY_LEFT, false)
	_key(node, KEY_RIGHT)
	assert_eq(node.session().heading(), 1)


func test_both_ways_at_once_stands_still_and_the_one_left_held_wins() -> void:
	var node := _minigame()
	_key(node, KEY_A)
	_key(node, KEY_D)
	assert_eq(node.session().heading(), 0, "pulled both ways, the dog stands")
	_key(node, KEY_A, false)
	assert_eq(node.session().heading(), 1, "D is still held")


func test_echoes_and_other_keys_do_not_walk() -> void:
	var node := _minigame()
	_key(node, KEY_SPACE)
	_key(node, KEY_W)
	_key(node, KEY_D, true, true)
	node._unhandled_input(InputEventMouseMotion.new())
	assert_eq(node.session().heading(), 0)


func test_reaching_the_pan_cooks() -> void:
	var node := _minigame(FAST)
	_key(node, KEY_A)
	await wait_process_frames(3)
	assert_signal_emit_count(node, "finished", 1)
	assert_eq(_result(node), {"score": 1.0, "skipped": false, "failed": false, "choice": "cook"})
	assert_false(node.is_running())


func test_reaching_the_phone_orders_takeout() -> void:
	var node := _minigame(FAST)
	_key(node, KEY_D)
	await wait_process_frames(3)
	assert_signal_emit_count(node, "finished", 1)
	assert_eq(_result(node), {"score": 1.0, "skipped": false, "failed": false, "choice": "takeout"})


func test_keys_after_dinner_is_decided_do_nothing() -> void:
	var node := _minigame(FAST)
	_key(node, KEY_A)
	await wait_process_frames(3)
	_key(node, KEY_A, false)
	_key(node, KEY_D)
	await wait_process_frames(3)
	assert_signal_emit_count(node, "finished", 1)


func test_running_out_of_time_is_the_sad_kibble() -> void:
	var node := _minigame({"time_limit": 0.05})
	await wait_seconds(WAIT)
	assert_signal_emit_count(node, "finished", 1)
	assert_eq(_result(node), {"score": 0.0, "skipped": false, "failed": true},
			"no choice: neither the pan nor the phone")


func test_the_kibble_gag_draws_through_the_dinner_folder_and_kills_the_keys() -> void:
	var node := _minigame({"time_limit": 0.05, "fail_gag_seconds": 100.0})
	assert_eq(node._art_folder(), "dinner")
	await wait_seconds(WAIT)
	assert_true(node.is_gagging())
	var gag := false
	for child in node.get_children():
		gag = gag or (child is Label and (child as Label).text == node.FAIL_GAG)
	assert_true(gag, "the sad kibble pops")
	_key(node, KEY_A)
	assert_eq(node.session().heading(), 0, "a lost walk goes dead to the keys")


func test_a_broke_dog_at_the_phone_gets_nothing_and_can_still_cook() -> void:
	var node := _minigame({"can_afford": false, "speed": 100.0})
	_key(node, KEY_D)
	await wait_process_frames(3)
	assert_signal_emit_count(node, "finished", 0, "the phone does nothing")
	_key(node, KEY_D, false)
	_key(node, KEY_A)
	await wait_process_frames(3)
	assert_eq(_result(node).choice, "cook")


func test_a_broke_dogs_phone_is_greyed_out() -> void:
	var broke := _minigame({"can_afford": false})
	var flush := _minigame()
	assert_eq(flush.get_node("%PhoneSlot").modulate, Color.WHITE, "an affordable phone is drawn as is")
	assert_ne(broke.get_node("%PhoneSlot").modulate, Color.WHITE, "a phone out of reach is greyed")
	assert_ne(broke.get_node("%Hint").text, flush.get_node("%Hint").text, "and says why")


func test_the_dog_rides_the_floor_with_the_session() -> void:
	var node := _minigame()
	var dog: Control = node.get_node("%DogSlot")
	assert_almost_eq(dog.anchor_left, PARKED.start, 0.0001, "drawn where it starts")
	_key(node, KEY_D)
	await wait_process_frames(3)
	assert_almost_eq(dog.anchor_left, node.session().position(), 0.02,
			"the dog is drawn where the session has it")


func test_the_props_draw_through_their_art_slots() -> void:
	var node := _minigame()
	assert_eq(_label_text(node.get_node("%DogSlot")), node.DOG_PLACEHOLDER)
	assert_eq(_label_text(node.get_node("%PanSlot")), node.PAN_PLACEHOLDER)
	assert_eq(_label_text(node.get_node("%PhoneSlot")), node.PHONE_PLACEHOLDER)


func test_the_shipped_params_run_the_scene_and_an_unstated_dog_is_a_rich_one() -> void:
	var node: Minigame = DinnerScene.instantiate()
	add_child_autofree(node)
	node.setup(Difficulty.dinner_params(50.0, BalanceConfig.new()))
	assert_true(node.session().can_afford())
	assert_true(node.has_countdown())
