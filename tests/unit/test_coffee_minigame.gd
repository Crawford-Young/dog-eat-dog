extends GutTest

## Node-level coverage for the coffee cart's cup grab (issue #18): the SPACE /
## click filter in front of CoffeeSession, the cup riding the frame, the result
## each outcome reports, the broke dog's greyed cup, the art slots and the
## public accessor the autoplay bot reads. The session's own rules are
## test_coffee_session.gd.

const CoffeeScene := preload("res://scenes/minigames/coffee.tscn")
## A slow cup that waits far off screen, so the test decides where it is.
const PARKED := {
	"speed": 0.5, "lead": 1000.0, "zone_center": 0.6, "zone_width": 0.2,
	"fail_gag_seconds": 0.05,
}
## Holds no art, so every slot draws its emoji placeholder.
const NO_ART_ROOT := "res://tests/fixtures/props/none"
const WAIT := 0.3


func _minigame(overrides := {}) -> Minigame:
	var params := PARKED.duplicate()
	params.merge(overrides, true)
	var node: Minigame = CoffeeScene.instantiate()
	node.props_root = NO_ART_ROOT
	add_child_autofree(node)
	watch_signals(node)
	node.setup(params)
	return node


## Moves the cup to the zone's centre.
func _to_zone(node: Minigame) -> void:
	node.session().tick(node.session().seconds_to_zone())


func _key(node: Minigame, keycode: Key, pressed := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	node._unhandled_input(event)


func _click(node: Minigame, button := MOUSE_BUTTON_LEFT, pressed := true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	node._unhandled_input(event)


func _result(node: Minigame) -> Dictionary:
	return get_signal_parameters(node, "finished")[0]


func _label_text(slot: Control) -> String:
	assert_eq(slot.get_child_count(), 1, "%s holds one piece of art" % slot.name)
	var art := slot.get_child(0) as Label
	assert_not_null(art, "%s: no PNG, so the placeholder draws" % slot.name)
	return art.text if art else ""


func test_the_scene_instantiates_and_runs() -> void:
	var node := _minigame()
	assert_true(node.is_running())
	assert_true(node.session() is CoffeeSession)
	assert_false(node.has_countdown(), "the cup passing is the clock; no timer bar")


func test_space_in_the_zone_buys_the_coffee() -> void:
	var node := _minigame()
	_to_zone(node)
	_key(node, KEY_SPACE)
	assert_signal_emit_count(node, "finished", 1)
	assert_eq(_result(node), {"score": 1.0, "skipped": false, "failed": false, "choice": "buy"})


func test_a_click_in_the_zone_buys_the_coffee() -> void:
	var node := _minigame()
	_to_zone(node)
	_click(node)
	assert_eq(_result(node).choice, "buy")


func test_a_press_off_the_cup_spills_it() -> void:
	var node := _minigame()
	_key(node, KEY_SPACE)
	assert_signal_emit_count(node, "finished", 0, "the spill plays its gag first")
	assert_true(node.is_gagging())
	await wait_seconds(WAIT)
	assert_signal_emit_count(node, "finished", 1)
	assert_eq(_result(node), {"score": 0.0, "skipped": false, "failed": true, "choice": "spill"})


func test_a_click_off_the_cup_spills_it() -> void:
	var node := _minigame()
	_click(node)
	await wait_seconds(WAIT)
	assert_eq(_result(node).choice, "spill")


func test_the_spill_gag_is_a_coffee_spill_through_the_coffee_folder() -> void:
	var node := _minigame()
	assert_eq(node._art_folder(), "coffee")
	_key(node, KEY_SPACE)
	var gag := false
	for child in node.get_children():
		gag = gag or (child is Label and (child as Label).text == node.FAIL_GAG)
	assert_true(gag, "the spill gag pops")


func test_a_cup_left_alone_passes_as_a_water_choice_not_a_skip() -> void:
	var node := _minigame({"lead": 0.0, "speed": 100.0})
	await wait_process_frames(3)
	assert_signal_emit_count(node, "finished", 1)
	assert_eq(_result(node), {"score": 1.0, "skipped": false, "failed": false, "choice": "skip"})
	assert_false(node.is_running())


func test_a_press_after_a_grab_does_nothing_more() -> void:
	var node := _minigame()
	_to_zone(node)
	_key(node, KEY_SPACE)
	_key(node, KEY_SPACE)
	_click(node)
	assert_signal_emit_count(node, "finished", 1)


func test_releases_echoes_other_keys_and_other_buttons_do_not_grab() -> void:
	var node := _minigame()
	_to_zone(node)
	_key(node, KEY_SPACE, false)
	_key(node, KEY_SPACE, true, true)
	_key(node, KEY_ENTER)
	_key(node, KEY_A)
	_click(node, MOUSE_BUTTON_RIGHT)
	_click(node, MOUSE_BUTTON_LEFT, false)
	node._unhandled_input(InputEventMouseMotion.new())
	assert_eq(node.session().outcome(), "", "none of those was a grab")
	assert_signal_emit_count(node, "finished", 0)


func test_a_broke_dog_cannot_grab_and_the_cup_passes() -> void:
	var node := _minigame({"can_afford": false, "lead": 0.0, "speed": 100.0})
	_to_zone(node)
	_key(node, KEY_SPACE)
	_click(node)
	assert_signal_emit_count(node, "finished", 0, "presses do nothing")
	await wait_process_frames(3)
	assert_eq(_result(node).choice, "skip")
	assert_false(_result(node).failed)


func test_a_broke_dogs_cup_is_greyed_out() -> void:
	var broke := _minigame({"can_afford": false})
	var flush := _minigame()
	var cup: Control = flush.get_node("%CupSlot")
	assert_eq(cup.modulate, Color.WHITE, "an affordable cup is drawn as is")
	assert_ne(broke.get_node("%CupSlot").modulate, Color.WHITE, "a cup out of reach is greyed")
	assert_ne(broke.get_node("%Hint").text, flush.get_node("%Hint").text, "and says why")


func test_the_cup_is_off_screen_until_it_enters() -> void:
	var node := _minigame()
	assert_false(node.get_node("%CupSlot").visible)
	node.session().tick(PARKED.lead)
	await wait_process_frames(1)
	assert_true(node.get_node("%CupSlot").visible)


func test_the_cup_rides_the_track_with_the_session() -> void:
	var node := _minigame()
	_to_zone(node)
	await wait_process_frames(1)
	var cup: Control = node.get_node("%CupSlot")
	assert_almost_eq(cup.anchor_left, node.session().position(), 0.02,
			"the cup is drawn where the session has it")
	assert_almost_eq(cup.anchor_left, PARKED.zone_center, 0.02)


func test_the_cup_runs_with_the_frames() -> void:
	var node := _minigame({"lead": 0.0})
	var start: float = node.session().position()
	await wait_process_frames(5)
	assert_gt(node.session().position(), start)


func test_the_zone_is_drawn_where_the_session_grabs() -> void:
	var node := _minigame()
	var zone: Control = node.get_node("%Zone")
	assert_almost_eq(zone.anchor_left, PARKED.zone_center - PARKED.zone_width / 2.0, 0.0001)
	assert_almost_eq(zone.anchor_right, PARKED.zone_center + PARKED.zone_width / 2.0, 0.0001)


func test_the_props_draw_through_their_art_slots() -> void:
	var node := _minigame()
	assert_eq(_label_text(node.get_node("%CupSlot")), node.CUP_PLACEHOLDER)
	assert_eq(_label_text(node.get_node("%DeskSlot")), node.DESK_PLACEHOLDER)
	assert_eq(_label_text(node.get_node("%PawSlot")), node.PAW_PLACEHOLDER)


func test_the_shipped_params_run_the_scene_and_an_unstated_dog_is_a_rich_one() -> void:
	var node: Minigame = CoffeeScene.instantiate()
	add_child_autofree(node)
	node.setup(Difficulty.cup_params(50.0, BalanceConfig.new()))
	assert_true(node.session().can_afford())
